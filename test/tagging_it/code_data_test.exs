defmodule TaggingIt.CodeDataTest do
  use ExUnit.Case, async: true

  alias TaggingIt.CodeData
  alias TaggingIt.CodeData.{PatternStrategy, UlidStrategy}

  describe "PatternStrategy" do
    test "generates prefix + zero-padded sequence + YYYYMMDD" do
      strategy = %PatternStrategy{prefix: "CODEPRODUCT", start: 1, count: 3, date: ~D[2026-01-01]}

      assert {:ok, codes} = CodeData.generate(strategy)
      assert codes == ["CODEPRODUCT00000120260101", "CODEPRODUCT00000220260101", "CODEPRODUCT00000320260101"]
    end

    test "zero-pads the sequence to six digits" do
      strategy = %PatternStrategy{prefix: "SKU", start: 1, count: 2, date: ~D[2026-01-01]}

      assert {:ok, codes} = CodeData.generate(strategy)
      assert codes == ["SKU00000120260101", "SKU00000220260101"]
    end

    test "sequence continues past 999999 without truncation" do
      strategy = %PatternStrategy{prefix: "X", start: 999_999, count: 2, date: ~D[2026-01-01]}

      assert {:ok, [a, b]} = CodeData.generate(strategy)
      assert a == "X99999920260101"
      assert b == "X100000020260101"
    end

    test "date defaults to today when omitted" do
      strategy = %PatternStrategy{prefix: "P", start: 1, count: 1}
      today = Date.utc_today() |> Date.to_string() |> String.replace("-", "")

      assert {:ok, [code]} = CodeData.generate(strategy)
      assert code == "P000001" <> today
    end

    test "count of zero returns no codes" do
      strategy = %PatternStrategy{prefix: "P", start: 1, count: 0, date: ~D[2026-01-01]}
      assert {:ok, []} = CodeData.generate(strategy)
    end
  end

  describe "UlidStrategy" do
    test "generates 26-char uppercase Crockford-base32 codes" do
      strategy = %UlidStrategy{count: 5}

      assert {:ok, codes} = CodeData.generate(strategy)
      assert length(codes) == 5
      assert Enum.all?(codes, fn c -> String.length(c) == 26 end)
      assert Enum.all?(codes, fn c -> String.match?(c, ~r/\A[0-9A-HJKMNP-TV-Z]+\z/) end)
    end

    test "generates distinct codes" do
      strategy = %UlidStrategy{count: 100}

      assert {:ok, codes} = CodeData.generate(strategy)
      assert length(Enum.uniq(codes)) == 100
    end

    test "count of zero returns no codes" do
      strategy = %UlidStrategy{count: 0}
      assert {:ok, []} = CodeData.generate(strategy)
    end
  end
end
