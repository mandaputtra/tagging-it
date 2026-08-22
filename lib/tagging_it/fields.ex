defmodule TaggingIt.Fields do
  @moduledoc """
  Resolves a code's field map from a batch template and per-code overrides.

  A code's stored field map is the fully resolved, ordered list of fields —
  template fields (with overridden values) followed by any override-only
  fields in override order. No merge happens at render time; the resolved map
  is what the code persists (see CONTEXT.md: Field map).
  """

  alias TaggingIt.Fields.Field

  @doc """
  Resolves `overrides` (list of `{name, value}`) against `template` (list of
  `Field`). Template order is preserved; an override replaces the value of a
  matching field, and overrides for unknown fields append after the template.
  """
  @spec resolve([Field.t()], [{String.t(), String.t()}]) :: [Field.t()]
  def resolve(template, overrides) do
    override_map = Map.new(overrides)

    template =
      Enum.map(template, fn %Field{name: name} = field ->
        case Map.fetch(override_map, name) do
          {:ok, value} -> %{field | value: value}
          :error -> field
        end
      end)

    template_names = MapSet.new(template, & &1.name)

    appended =
      overrides
      |> Enum.uniq_by(fn {name, _} -> name end)
      |> Enum.reject(fn {name, _} -> MapSet.member?(template_names, name) end)
      |> Enum.map(fn {name, value} -> %Field{name: name, value: value} end)

    template ++ appended
  end
end
