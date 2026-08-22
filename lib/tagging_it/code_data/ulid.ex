defmodule TaggingIt.CodeData.Ulid do
  @moduledoc """
  ULID generation — 48-bit millisecond timestamp + 82 bits of randomness,
  encoded as 26 chars of Crockford base32 (time-sortable, lexicographically
  ordered). Implemented locally with `:crypto`; no dependency needed.

  Crockford base32 alphabet: 0-9 A-Z minus I, L, O, U.
  """

  @alphabet ~c"0123456789ABCDEFGHJKMNPQRSTVWXYZ"
  @total_chars 26

  @doc "Generates a fresh ULID string."
  @spec generate() :: String.t()
  def generate do
    timestamp = :os.system_time(:millisecond)
    random = :crypto.strong_rand_bytes(11)

    encode(<<timestamp::48, random::bitstring-size(82)>>, @total_chars)
  end

  defp encode(binary, chars), do: encode(binary, chars, [])
  defp encode(_binary, 0, acc), do: acc |> Enum.reverse() |> List.to_string()

  defp encode(binary, remaining, acc) do
    <<value::5, rest::bitstring>> = binary
    encode(rest, remaining - 1, [Enum.at(@alphabet, value) | acc])
  end
end
