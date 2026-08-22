defmodule TaggingItWeb.LandingLiveTest do
  use TaggingItWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "landing renders the hero, CTA, and embedded batch form" do
    {:ok, _view, html} = live(build_conn(), "/")

    assert text(html) =~ "Tagging It"
    assert find(html, "#batch-form") != []
    assert text(html) =~ "Create"
  end

  test "recent batches arrive from the client and render links to their sheets" do
    {:ok, view, _html} = live(build_conn(), "/")

    view
    |> render_hook("recent:loaded", %{
      "batches" => [
        %{"id" => "b-1", "name" => "Products", "updated_at" => "2026-08-22T10:00:00Z", "code_count" => 3},
        %{"id" => "b-2", "name" => "Old labels", "updated_at" => "2026-08-01T10:00:00Z", "code_count" => 1}
      ]
    })

    html = render(view)
    assert text(html) =~ "Products"
    assert text(html) =~ "Old labels"
    assert find(html, "a[href='/sheet/b-1']") != []
    assert find(html, "a[href='/sheet/b-2']") != []
    assert text(html) =~ "3"
    assert find(html, "button[phx-hook='BatchDelete'][data-batch-id='b-1']") != []
    assert find(html, "button[phx-hook='BatchDelete'][data-batch-id='b-2']") != []
  end

  test "renders no recent section before the client reports batches" do
    {:ok, _view, html} = live(build_conn(), "/")

    refute find(html, "#recent-batches-list") != []
  end

  defp find(html, selector) do
    html |> to_string() |> Floki.parse_fragment!() |> Floki.find(selector)
  end

  defp text(html) do
    html |> to_string() |> Floki.parse_fragment!() |> Floki.text()
  end
end
