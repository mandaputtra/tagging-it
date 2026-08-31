defmodule TaggingItWeb.CodeDetailLiveTest do
  use TaggingItWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TaggingIt.Batch
  alias TaggingIt.Batch.Template
  alias TaggingIt.CodeData.PatternStrategy

  test "renders loading before code payload arrives" do
    {:ok, _view, html} = live(build_conn(), "/codes/c-1")
    assert html =~ "Loading"
  end

  test "renders code detail with barcode placeholder and batch breadcrumb on hit" do
    {:ok, view, _html} = live(build_conn(), "/codes/c-1")
    %{batch: batch, codes: [code | _]} = sample_batch()
    view |> render_hook("code:loaded", wire_code(batch, code))
    html = render(view)

    assert text(html) =~ code.code_data
    assert text(html) =~ code.sequence
    # back arrow to the batch (not scan — this entry is batch detail)
    assert find(html, "a[href='/batches/#{batch.id}']") != []
    # print entry
    assert find(html, "a[href='/sheet/#{batch.id}']") != []
    # barcode placeholder the hook renders into
    assert find(html, ".barcode[data-text='#{code.code_data}']") != []
  end

  test "renders field chips from the code's field map" do
    {:ok, view, _html} = live(build_conn(), "/codes/c-1")
    %{batch: batch, codes: [code | _]} = sample_batch()
    code = %{code | fields: [%{name: "item", value: "widget"}, %{name: "note", value: "fragile"}]}
    view |> render_hook("code:loaded", wire_code(batch, code))
    html = render(view)
    assert text(html) =~ "item: widget"
    assert text(html) =~ "note: fragile"
  end

  test "shows error when payload is invalid" do
    {:ok, view, _html} = live(build_conn(), "/codes/c-1")
    view |> render_hook("code:loaded", %{"batch" => %{"id" => ""}, "code" => %{}})
    html = render(view)
    assert text(html) =~ "Couldn't load"
  end

  test "shows error when payload missing keys" do
    {:ok, view, _html} = live(build_conn(), "/codes/c-1")
    view |> render_hook("code:loaded", %{})
    html = render(view)
    assert text(html) =~ "Couldn't load"
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
      strategy: %PatternStrategy{prefix: "ITEM", start: 1, count: 2, date: ~D[2026-01-01]},
      label_size: "avery5160",
      show_sequence: true
    }

    {:ok, batch, codes} = Batch.create(template)
    batch = %{batch | id: "b-1", name: "Demo Batch"}
    codes = Enum.map(codes, fn c -> %{c | symbology: "qrcode"} end)
    %{batch: batch, codes: codes}
  end

  defp wire_code(batch, code) do
    %{"batch" => wire(batch), "code" => wire(code)}
  end

  defp wire(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp wire(%{__struct__: _} = s), do: s |> Map.from_struct() |> Enum.map(fn {k, v} -> {Atom.to_string(k), wire(v)} end) |> Map.new()
  defp wire(list) when is_list(list), do: Enum.map(list, &wire/1)
  defp wire(v), do: v
end
