defmodule TaggingItWeb.PrintPrototypeController do
  use TaggingItWeb, :controller

  # PROTOTYPE — three label-print flow variants, switchable via ?variant=A|B|C (#9).
  # Throwaway: no tests, no persistence, no polish. Delete after verdict.

  @sample_code %{
    "CODEPRODUCT" => "CODEPRODUCT00000120260101",
    "SKU" => "SKU-2041-B",
    "Price" => "$12.50",
    "Batch" => "B-2208"
  }

  @label_sizes [
    %{id: "avery5160", name: "Avery 5160 — 1\" × 2⅝\" (30/sheet)", w: "2.625in", h: "1in"},
    %{id: "custom_2x1", name: "Custom 2\" × 1\"", w: "2in", h: "1in"},
    %{id: "custom_50x25", name: "Custom 50mm × 25mm", w: "50mm", h: "25mm"}
  ]

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
      sample_code: @sample_code,
      label_sizes: @label_sizes
    )
  end

  defp render_variant(template) do
    assigns = %{sample: @sample_code, sizes: @label_sizes}

    rendered =
      case template do
        "variant_a.html" -> TaggingItWeb.PrintPrototypeHTML.variant_a(assigns)
        "variant_b.html" -> TaggingItWeb.PrintPrototypeHTML.variant_b(assigns)
        "variant_c.html" -> TaggingItWeb.PrintPrototypeHTML.variant_c(assigns)
      end

    Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()
  end
end
