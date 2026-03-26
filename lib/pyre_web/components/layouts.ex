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
  attr :breadcrumbs, :list, default: []
  slot :inner_block, required: true

  def page_layout(assigns) do
    ~H"""
    <div class="flex flex-col min-h-screen">
      <.header prefix={@prefix} />
      <div class="flex flex-1">
        <.sidebar current_page={@current_page} prefix={@prefix} />
        <div class="flex-1 p-8 overflow-y-auto">
          <.breadcrumbs :if={@breadcrumbs != []} items={@breadcrumbs} />
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders DaisyUI breadcrumbs. Each item is a map with `:label` and an optional `:path`.
  Items with a `:path` render as navigate links; the last item (no path) renders as plain text.
  """
  attr :items, :list, required: true

  def breadcrumbs(assigns) do
    ~H"""
    <div class="breadcrumbs text-sm mb-4">
      <ul>
        <li :for={item <- @items}>
          <.link :if={item[:path]} navigate={item.path}>{item.label}</.link>
          <span :if={!item[:path]}>{item.label}</span>
        </li>
      </ul>
    </div>
    """
  end

  attr :prefix, :string, required: true

  def header(assigns) do
    ~H"""
    <div class="w-full h-16 pl-6 pr-6 items-center flex justify-between shadow-sm relative z-10">
      <div class="flex items-center">
        <.link class="tracking-widest text-2xl font-light uppercase" navigate={@prefix}>
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
      </div>
    </div>
    """
  end

  attr :current_page, :atom, required: true
  attr :prefix, :string, required: true

  def sidebar(assigns) do
    ~H"""
    <nav class="w-64 shrink-0 bg-base-200 py-6 px-3" style="min-height: calc(100vh - 4rem);">
      <div class="w-full">
        <ul class="menu menu-sm w-full">
          <li>
            <.link navigate={@prefix} class={@current_page == :home && "active"}>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
                class="size-4"
              >
                <path
                  fill-rule="evenodd"
                  d="M9.293 2.293a1 1 0 0 1 1.414 0l7 7A1 1 0 0 1 17 11h-1v6a1 1 0 0 1-1 1h-2a1 1 0 0 1-1-1v-3a1 1 0 0 0-1-1H9a1 1 0 0 0-1 1v3a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-6H3a1 1 0 0 1-.707-1.707l7-7Z"
                  clip-rule="evenodd"
                />
              </svg>
              Home
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
      </div>
    </nav>
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
end
