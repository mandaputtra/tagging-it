defmodule TaggingItWeb.CodeDetailLive do
  @moduledoc """
  Code Detail — per-code view opened from Batch Detail (#24).

  The batch detail code list links each row to `GET /codes/:code_id`; the free
  tier is browser-only, so the client hook `CodeDetailLoader` reads the code +
  its batch from IndexedDB (`getCode` + `getBatch`) and pushes `code:loaded`
  (wire: batch + code as string-key maps). Valid payload renders barcode +
  fields + batch breadcrumb + Print; invalid payload renders an error (no
  crash). Mirrors VerifiedLive but with batch-detail context (neutral branding,
  back to the batch) — the Verified view stays scan-branded per #22.
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
    qr: [
      "M3 3h5v5H3z",
      "M16 3h5v5h-5z",
      "M3 16h5v5H3z",
      "M21 16h-3a2 2 0 0 0-2 2v3",
      "M21 21h.01",
      "M12 7h3a2 2 0 0 1 2 2v3",
      "M3 12h.01",
      "M12 3h.01",
      "M12 16h.01",
      "M16 12h.01",
      "M21 12h.01",
      "M12 21v-1"
    ]
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
  def handle_event("code:loaded", %{"batch" => batch, "code" => code}, socket) do
    case validate_code(batch, code) do
      {:ok, batch, code} -> {:noreply, assign(socket, batch: batch, code: code, error: nil)}
      :error -> {:noreply, assign(socket, error: "Couldn't load code — the payload was invalid.")}
    end
  end

  def handle_event("code:loaded", _payload, socket) do
    {:noreply, assign(socket, error: "Couldn't load code — the payload was invalid.")}
  end

  defp validate_code(%{"id" => bid} = batch, %{"id" => cid, "code_data" => cd} = code)
       when is_binary(bid) and bid != "" and is_binary(cid) and is_binary(cd) and cid != "" do
    {:ok, batch, code}
  end

  defp validate_code(_batch, _code), do: :error

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
