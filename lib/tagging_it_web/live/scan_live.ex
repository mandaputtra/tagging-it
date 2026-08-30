defmodule TaggingItWeb.ScanLive do
  @moduledoc """
  Scan Label — Variant A per #21 (camera viewport + manual fallback input) but
  input is the v1 pivot; camera is progressive enhancement per #19.

  The free tier is browser-only: the hook `ScanLoader` reads `codesByValue`
  from IndexedDB and either navigates to `/verified/:id` (hit) or pushes
  `scan:miss` (miss → modal popup, stays on Scan).
  """

  use TaggingItWeb, :live_view

  @icon_paths %{
    arrow_left: ["M19 12H5", "m12 19-7-7 7-7"],
    scan: ["M3 7v5a4 4 0 0 0 8 0V7", "M3 16v5a4 4 0 0 0 8 0v-5", "M21 7v5a4 4 0 0 0-8 0V7", "M21 16v5a4 4 0 0 0-8 0v-5"],
    qr: ["M3 3h5v5H3z", "M16 3h5v5h-5z", "M3 16h5v5H3z", "M21 16h-3a2 2 0 0 0-2 2v3", "M21 21h.01", "M12 7h3a2 2 0 0 1 2 2v3", "M3 12h.01", "M12 3h.01", "M12 16h.01", "M16 12h.01", "M21 12h.01", "M12 21v-1"]
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       scan_value: "",
       show_miss: false,
       miss_value: "",
       icon_paths: @icon_paths
     )}
  end

  @impl true
  def handle_event("scan:miss", %{"value" => value}, socket) when is_binary(value) do
    {:noreply, assign(socket, show_miss: true, miss_value: value)}
  end

  def handle_event("scan:miss", _payload, socket) do
    {:noreply, assign(socket, show_miss: true, miss_value: "")}
  end

  @impl true
  def handle_event("scan:clear", _payload, socket) do
    {:noreply, assign(socket, show_miss: false, miss_value: "")}
  end

  defp icon(name, class) do
    assigns = %{name: name, class: class, paths: @icon_paths[name]}
    ~H"""
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class={@class} aria-hidden="true">
      <path :for={p <- @paths} d={p} />
    </svg>
    """
  end
end
