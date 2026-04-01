defmodule PyreWeb.WebhookController do
  @moduledoc """
  Handles incoming GitHub webhook events.

  Verifies the HMAC-SHA256 signature, parses the event type,
  and dispatches to the appropriate handler.
  """

  use Phoenix.Controller, formats: [:json]

  plug :skip_csrf_protection

  require Logger

  def github(conn, params) do
    raw_body = conn.private[:raw_body] || ""
    event = get_req_header(conn, "x-github-event") |> List.first()

    with :ok <- verify_signature(conn, raw_body),
         :ok <- PyreWeb.Config.authorize(:authorize_webhook, [event, params]) do
      handle_event(event, params["action"], params)
      json(conn, %{status: "accepted"})
    else
      {:error, :invalid_signature} ->
        conn |> put_status(401) |> json(%{error: "invalid signature"})

      {:error, reason} ->
        conn |> put_status(403) |> json(%{error: inspect(reason)})
    end
  end

  # --- Signature verification ---

  defp verify_signature(conn, raw_body) do
    secret = github_app_config(:webhook_secret)

    if secret do
      signature = get_req_header(conn, "x-hub-signature-256") |> List.first() || ""
      expected_mac = :crypto.mac(:hmac, :sha256, secret, raw_body)
      expected = "sha256=" <> Base.encode16(expected_mac, case: :lower)

      if Plug.Crypto.secure_compare(signature, expected) do
        :ok
      else
        {:error, :invalid_signature}
      end
    else
      Logger.warning("GitHub webhook secret not configured — skipping signature verification")
      :ok
    end
  end

  # --- Event dispatch ---

  defp handle_event("issue_comment", "created", payload) do
    if payload["issue"]["pull_request"] do
      handle_mention(payload, :issue_comment)
    end
  end

  defp handle_event("pull_request_review_comment", "created", payload) do
    handle_mention(payload, :review_comment)
  end

  defp handle_event("installation", _action, payload) do
    Logger.info(
      "GitHub App installation event: #{payload["action"]} for #{payload["installation"]["id"]}"
    )
  end

  defp handle_event(event, action, _payload) do
    Logger.debug("Ignoring GitHub webhook: #{event}/#{action}")
  end

  # --- @Mention handling ---

  defp handle_mention(payload, comment_type) do
    bot_slug = github_app_config(:bot_slug)

    unless bot_slug do
      Logger.warning("GitHub App bot_slug not configured — cannot detect @mentions")
    else
      body = payload["comment"]["body"] || ""

      case PyreWeb.MentionParser.parse(body, bot_slug) do
        {:ok, command} ->
          dispatch_command(command, payload, comment_type)

        :ignore ->
          :ok
      end
    end
  end

  defp dispatch_command(command, payload, comment_type) do
    {command_name, _opts} = normalize_command(command)

    owner = get_in(payload, ["repository", "owner", "login"])
    repo = get_in(payload, ["repository", "name"])
    installation_id = get_in(payload, ["installation", "id"])

    pr_number =
      case comment_type do
        :issue_comment -> payload["issue"]["number"]
        :review_comment -> get_in(payload, ["pull_request", "number"])
      end

    in_reply_to =
      case comment_type do
        :review_comment -> payload["comment"]["id"]
        :issue_comment -> nil
      end

    job = %{
      owner: owner,
      repo: repo,
      pr_number: pr_number,
      installation_id: installation_id,
      comment_id: payload["comment"]["id"],
      in_reply_to: in_reply_to,
      command: command_name
    }

    job =
      case command do
        {:followup, text} -> Map.put(job, :followup_text, text)
        _ -> job
      end

    if PyreWeb.ReviewQueue.running?() do
      post_acknowledgment(job, command_name)
      PyreWeb.ReviewQueue.enqueue(job)
    else
      Logger.warning("PyreWeb.ReviewQueue not started — ignoring @mention command")
    end
  end

  defp normalize_command({:followup, _text} = cmd), do: {:followup, cmd}
  defp normalize_command({name, opts}), do: {name, opts}

  defp post_acknowledgment(_job, :help), do: :ok

  defp post_acknowledgment(job, command) do
    Task.start(fn ->
      case apply(Pyre.GitHub.App, :installation_token, [job.installation_id]) do
        {:ok, token} ->
          label = if command == :review, do: "Reviewing", else: "Working on"
          body = "> #{label} this PR now. I'll reply here when done."
          apply(Pyre.GitHub, :create_comment, [job.owner, job.repo, job.pr_number, body, token])

        _ ->
          :ok
      end
    end)
  end

  # --- CSRF ---

  # Webhook POSTs come from GitHub, not a browser, so CSRF protection must be
  # skipped. This allows the route to live inside the :browser pipeline alongside
  # the rest of the pyre_web routes.
  defp skip_csrf_protection(conn, _opts) do
    Plug.Conn.put_private(conn, :plug_skip_csrf_protection, true)
  end

  # --- Config helpers ---

  defp github_app_config(key) do
    case PyreWeb.Config.call(:load_github_app, []) do
      config when is_map(config) and map_size(config) > 0 ->
        Map.get(config, key)

      _ ->
        app_env = Application.get_env(:pyre, :github_app, [])

        if is_list(app_env) do
          Keyword.get(app_env, key)
        else
          Map.get(app_env, key)
        end
    end
  end
end
