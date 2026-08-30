defmodule TaggingItWeb.SingleCodeLive do
  @moduledoc """
  Create Code (Single) — the own-route single-code flow (gPPs2) per #18.

  Single = batch size 1 per #14. Reuses `Batch`/`Template` but locks count to 1:
  a single Value input (code_data, defaults to Sequence) + shared Fields + Label size.
  On create, builds a Template (strategy nil → paste) and `Batch.create_from_values/2`
  with one value, then pushes `batch:created` for the client hook to persist and
  navigate to the new Detail (`/batches/:id`). Browser-only per #20 pattern.
  """

  use TaggingItWeb, :live_view

  alias TaggingIt.Batch
  alias TaggingIt.Batch.Template
  alias TaggingIt.Fields.Field
  alias TaggingItWeb.BatchSerializer

  @label_sizes [
    %{id: "avery5160", name: "Avery 5160 — 1\" × 2⅝\" (30/sheet)"},
    %{id: "custom_2x1", name: "Custom 2\" × 1\""},
    %{id: "custom_50x25", name: "Custom 50mm × 25mm"}
  ]

  @symbologies [
    %{id: "qrcode", name: "QR code"},
    %{id: "code128", name: "Code 128"},
    %{id: "code39", name: "Code 39"},
    %{id: "ean13", name: "EAN-13"},
    %{id: "ean8", name: "EAN-8"},
    %{id: "upca", name: "UPC-A"},
    %{id: "pdf417", name: "PDF417"},
    %{id: "datamatrix", name: "DataMatrix"},
    %{id: "azteccode", name: "Aztec"}
  ]

  @names %{
    "qrcode" => "QR Code",
    "code128" => "Code 128",
    "code39" => "Code 39",
    "ean13" => "EAN-13",
    "ean8" => "EAN-8",
    "upca" => "UPC-A",
    "pdf417" => "PDF417",
    "datamatrix" => "DataMatrix",
    "azteccode" => "Aztec"
  }

  @icon_paths %{
    arrow_left: ["M19 12H5", "m12 19-7-7 7-7"],
    plus: ["M5 12h14", "M12 5v14"],
    qr: ["M3 3h5v5H3z", "M16 3h5v5h-5z", "M3 16h5v5H3z", "M21 16h-3a2 2 0 0 0-2 2v3", "M21 21h.01", "M12 7h3a2 2 0 0 1 2 2v3", "M3 12h.01", "M12 3h.01", "M12 16h.01", "M16 12h.01", "M21 12h.01", "M12 21v-1"],
    barcode: ["M3 5v14", "M8 5v14", "M12 5v14", "M17 5v14", "M21 5v14"]
  }

  @impl true
  def mount(params, _session, socket) do
    symbology = Map.get(params, "symbology", "code128")

    {:ok,
     assign(socket,
       form: %{
         name: "",
         value: "",
         symbology: symbology,
         label_size: "avery5160",
         show_sequence: true
       },
       fields: [%Field{name: "", value: ""}],
       label_sizes: @label_sizes,
       symbologies: @symbologies,
       symbology_name: Map.get(@names, symbology, symbology),
       icon_paths: @icon_paths,
       errors: []
     )}
  end

  @impl true
  def handle_event("create_single", %{"batch" => batch_params} = params, socket) do
    fields_params = Map.get(params, "fields", %{})

    case build_template(batch_params, fields_params) do
      {:ok, template, value, errors: []} ->
        {:ok, batch, codes} = Batch.create_from_values(template, [value])
        wire = BatchSerializer.to_wire(batch, codes)
        {:noreply, push_event(socket, "batch:created", wire)}

      {:ok, _template, _value, errors: errors} ->
        {:noreply, assign(socket, errors: errors)}
    end
  end

  def handle_event("create_single", _params, socket) do
    {:noreply, assign(socket, errors: ["Invalid form."])}
  end

  defp build_template(batch_params, fields_params) do
    name = String.trim(batch_params["name"] || "")
    value = String.trim(batch_params["value"] || "")
    label_size = batch_params["label_size"] || "avery5160"
    symbology = batch_params["symbology"] || "code128"

    fields =
      fields_params
      |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
      |> Enum.map(fn {_k, f} -> %Field{name: String.trim(f["name"] || ""), value: f["value"] || ""} end)
      |> Enum.reject(&(&1.name == ""))

    errors = []
    errors = if name == "", do: ["Name is required." | errors], else: errors
    errors = if value == "", do: ["Value is required." | errors], else: errors

    template = %Template{
      name: name,
      fields: fields,
      strategy: nil,
      symbology: symbology,
      label_size: label_size,
      show_sequence: batch_params["show_sequence"] == "true"
    }

    {:ok, template, value, errors: Enum.reverse(errors)}
  end

  defp icon(name, class) do
    assigns = %{name: name, class: class, paths: @icon_paths[name]}
    ~H"""
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class={@class} aria-hidden="true">
      <path :for={p <- @paths} d={p} />
    </svg>
    """
  end
end
