import nakai/html
import nakai/html/attrs
import jsorm/pages/layout

fn get_message(code: Int) -> String {
  case code {
    401 -> "Unauthorized"
    403 -> "Forbidden"
    404 -> "Page not found"
    405 -> "Method not allowed"
    500 -> "Something went wrong"
    _ -> "Oof, something went wrong"
  }
}

fn get_subtext(code: Int) -> String {
  case code {
    401 -> "Looks like you're not logged in, please log in and try again"
    403 -> "You're not allowed to view this page"
    404 -> "The page you're looking for doesn't exist"
    405 -> "You're not allowed to do that"
    500 -> "We're having some trouble on our end, please try again later"
    _ -> "Please try again later or contact us if the problem persists"
  }
}

pub fn page(code: Int) -> html.Node(t) {
  let message = get_message(code)

  html.div(
    [
      attrs.class(
        "min-h-screen flex flex-col text-center items-center justify-center px-6",
      ),
    ],
    [
      html.h1_text(
        [attrs.class("max-w-2xl text-4xl font-bold mb-3")],
        get_message(code),
      ),
      html.p_text([attrs.class("text-base text-stone-500")], get_subtext(code)),
    ],
  )
  |> layout.render(message)
}
