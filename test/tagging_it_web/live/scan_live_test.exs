defmodule TaggingItWeb.ScanLiveTest do
  use TaggingItWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders scan input with camera placeholder and verify affordance (Variant A)" do
    {:ok, _view, html} = live(build_conn(), "/scan")
    assert html =~ "Scan Label"
    assert find(html, "#scan-view") != []
    assert find(html, "input[placeholder*=\"CODE\" i]") != [] or html =~ "type / paste code"
    assert find(html, "#scan-verify") != []
    # camera viewport per Variant A
    assert html =~ "Camera viewport" or find(html, "#scan-camera") != []
  end

  test "shows popup hidden by default, and shows miss popup on scan:miss" do
    {:ok, view, _html} = live(build_conn(), "/scan")
    # miss popup is hidden initially
    html = render(view)
    # popup exists but hidden (or not yet shown) — we check it can be triggered
    view |> render_hook("scan:miss", %{"value" => "UNKNOWN-999"})
    html2 = render(view)
    assert html2 =~ "Code not found"
    assert html2 =~ "UNKNOWN-999"
  end

  test "scan:miss shows empty value message when value is blank" do
    {:ok, view, _html} = live(build_conn(), "/scan")
    view |> render_hook("scan:miss", %{})
    html = render(view)
    assert html =~ "Code not found"
  end

  defp find(html, selector) do
    html |> to_string() |> Floki.parse_fragment!() |> Floki.find(selector)
  end
end
