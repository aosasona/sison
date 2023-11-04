import jsorm/pages
import jsorm/web
import jsorm/components/status_box as status
import jsorm/pages/layout
import jsorm/pages/login
import jsorm/models/user
import jsorm/models/auth_token
import jsorm/models/token_requests_log
import jsorm/lib/auth
import jsorm/lib/validator
import jsorm/mail
import ids/ulid
import gleam/io
import gleam/string
import gleam/int
import gleam/result
import gleam/list
import gleam/http/request
import gleam/option.{None, Some}
import gleam/http.{Get, Post}
import plunk
import wisp
import nakai/html
import nakai/html/attrs
import sqlight

// This is a hack to get around the current messy syntax highlighting in my editor
type Context =
  web.Context

type Request =
  wisp.Request

type Response =
  wisp.Response

type RatelimitType {
  Throttle
  HardLimit
}

pub fn sign_in(req: Request, ctx: Context) -> Response {
  case req.method {
    Get -> render_signin(req, ctx)
    Post -> send_otp(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

pub fn sign_out(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Get)

  case ctx.session_token {
    Some(token) -> {
      let _ = auth.remove_session_token(ctx.db, token)
      wisp.redirect("/")
    }
    None -> wisp.redirect("/")
  }
}

fn render_signin(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Get)

  let default_email =
    request.get_query(req)
    |> result.unwrap([])
    |> list.key_find("email")
    |> result.unwrap("")

  pages.login(default_email)
  |> layout.render(layout.Props(title: "Sign in", ctx: ctx))
  |> web.render(200)
}

pub fn verify_otp(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)
  use email <- validate_email(formdata)

  let otp =
    list.key_find(formdata.values, "otp")
    |> result.unwrap("")

  let uid = case user.find_by_email(ctx.db, email) {
    Some(user) -> user.id
    None -> 0
  }

  let target =
    request.get_query(req)
    |> result.unwrap([])
    |> list.key_find("redirect")
    |> result.unwrap("e")

  case auth_token.find_by_user(ctx.db, uid) {
    Ok(auth_token) -> {
      case auth_token == otp {
        True -> {
          case auth.signin_as_user(ctx.db, uid) {
            Ok(session_token) -> {
              html.div(
                [
                  attrs.Attr(
                    "_",
                    "init js window.location.replace('/" <> target <> "')",
                  ),
                ],
                [html.p_text([], "redirecting..")],
              )
              |> web.render(200)
              |> auth.set_auth_cookie(req, session_token.token)
            }
            Error(e) -> {
              io.println("signin as user")
              io.debug(e)
              render_error("Something went wrong, please try again", 500)
            }
          }
        }
        False ->
          render_error(
            "Invalid one-time password, please try again or request a new one",
            400,
          )
      }
    }
    Error(e) -> {
      io.println("find_by_user ")
      io.debug(e)
      render_error("Something went wrong, please try again", 500)
    }
  }
}

fn send_otp(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)
  use email <- validate_email(formdata)
  use user <- create_user_if_not_exists(ctx.db, email)
  use <- rate_limit(ctx.db, Throttle, user.id)
  use <- rate_limit(ctx.db, HardLimit, user.id)
  use code <- try_send_otp(ctx.plunk, email)
  use <- auth.save_otp(ctx.db, user.id, code)
  use <- log_token_request(ctx.db, user.id)

  html.div(
    [],
    [
      status.component(status.Props(
        message: "Please check your email for the OTP",
        status: status.Success,
        class: "mb-6",
      )),
      login.otp_form_component(email),
    ],
  )
  |> web.render(200)
}

fn log_token_request(
  db: sqlight.Connection,
  user_id: Int,
  next: fn() -> Response,
) -> Response {
  case token_requests_log.create(db, user_id, token_requests_log.AuthToken) {
    Ok(_) -> next()
    Error(e) -> {
      io.debug(e)
      render_error("Something went wrong, please try again", 500)
    }
  }
}

fn rate_limit(
  db: sqlight.Connection,
  ratelimit_type r_type: RatelimitType,
  user_id user_id: Int,
  next next: fn() -> Response,
) -> Response {
  let max = case r_type {
    Throttle -> 1
    HardLimit -> 5
  }

  let seconds = case r_type {
    Throttle -> 60
    HardLimit -> 60 * 60 * 6
  }

  let err_msg = case r_type {
    Throttle ->
      "You can only make " <> int.to_string(max) <> " request every " <> int.to_string(
        seconds,
      ) <> " seconds"
    HardLimit ->
      "You can only make " <> int.to_string(max) <> " requests every " <> int.to_string(
        seconds / 60 / 60,
      ) <> " hours"
  }

  case
    token_requests_log.get_logs_in_duration(
      db,
      user_id: user_id,
      seconds: seconds,
    )
  {
    Ok(req_counts) -> {
      case req_counts {
        req_counts if req_counts >= max -> {
          render_error(err_msg, 429)
        }
        _ -> next()
      }
    }
    Error(e) -> {
      io.debug(e)
      render_error("Something went wrong, please try again", 500)
    }
  }
}

fn try_send_otp(p: plunk.Instance, email: String, next: fn(String) -> Response) {
  let code =
    ulid.generate()
    |> string.slice(at_index: -6, length: 6)
    |> string.uppercase

  case mail.send_otp(p, email, code) {
    Ok(_) -> next(code)
    Error(err) -> {
      io.print_error("Failed to send OTP")
      io.debug(err)
      render_error("Failed to send OTP, please try again later", 500)
    }
  }
}

fn create_user_if_not_exists(
  db: sqlight.Connection,
  email: String,
  next: fn(user.User) -> Response,
) {
  case user.find_by_email(db, email) {
    Some(user) -> next(user)
    None -> {
      case user.create(db, string.lowercase(email)) {
        Ok(user) -> {
          next(user)
        }
        Error(err) -> {
          io.debug(err)
          render_error("Failed to send OTP, please try again later", 500)
        }
      }
    }
  }
}

fn validate_email(formdata: wisp.FormData, next: fn(String) -> Response) {
  case list.key_find(formdata.values, "email") {
    Ok(email) -> {
      case
        validator.validate_field(email, [validator.Required, validator.Email])
      {
        #(True, errors) ->
          render_error(
            "Email address " <> {
              list.first(errors)
              |> result.unwrap("must be valid")
            },
            400,
          )
        #(False, _) -> next(email)
      }
    }
    Error(_) -> render_error("Email address is required", 400)
  }
}

fn render_error(msg: String, code: Int) {
  status.component(status.Props(
    message: msg,
    status: status.Failure,
    class: "mb-4",
  ))
  |> web.render(code)
}
