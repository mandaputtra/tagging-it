defmodule TaggingItWeb.BatchDetailLive do
  @moduledoc """
  Batch Detail — the bridgehead for single-code (batch size 1) and bulk batches.

  Per #18 the home Recent list now links here (not directly to the sheet).
  The free tier is browser-only: the client reads the batch + codes from
  IndexedDB (`getBatch` + `codesByBatch`) and pushes `detail:loaded`; this view
  validates the wire payload and renders the sticker detail (batch meta + code
  list) with Print → sheet, Delete, and Scan entry points.
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
    trash_2: [
      "M3 6h18",
      "M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6",
      "M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2",
      "M10 11v6",
      "M14 11v6"
    ],
    scan: ["M3 7v5a4 4 0 0 0 8 0V7", "M3 16v5a4 4 0 0 0 8 0v-5", "M21 7v5a4 4 0 0 0-8 0V7", "M21 16v5a4 4 0 0 0-8 0v-5"],
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
  def mount(%{"batch_id" => batch_id}, _session, socket) do
    {:ok,
     assign(socket,
       batch_id: batch_id,
       batch: nil,
       codes: [],
       error: nil,
       icon_paths: @icon_paths
     )}
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       batch_id: nil,
       batch: nil,
       codes: [],
       error: nil,
       icon_paths: @icon_paths
     )}
  end

  @impl true
  def handle_event("detail:loaded", %{"batch" => batch, "codes" => codes}, socket) do
    case validate_detail(batch, codes) do
      {:ok, batch, codes} -> {:noreply, assign(socket, batch: batch, codes: codes, error: nil)}
      :error -> {:noreply, assign(socket, error: "Couldn't load batch data — the payload was invalid.")}
    end
  end

  def handle_event("detail:loaded", _payload, socket) do
    {:noreply, assign(socket, error: "Couldn't load batch data — the payload was invalid.")}
  end

  defp validate_detail(%{"id" => id} = batch, codes) when is_binary(id) and id != "" do
    if valid_codes?(codes), do: {:ok, batch, codes}, else: :error
  end

  defp validate_detail(_batch, _codes), do: :error

  defp valid_codes?(codes) when is_list(codes) do
    Enum.all?(codes, fn
      %{"id" => id, "code_data" => code_data} when is_binary(id) and is_binary(code_data) and id != "" -> true
      _ -> false
    end)
  end

  defp valid_codes?(_), do: false

  defp icon(name, class) do
    assigns = %{name: name, class: class, paths: @icon_paths[name]}
    ~H"""
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class={@class} aria-hidden="true">
      <path :for={p <- @paths} d={p} />
    </svg>
    """
  end

  defp symbology_name(batch) do
    case get_in(batch || %{}, ["template", "symbology"]) do
      nil -> ""
      sym -> Map.get(@names, sym, sym)
    end
  end
end
