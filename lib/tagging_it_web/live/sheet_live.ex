defmodule TaggingItWeb.SheetLive do
  @moduledoc """
  The real SheetView print flow (prototype verdict: variant B full-sheet grid +
  variant C live field editing).

  The free tier is browser-only: the client's IndexedDB store pushes the batch
  and its codes via the `sheet:loaded` event, and this view renders them as a
  print-ready label sheet (Avery 5160 geometry per docs/research/print-layout.md).
  Field values are edited live with `TaggingIt.Fields.resolve` semantics.

  UI follows the pen.dev Print Preview design: a sticker-style shell around a
  scrollable live preview of the label sheets. Void states: loading on mount, an
  empty state for a batch with no codes, and an error message (no crash) for an
  invalid payload.
  """

  use TaggingItWeb, :live_view

  import Phoenix.Component

  alias TaggingIt.Fields
  alias TaggingIt.Fields.Field

  # Fixed sample geometry — Avery 5160: letter sheet, 3×10 grid of 2.625in×1in.
  # One `.sheet` block per page; 30 labels fit a sheet.
  @sheet_capacity 30
  @sheet_cols 3
  @sheet_rows 10

  # Symbology id → display name (for the info-card meta line).
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

  # Lucide icon path data (24px stroke set), keyed by the atoms above.
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
       icon_paths: @icon_paths,
       sheet: %{cols: @sheet_cols, rows: @sheet_rows, capacity: @sheet_capacity}
     )}
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       batch_id: nil,
       batch: nil,
       codes: [],
       error: nil,
       icon_paths: @icon_paths,
       sheet: %{cols: @sheet_cols, rows: @sheet_rows, capacity: @sheet_capacity}
     )}
  end

  @impl true
  def handle_event("sheet:loaded", %{"batch" => batch, "codes" => codes}, socket) do
    case validate_sheet(batch, codes) do
      {:ok, batch, codes} ->
        {:noreply, assign(socket, batch: batch, codes: codes, error: nil)}

      :error ->
        {:noreply, assign(socket, error: "Couldn't load sheet data — the payload was invalid.")}
    end
  end

  def handle_event("sheet:loaded", _payload, socket) do
    {:noreply, assign(socket, error: "Couldn't load sheet data — the payload was invalid.")}
  end

  @impl true
  def handle_event("field:update", %{"code_id" => code_id, "name" => name, "value" => value}, socket) do
    codes =
      Enum.map(socket.assigns.codes, fn code ->
        if code["id"] == code_id, do: update_field(code, name, value), else: code
      end)

    {:noreply, assign(socket, codes: codes)}
  end

  def handle_event("field:update", _payload, socket) do
    {:noreply, socket}
  end

  defp update_field(code, name, value) do
    # Resolve semantics: template order preserved, matching field replaced,
    # unknown names appended (TaggingIt.Fields.resolve/2).
    resolved =
      code
      |> Map.get("fields", [])
      |> Enum.map(&to_field/1)
      |> Fields.resolve([{name, value}])

    put_in(code["fields"], Enum.map(resolved, &%{"name" => &1.name, "value" => &1.value}))
  end

  # struct/2 does not map string keys onto struct fields; convert explicitly.
  defp to_field(%{"name" => name} = map) do
    %Field{name: name, value: Map.get(map, "value", "")}
  end

  defp validate_sheet(%{"id" => id} = batch, codes) when is_binary(id) and id != "" do
    if valid_codes?(codes), do: {:ok, batch, codes}, else: :error
  end

  defp validate_sheet(_batch, _codes), do: :error

  defp valid_codes?(codes) when is_list(codes) do
    Enum.all?(codes, fn
      %{"id" => id, "code_data" => code_data}
      when is_binary(id) and is_binary(code_data) and id != "" ->
        true

      _ ->
        false
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

  # "3 labels · 3×10 grid" plus " · Symbology Name" when the template has one.
  defp meta_line(codes, sheet, batch) do
    base = "#{length(codes)} labels · #{sheet.cols}×#{sheet.rows} grid"

    case symbology_name(batch) do
      "" -> base
      name -> base <> " · " <> name
    end
  end

  defp symbology_name(batch) do
    case get_in(batch || %{}, ["template", "symbology"]) do
      nil -> ""
      sym -> Map.get(@names, sym, sym)
    end
  end

  defp page_count(codes, capacity) when capacity > 0 do
    max(1, div(length(codes) + capacity - 1, capacity))
  end

  defp page_count(_codes, _capacity), do: 1
end
