defmodule TaggingItWeb.SheetLiveTest do
  use TaggingItWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TaggingIt.Batch
  alias TaggingIt.Batch.Template
  alias TaggingIt.CodeData.PatternStrategy
  alias TaggingIt.Fields.Field

  describe "mount" do
    test "renders a loading state before the sheet is loaded" do
      {:ok, _view, html} = live(build_conn(), "/sheet/batch-1")

      assert html =~ "Loading sheet"
      assert find(html, ".sheet-loading") != []
    end

    test "renders the Print Preview nav with a back link and title" do
      {:ok, _view, html} = live(build_conn(), "/sheet/batch-1")

      assert text(html) =~ "Print Preview"
      assert find(html, ~s(a[href="/"])) != []
    end
  end

  describe "sheet:loaded" do
    test "renders one label per code, each with its code data and field lines" do
      {:ok, view, _html} = live(build_conn(), "/sheet/batch-1")
      {batch, codes} = sample_sheet()

      html = render_click(view, "sheet:loaded", %{"batch" => wire(batch), "codes" => wire(codes)})

      assert length(find(html, ".label")) == length(codes)

      assert find(html, ~s(button[phx-hook='SheetDelete'][data-batch-id="#{batch.id}"])) != []

      for code <- codes do
        assert [label] = find(html, ~s(.label[data-code-data="#{code.code_data}"]))
        assert [barcode] = Floki.find(label, ".barcode")
        assert Floki.attribute(barcode, "data-text") == [code.code_data]
        assert Floki.attribute(barcode, "data-bcid") == ["code128"]

        for field <- code.fields do
          assert Floki.text(label) =~ field.name

          assert [input] = Floki.find(label, ~s(input[data-field-name="#{field.name}"]))
          assert Floki.attribute(input, "value") == [field.value]
        end
      end
    end

    test "renders the info card, page row, and actions once the batch loads" do
      {:ok, view, _html} = live(build_conn(), "/sheet/batch-1")
      {batch, codes} = sample_sheet()

      html = render_click(view, "sheet:loaded", %{"batch" => wire(batch), "codes" => wire(codes)})

      # info card: batch name + meta line (labels · grid · symbology)
      assert text(html) =~ batch.name
      assert text(html) =~ "3 labels · 3×10 grid · Code 128"

      # page row: 3 codes fit one 30-capacity sheet
      assert text(html) =~ "Page 1 of 1"

      # actions: print + delete
      assert find(html, ".sheet-print") != []
      assert find(html, "#sheet-delete") != []
      assert text(html) =~ "Print"
      assert text(html) =~ "Delete batch"

      # the print sheet markup still renders inside the preview
      assert find(html, ".sheet") != []
    end

    test "shows an error card with a link home when the payload is invalid" do
      {:ok, view, _html} = live(build_conn(), "/sheet/batch-1")

      html = render_click(view, "sheet:loaded", %{"batch" => %{"id" => ""}, "codes" => []})

      assert find(html, ".sheet-error") != []
      assert text(html) =~ "Couldn't load this batch from this browser."
      assert find(html, ~s(a[href="/"])) != []
    end

    test "shows an empty state when the batch has no codes" do
      {:ok, view, _html} = live(build_conn(), "/sheet/batch-1")
      {batch, _codes} = sample_sheet()

      html = render_click(view, "sheet:loaded", %{"batch" => wire(batch), "codes" => []})

      assert find(html, ".sheet-empty") != []
      assert text(html) =~ "No codes"
      assert find(html, ".label") == []
    end

    test "renders the sequence line on each label by default" do
      {:ok, view, _html} = live(build_conn(), "/sheet/batch-1")
      {batch, codes} = sample_sheet()

      html = render_click(view, "sheet:loaded", %{"batch" => wire(batch), "codes" => wire(codes)})

      for code <- codes do
        assert [label] = find(html, ~s(.label[data-code-data="#{code.code_data}"]))
        assert [seq] = Floki.find(label, ".label-seq")
        assert Floki.text(seq) =~ code.sequence
      end
    end

    test "omits the sequence line when the template hides it" do
      {:ok, view, _html} = live(build_conn(), "/sheet/batch-1")
      {batch, codes} = sample_sheet()
      batch = put_in(batch.template.show_sequence, false)

      html = render_click(view, "sheet:loaded", %{"batch" => wire(batch), "codes" => wire(codes)})

      assert find(html, ".label-seq") == []
      assert length(find(html, ".label")) == length(codes)
    end
  end

  describe "field:update" do
    test "updates that code's field value and re-renders without touching siblings" do
      {:ok, view, _html} = live(build_conn(), "/sheet/batch-1")
      {batch, [target | rest]} = sample_sheet()
      other = hd(rest)

      html = render_click(view, "sheet:loaded", %{"batch" => wire(batch), "codes" => wire([target | rest])})

      assert [before] = find(html, ~s(#label-#{target.id} input[data-field-name="Price"]))
      assert Floki.attribute(before, "value") == ["$12.50"]

      html =
        render_change(view, "field:update", %{
          "code_id" => target.id,
          "name" => "Price",
          "value" => "$15.00"
        })

      assert [updated] = find(html, ~s(#label-#{target.id} input[data-field-name="Price"]))
      assert Floki.attribute(updated, "value") == ["$15.00"]

      # sibling field on the same code is untouched
      assert [sibling] = find(html, ~s(#label-#{target.id} input[data-field-name="SKU"]))
      assert Floki.attribute(sibling, "value") == ["SKU-2041-B"]

      # other codes are untouched
      assert [other_price] = find(html, ~s(#label-#{other.id} input[data-field-name="Price"]))
      assert Floki.attribute(other_price, "value") == ["$12.50"]
    end
  end

  describe "print css" do
    test "renders letter page CSS for label-stock printing" do
      {:ok, view, _html} = live(build_conn(), "/sheet/batch-1")
      {batch, codes} = sample_sheet()

      html = render_click(view, "sheet:loaded", %{"batch" => wire(batch), "codes" => wire(codes)})

      assert html =~ "@page"
      assert html =~ "8.5in 11in"
      assert html =~ "@media print"
      assert html =~ "page-break-before"
    end
  end

  # LiveViewTest 1.2 returns html as a binary; Floki 0.38's `find/2` and
  # `text/1` require a parsed tree, so parse first.
  defp find(html, selector) do
    html |> to_string() |> Floki.parse_fragment!() |> Floki.find(selector)
  end

  defp text(html) do
    html |> to_string() |> Floki.parse_fragment!() |> Floki.text()
  end

  # Builds a 3-code batch through the domain aggregate — the same fixture the
  # client-side store would serialize.
  defp sample_sheet do
    template = %Template{
      name: "Widgets",
      fields: [
        %Field{name: "SKU", value: "SKU-2041-B"},
        %Field{name: "Price", value: "$12.50"}
      ],
      strategy: %PatternStrategy{prefix: "CODEPRODUCT", start: 1, count: 3},
      symbology: "code128"
    }

    {:ok, batch, codes} = Batch.create(template)
    {batch, codes}
  end

  # Wire shape: string keys, ISO-8601 timestamps, nested maps — as sent by the
  # browser's IndexedDB store (see shared data contract).
  defp wire(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp wire(%{__struct__: _} = struct) do
    struct
    |> Map.from_struct()
    |> Enum.map(fn {key, value} -> {to_string(key), wire(value)} end)
    |> Map.new()
  end

  defp wire(list) when is_list(list), do: Enum.map(list, &wire/1)
  defp wire(value), do: value
end
