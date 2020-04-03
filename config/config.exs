# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :quadlink, QuadlinkWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "74ZrV9FELUZ8F9xH6W4QH9fVD/JPvYlBKKRwldidheNY8YMtJbsuUQcEX5kZrIaU",
  render_errors: [view: QuadlinkWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Quadlink.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [signing_salt: "2ND8AKWU6UHB7W3NDgUz6GeKP6jpkZaa"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
