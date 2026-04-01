defmodule PyreWeb.SettingsGithubAppsIndexLive do
  @moduledoc """
  GitHub Apps landing page showing current configuration and a link to register.
  """
  use PyreWeb.Web, :live_view

  @impl true
  def mount(_params, _session, socket) do
    config = PyreWeb.Config.call(:get_github_app, [])

    app =
      if is_map(config) and config[:app_id] do
        %{
          app_id: config[:app_id],
          bot_slug: config[:bot_slug],
          webhook_secret_set: config[:webhook_secret] != nil,
          private_key_set: config[:private_key] != nil
        }
      else
        nil
      end

    {:ok, assign(socket, page_title: "GitHub Apps", app: app)}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :uri, uri)}
  end
end
