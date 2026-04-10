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
        def update_github_app(credentials) do
          MyApp.Repo.insert_or_update_github_app(credentials)
        end

        @impl true
        def list_github_apps do
          MyApp.Repo.list_github_apps()
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
  import Phoenix.Component, only: [sigil_H: 2]

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
  @callback update_github_app(credentials :: map()) :: :ok | {:error, term()}

  @doc """
  Returns all configured GitHub Apps.

  Should return a list of maps, each with the same keys as
  `update_github_app/1`.

  Default implementation: reads from `config :pyre, :github_apps`
  and normalizes each entry to a map.

  Override in consuming apps to load from a database.
  """
  @callback list_github_apps() :: [map()]

  # -- Render Callbacks --

  @doc """
  Returns HEEx markup to render additional items in the sidebar.

  The `assigns` map includes `:current_page`, `:prefix`, and `:uri` from the
  sidebar component.

  Default implementation: renders nothing (empty HEEx).

  Override in consuming apps to inject custom content (e.g. user info,
  environment badge, version number).
  """
  @callback additional_nav_links(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc """
  Returns HEEx markup to render at the bottom of the sidebar.

  The `assigns` map includes `:current_page`, `:prefix`, and `:uri` from the
  sidebar component.

  Default implementation: renders nothing (empty HEEx).

  Override in consuming apps to inject custom content (e.g. user info,
  environment badge, version number).
  """
  @callback sidebar_footer(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  # -- Workflow Callbacks --

  @doc """
  Called when a user submits a new workflow run from the UI.

  Receives the feature description and fully-prepared options keyword list
  containing:

    * `:workflow` - atom (`:chat`, `:feature`, `:prototype`, etc.)
    * `:skipped_stages` - list of atoms
    * `:interactive_stages` - list of atoms
    * `:attachments` - list of `%{filename, content, media_type}` maps
    * `:llm` - LLM backend module (e.g., `Pyre.LLM.ClaudeCLI`)
    * `:feature` - optional feature name string or nil

  Returns `{:ok, opts}` where `opts` is a keyword list. Recognized keys:

    * `:redirect_to` - path string relative to the pyre_web mount point
      (e.g., `"/runs/abc123"` or `"/workflows/42"`). When present, the UI
      navigates to that path. When absent, the UI stays on the current
      page and shows a success flash.

  Default implementation: starts the run immediately via
  `Pyre.RunServer.start_run/2` and redirects to the run show page.

  Override in consuming apps to enqueue the workflow (e.g., via Oban),
  persist it to a database, or handle submission however the host app needs.
  """
  @callback workflow_submit(description :: String.t(), opts :: keyword()) ::
              {:ok, keyword()} | {:error, term()}

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
      def update_github_app(_credentials), do: :ok
      @impl PyreWeb.Config
      def list_github_apps, do: PyreWeb.Config.list_github_apps_from_env()
      @impl PyreWeb.Config
      def additional_nav_links(var!(assigns)), do: ~H""
      @impl PyreWeb.Config
      def sidebar_footer(var!(assigns)), do: ~H""

      @impl PyreWeb.Config
      def workflow_submit(description, opts) do
        case apply(Pyre.RunServer, :start_run, [description, opts]) do
          {:ok, run_id} -> {:ok, redirect_to: "/runs/#{run_id}"}
          {:error, _} = error -> error
        end
      end

      defoverridable authorize_socket_connect: 2,
                     authorize_channel_join: 2,
                     authorize_run_create: 2,
                     authorize_run_control: 2,
                     authorize_remote_action: 2,
                     authorize_webhook: 2,
                     update_github_app: 1,
                     list_github_apps: 0,
                     additional_nav_links: 1,
                     sidebar_footer: 1,
                     workflow_submit: 2
    end
  end

  # -- Default implementations (used when no custom config module is configured) --

  def authorize_socket_connect(_params, _connect_info), do: :ok
  def authorize_channel_join(_topic, _socket), do: :ok
  def authorize_run_create(_run_params, _socket), do: :ok
  def authorize_run_control(_action, _socket), do: :ok
  def authorize_remote_action(_action, _socket), do: :ok
  def authorize_webhook(_event, _payload), do: :ok
  def update_github_app(_credentials), do: :ok
  def list_github_apps, do: list_github_apps_from_env()
  def additional_nav_links(assigns), do: ~H""
  def sidebar_footer(assigns), do: ~H""

  def workflow_submit(description, opts) do
    case apply(Pyre.RunServer, :start_run, [description, opts]) do
      {:ok, run_id} -> {:ok, "/runs/#{run_id}"}
      {:error, _} = error -> error
    end
  end

  @doc false
  def list_github_apps_from_env do
    case Application.get_env(:pyre, :github_apps) do
      nil ->
        []

      apps when is_list(apps) ->
        apps
        |> Enum.reject(&is_nil/1)
        |> Enum.map(fn
          entry when is_list(entry) -> Map.new(entry)
          entry when is_map(entry) -> entry
        end)
    end
  end
end
