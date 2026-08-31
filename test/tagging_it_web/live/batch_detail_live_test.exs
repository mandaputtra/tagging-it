defmodule TaggingItWeb.BatchDetailLiveTest do
  use TaggingItWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TaggingIt.Batch
  alias TaggingIt.Batch.Template
  alias TaggingIt.CodeData.PatternStrategy

  describe "mount" do
    test "renders a loading state before the batch is loaded" do
      {:ok, _view, html} = live(build_conn(), "/batches/b-123")

      assert text(html) =~ "Loading"
    end

    test "works without a batch_id param (direct mount)" do
      {:ok, view, _html} = live(build_conn(), "/batches/b-123")
      assert has_element?(view, "#batch-detail-view")
    end
  end

  describe "detail:loaded" do
    test "renders batch meta and its codes when payload is valid" do
      {:ok, view, _html} = live(build_conn(), "/batches/b1")

      %{batch: batch, codes: codes} = sample_batch()
      view |> render_hook("detail:loaded", wire_payload(batch, codes))
      html = render(view)

      assert text(html) =~ batch.name
      assert text(html) =~ "QR Code"
      assert text(html) =~ "1 labels" or text(html) =~ "3 labels"
      assert find(html, "a[href='/sheet/#{batch.id}']") != []
      # scan entry
      assert find(html, "a[href='/scan']") != [] or text(html) =~ "Scan"
      for code <- codes do
        assert text(html) =~ code.code_data
      end
    end

    test "shows an error when the payload is invalid" do
      {:ok, view, _html} = live(build_conn(), "/batches/b1")
      view |> render_hook("detail:loaded", %{"batch" => %{"id" => ""}, "codes" => []})
      html = render(view)
      assert text(html) =~ "Couldn't load"
    end

    test "shows an error when payload is missing keys" do
      {:ok, view, _html} = live(build_conn(), "/batches/b1")
      view |> render_hook("detail:loaded", %{})
      html = render(view)
      assert text(html) =~ "Couldn't load"
    end

    test "renders empty state when batch has no codes" do
      {:ok, view, _html} = live(build_conn(), "/batches/b1")
      %{batch: batch} = sample_batch()
      view |> render_hook("detail:loaded", wire_payload(batch, []))
      html = render(view)
      assert text(html) =~ batch.name
      assert text(html) =~ "No codes" or text(html) =~ "0 labels"
    end
  end

  describe "actions" do
    test "print button links to the sheet for the batch" do
      {:ok, view, _html} = live(build_conn(), "/batches/b1")
      %{batch: batch, codes: codes} = sample_batch()
      view |> render_hook("detail:loaded", wire_payload(batch, codes))
      html = render(view)
      assert find(html, "a[href='/sheet/#{batch.id}']") != []
    end

    test "delete button is present with batch id" do
      {:ok, view, _html} = live(build_conn(), "/batches/b1")
      %{batch: batch, codes: codes} = sample_batch()
      view |> render_hook("detail:loaded", wire_payload(batch, codes))
      html = render(view)
      # SheetDelete/BatchDelete pattern: data-batch-id
      assert find(html, "[data-batch-id='#{batch.id}']") != []
    end
    test "each code row links to its code detail page" do
      {:ok, view, _html} = live(build_conn(), "/batches/b1")
      %{batch: batch, codes: codes} = sample_batch()
      view |> render_hook("detail:loaded", wire_payload(batch, codes))
      html = render(view)
      for code <- codes do
        assert find(html, "a[href='/codes/#{code.id}']") != []
      end
    end
  end

  defp find(html, selector) do
    html |> to_string() |> Floki.parse_fragment!() |> Floki.find(selector)
  end

  defp text(html) do
    html |> to_string() |> Floki.parse_fragment!() |> Floki.text()
  end

  defp sample_batch do
    template = %Template{
      name: "Demo Batch",
      symbology: "qrcode",
      fields: [],
      strategy: %PatternStrategy{prefix: "ITEM", start: 1, count: 3, date: ~D[2026-01-01]},
      label_size: "avery5160",
      show_sequence: true
    }

    {:ok, batch, codes} = Batch.create(template)
    # Override id for stable test link
    batch = %{batch | id: "b-1", name: "Demo Batch"}
    codes = Enum.map(codes, fn c -> %{c | symbology: "qrcode"} end)
    %{batch: batch, codes: codes}
  end

  defp wire_payload(batch, codes) do
    %{"batch" => wire(batch), "codes" => wire(codes)}
  end

  defp wire(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp wire(%{__struct__: _} = struct) do
    struct
    |> Map.from_struct()
    |> Enum.map(fn {k, v} -> {Atom.to_string(k), wire(v)} end)
    |> Map.new()
  end
  defp wire(list) when is_list(list), do: Enum.map(list, &wire/1)
  defp wire(v), do: v
end
