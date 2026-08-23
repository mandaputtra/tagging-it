defmodule TaggingIt.UUID do
  @moduledoc """
  UUID v7 generation via `:crypto` — no dependency needed.

  RFC 9562: 48-bit unix-ms timestamp, version nibble 7, variant bits `10xx`.
  Time-sortable (per #14 Code ID), which also helps sync ordering (#6).
  """

  @doc "Generates a UUID v7 string."
  @spec generate() :: String.t()
  def generate do
    ts = System.system_time(:millisecond)
    <<rand_a::12, rand_b::62>> = <<random(74)::74>>

    <<ts::48, 7::4, rand_a::12, 0b10::2, rand_b::62>>
    |> format()
  end

  @doc "Checks whether a string is a valid UUID v7."
  @spec valid?(String.t()) :: boolean()
  def valid?(uuid) when is_binary(uuid) do
    Regex.match?(
      ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/,
      uuid
    )
  end

  def valid?(_), do: false

  # `bits` random bits as an integer, from a byte-aligned buffer.
  defp random(bits) do
    bytes = div(bits + 7, 8)
    <<r::size(^bits), _::size(bytes * 8 - bits)>> = :crypto.strong_rand_bytes(bytes)
    r
  end

  defp format(<<a::32, b::16, c::16, d::16, e::48>>) do
    :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b", [a, b, c, d, e])
    |> IO.iodata_to_binary()
  end
end
