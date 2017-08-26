defmodule MyApp.Email do
  import Bamboo.Email

  def welcome_email do
    # new_email(
    #   to: "john@gmail.com",
    #   from: "support@myapp.com",
    #   subject: "Welcome to the app.",
    #   html_body: "<strong>Thanks for joining!</strong>",
    #   text_body: "Thanks for joining!"
    # )
    #
    # # or pipe using Bamboo.Email functions
    :timer.sleep(4000)

    new_email
    |> to("foo@example.com")
    |> from("me@example.com")
    |> subject("Welcome!!!")
    |> html_body("<strong>Welcome</strong>")
    |> text_body("welcome")
  end

  def send_email(email) do
    new_email(
      to: email["to"],
      from: email["from"],
      cc: email["cc"],
      bcc: email["bcc"],
      subject: email["subject"],
      html_body: email["html"],
      text_body: email["text"]
    )
  end
end
