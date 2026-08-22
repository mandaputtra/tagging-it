defmodule TaggingIt.CodeData.PatternStrategy do
  @moduledoc """
  Code data as `prefix` + zero-padded sequence + `YYYYMMDD`.

  Example: `CODEPRODUCT` + `000001` + `20260101` → `CODEPRODUCT00000120260101`.
  """

  @enforce_keys [:prefix]
  defstruct prefix: nil, start: 1, count: 1, date: nil

  @type t :: %__MODULE__{
          prefix: String.t(),
          start: pos_integer(),
          count: non_neg_integer(),
          date: Date.t() | nil
        }
end
