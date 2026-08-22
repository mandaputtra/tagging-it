defmodule TaggingIt.CodeData do
  @moduledoc """
  Generates code data strings per a batch's strategy.

  A `CodeData` string is the value encoded in the barcode. Two strategies:

    * `PatternStrategy` — `prefix` + zero-padded sequence + `YYYYMMDD`
    * `UlidStrategy` — 26-char ULID (Crockford base32, time-sortable)

  Returns `{:ok, [code_data]}`, never raises. Invalid strategies return
  `{:error, :invalid_strategy}`.
  """

  alias TaggingIt.CodeData.{PatternStrategy, UlidStrategy}

  @seq_width 6

  @doc "Generates code data strings for the given strategy."
  @spec generate(PatternStrategy.t() | UlidStrategy.t()) :: {:ok, [String.t()]} | {:error, atom()}
  def generate(%PatternStrategy{count: 0}), do: {:ok, []}

  def generate(%PatternStrategy{} = strategy) do
    codes =
      Enum.map(strategy.start..(strategy.start + strategy.count - 1), fn n ->
        sequence = String.pad_leading(Integer.to_string(n), @seq_width, "0")
        date = strategy.date || Date.utc_today()

        strategy.prefix <> sequence <> Date.to_string(date) |> String.replace("-", "")
      end)

    {:ok, codes}
  end

  def generate(%UlidStrategy{count: 0}), do: {:ok, []}

  def generate(%UlidStrategy{} = strategy) do
    {:ok, Enum.map(1..strategy.count, fn _ -> TaggingIt.CodeData.Ulid.generate() end)}
  end

  def generate(_), do: {:error, :invalid_strategy}
end
