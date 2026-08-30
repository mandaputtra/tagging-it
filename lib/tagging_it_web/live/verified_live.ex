defmodule TaggingItWeb.VerifiedLive do
  @moduledoc """
  Verified Code — shows a single code resolved by scan (tZkkH per #21 Variant A).

  `GET /verified/:code_id` mounts; the client hook `VerifiedLoader` fetches the
  code + its batch from IndexedDB and pushes `verified:loaded` (wire: batch + code
  as string-key maps). Valid payload renders barcode + fields + batch breadcrumb
  + Print; invalid payload renders an error (no crash).
  """

  use TaggingItWeb, :live_view

  @names %{
    "qrcode" => "QR Code",
    "code128" => "Code 128",
    "code39" => "Code 39",
    "ean13" => "EAN-13",
    "ean8" => "EAN-8",
    "upca" => "UPC-A",
    "pdf417" => "PDF417",
    "datamatrix" => "DataMatrix",
    "azteccode" => "Aztec"
  }

  @icon_paths %{
    arrow_left: ["M19 12H5", "m12 19-7-7 7-7"],
    printer: [
      "M6 9V2h12v7",
      "M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2",
      "M6 14h12v8a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1z"
    ],
    check: ["M20 6 9 17l-5-5"]
  }

  @impl true
  def mount(%{"code_id" => code_id}, _session, socket) do
    {:ok,
     assign(socket,
       code_id: code_id,
       batch: nil,
       code: nil,
       error: nil,
       icon_paths: @icon_paths
     )}
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       code_id: nil,
       batch: nil,
       code: nil,
       error: nil,
       icon_paths: @icon_paths
     )}
  end

  @impl true
  def handle_event("verified:loaded", %{"batch" => batch, "code" => code}, socket) do
    case validate_verified(batch, code) do
      {:ok, batch, code} -> {:noreply, assign(socket, batch: batch, code: code, error: nil)}
      :error -> {:noreply, assign(socket, error: "Couldn't load verified code — the payload was invalid.")}
    end
  end

  def handle_event("verified:loaded", _payload, socket) do
    {:noreply, assign(socket, error: "Couldn't load verified code — the payload was invalid.")}
  end

  defp validate_verified(%{"id" => bid} = batch, %{"id" => cid, "code_data" => cd} = code)
       when is_binary(bid) and bid != "" and is_binary(cid) and is_binary(cd) and cid != "" do
    {:ok, batch, code}
  end

  defp validate_verified(_batch, _code), do: :error

  defp icon(name, class) do
    assigns = %{name: name, class: class, paths: @icon_paths[name]}
    ~H"""
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class={@class} aria-hidden="true">
      <path :for={p <- @paths} d={p} />
    </svg>
    """
  end

  defp symbology_name(code) do
    Map.get(@names, code["symbology"] || "", "")
  end
end
