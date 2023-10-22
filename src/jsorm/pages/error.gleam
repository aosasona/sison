import nakai/html
import nakai/html/attrs
import jsorm/pages/layout

fn get_message(code: Int) -> String {
  case code {
    404 -> "Page not found"
    405 -> "Method not allowed"
    _ -> "Oof, something went wrong"
  }
}

fn get_subtext(code: Int) -> String {
  case code {
    404 -> "The page you're looking for doesn't exist"
    405 -> "You're not allowed to do that"
    _ -> "Please try again later or contact us if the problem persists"
  }
}

pub fn page(code: Int) -> html.Node(t) {
  let message = get_message(code)

  html.div(
    [attrs.class("min-h-screen flex flex-col items-center justify-center px-6")],
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
