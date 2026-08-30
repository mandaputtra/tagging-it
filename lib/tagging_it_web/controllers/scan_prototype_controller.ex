defmodule TaggingItWeb.ScanPrototypeController do
  use TaggingItWeb, :controller

  # PROTOTYPE — scan + verified flow variants, switchable via ?variant=A|B|C (#21).
  # Throwaway: no tests, no persistence. Delete after verdict.

  @sample_codes [
    %{id: "c-1", code_data: "CODEPRODUCT00000120260101", sequence: "CODEPRODUCT00000120260101", symbology: "code128", fields: [%{"name" => "Item", "value" => "Widget"}]},
    %{id: "c-2", code_data: "ITEM-PASTE-42", sequence: "2", symbology: "qrcode", fields: []}
  ]

  @sample_batch %{
    "id" => "b-demo",
    "name" => "Demo Batch",
    "template" => %{"symbology" => "code128", "show_sequence" => true},
    "code_ids" => ["c-1", "c-2"]
  }

  def show(conn, %{"variant" => variant}) when variant in ["A", "B", "C"] do
    render_prototype(conn, variant)
  end

  def show(conn, _params) do
    render_prototype(conn, "A")
  end

  defp render_prototype(conn, variant) do
    render(conn, :show,
      variant: variant,
      variant_a: render_variant("variant_a.html"),
      variant_b: render_variant("variant_b.html"),
      variant_c: render_variant("variant_c.html"),
      sample_batch: @sample_batch,
      sample_codes: @sample_codes
    )
  end

  defp render_variant(template) do
    assigns = %{batch: @sample_batch, codes: @sample_codes}

    rendered =
      case template do
        "variant_a.html" -> TaggingItWeb.ScanPrototypeHTML.variant_a(assigns)
        "variant_b.html" -> TaggingItWeb.ScanPrototypeHTML.variant_b(assigns)
        "variant_c.html" -> TaggingItWeb.ScanPrototypeHTML.variant_c(assigns)
      end

    Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()
  end
end
