defmodule TaggingItWeb.BatchSerializer do
  @moduledoc """
  Serializes a `Batch` + its `Code`s into the wire shape the browser's
  IndexedDB store persists: plain maps with string keys, ISO-8601 timestamps,
  fields as `%{name, value}` maps. This is the `sheet:loaded` payload contract
  shared with the client (`assets/js/sheet_bridge.js`).
  """

  alias TaggingIt.Batch
  alias TaggingIt.Code

  @spec to_wire(Batch.t(), [Code.t()]) :: %{batch: map(), codes: [map()]}
  def to_wire(%Batch{} = batch, codes) do
    %{
      batch: batch_map(batch),
      codes: Enum.map(codes, &code_map/1)
    }
  end

  defp batch_map(%Batch{} = batch) do
    %{
      "id" => batch.id,
      "name" => batch.name,
      "template" => template_map(batch.template),
      "code_ids" => batch.code_ids,
      "created_at" => iso(batch.created_at),
      "updated_at" => iso(batch.updated_at),
      "dirty" => batch.dirty
    }
  end

  defp code_map(%Code{} = code) do
    %{
      "id" => code.id,
      "batch_id" => code.batch_id,
      "sequence" => code.sequence,
      "code_data" => code.code_data,
      "symbology" => code.symbology,
      "fields" => Enum.map(code.fields, &field_map/1),
      "created_at" => iso(code.created_at),
      "updated_at" => iso(code.updated_at),
      "dirty" => code.dirty
    }
  end

  defp template_map(template) do
    %{
      "name" => template.name,
      "fields" => Enum.map(template.fields, &field_map/1),
      "strategy" => strategy_map(template.strategy),
      "symbology" => template.symbology,
      "label_size" => template.label_size,
      "show_sequence" => template.show_sequence
    }
  end

  defp field_map(%{name: name, value: value}) do
    %{"name" => name, "value" => value}
  end

  defp strategy_map(nil), do: %{"type" => "paste"}

  defp strategy_map(%{__struct__: mod} = strategy) do
    base = %{"type" => String.replace(Module.split(mod) |> List.last(), "Strategy", "") |> String.downcase()}

    Enum.reduce(Map.from_struct(strategy), base, fn
      {_k, nil}, acc -> acc
      {k, %Date{} = v}, acc -> Map.put(acc, Atom.to_string(k), Date.to_iso8601(v))
      {k, v}, acc -> Map.put(acc, Atom.to_string(k), v)
    end)
  end

  defp iso(nil), do: nil
  defp iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
end
