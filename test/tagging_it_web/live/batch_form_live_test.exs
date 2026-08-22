defmodule TaggingItWeb.BatchFormLiveTest do
  use TaggingItWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "mount" do
    test "renders the batch creation form" do
      {:ok, _view, html} = live(build_conn(), "/batches/new")

      assert find(html, "form#batch-form") != []
      assert find(html, "input[name='batch[name]']") != []
      assert find(html, "input[name='batch[prefix]']") != []
      assert find(html, "input[name='batch[start]']") != []
      assert find(html, "input[name='batch[count]']") != []
      assert find(html, "select[name='batch[label_size]']") != []
    end

    test "renders a field template editor with one empty row" do
      {:ok, _view, html} = live(build_conn(), "/batches/new")

      assert find(html, "input[name='fields[0][name]']") != []
      assert find(html, "input[name='fields[0][value]']") != []
    end

    test "offers the preset label sizes plus a custom option" do
      {:ok, _view, html} = live(build_conn(), "/batches/new")

      options = Floki.attribute(find(html, "select[name='batch[label_size]'] option"), "value")
      assert "avery5160" in options
      assert "custom_2x1" in options
      assert "custom_50x25" in options
    end

    test "offers the v1 symbology set with QR selectable" do
      {:ok, _view, html} = live(build_conn(), "/batches/new")

      options = Floki.attribute(find(html, "select[name='batch[symbology]'] option"), "value")
      assert "code128" in options
      assert "qrcode" in options
      assert "code39" in options
      assert "ean13" in options
      assert "ean8" in options
      assert "upca" in options
      assert "pdf417" in options
      assert "datamatrix" in options
      assert "azteccode" in options
    end
  end

  describe "sequence mode" do
    test "creates a batch with generated pattern codes and pushes the payload" do
      {:ok, view, _html} = live(build_conn(), "/batches/new")

      html =
        render_submit(view, "create_batch", %{
          "batch" => %{
            "name" => "Products",
            "mode" => "pattern",
            "prefix" => "CODEPRODUCT",
            "start" => "1",
            "count" => "3",
            "date" => "2026-01-01",
            "label_size" => "avery5160"
          },
          "fields" => %{
            "0" => %{"name" => "SKU", "value" => ""},
            "1" => %{"name" => "Price", "value" => "$10"}
          }
        })

      # the client persists the payload and navigates; server only pushes
      assert_push_event(view, "batch:created", %{
        batch: %{"name" => "Products", "id" => batch_id},
        codes: codes
      })

      assert length(codes) == 3
      assert Enum.map(codes, & &1["code_data"]) == [
               "CODEPRODUCT00000120260101",
               "CODEPRODUCT00000220260101",
               "CODEPRODUCT00000320260101"
             ]
    end

    test "generates QR codes when symbology is qrcode" do
      {:ok, view, _html} = live(build_conn(), "/batches/new")

      render_submit(view, "create_batch", %{
        "batch" => %{
          "name" => "Links",
          "mode" => "pattern",
          "prefix" => "URL",
          "start" => "1",
          "count" => "2",
          "date" => "2026-01-01",
          "label_size" => "avery5160",
          "symbology" => "qrcode"
        },
        "fields" => %{}
      })

      assert_push_event(view, "batch:created", %{
        batch: %{"template" => %{"symbology" => "qrcode"}},
        codes: codes
      })
      assert length(codes) == 2
      assert Enum.all?(codes, &(&1["symbology"] == "qrcode"))
    end

    test "rejects an empty prefix" do
      {:ok, view, _html} = live(build_conn(), "/batches/new")

      html =
        render_submit(view, "create_batch", %{
          "batch" => %{"name" => "Products", "mode" => "pattern", "prefix" => "", "start" => "1", "count" => "3"},
          "fields" => %{}
        })

      assert find(html, ".form-error") != []
      assert text(html) =~ "Prefix is required"
    end

    test "rejects a count of zero" do
      {:ok, view, _html} = live(build_conn(), "/batches/new")

      html =
        render_submit(view, "create_batch", %{
          "batch" => %{"name" => "Products", "mode" => "pattern", "prefix" => "P", "start" => "1", "count" => "0"},
          "fields" => %{}
        })

      assert find(html, ".form-error") != []
      assert text(html) =~ "Count must be at least 1"
    end

    test "creates a batch with ULID codes when mode is ulid" do
      {:ok, view, _html} = live(build_conn(), "/batches/new")

      html =
        render_submit(view, "create_batch", %{
          "batch" => %{"name" => "Ids", "mode" => "ulid", "count" => "2", "label_size" => "avery5160"},
          "fields" => %{}
        })

      assert_push_event(view, "batch:created", %{
        batch: %{"name" => "Ids", "id" => _},
        codes: ulid_codes
      })

      assert length(ulid_codes) == 2
      assert Enum.all?(ulid_codes, &(String.length(&1["code_data"]) == 26))
      refute find(html, ".form-errors") != []
    end
  end

  describe "paste mode" do
    test "creates a batch from pasted code data values" do
      {:ok, view, _html} = live(build_conn(), "/batches/new")

      html =
        render_submit(view, "create_batch", %{
          "batch" => %{
            "name" => "Inventory",
            "mode" => "paste",
            "paste" => "SN-001\nSN-002\nSN-003",
            "label_size" => "custom_2x1"
          },
          "fields" => %{"0" => %{"name" => "SKU", "value" => ""}}
        })

      assert_push_event(view, "batch:created", %{
        batch: %{"name" => "Inventory", "id" => _},
        codes: paste_codes
      })

      assert Enum.map(paste_codes, & &1["code_data"]) == ["SN-001", "SN-002", "SN-003"]
      refute find(html, ".form-errors") != []
    end

    test "rejects empty paste input" do
      {:ok, view, _html} = live(build_conn(), "/batches/new")

      html =
        render_submit(view, "create_batch", %{
          "batch" => %{"name" => "Inventory", "mode" => "paste", "paste" => "", "label_size" => "custom_2x1"},
          "fields" => %{}
        })

      assert find(html, ".form-error") != []
      assert text(html) =~ "Paste at least one code value"
    end
  end

  defp find(html, selector) do
    html |> to_string() |> Floki.parse_fragment!() |> Floki.find(selector)
  end

  defp text(html) do
    html |> to_string() |> Floki.parse_fragment!() |> Floki.text()
  end
end
