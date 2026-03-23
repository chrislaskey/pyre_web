## PyreWeb

Web interface for the [Pyre](https://github.com/chrislaskey/pyre) multi-agent
LLM framework. Mounts into an existing Phoenix LiveView application as a
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
```

### Setup

#### 1. Configure PubSub

Tell Pyre which PubSub server to use for real-time run updates. This should
match the PubSub already started in your application's supervision tree:

```elixir
# config/config.exs
config :pyre, :pubsub, MyApp.PubSub
```

#### 2. Configure GitHub (for Shipper)

To enable the Shipper agent (creates branches and opens GitHub PRs), configure
your repository in `config/runtime.exs`:

```elixir
# config/runtime.exs
if System.get_env("GITHUB_REPO_URL") do
  config :pyre, :github,
    repositories: [
      [
        url: System.get_env("GITHUB_REPO_URL"),
        token: System.get_env("GITHUB_TOKEN"),
        base_branch: System.get_env("GITHUB_BASE_BRANCH", "main")
      ]
    ]
end
```

Without this configuration, the pipeline still runs but the Shipper will skip
PR creation.

#### 2b. Configure Allowed Paths (monorepos)

If your agents need to read or write files outside the working directory (e.g.,
sibling apps in a monorepo), configure additional allowed paths:

```bash
export PYRE_ALLOWED_PATHS="/path/to/apps/other,/path/to/libs/shared"
```

Or in your application config:

```elixir
# config/runtime.exs
config :pyre, allowed_paths: [
  "/path/to/apps/other",
  "/path/to/libs/shared"
]
```

Relative paths are resolved against the working directory. See the
[Pyre README](../pyre/README.md) for full details.

#### 3. Add routes

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

#### 4. (Optional) Support Pyre native app

PyreWeb serves its own JavaScript to connect to your app's LiveView socket.
Your endpoint must have the standard LiveView socket configured:

```elixir
# lib/my_app_web/endpoint.ex
socket "/live", Phoenix.LiveView.Socket
```

This is included by default in Phoenix applications generated with
`mix phx.new`.

To enable the Pyre native app to connect over Phoenix channels, add the
`PyreWeb.Socket` to your endpoint. The path must match the route prefix you
use in step 4 below (e.g., `/pyre`):

```elixir
# lib/my_app_web/endpoint.ex
socket "/pyre", PyreWeb.Socket,
  websocket: [connect_info: [:peer_data, :x_headers]]
```

> **Why the endpoint?** Phoenix channels are handled at the endpoint level,
> not the router. The `socket/3` declaration tells Phoenix to upgrade
> WebSocket connections at the given path before they reach the router's
> plug pipeline. This is the same pattern used by `Phoenix.LiveView.Socket`.

To track connected native apps on the homepage, add `PyreWeb.Presence` to
your supervision tree. It reuses the PubSub server from `config :pyre, :pubsub`
— no additional configuration is needed:

```elixir
# lib/my_app/application.ex
children = [
  # ... existing children ...
  PyreWeb.Presence
]
```

This enables the homepage to display which native app instances are currently
connected, along with their system information (computer name, CPU, memory,
OS version).

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

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `:on_mount` | `nil` | LiveView `on_mount` callbacks for auth |
| `:live_socket_path` | `"/live"` | Must match your endpoint's LiveView socket |
| `:live_session_name` | `:pyre_web` | Session name (only needed for multiple mounts) |
