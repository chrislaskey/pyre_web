## PyreWeb

> For a fully configured standlone application see [Pyre App](https://github.com/chrislaskey/pyre_app)

The modular web interface dependency for [Pyre](https://github.com/chrislaskey/pyre).

Mounts into an existing Phoenix LiveView application as a
standalone dashboard — similar to
[Phoenix LiveDashboard](https://github.com/phoenixframework/phoenix_live_dashboard).

### Installation

Add `pyre_web` (and `pyre` if not already installed) to your dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:pyre, git: "https://github.com/chrislaskey/pyre", sparse: "pyre", branch: "main"},
    {:pyre_web, git: "https://github.com/chrislaskey/pyre", sparse: "pyre_web", branch: "main"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
mix pyre.install
```

This creates:

- `priv/pyre/personas/` — Editable persona files for each agent
- `priv/pyre/features/.gitkeep` — Directory where pipeline artifacts are stored
- `.gitignore` entries to exclude run output from version control

### Configuration

#### Pyre

Follow the [Pyre app configuration steps](https://github.com/chrislaskey/pyre_core?tab=readme-ov-file#configuration).

#### Add PyreWeb routes

Add the PyreWeb route to your router:

```elixir
# lib/my_app_web/router.ex
import PyreWeb.Router

scope "/" do
  pipe_through :browser
  pyre_web "/pyre"
end
```

Visit `/pyre` in your browser to see the PyreWeb interface.

#### Track connected apps

To track connected apps on the homepage, add `PyreWeb.Presence` to
your supervision tree. It reuses the PubSub server from `config :pyre, :pubsub`
— no additional configuration is needed:

```elixir
# lib/my_app/application.ex
children = [
  # ... existing children ...
  # {Phoenix.PubSub, name: MyApp.PubSub}
  PyreWeb.Presence
  # MyAppWeb.Endpoint
]
```

This enables the homepage to display which app instances are currently
connected.

#### (Optional) Use remote macOS hosts as runners using PyreNative app

PyreWeb supports using multiple remote macOS hosts as runners. This lets you leverage fully configured development environments and load balance requests across your LLM subscriptions. Setup is easy, see:

> The [Pyre Native App](https://github.com/chrislaskey/pyre_native) repository

### Pages

| Route | Description |
|-------|-------------|
| `/pyre` | Home page with links to start or view runs |
| `/pyre/runs` | List of all pipeline runs with status |
| `/pyre/runs/new` | Form to start a new pipeline run |
| `/pyre/runs/:id` | Streaming output for a specific run |

Run processes are managed by `Pyre.RunServer` — a GenServer per run, supervised
by a DynamicSupervisor and registered in a Registry. This means:

- **Runs survive page refreshes**: output is buffered in the GenServer and
  replayed when you navigate back to a run page.
- **Real-time streaming**: LiveViews subscribe to PubSub for live updates as
  agents produce output.
- **Multiple viewers**: any number of browser tabs can watch the same run.

### File Attachments

The "New Run" form supports file attachments via paste, drag-and-drop, or file
browser. Accepted formats include images (PNG, JPG, GIF, WebP) and text files
(Markdown, JSON, CSV, HTML, CSS, JS). Up to 10 files, 10 MB each.

Image attachments are sent as vision content to the LLM, so agents like the
Designer can reference pasted screenshots or mockups directly.

### How it works

PyreWeb bundles its own JavaScript that includes the Phoenix LiveView client
library. The JS is embedded at compile time and served via a versioned route
(`/pyre/js-<md5hash>`). The `<script>` tag is included automatically in
PyreWeb's isolated root layout — no changes to your app's asset pipeline are
required.

The layout also loads [DaisyUI](https://daisyui.com/) and
[Tailwind CSS](https://tailwindcss.com/) from CDN for styling, keeping PyreWeb
fully independent of your app's CSS.

### Authentication

Use the `:on_mount` option to protect the route with your app's
authentication:

```elixir
pyre_web "/pyre",
  on_mount: [{MyAppWeb.Auth, :ensure_admin}]
```

### Authorization Hooks

PyreWeb provides 5 authorization hooks that let your app gate WebSocket
connections, channel joins, run creation, run control, and remote action
dispatch. Create a module that `use PyreWeb.Config` and override the
callbacks you need:

```elixir
defmodule MyApp.PyreConfig do
  use Pyre.Config
  use PyreWeb.Config

  # --- Pyre lifecycle hooks (optional) ---

  @impl Pyre.Config
  def after_flow_complete(%Pyre.Events.FlowCompleted{} = event) do
    MyApp.Telemetry.emit(:pyre_flow_complete, %{elapsed_ms: event.elapsed_ms})
    :ok
  end

  # --- PyreWeb authorization hooks ---

  @impl PyreWeb.Config
  def authorize_socket_connect(params, _connect_info) do
    case Map.get(params, "token") do
      nil -> {:error, :missing_token}
      token -> if MyApp.Auth.valid_token?(token), do: :ok, else: {:error, :invalid_token}
    end
  end

  @impl PyreWeb.Config
  def authorize_run_create(_run_params, socket) do
    if socket.assigns[:current_user], do: :ok, else: {:error, :unauthenticated}
  end
end
```

Then register the module in your config. Both libraries can share one module
since the callback names don't overlap (`after_*` for Pyre, `authorize_*` for
PyreWeb):

```elixir
# config/config.exs
config :pyre, config: MyApp.PyreConfig
config :pyre_web, config: MyApp.PyreConfig
```

The 5 hooks and their arguments:

| Hook | Arguments | Used in |
|------|-----------|---------|
| `authorize_socket_connect` | `(params, connect_info)` | `PyreWeb.Socket` |
| `authorize_channel_join` | `(topic, socket)` | `PyreWeb.Channel` |
| `authorize_run_create` | `(run_params, socket)` | New run form |
| `authorize_run_control` | `(action, socket)` | Run show (stop, toggle, reply) |
| `authorize_remote_action` | `(action, socket)` | Home page action dispatch |

All callbacks return `:ok | {:error, term()}`. Defaults permit all operations.
Exceptions in callbacks are rescued and return `:ok` (fail-open) to avoid
locking users out when a hook crashes.

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `:on_mount` | `nil` | LiveView `on_mount` callbacks for auth |
| `:live_socket_path` | `"/live"` | Must match your endpoint's LiveView socket |
| `:live_session_name` | `:pyre_web` | Session name (only needed for multiple mounts) |
