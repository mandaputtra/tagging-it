defmodule TaggingItWeb.SheetLive do
  @moduledoc """
  The real SheetView print flow (prototype verdict: variant B full-sheet grid +
  variant C live field editing).

  The free tier is browser-only: the client's IndexedDB store pushes the batch
  and its codes via the `sheet:loaded` event, and this view renders them as a
  print-ready label sheet (Avery 5160 geometry per docs/research/print-layout.md).
  Field values are edited live with `TaggingIt.Fields.resolve` semantics.

  Void states: loading on mount, an empty state for a batch with no codes, and
  an error message (no crash) for an invalid payload.
  """

  use TaggingItWeb, :live_view

  alias TaggingIt.Fields
  alias TaggingIt.Fields.Field

  # Fixed sample geometry — Avery 5160: letter sheet, 3×10 grid of 2.625in×1in.
  # One `.sheet` block per page; 30 labels fit a sheet.
  @sheet_capacity 30
  @sheet_cols 3
  @sheet_rows 10

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       batch: nil,
       codes: [],
       error: nil,
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
end
