defmodule TaggingItWeb.HomePrototypeController do
  use TaggingItWeb, :controller

  # PROTOTYPE — symbology-first home variants, switchable via ?variant=A|B|C (#15).
  # Throwaway: no tests, no persistence, no polish. Delete after verdict.
  # Three variants of the symbology-first home (user onboarding sketch steps 1-3).

  @symbologies [
    %{name: "QR Code", bcid: "qrcode", sample: "https://tagging.it/r/DEMO-001", blurb: "Any text or URL — scans with any phone camera", tint: "#fbe4d5"},
    %{name: "Code 128", bcid: "code128", sample: "SHP-2026-0815", blurb: "Dense alphanumeric — shipping & inventory", tint: "#e8e3fa"},
    %{name: "Code 39", bcid: "code39", sample: "PART-42A", blurb: "Legacy industrial — uppercase letters & digits", tint: "#dcf2e5"},
    %{name: "EAN-13", bcid: "ean13", sample: "5901234123457", blurb: "Worldwide retail products (13 digits)", tint: "#ddeefa"},
    %{name: "EAN-8", bcid: "ean8", sample: "96385074", blurb: "Small retail packs (8 digits)", tint: "#f7e0e9"},
    %{name: "UPC-A", bcid: "upca", sample: "036000291452", blurb: "US & Canada retail products (12 digits)", tint: "#fbf3d5"},
    %{name: "PDF417", bcid: "pdf417", sample: "ID-2026-DEMO", blurb: "IDs & tickets — lots of data in a 2D code", tint: "#fbe4d5"},
    %{name: "DataMatrix", bcid: "datamatrix", sample: "SN-0042-XK", blurb: "Tiny marks for small parts & electronics", tint: "#e8e3fa"},
    %{name: "Aztec", bcid: "azteccode", sample: "GATE-A17-2026", blurb: "Transit tickets & boarding passes", tint: "#dcf2e5"}
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
      symbologies: @symbologies,
      variant_a: render_variant("variant_a.html"),
      variant_b: render_variant("variant_b.html"),
      variant_c: render_variant("variant_c.html")
    )
  end

  defp render_variant(template) do
    assigns = %{symbologies: @symbologies}

    rendered =
      case template do
        "variant_a.html" -> TaggingItWeb.HomePrototypeHTML.variant_a(assigns)
        "variant_b.html" -> TaggingItWeb.HomePrototypeHTML.variant_b(assigns)
        "variant_c.html" -> TaggingItWeb.HomePrototypeHTML.variant_c(assigns)
      end

    Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()
  end
end
