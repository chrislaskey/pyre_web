defmodule PyreWeb.Config do
  @moduledoc """
  Behaviour and default configuration for PyreWeb hooks.

  Applications can provide a custom config module by:

  1. Creating a module that `use PyreWeb.Config`
  2. Overriding any callbacks they need
  3. Configuring it in `config.exs`:

         config :pyre_web, config: MyApp.PyreWebConfig

  If no config module is set, `PyreWeb.Config` itself provides the default
  implementations for all callbacks (permit all / no-op).

  ## Example

      defmodule MyApp.PyreWebConfig do
        use PyreWeb.Config

        @impl true
        def authorize_socket_connect(params, _connect_info) do
          case Map.get(params, "token") do
            nil -> {:error, :missing_token}
            _token -> :ok
          end
        end

        @impl true
        def store_github_app(credentials) do
          MyApp.Repo.insert_or_update_github_app(credentials)
        end

        @impl true
        def load_github_app do
          MyApp.Repo.get_github_app()
        end
      end

  Any callback not overridden in the custom module will fall back to the
  default implementation provided by `PyreWeb.Config`.

  ## Dispatching

  Use `PyreWeb.Config.authorize/2` to dispatch authorization checks.
  Use `PyreWeb.Config.call/2` to dispatch data-returning callbacks.
  Exceptions raised inside user-provided callbacks are rescued and logged —
  authorization returns `:ok` (fail-open), data callbacks return `nil`.
  """

  require Logger

  # -- Authorization Callbacks --

  @callback authorize_socket_connect(params :: map(), connect_info :: map()) ::
              :ok | {:error, term()}

  @callback authorize_channel_join(topic :: String.t(), socket :: Phoenix.Socket.t()) ::
              :ok | {:error, term()}

  @callback authorize_run_create(run_params :: map(), socket :: Phoenix.LiveView.Socket.t()) ::
              :ok | {:error, term()}

  @callback authorize_run_control(action :: map(), socket :: Phoenix.LiveView.Socket.t()) ::
              :ok | {:error, term()}

  @callback authorize_remote_action(action :: map(), socket :: Phoenix.LiveView.Socket.t()) ::
              :ok | {:error, term()}

  @callback authorize_webhook(event :: String.t(), payload :: map()) ::
              :ok | {:error, term()}

  # -- GitHub App Persistence Callbacks --

  @doc """
  Called after the GitHub App manifest flow to store App credentials.

  The `credentials` map contains:

    * `:app_id` - GitHub App ID (string)
    * `:private_key` - PEM-encoded RSA private key
    * `:webhook_secret` - Webhook HMAC secret
    * `:client_id` - OAuth client ID
    * `:client_secret` - OAuth client secret
    * `:bot_slug` - App slug (used for @mention detection)
    * `:html_url` - URL of the App on GitHub

  Default implementation: no-op (returns `:ok`). Override in consuming apps
  to persist credentials to a database.
  """
  @callback store_github_app(credentials :: map()) :: :ok | {:error, term()}

  @doc """
  Loads stored GitHub App credentials.

  Should return a map with the same keys as `store_github_app/1`,
  or `nil` if no credentials are stored.

  Default implementation: returns `nil`. Override in consuming apps
  to load credentials from a database.
  """
  @callback load_github_app() :: map() | nil

  # -- Public API --

  @doc """
  Returns the configured PyreWeb config module.

  Reads `config :pyre_web, config: MyApp.PyreWebConfig` from the application environment.
  Falls back to `PyreWeb.Config` (default implementations) if none is configured.
  """
  def get_module do
    Application.get_env(:pyre_web, :config) || __MODULE__
  end

  @doc """
  Dispatches an authorization check to the configured config module.

  Returns `:ok` or `{:error, reason}`. Rescues any exception raised inside
  the user's callback and returns `:ok` (fail-open) with a logged warning.
  """
  @spec authorize(atom(), list()) :: :ok | {:error, term()}
  def authorize(hook, args) do
    mod = get_module()

    try do
      apply(mod, hook, args)
    rescue
      e ->
        Logger.warning("PyreWeb.Config hook #{hook} raised: #{Exception.message(e)}")

        :ok
    end
  end

  @doc """
  Dispatches a data-returning callback to the configured config module.

  Returns whatever the callback returns. Rescues any exception and returns
  `nil` with a logged warning.
  """
  @spec call(atom(), list()) :: term()
  def call(hook, args) do
    mod = get_module()

    try do
      apply(mod, hook, args)
    rescue
      e ->
        Logger.warning("PyreWeb.Config hook #{hook} raised: #{Exception.message(e)}")
        nil
    end
  end

  # -- __using__ macro --

  defmacro __using__(_opts) do
    quote do
      @behaviour PyreWeb.Config

      @impl PyreWeb.Config
      def authorize_socket_connect(_params, _connect_info), do: :ok
      @impl PyreWeb.Config
      def authorize_channel_join(_topic, _socket), do: :ok
      @impl PyreWeb.Config
      def authorize_run_create(_run_params, _socket), do: :ok
      @impl PyreWeb.Config
      def authorize_run_control(_action, _socket), do: :ok
      @impl PyreWeb.Config
      def authorize_remote_action(_action, _socket), do: :ok
      @impl PyreWeb.Config
      def authorize_webhook(_event, _payload), do: :ok
      @impl PyreWeb.Config
      def store_github_app(_credentials), do: :ok
      @impl PyreWeb.Config
      def load_github_app, do: nil

      defoverridable authorize_socket_connect: 2,
                     authorize_channel_join: 2,
                     authorize_run_create: 2,
                     authorize_run_control: 2,
                     authorize_remote_action: 2,
                     authorize_webhook: 2,
                     store_github_app: 1,
                     load_github_app: 0
    end
  end

  # -- Default implementations (used when no custom config module is configured) --

  def authorize_socket_connect(_params, _connect_info), do: :ok
  def authorize_channel_join(_topic, _socket), do: :ok
  def authorize_run_create(_run_params, _socket), do: :ok
  def authorize_run_control(_action, _socket), do: :ok
  def authorize_remote_action(_action, _socket), do: :ok
  def authorize_webhook(_event, _payload), do: :ok
  def store_github_app(_credentials), do: :ok
  def load_github_app, do: nil
end
