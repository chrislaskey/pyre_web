# Changelog

## v0.1.0 — Initial release

Mountable Phoenix LiveView interface for Pyre.

### Added

- **Router macro** (`PyreWeb.Router`) — Mount PyreWeb in any Phoenix app with `pyre_web "/pyre"`. Supports `:on_mount` for authentication, `:live_socket_path`, and `:live_session_name` options.
- **Isolated layout** (`PyreWeb.LayoutView`) — Custom root layout prevents host app styles from interfering.
- **Home page** (`PyreWeb.HomeLive`) — Landing page displaying Pyre version and description.
