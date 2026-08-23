defmodule TaggingItWeb.LandingLive do
  use TaggingItWeb, :live_view

  import Phoenix.Component

  # The 9 v1 symbologies — id + display name + live example + one-line "use
  # when". The gallery cards render a bwip-js example client-side
  # (SymbologyGallery hook) and link into the batch creator with the symbology
  # preselected. Same ids as the BatchFormLive select.
  @symbologies [
    %{id: "qrcode", name: "QR Code", sample: "https://tagging.it/r/DEMO-001", blurb: "Any text or URL — scans with any phone camera", tint: "peach"},
    %{id: "code128", name: "Code 128", sample: "SHP-2026-0815", blurb: "Dense alphanumeric — shipping & inventory", tint: "lavender"},
    %{id: "code39", name: "Code 39", sample: "PART-42A", blurb: "Legacy industrial — uppercase & digits", tint: "mint"},
    %{id: "ean13", name: "EAN-13", sample: "5901234123457", blurb: "Worldwide retail products (13 digits)", tint: "sky"},
    %{id: "ean8", name: "EAN-8", sample: "96385074", blurb: "Small retail packs (8 digits)", tint: "rose"},
    %{id: "upca", name: "UPC-A", sample: "036000291452", blurb: "US & Canada retail (12 digits)", tint: "yellow"},
    %{id: "pdf417", name: "PDF417", sample: "ID-2026-DEMO", blurb: "IDs & tickets — lots of data in 2D", tint: "peach"},
    %{id: "datamatrix", name: "DataMatrix", sample: "SN-0042-XK", blurb: "Tiny marks for small parts", tint: "lavender"},
    %{id: "azteccode", name: "Aztec", sample: "GATE-A17-2026", blurb: "Transit tickets & boarding passes", tint: "mint"}
  ]

  # Symbology id → display name (for recent-batch rows).
  @names Map.new(@symbologies, &{&1.id, &1.name})

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, symbologies: @symbologies, recent_batches: [])}
  end

  @impl true
  def handle_event("recent:loaded", %{"batches" => batches}, socket) do
    rows =
      Enum.map(batches, fn batch ->
        %{
          "id" => batch["id"],
          "name" => batch["name"],
          "symbology" => Map.get(@names, batch["symbology"], batch["symbology"]),
          "count" => batch["code_count"],
          "date" => format_date(batch["created_at"])
        }
      end)

    {:noreply, assign(socket, recent_batches: rows)}
  end

  def handle_event("recent:loaded", _payload, socket) do
    {:noreply, assign(socket, recent_batches: [])}
  end

  # "2026-08-20T10:00:00Z" → "Aug 20, 2026". Unparseable stays as-is.
  defp format_date(nil), do: nil

  defp format_date(iso) do
    case iso |> String.slice(0, 10) |> Date.from_iso8601() do
      {:ok, date} ->
        month = ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec) |> Enum.at(date.month - 1)
        "#{month} #{date.day}, #{date.year}"

      {:error, _} ->
        iso
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="landing-view" phx-hook="RecentBatches">
      <!-- Hero: navy band, purple CTA. -->
      <header class="bg-navy text-on-dark">
        <div class="mx-auto max-w-5xl px-4 py-14 sm:py-20">
          <nav class="mb-12 flex items-center justify-between">
            <span class="text-lg font-semibold tracking-tight">Tagging It</span>
            <a href="/batches/new" class="text-sm text-on-dark-muted hover:text-on-dark">
              Bulk batch →
            </a>
          </nav>

          <div class="mx-auto max-w-2xl text-center">
            <h1 class="text-4xl font-semibold leading-tight tracking-tight sm:text-5xl">
              Make a label for anything.
            </h1>
            <p class="mt-4 text-lg text-on-dark-muted">
              Pick a barcode or QR format to get started. Not sure? Browse the examples.
            </p>
          </div>
        </div>
      </header>

      <!-- Symbology gallery: pick a format → batch creator with it preselected. -->
      <main class="mx-auto max-w-5xl px-4 py-10">
        <div id="symbology-gallery" phx-hook="SymbologyGallery" class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <a
            :for={sym <- @symbologies}
            href={"/batches/new?symbology=" <> sym.id}
            class={"gallery-card rounded-xl border border-hairline bg-tint-#{sym.tint} p-5 transition-shadow hover:shadow-card"}
          >
            <h3 class="text-base font-semibold text-ink">{sym.name}</h3>
            <div
              class="barcode mt-3 flex h-16 items-center justify-center rounded-md bg-canvas p-1"
              data-bcid={sym.id}
              data-text={sym.sample}
              role="img"
              aria-label={"Example " <> sym.name <> " barcode"}
            >
            </div>
            <p class="mt-3 text-sm text-steel">{sym.blurb}</p>
          </a>
        </div>
      </main>

      <!-- Recent batches: content section below the gallery, same max-width. -->
      <section id="recent-batches" class="mx-auto max-w-5xl px-4 pb-14">
        <h2 class="text-2xl font-semibold tracking-tight text-ink">Recent batches</h2>
        <p class="mt-1 text-sm text-steel">Stored in this browser — nothing is uploaded.</p>

        <%= if @recent_batches == [] do %>
          <p class="mt-6 rounded-xl border border-hairline bg-canvas p-5 text-sm text-muted" id="recent-batches-empty">
            No batches yet. Pick a format above to make your first label.
          </p>
        <% else %>
          <ul class="mt-4 overflow-hidden rounded-xl border border-hairline bg-canvas">
            <li :for={batch <- @recent_batches} class="recent-row border-b border-hairline last:border-0">
              <a href={"/sheet/" <> batch["id"]} class="flex items-baseline gap-2 px-5 py-3.5 text-sm hover:bg-surface-soft">
                <span class="truncate font-medium text-ink">{batch["name"]}</span>
                <span class="text-steel">({batch["count"]})</span>
                <span class="mx-1 text-hairline-strong">—</span>
                <span class="shrink-0 text-steel">{batch["symbology"]}</span>
                <%= if batch["date"] do %>
                  <span class="ml-auto shrink-0 text-muted">{batch["date"]}</span>
                <% end %>
              </a>
            </li>
          </ul>
        <% end %>
      </section>

      <footer class="border-t border-hairline py-8">
        <div class="mx-auto max-w-5xl px-4 text-sm text-steel">
          Tagging It — free, private, in-browser label generation.
        </div>
      </footer>
    </div>
    """
  end
end
