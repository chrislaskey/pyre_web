defmodule PyreWeb.Socket do
  @moduledoc """
  Phoenix Socket for Pyre native app connections.

  Routes channel topic requests to the appropriate channel modules.

  ## Host App Setup

  This socket must be mounted in the host application's endpoint:

      # lib/my_app_web/endpoint.ex
      socket "/pyre", PyreWeb.Socket,
        websocket: [connect_info: [:peer_data, :x_headers]]

  The path (`/pyre`) should match the path used when mounting `pyre_web`
  in the router.
  """
  use Phoenix.Socket

  require Logger

  channel "pyre:*", PyreWeb.Channel

  @impl true
  def connect(params, socket, _connect_info) do
    socket = assign(socket, :params, params)
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
