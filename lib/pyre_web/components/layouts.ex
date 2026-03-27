defmodule PyreWeb.Components.Layouts do
  @moduledoc false
  use PyreWeb.Web, :html

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

  attr :current_page, :atom, required: true
  attr :prefix, :string, required: true
  attr :uri, :string, default: ""
  attr :breadcrumbs, :list, default: []
  slot :inner_block, required: true

  def page_layout(assigns) do
    ~H"""
    <div class="flex flex-col min-h-screen">
      <.page_header current_page={@current_page} prefix={@prefix} uri={@uri} />
      <.mobile_menu current_page={@current_page} prefix={@prefix} uri={@uri} />
      <div class="flex flex-1">
        <.sidebar current_page={@current_page} prefix={@prefix} uri={@uri} />
        <div class="flex-1 p-8 overflow-y-auto">
          <.breadcrumbs items={@breadcrumbs} prefix={@prefix} />
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders DaisyUI breadcrumbs. A home icon is always shown as the first crumb.
  Each item is a map with `:label` and an optional `:path`.
  Items with a `:path` render as navigate links; the last item (no path) renders as plain text.
  """
  attr :items, :list, required: true
  attr :prefix, :string, required: true

  def breadcrumbs(assigns) do
    ~H"""
    <div class="breadcrumbs text-sm text-base-content/60 mb-4">
      <ul>
        <li>
          <.link class="flex gap-x-1" navigate={@prefix}>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="size-4"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="m2.25 12 8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25"
              />
            </svg>
            Home
          </.link>
        </li>
        <li :for={item <- @items}>
          <.link :if={item[:path]} navigate={item.path}>{item.label}</.link>
          <span :if={!item[:path]}>{item.label}</span>
        </li>
      </ul>
    </div>
    """
  end

  attr :current_page, :atom, required: true
  attr :prefix, :string, required: true
  attr :uri, :string, default: ""

  def page_header(assigns) do
    ~H"""
    <div class="w-full h-16 pl-8 pr-6 items-center flex justify-between shadow-sm relative z-10">
      <div class="flex items-center gap-x-2">
        <.link
          patch={toggle_menu_path(@uri)}
          class="btn btn-ghost btn-sm btn-square flex md:hidden"
          aria-label="Open menu"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="1.5"
            stroke="currentColor"
            class="size-5"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
            />
          </svg>
        </.link>
        <.link class="w-48 tracking-widest text-2xl font-light uppercase" navigate={@prefix}>
          Pyre
        </.link>
      </div>
      <div class="flex items-center gap-x-1">
        <.link navigate={"#{@prefix}/runs/new"} class="btn hover:btn-accent btn-ghost">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
            class="size-5"
          >
            <path d="M10.75 4.75a.75.75 0 0 0-1.5 0v4.5h-4.5a.75.75 0 0 0 0 1.5h4.5v4.5a.75.75 0 0 0 1.5 0v-4.5h4.5a.75.75 0 0 0 0-1.5h-4.5v-4.5Z" />
          </svg>
          <span>New run</span>
        </.link>
        <.theme_selector />
        <.link
          patch={toggle_sidebar_path(@uri)}
          class="btn btn-ghost btn-sm btn-square hidden sm:flex"
          aria-label="Toggle sidebar"
        >
          <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" class="size-5">
            <rect
              x="2.74709"
              y="4.77295"
              width="18.5"
              height="14.5"
              rx="1.25"
              stroke="currentColor"
              stroke-width="1.5"
            />
            <path
              d="M8.49709 5.02295V19.0229"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="square"
            />
            <path
              d="M4.99709 8.52295L5.99709 8.52295"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
            />
            <path
              d="M4.99709 10.5229L5.99709 10.5229"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
            />
            <path
              d="M4.99709 12.5229L5.99709 12.5229"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
            />
          </svg>
        </.link>
      </div>
    </div>
    """
  end

  attr :current_page, :atom, required: true
  attr :prefix, :string, required: true
  attr :uri, :string, required: true

  def sidebar(assigns) do
    ~H"""
    <nav
      :if={!sidebar_collapsed?(@uri)}
      class="hidden md:block w-56 shrink-0 bg-base-200 border-r border-base-300 py-6 px-3"
      style="min-height: calc(100vh - 4rem);"
    >
      <div class="w-full">
        <.nav_links current_page={@current_page} prefix={@prefix} />
      </div>
    </nav>
    """
  end

  attr :current_page, :atom, required: true
  attr :prefix, :string, required: true
  attr :uri, :string, required: true

  def mobile_menu(assigns) do
    ~H"""
    <div :if={menu_open?(@uri)} class="fixed inset-0 z-50 bg-base-100 flex flex-col md:hidden">
      <div class="flex items-center gap-x-2 h-16 pl-8 pr-6 shadow-sm">
        <.link
          patch={toggle_menu_path(@uri)}
          class="btn btn-ghost btn-sm btn-square"
          aria-label="Close menu"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="1.5"
            stroke="currentColor"
            class="size-5"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
          </svg>
        </.link>
        <.link class="tracking-widest text-2xl font-light uppercase" navigate={@prefix}>
          Pyre
        </.link>
      </div>
      <div class="flex-1 overflow-y-auto py-6 px-3 bg-base-200 flex-1 border-t border-base-300">
        <.nav_links current_page={@current_page} prefix={@prefix} />
      </div>
    </div>
    """
  end

  attr :current_page, :atom, required: true
  attr :prefix, :string, required: true

  def nav_links(assigns) do
    ~H"""
    <ul class="menu w-full">
      <li>
        <.link navigate={@prefix} class={@current_page == :home && "active"}>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="1.5"
            stroke="currentColor"
            class="size-4"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="m2.25 12 8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25"
            />
          </svg>
          Home
        </.link>
      </li>
      <li>
        <.link
          navigate={"#{@prefix}/connected-apps"}
          class={@current_page in [:connected_apps] && "active"}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
            class="size-4"
          >
            <path d="M12.232 4.232a2.5 2.5 0 0 1 3.536 3.536l-1.225 1.224a.75.75 0 0 0 1.061 1.06l1.224-1.224a4 4 0 0 0-5.656-5.656l-3 3a4 4 0 0 0 .225 5.865.75.75 0 0 0 .977-1.138 2.5 2.5 0 0 1-.142-3.667l3-3Z" />
            <path d="M11.603 7.963a.75.75 0 0 0-.977 1.138 2.5 2.5 0 0 1 .142 3.667l-3 3a2.5 2.5 0 0 1-3.536-3.536l1.225-1.224a.75.75 0 0 0-1.061-1.06l-1.224 1.224a4 4 0 0 0 5.656 5.656l3-3a4 4 0 0 0-.225-5.865Z" />
          </svg>
          Connected Apps
        </.link>
      </li>
      <li>
        <.link
          navigate={"#{@prefix}/runs"}
          class={@current_page in [:runs, :run_show] && "active"}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
            class="size-4"
          >
            <path
              fill-rule="evenodd"
              d="M6 4.75A.75.75 0 0 1 6.75 4h10.5a.75.75 0 0 1 0 1.5H6.75A.75.75 0 0 1 6 4.75ZM6 10a.75.75 0 0 1 .75-.75h10.5a.75.75 0 0 1 0 1.5H6.75A.75.75 0 0 1 6 10Zm0 5.25a.75.75 0 0 1 .75-.75h10.5a.75.75 0 0 1 0 1.5H6.75a.75.75 0 0 1-.75-.75ZM1.99 4.75a1 1 0 0 1 1-1H3a1 1 0 0 1 1 1v.01a1 1 0 0 1-1 1h-.01a1 1 0 0 1-1-1v-.01ZM1.99 15.25a1 1 0 0 1 1-1H3a1 1 0 0 1 1 1v.01a1 1 0 0 1-1 1h-.01a1 1 0 0 1-1-1v-.01ZM1.99 10a1 1 0 0 1 1-1H3a1 1 0 0 1 1 1v.01a1 1 0 0 1-1 1h-.01a1 1 0 0 1-1-1V10Z"
              clip-rule="evenodd"
            />
          </svg>
          Runs
        </.link>
      </li>
      <li>
        <.link navigate={"#{@prefix}/runs/new"} class={@current_page == :new_run && "active"}>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
            class="size-4"
          >
            <path d="M10.75 4.75a.75.75 0 0 0-1.5 0v4.5h-4.5a.75.75 0 0 0 0 1.5h4.5v4.5a.75.75 0 0 0 1.5 0v-4.5h4.5a.75.75 0 0 0 0-1.5h-4.5v-4.5Z" />
          </svg>
          New Run
        </.link>
      </li>
    </ul>
    """
  end

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

  slot :inner_block, required: true

  def h1(assigns) do
    ~H"""
    <h1 class="text-3xl font-light">
      {render_slot(@inner_block)}
    </h1>
    """
  end

  defp sidebar_collapsed?(uri) when uri in ["", nil], do: false

  defp sidebar_collapsed?(uri) do
    uri
    |> URI.parse()
    |> Map.get(:query)
    |> case do
      nil -> %{}
      q -> URI.decode_query(q)
    end
    |> Map.get("sidebar") == "collapsed"
  end

  defp toggle_sidebar_path(uri) when uri in ["", nil], do: "?sidebar=collapsed"

  defp toggle_sidebar_path(uri) do
    parsed = URI.parse(uri)
    params = URI.decode_query(parsed.query || "")

    new_nav = if params["sidebar"] == "collapsed", do: "open", else: "collapsed"
    new_params = Map.put(params, "sidebar", new_nav)
    new_query = URI.encode_query(new_params)

    %URI{parsed | query: new_query} |> URI.to_string()
  end

  defp menu_open?(uri) when uri in ["", nil], do: false

  defp menu_open?(uri) do
    uri
    |> URI.parse()
    |> Map.get(:query)
    |> case do
      nil -> %{}
      q -> URI.decode_query(q)
    end
    |> Map.get("menu") == "open"
  end

  defp toggle_menu_path(uri) when uri in ["", nil], do: "?menu=open"

  defp toggle_menu_path(uri) do
    parsed = URI.parse(uri)
    params = URI.decode_query(parsed.query || "")

    new_menu = if params["menu"] == "open", do: "hidden", else: "open"
    new_params = Map.put(params, "menu", new_menu)
    new_query = URI.encode_query(new_params)

    %URI{parsed | query: new_query} |> URI.to_string()
  end
end
