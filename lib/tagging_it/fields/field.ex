defmodule TaggingIt.Fields.Field do
  @moduledoc """
  A single `{field_name, value}` pair rendered on a label.

  Free-form: the name is arbitrary text chosen by the user (e.g. "SKU",
  "Price", "Batch"); the value is any string. No preset taxonomy.
  """

  @enforce_keys [:name]
  defstruct name: nil, value: ""

  @type t :: %__MODULE__{name: String.t(), value: String.t()}
end
