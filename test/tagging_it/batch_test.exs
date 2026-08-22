defmodule TaggingIt.BatchTest do
  use ExUnit.Case, async: true

  alias TaggingIt.Batch
  alias TaggingIt.Batch.Template
  alias TaggingIt.CodeData.{PatternStrategy, UlidStrategy}
  alias TaggingIt.Fields.Field

  defp template(overrides \\ []) do
    struct!(
      Template,
      Keyword.merge(
        [
          name: "Products",
          fields: [
            %Field{name: "SKU", value: ""},
            %Field{name: "Price", value: "$10"}
          ],
          strategy: %PatternStrategy{prefix: "CODEPRODUCT", start: 1, count: 3, date: ~D[2026-01-01]}
        ],
        overrides
      )
    )
  end

  describe "create/1" do
    test "creates one code per strategy count, sharing the batch id" do
      assert {:ok, batch, codes} = Batch.create(template())

      assert length(codes) == 3
      assert Enum.all?(codes, &(&1.batch_id == batch.id))
      assert Enum.map(codes, & &1.code_data) == [
               "CODEPRODUCT00000120260101",
               "CODEPRODUCT00000220260101",
               "CODEPRODUCT00000320260101"
             ]
    end

    test "each code carries a unique id and the template's symbology" do
      assert {:ok, _batch, codes} = Batch.create(template())

      assert length(Enum.uniq(Enum.map(codes, & &1.id))) == 3
      assert Enum.all?(codes, &(&1.symbology == "code128"))
    end

    test "each code's field map is the template's resolved fields" do
      assert {:ok, _batch, codes} = Batch.create(template())

      expected = [
        %Field{name: "SKU", value: ""},
        %Field{name: "Price", value: "$10"}
      ]

      assert Enum.all?(codes, &(&1.fields == expected))
    end

    test "new codes and the batch are dirty (pending sync)" do
      assert {:ok, batch, codes} = Batch.create(template())
      assert batch.dirty
      assert Enum.all?(codes, & &1.dirty)
    end

    test "codes carry created_at and updated_at" do
      assert {:ok, _batch, codes} = Batch.create(template())
      assert Enum.all?(codes, &(&1.created_at != nil))
      assert Enum.all?(codes, &(&1.updated_at != nil))
    end

    test "ulid strategy produces codes with 26-char data" do
      t = template(strategy: %UlidStrategy{count: 2})

      assert {:ok, _batch, codes} = Batch.create(t)
      assert length(codes) == 2
      assert Enum.all?(codes, &(String.length(&1.code_data) == 26))
    end

    test "empty field template yields codes with empty field maps" do
      t = template(fields: [])
      assert {:ok, _batch, codes} = Batch.create(t)
      assert Enum.all?(codes, &(&1.fields == []))
    end

    test "batch id and code ids are valid uuid v4" do
      assert {:ok, batch, codes} = Batch.create(template())

      ids = [batch.id | Enum.map(codes, & &1.id)]
      assert Enum.all?(ids, &TaggingIt.UUID.valid?/1)
    end
  end
end
