# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :smtp_test, SmtpTestWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "VW8t8B3nc6fQODatm4UGcWXLDIoL1O+HG22lzwvdceX1uY5ZFy604nmCkn5f7VjS",
  render_errors: [view: SmtpTestWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: SmtpTest.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
config :smtp_test, MyApp.Mailer,
  adapter: Bamboo.SMTPAdapter,
  server: '127.0.0.1', #System.get_env("SMTP_HOSTNAME"),
  port: 1025, #System.get_env("SMTP_PORT"),
  username: '', #System.get_env("SMTP_USERNAME"),
  password: '', #System.get_env("SMTP_PASSWORD"),
  tls: :if_available, # can be `:always` or `:never`
  ssl: false, # can be `true`
  retries: 1

import_config "#{Mix.env}.exs"
