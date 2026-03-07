defmodule PyreWeb.Web do
  @moduledoc false

  def html do
    quote do
      @moduledoc false
      use Phoenix.Component
      import Phoenix.HTML
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView
      import Phoenix.HTML
    end
  end

  def live_component do
    quote do
      @moduledoc false
      use Phoenix.LiveComponent
      import Phoenix.HTML
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
