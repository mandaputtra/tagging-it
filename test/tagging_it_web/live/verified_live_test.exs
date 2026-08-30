defmodule TaggingItWeb.VerifiedLiveTest do
  use TaggingItWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TaggingIt.Batch
  alias TaggingIt.Batch.Template
  alias TaggingIt.CodeData.PatternStrategy

  test "renders loading before verified payload arrives" do
    {:ok, _view, html} = live(build_conn(), "/verified/c-1")
    assert html =~ "Loading"
  end

  test "renders verified code with barcode placeholder and batch breadcrumb on hit" do
    {:ok, view, _html} = live(build_conn(), "/verified/c-1")
    %{batch: batch, codes: [code | _]} = sample_batch()
    view |> render_hook("verified:loaded", wire_verified(batch, code))
    html = render(view)
    assert html =~ "Verified"
    assert html =~ code.code_data
    assert html =~ code.sequence
    assert find(html, "a[href='/batches/#{batch.id}']") != []
    assert find(html, "a[href='/sheet/#{batch.id}']") != []
    assert find(html, ".barcode[data-text='#{code.code_data}']") != []
  end

  test "shows error when payload is invalid" do
    {:ok, view, _html} = live(build_conn(), "/verified/c-1")
    view |> render_hook("verified:loaded", %{"batch" => %{"id" => ""}, "code" => %{}})
    html = render(view)
    assert text(html) =~ "Couldn't load"
  end

  test "shows error when payload missing keys" do
    {:ok, view, _html} = live(build_conn(), "/verified/c-1")
    view |> render_hook("verified:loaded", %{})
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
      symbology: "code128",
      fields: [],
      strategy: %PatternStrategy{prefix: "ITEM", start: 1, count: 2, date: ~D[2026-01-01]},
      label_size: "avery5160",
      show_sequence: true
    }

    {:ok, batch, codes} = Batch.create(template)
    batch = %{batch | id: "b-1", name: "Demo Batch"}
    codes = Enum.map(codes, fn c -> %{c | symbology: "code128"} end)
    %{batch: batch, codes: codes}
  end

  defp wire_verified(batch, code) do
    %{"batch" => wire(batch), "code" => wire(code)}
  end

  defp wire(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp wire(%{__struct__: _} = s), do: s |> Map.from_struct() |> Enum.map(fn {k, v} -> {Atom.to_string(k), wire(v)} end) |> Map.new()
  defp wire(list) when is_list(list), do: Enum.map(list, &wire/1)
  defp wire(v), do: v
end
