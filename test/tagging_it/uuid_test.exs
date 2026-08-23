defmodule TaggingIt.UUIDTest do
  use ExUnit.Case, async: true

  alias TaggingIt.UUID

  describe "generate/0" do
    test "produces a UUID v7 string (version nibble 7, RFC 9562 layout)" do
      uuid = UUID.generate()

      assert String.match?(uuid, ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
    end

    test "is unique across many calls" do
      assert length(Enum.uniq(Enum.map(1..100, fn _ -> UUID.generate() end))) == 100
    end

    test "embeds the current unix timestamp in the first 48 bits (time-sortable)" do
      before = System.system_time(:millisecond)
      uuid = UUID.generate()
      after_ts = System.system_time(:millisecond)

      <<ts::48, _::80>> = decode(uuid)

      assert ts >= before
      assert ts <= after_ts
    end
  end

  describe "valid?/1" do
    test "accepts generated v7 uuids" do
      assert UUID.valid?(UUID.generate())
    end

    test "rejects malformed strings" do
      refute UUID.valid?(nil)
      refute UUID.valid?("not-a-uuid")
      refute UUID.valid?("00000000-0000-0000-0000-000000000000")
      refute UUID.valid?(String.replace(UUID.generate(), "-", ""))
    end
  end

  # 8-4-4-4-12 hex groups → 128 bits.
  defp decode(uuid) do
    uuid
    |> String.replace("-", "")
    |> Base.decode16!(case: :lower)
  end
end
