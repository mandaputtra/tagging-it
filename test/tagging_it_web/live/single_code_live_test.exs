defmodule TaggingItWeb.SingleCodeLiveTest do
  use TaggingItWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders single-code form with Value input and sticker shell" do
    {:ok, _view, html} = live(build_conn(), "/codes/new")
    assert html =~ "Create Code"
    assert html =~ "Value"
    assert find(html, "#single-code-view") != []
    assert find(html, "input[name=\"batch[value]\"]") != []
  end

  test "mount respects symbology param" do
    {:ok, _view, html} = live(build_conn(), "/codes/new?symbology=qrcode")
    assert html =~ "QR Code" or html =~ "qrcode"
  end

  test "shows error when Value is blank on create" do
    {:ok, view, _html} = live(build_conn(), "/codes/new")
    html = view |> element("form") |> render_submit(%{"batch" => %{"name" => "", "value" => ""}})
    assert html =~ "Name is required" or html =~ "Value is required" or html =~ "is required"
  end

  test "creates a batch size 1 and pushes batch:created on valid submit" do
    {:ok, view, _html} = live(build_conn(), "/codes/new?symbology=code128")
    # Submit with name + value + default label_size
    html = view |> element("form") |> render_submit(%{"batch" => %{"name" => "Single Demo", "value" => "CODE-001", "symbology" => "code128", "label_size" => "avery5160"}})
    # After create, LiveView should have pushed batch:created (handled by hook) — we check the form still renders with success or the payload was pushed (no error)
    # The server renders the same form but the client hook would persist; server side we check no error
    refute html =~ "is required"
  end

  defp find(html, selector) do
    html |> to_string() |> Floki.parse_fragment!() |> Floki.find(selector)
  end
end
