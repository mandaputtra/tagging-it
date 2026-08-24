defmodule TaggingItWeb.ChooseTypeLiveTest do
  use TaggingItWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the title plate and subtitle" do
    {:ok, _view, html} = live(build_conn(), "/batches/new")

    assert text(html) =~ "Choose a code type"
    assert text(html) =~ "Pick a barcode or QR format to get started"
  end

  test "renders exactly 9 cards linking to their symbology routes" do
    {:ok, _view, html} = live(build_conn(), "/batches/new")

    cards = find(html, "a[href^='/batches/new/']")
    assert length(cards) == 9

    assert text(html) =~ "QR Code"
    assert find(html, "a[href='/batches/new/qrcode']") != []
    assert text(html) =~ "EAN-13"
    assert find(html, "a[href='/batches/new/ean13']") != []

    for {name, sym} <- [
          {"Code 128", "code128"},
          {"Code 39", "code39"},
          {"EAN-8", "ean8"},
          {"UPC-A", "upca"},
          {"PDF417", "pdf417"},
          {"DataMatrix", "datamatrix"},
          {"Aztec", "azteccode"}
        ] do
      assert text(html) =~ name, "expected card name #{name}"
      assert find(html, "a[href='/batches/new/#{sym}']") != [], "expected link #{sym}"
    end
  end

  test "cards show category chips (2D, Linear, Retail)" do
    {:ok, _view, html} = live(build_conn(), "/batches/new")

    assert text(html) =~ "2D"
    assert text(html) =~ "Linear"
    assert text(html) =~ "Retail"
    assert find(html, "a[href='/batches/new']") == []
  end

  test "back button links to the landing page" do
    {:ok, _view, html} = live(build_conn(), "/batches/new")

    assert find(html, "a[href='/']") != []
  end

  defp find(html, selector) when is_binary(html) do
    html |> to_string() |> Floki.parse_fragment!() |> Floki.find(selector)
  end

  defp find(node, selector) when is_tuple(node), do: Floki.find(node, selector)

  defp text(html) when is_binary(html) do
    html |> to_string() |> Floki.parse_fragment!() |> Floki.text()
  end

  defp text(node) when is_tuple(node), do: Floki.text(node)
end
