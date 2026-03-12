// PyreWeb LiveView connector
// Phoenix JS dependencies (phoenix.js, phoenix_html.js, phoenix_live_view.js)
// are prepended at compile time by PyreWeb.Assets.

let socketPath = document.querySelector("html").getAttribute("phx-socket") || "/live"
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}

Hooks.PasteUpload = {
  mounted() {
    this.handlePaste = (e) => {
      const files = e.clipboardData?.files;
      if (!files?.length) return;

      const input = this.el.querySelector("input[type=file]");
      if (!input) return;

      const dt = new DataTransfer();
      for (const f of files) {
        if (f.type.startsWith("image/")) dt.items.add(f);
      }
      if (dt.files.length) {
        input.files = dt.files;
        input.dispatchEvent(new Event("input", { bubbles: true }));
      }
    };
    window.addEventListener("paste", this.handlePaste);
  },
  destroyed() {
    window.removeEventListener("paste", this.handlePaste);
  }
}

let liveSocket = new LiveView.LiveSocket(socketPath, Phoenix.Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks
})

// WebSocket -> LongPoll fallback
const socket = liveSocket.socket
const originalOnConnError = socket.onConnError
let fallbackToLongPoll = true

socket.onOpen(() => { fallbackToLongPoll = false })

socket.onConnError = (...args) => {
  if (fallbackToLongPoll) {
    fallbackToLongPoll = false
    socket.disconnect(null, 3000)
    socket.transport = Phoenix.LongPoll
    socket.connect()
  } else {
    originalOnConnError.apply(socket, args)
  }
}

liveSocket.connect()

window.liveSocket = liveSocket
