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

PyreWeb serves its own JavaScript to connect to your app's LiveView socket.
Your endpoint must have the standard LiveView socket configured:

```elixir
# lib/my_app_web/endpoint.ex
socket "/live", Phoenix.LiveView.Socket
```

This is included by default in Phoenix applications generated with
`mix phx.new`. No additional endpoint configuration is needed.

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
