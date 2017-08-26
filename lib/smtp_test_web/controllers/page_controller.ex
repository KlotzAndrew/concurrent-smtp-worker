defmodule SmtpTestWeb.PageController do
  use SmtpTestWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
