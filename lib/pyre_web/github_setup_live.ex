defmodule PyreWeb.GitHubSetupLive do
  @moduledoc """
  GitHub App setup page using the manifest flow.

  Renders a form that POSTs a manifest to GitHub to register a new App.
  After registration, GitHub redirects to the callback URL with credentials.
  """
  use PyreWeb.Web, :live_view

  @impl true
  def mount(_params, _session, socket) do
    configured = github_app_configured?()
    bot_slug = github_app_config(:bot_slug)

    {:ok,
     socket
     |> assign(
       page_title: "GitHub App Setup",
       configured: configured,
       bot_slug: bot_slug,
       org_name: nil
     )}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :uri, uri)}
  end

  @impl true
  def handle_event("set_org", %{"org_name" => org_name}, socket) do
    org_name = if org_name == "", do: nil, else: String.trim(org_name)
    {:noreply, assign(socket, :org_name, org_name)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout
      current_page={:github_setup}
      prefix={pyre_path(@socket, "")}
      uri={@uri}
      breadcrumbs={[%{label: "GitHub Setup"}]}
    >
      <%= if @configured do %>
        <div class="card bg-base-200 p-6">
          <h3 class="text-lg font-semibold mb-2">GitHub App Connected</h3>
          <p>Your GitHub App is configured and ready to receive webhook events.</p>
          <p class="mt-2">
            Bot slug: <code class="badge badge-ghost"><%= @bot_slug %></code>
          </p>
          <p class="mt-1">
            Users can mention <code class="badge badge-ghost">@<%= @bot_slug %></code>
            in PR comments to trigger reviews.
          </p>
        </div>
      <% else %>
        <div class="card bg-base-200 p-6">
          <h3 class="text-lg font-semibold mb-2">Register a GitHub App</h3>
          <p>
            Register a GitHub App to enable @mention-triggered PR reviews.
            This uses GitHub's manifest flow to create an App with the correct permissions.
          </p>

          <div class="form-control mt-4">
            <label class="label" for="org_name">
              <span class="label-text">
                Organization (optional — leave blank for personal account)
              </span>
            </label>
            <input
              type="text"
              id="org_name"
              name="org_name"
              value={@org_name || ""}
              phx-blur="set_org"
              placeholder="your-org-name"
              class="input input-bordered input-sm w-full max-w-xs"
            />
          </div>

          <form method="post" action={github_new_app_url(@org_name)} class="mt-4">
            <input type="hidden" name="manifest" value={manifest_json(base_url(@uri))} />
            <button type="submit" class="btn btn-primary btn-sm">
              Register GitHub App on GitHub
            </button>
          </form>

          <div class="mt-6">
            <h4 class="font-semibold mb-1">What happens next</h4>
            <ol class="list-decimal list-inside text-sm space-y-1">
              <li>You'll be redirected to GitHub to review and approve the App.</li>
              <li>GitHub redirects back here with your App credentials.</li>
              <li>Set the credentials as environment variables and restart.</li>
            </ol>

            <h4 class="font-semibold mt-4 mb-1">Required environment variables</h4>
            <ul class="list-disc list-inside text-sm space-y-1">
              <li><code>GITHUB_APP_ID</code></li>
              <li><code>GITHUB_APP_PRIVATE_KEY</code></li>
              <li><code>GITHUB_WEBHOOK_SECRET</code></li>
              <li><code>GITHUB_APP_BOT_SLUG</code></li>
            </ul>
          </div>
        </div>
      <% end %>
    </.page_layout>
    """
  end

  defp github_new_app_url(nil), do: "https://github.com/settings/apps/new"
  defp github_new_app_url(org), do: "https://github.com/organizations/#{org}/settings/apps/new"

  defp manifest_json(base_url) do
    %{
      name: "Pyre Code Review",
      url: base_url,
      hook_attributes: %{url: "#{base_url}/pyre/webhooks/github", active: true},
      redirect_url: "#{base_url}/pyre/github/callback",
      public: false,
      default_permissions: %{
        pull_requests: "write",
        contents: "read",
        metadata: "read",
        issues: "write"
      },
      default_events: [
        "issue_comment",
        "pull_request_review_comment"
      ]
    }
    |> Jason.encode!()
  end

  defp base_url(uri) do
    case Application.get_env(:pyre_web, :public_url) do
      nil ->
        parsed = URI.parse(uri)
        "#{parsed.scheme}://#{parsed.host}#{if parsed.port not in [80, 443], do: ":#{parsed.port}", else: ""}"

      url ->
        String.trim_trailing(url, "/")
    end
  end

  defp github_app_configured? do
    config = github_app_full_config()
    config[:app_id] != nil and config[:private_key] != nil
  end

  defp github_app_config(key) do
    config = github_app_full_config()

    if is_map(config) do
      Map.get(config, key)
    else
      Keyword.get(config, key)
    end
  end

  defp github_app_full_config do
    case PyreWeb.Config.call(:load_github_app, []) do
      config when is_map(config) and map_size(config) > 0 -> config
      _ -> Application.get_env(:pyre, :github_app, [])
    end
  end
end
