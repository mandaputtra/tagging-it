defmodule TaggingItWeb.LandingLiveTest do
  use TaggingItWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "landing renders the sticker hero and CTA into the batch creator" do
    {:ok, _view, html} = live(build_conn(), "/")

    assert text(html) =~ "TaggingIt"
    assert text(html) =~ "Create a barcode/QR, Print, Label, Verify"
    assert text(html) =~ "Create batch"
    assert text(html) =~ "Free · Private · In your browser"
    assert find(html, "a[href='/batches/new']") != []
  end

  test "hero shows the four step tiles Create, Print, Label, Verify" do
    {:ok, _view, html} = live(build_conn(), "/")

    for step <- ["Create", "Print", "Label", "Verify"] do
      assert text(html) =~ step
    end
  end

  test "recent batches render as sticker cards with count chip and date" do
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
    assert text(html) =~ "Code 128 · 30 labels"
    assert text(html) =~ "30 labels"
    assert text(html) =~ "WiFi guest cards"
    assert text(html) =~ "QR Code · 12 labels"
    assert text(html) =~ "Aug 20"
    assert find(html, "a[href='/sheet/b-1']") != []
    assert find(html, "a[href='/sheet/b-2']") != []
  end

  test "renders a void state for recent batches before the client reports" do
    {:ok, _view, html} = live(build_conn(), "/")

    assert find(html, "#recent-batches") != []
    assert text(html) =~ "No batches yet"
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
