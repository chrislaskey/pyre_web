defmodule PyreWeb.LayoutView do
  @moduledoc false
  use PyreWeb.Web, :html

  embed_templates "layouts/*"

  def render("root.html", assigns), do: root(assigns)

  @themes [
    "light",
    "dark",
    "retro",
    "cyberpunk",
    "valentine",
    "aqua",
    "dracula",
    "nord",
    "synthwave",
    "night",
    "coffee",
    "forest",
    "cupcake",
    "pastel",
    "caramellatte",
    "sunset"
  ]

  attr :themes, :list, default: @themes

  def theme_selector(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="btn btn-ghost btn-sm">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 20 20"
          fill="currentColor"
          class="size-4"
        >
          <path
            fill-rule="evenodd"
            d="M3.5 2A1.5 1.5 0 0 0 2 3.5V5c0 .69.56 1.25 1.25 1.25H5.5c.69 0 1.25-.56 1.25-1.25V3.5c0-.83-.67-1.5-1.5-1.5h-1.75ZM2 9.25c0-.69.56-1.25 1.25-1.25H5.5c.69 0 1.25.56 1.25 1.25V11c0 .83-.67 1.5-1.5 1.5H3.5A1.5 1.5 0 0 1 2 11V9.25ZM9.25 2c-.69 0-1.25.56-1.25 1.25V5.5c0 .69.56 1.25 1.25 1.25H11c.83 0 1.5-.67 1.5-1.5V3.5c0-.83-.67-1.5-1.5-1.5H9.25ZM8 9.25c0-.69.56-1.25 1.25-1.25H11c.83 0 1.5.67 1.5 1.5V11c0 .83-.67 1.5-1.5 1.5H9.25C8.56 12.5 8 11.94 8 11.25V9.25ZM15 2c-.83 0-1.5.67-1.5 1.5V5c0 .69.56 1.25 1.25 1.25H17c.69 0 1.25-.56 1.25-1.25V3.5c0-.83-.67-1.5-1.5-1.5h-1.75ZM13.5 9.25c0-.69.56-1.25 1.25-1.25H17c.69 0 1.25.56 1.25 1.25V11c0 .83-.67 1.5-1.5 1.5h-1.75c-.83 0-1.5-.67-1.5-1.5V9.25ZM3.5 14c-.83 0-1.5.67-1.5 1.5V17c0 .69.56 1.25 1.25 1.25H5.5c.69 0 1.25-.56 1.25-1.25v-1.75c0-.83-.67-1.5-1.5-1.5H3.5ZM8 15.25c0-.69.56-1.25 1.25-1.25H11c.83 0 1.5.67 1.5 1.5V17c0 .69-.56 1.25-1.25 1.25H9.25C8.56 18.25 8 17.69 8 17v-1.75ZM15 14c-.83 0-1.5.67-1.5 1.5V17c0 .69.56 1.25 1.25 1.25H17c.69 0 1.25-.56 1.25-1.25v-1.75c0-.83-.67-1.5-1.5-1.5h-1.75Z"
            clip-rule="evenodd"
          />
        </svg>
        Theme
        <svg
          width="12px"
          height="12px"
          class="inline-block h-2 w-2 fill-current opacity-60"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 2048 2048"
        >
          <path d="M1799 349l242 241-1017 1017L7 590l242-241 775 775 775-775z"></path>
        </svg>
      </div>
      <ul
        tabindex="0"
        class="dropdown-content bg-base-300 rounded-box z-10 w-52 p-2 shadow-2xl max-h-80 overflow-y-auto"
      >
        <li :for={theme <- @themes}>
          <input
            type="radio"
            name="theme-dropdown"
            class="theme-controller w-full btn btn-sm btn-block btn-ghost justify-start"
            aria-label={String.capitalize(theme)}
            value={theme}
          />
        </li>
      </ul>
    </div>
    """
  end

  defp live_socket_path(conn) do
    [Enum.map(conn.script_name, &["/" | &1]) | conn.private.live_socket_path]
  end

  defp asset_path(conn, :js) do
    hash = PyreWeb.Assets.current_hash(:js)
    prefix = conn.private.phoenix_router.__pyre_web_prefix__()

    Phoenix.VerifiedRoutes.unverified_path(
      conn,
      conn.private.phoenix_router,
      "#{prefix}/js-#{hash}"
    )
  end
end
