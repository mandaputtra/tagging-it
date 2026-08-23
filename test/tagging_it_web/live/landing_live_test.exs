defmodule TaggingItWeb.LandingLiveTest do
  use TaggingItWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "landing renders the hero and a symbology gallery of all 9 formats" do
    {:ok, _view, html} = live(build_conn(), "/")

    assert text(html) =~ "Tagging It"
    assert text(html) =~ "Make a label for anything"
    assert length(find(html, ".gallery-card")) == 9

    # each card links to the batch creator with its symbology preselected
    for {sym, href} <- [
          {"QR Code", "/batches/new?symbology=qrcode"},
          {"Code 128", "/batches/new?symbology=code128"},
          {"Code 39", "/batches/new?symbology=code39"},
          {"EAN-13", "/batches/new?symbology=ean13"},
          {"EAN-8", "/batches/new?symbology=ean8"},
          {"UPC-A", "/batches/new?symbology=upca"},
          {"PDF417", "/batches/new?symbology=pdf417"},
          {"DataMatrix", "/batches/new?symbology=datamatrix"},
          {"Aztec", "/batches/new?symbology=azteccode"}
        ] do
      card = find(html, ".gallery-card") |> Enum.find(&(text(&1) =~ sym))
      assert card != nil, "missing gallery card for #{sym}"
      assert find(card, "a[href='#{href}']") != []
    end
  end

  test "gallery cards carry barcode placeholders for live bwip-js rendering" do
    {:ok, _view, html} = live(build_conn(), "/")

    assert length(find(html, ".gallery-card .barcode[data-bcid]")) == 9
    assert find(html, "div[phx-hook='SymbologyGallery']") != []
  end

  test "recent batches arrive from the client and render rows in the gallery section" do
    {:ok, view, _html} = live(build_conn(), "/")

    view
    |> render_hook("recent:loaded", %{
      "batches" => [
        %{
          "id" => "b-1",
          "name" => "Warehouse shelf labels",
          "symbology" => "code128",
          "created_at" => "2026-08-20T10:00:00Z",
          "code_count" => 30
        },
        %{
          "id" => "b-2",
          "name" => "WiFi guest cards",
          "symbology" => "qrcode",
          "created_at" => "2026-08-18T10:00:00Z",
          "code_count" => 12
        }
      ]
    })

    html = render(view)
    assert find(html, "#recent-batches") != []
    assert text(html) =~ "Warehouse shelf labels"
    assert text(html) =~ "(30)"
    assert text(html) =~ "Code 128"
    assert text(html) =~ "WiFi guest cards"
    assert text(html) =~ "(12)"
    assert text(html) =~ "QR Code"
    assert find(html, "a[href='/sheet/b-1']") != []
    assert find(html, "a[href='/sheet/b-2']") != []
  end

  test "renders a void state for recent batches before the client reports" do
    {:ok, _view, html} = live(build_conn(), "/")

    assert find(html, "#recent-batches") != []
    assert text(html) =~ "No batches yet"
    refute find(html, ".recent-row") != []
  end

  test "bulk mode is a link, not an embedded form" do
    {:ok, _view, html} = live(build_conn(), "/")

    refute find(html, "#batch-form") != []
    assert find(html, "a[href='/batches/new']") != []
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
