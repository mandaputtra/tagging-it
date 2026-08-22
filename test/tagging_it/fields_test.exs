defmodule TaggingIt.FieldsTest do
  use ExUnit.Case, async: true

  alias TaggingIt.Fields
  alias TaggingIt.Fields.Field

  describe "resolve/2" do
    test "returns the template unchanged when there are no overrides" do
      template = [
        %Field{name: "SKU", value: "SKU-1"},
        %Field{name: "Price", value: "$10"}
      ]

      assert Fields.resolve(template, []) == template
    end

    test "an override replaces the value of the matching field, preserving order" do
      template = [
        %Field{name: "SKU", value: "SKU-1"},
        %Field{name: "Price", value: "$10"}
      ]

      assert Fields.resolve(template, [{"SKU", "SKU-2"}]) == [
               %Field{name: "SKU", value: "SKU-2"},
               %Field{name: "Price", value: "$10"}
             ]
    end

    test "an override for an unknown field appends a new field after the template" do
      template = [%Field{name: "SKU", value: "SKU-1"}]

      assert Fields.resolve(template, [{"Batch", "B-2208"}]) == [
               %Field{name: "SKU", value: "SKU-1"},
               %Field{name: "Batch", value: "B-2208"}
             ]
    end

    test "known overrides replace in place, unknown overrides append in order" do
      template = [
        %Field{name: "A", value: "1"},
        %Field{name: "B", value: "2"}
      ]

      assert Fields.resolve(template, [{"B", "22"}, {"C", "3"}]) == [
               %Field{name: "A", value: "1"},
               %Field{name: "B", value: "22"},
               %Field{name: "C", value: "3"}
             ]
    end

    test "an empty template with overrides yields just the override fields" do
      assert Fields.resolve([], [{"X", "1"}, {"Y", "2"}]) == [
               %Field{name: "X", value: "1"},
               %Field{name: "Y", value: "2"}
             ]
    end

    test "empty template and no overrides yields an empty field map" do
      assert Fields.resolve([], []) == []
    end

    test "duplicate override names: the last one wins" do
      template = [%Field{name: "A", value: "1"}]

      assert Fields.resolve(template, [{"A", "2"}, {"A", "3"}]) == [
               %Field{name: "A", value: "3"}
             ]
    end

    test "an override with an empty string value keeps the field" do
      template = [%Field{name: "Note", value: "x"}]

      assert Fields.resolve(template, [{"Note", ""}]) == [%Field{name: "Note", value: ""}]
    end
  end
end
