defmodule TaggingIt.CodeData.UlidStrategy do
  @moduledoc "Code data as a random 26-char ULID (Crockford base32, time-sortable)."

  @enforce_keys [:count]
  defstruct count: 1

  @type t :: %__MODULE__{count: non_neg_integer()}
end
