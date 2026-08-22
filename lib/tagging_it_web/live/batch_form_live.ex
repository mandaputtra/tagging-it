defmodule TaggingItWeb.BatchFormLive do
  @moduledoc """
  Batch creation form — the entry point of the free tier.

  Two input modes (#8): a sequence-generation form (pattern prefix + start +
  date, or ULID) as the first-class flow, and a paste-list of code data values.
  The template's fields (names + shared values) and the label size are set
  here; generated codes pre-fill from the template per #7.

  On create, the batch + codes are serialized to the wire shape and pushed to
  the client (`batch:created`), which persists them in IndexedDB and navigates
  to the sheet — the server never stores free-tier data.
  """

  use TaggingItWeb, :live_view

  alias TaggingIt.Batch
  alias TaggingIt.Batch.Template
  alias TaggingIt.CodeData.{PatternStrategy, UlidStrategy}
  alias TaggingIt.Fields.Field
  alias TaggingItWeb.BatchSerializer

  @label_sizes [
    %{id: "avery5160", name: "Avery 5160 — 1\" × 2⅝\" (30/sheet)"},
    %{id: "custom_2x1", name: "Custom 2\" × 1\""},
    %{id: "custom_50x25", name: "Custom 50mm × 25mm"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       form: %{
         name: "",
         mode: "pattern",
         prefix: "CODEPRODUCT",
         start: "1",
         count: "10",
         date: Date.to_iso8601(Date.utc_today()),
         paste: "",
         label_size: "avery5160"
       },
       fields: [%Field{name: "", value: ""}],
       label_sizes: @label_sizes,
       errors: []
     )}
  end

  @impl true
  def handle_event("set_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, form: Map.put(socket.assigns.form, :mode, mode))}
  end

  def handle_event("add_field", _params, socket) do
    {:noreply, assign(socket, fields: socket.assigns.fields ++ [%Field{name: "", value: ""}])}
  end

  def handle_event("remove_field", %{"index" => index}, socket) do
    fields =
      socket.assigns.fields
      |> List.delete_at(String.to_integer(index))

    {:noreply, assign(socket, fields: fields)}
  end

  def handle_event("create_batch", %{"batch" => batch_params} = params, socket) do
    fields_params = Map.get(params, "fields", %{})
    case build_template(batch_params, fields_params) do
      {:ok, template, errors: []} ->
        result =
          case batch_params["mode"] do
            "paste" -> Batch.create_from_values(template, String.split(batch_params["paste"] || "", "\n"))
            _ -> Batch.create(template)
          end

        IO.inspect(result, label: "DEBUG create result")
        case result do
          {:ok, batch, codes} ->
            payload = BatchSerializer.to_wire(batch, codes)

            {:noreply,
             socket
             |> assign(errors: [])
             |> push_event("batch:created", payload)}

          {:error, _reason} ->
            {:noreply, assign(socket, errors: ["Couldn't generate codes."])}
        end

      {:ok, _template, errors: errors} ->
        {:noreply, assign(socket, errors: errors)}
    end
  end

  def handle_event("create_batch", _params, socket) do
    {:noreply, assign(socket, errors: ["Invalid form."])}
  end

  defp build_template(batch_params, fields_params) do
    name = String.trim(batch_params["name"] || "")
    label_size = batch_params["label_size"] || "avery5160"
    mode = batch_params["mode"] || "pattern"

    fields =
      fields_params
      |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
      |> Enum.map(fn {_k, f} -> %Field{name: String.trim(f["name"] || ""), value: f["value"] || ""} end)
      |> Enum.reject(&(&1.name == ""))

    {strategy, errors} = strategy_and_errors(mode, batch_params)

    errors = if name == "", do: ["Name is required." | errors], else: errors

    template = %Template{
      name: name,
      fields: fields,
      strategy: strategy,
      label_size: label_size
    }

    {:ok, template, errors: Enum.reverse(errors)}
  end

  # Returns {strategy_or_nil, error_list}. Paste mode has no strategy; the
  # form's strategy field is only meaningful for generated batches.
  defp strategy_and_errors("ulid", params) do
    count = parse_int(params["count"])

    if count > 0 do
      {%UlidStrategy{count: count}, []}
    else
      {nil, ["Count must be at least 1."]}
    end
  end

  defp strategy_and_errors("paste", params) do
    case String.trim(params["paste"] || "") do
      "" -> {nil, ["Paste at least one code value."]}
      _ -> {nil, []}
    end
  end

  defp strategy_and_errors(_mode, params) do
    prefix = String.trim(params["prefix"] || "")
    start = parse_int(params["start"])
    count = parse_int(params["count"])

    errors =
      []
      |> maybe_push(prefix == "", "Prefix is required.")
      |> maybe_push(count < 1, "Count must be at least 1.")
      |> maybe_push(start < 1, "Start must be at least 1.")

    {%PatternStrategy{prefix: prefix, start: start, count: count, date: parse_date(params["date"])}, errors}
  end

  defp maybe_push(errors, true, msg), do: errors ++ [msg]
  defp maybe_push(errors, false, _msg), do: errors

  defp parse_int(nil), do: 0
  defp parse_int(""), do: 0

  defp parse_int(str) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      :error -> nil
    end
  end
end
