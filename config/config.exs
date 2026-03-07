import Config

config :phoenix, :json_library, Jason

if config_env() == :test do
  config :logger, level: :warning
end
