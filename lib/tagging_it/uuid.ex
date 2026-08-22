defmodule TaggingIt.UUID do
  @moduledoc """
  UUID v4 generation via `:crypto` — no dependency needed.

  Format: 8-4-4-4-12 hex digits, version nibble 4, variant bits 10xx.
  """

  @doc "Generates a UUID v4 string."
  @spec generate() :: String.t()
  def generate do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)

    c = Bitwise.bor(Bitwise.band(c, 0x0FFF), 0x4000)
    d = Bitwise.bor(Bitwise.band(d, 0x3FFF), 0x8000)

    :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b", [a, b, c, d, e])
    |> IO.iodata_to_binary()
  end

  @doc "Checks whether a string is a valid UUID v4."
  @spec valid?(String.t()) :: boolean()
  def valid?(uuid) when is_binary(uuid) do
    Regex.match?(~r/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/, uuid)
  end

  def valid?(_), do: false
end
