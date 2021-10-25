import Config

config :goth,
  json: System.get_env("GOOGLE_PUBSUB_CONFIG") |> File.read!()
