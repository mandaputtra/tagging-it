defmodule TaggingItWeb.LandingLive do
  use TaggingItWeb, :live_view

  import Phoenix.Component

  # Symbology id → display name (for recent-batch rows and card bubbles).
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

  # Recent-batch bubble: {lucide icon, tile bg, icon color}. Icon color is ink
  # on yellow tiles (white on yellow is unreadable), white elsewhere.
  @bubble %{
    "qrcode" => {:qr, "bg-sticker-grape", "text-white"},
    "code128" => {:barcode, "bg-sticker-coral", "text-white"},
    "code39" => {:barcode, "bg-sticker-sky", "text-white"},
    "ean13" => {:barcode, "bg-sticker-pink", "text-white"},
    "ean8" => {:barcode, "bg-sticker-teal", "text-white"},
    "upca" => {:barcode, "bg-sticker-yellow", "text-sticker-ink"},
    "pdf417" => {:ticket, "bg-sticker-teal", "text-white"},
    "datamatrix" => {:qr, "bg-sticker-sky", "text-white"},
    "azteccode" => {:qr, "bg-sticker-grape", "text-white"}
  }
  @default_bubble {:qr, "bg-sticker-grape", "text-white"}

  # Hero step tiles: {lucide icon, tile bg, label}.
  @steps [
    %{icon: :plus, bg: "bg-sticker-yellow", label: "Create"},
    %{icon: :printer, bg: "bg-sticker-sky", label: "Print"},
    %{icon: :tag, bg: "bg-sticker-pink", label: "Label"},
    %{icon: :check, bg: "bg-sticker-teal", label: "Verify"}
  ]

  # Lucide icon path data (24px stroke set), keyed by the atoms above.
  @icon_paths %{
    plus: ["M5 12h14", "M12 5v14"],
    printer: [
      "M6 9V2h12v7",
      "M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2",
      "M6 14h12v8a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1z"
    ],
    tag: [
      "M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z",
      "M7.5 7.5h.01"
    ],
    check: [
      "M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z",
      "m9 12 2 2 4-4"
    ],
    qr: [
      "M3 3h5v5H3z",
      "M16 3h5v5h-5z",
      "M3 16h5v5H3z",
      "M21 16h-3a2 2 0 0 0-2 2v3",
      "M21 21h.01",
      "M12 7h3a2 2 0 0 1 2 2v3",
      "M3 12h.01",
      "M12 3h.01",
      "M12 16h.01",
      "M16 12h.01",
      "M21 12h.01",
      "M12 21v-1"
    ],
    barcode: ["M3 5v14", "M8 5v14", "M12 5v14", "M17 5v14", "M21 5v14"],
    ticket: [
      "M2 9a3 3 0 0 1 0 6v2a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-2a3 3 0 0 1 0-6V7a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2Z",
      "M13 5v2",
      "M13 17v2",
      "M13 11v2"
    ],
    sparkle: [
      "M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z"
    ],
    sparkles: [
      "M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z",
      "M20 3v4",
      "M22 5h-4",
      "M4 17v2",
      "M5 18H3"
    ]
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, recent_batches: [], steps: @steps, icon_paths: @icon_paths)}
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

  # "2026-08-20T10:00:00Z" → "Aug 20". Unparseable stays as-is.
  defp format_date(nil), do: nil

  defp format_date(iso) do
    case iso |> String.slice(0, 10) |> Date.from_iso8601() do
      {:ok, date} ->
        month = ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec) |> Enum.at(date.month - 1)
        "#{month} #{date.day}"

      {:error, _} ->
        iso
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="landing-view"
      phx-hook="RecentBatches"
      class="min-h-screen bg-sticker-cream font-body text-sticker-ink"
    >
      <div class="relative mx-auto flex min-h-screen w-full max-w-[420px] flex-col gap-8 px-6 py-12">
        <svg class="absolute right-3 top-8 h-5 w-5 rotate-[-18deg] text-sticker-coral" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path :for={p <- @icon_paths.sparkle} d={p} />
        </svg>
        <svg class="absolute left-3 top-4 h-[18px] w-[18px] rotate-[14deg] text-sticker-sky" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path :for={p <- @icon_paths.sparkle} d={p} />
        </svg>

        <!-- Hero -->
        <header class="flex flex-col items-center gap-3">
          <div class="flex h-[86px] w-[86px] items-center justify-center rounded-[26px] bg-sticker-yellow shadow-sticker-soft outline-3 outline-solid outline-sticker-ink outline-offset-[-1.5px]">
            <svg class="h-[42px] w-[42px] text-sticker-ink" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <path :for={p <- @icon_paths.qr} d={p} />
            </svg>
          </div>

          <div class="rotate-2 rounded-[18px] bg-sticker-yellow px-5 pb-2.5 pt-2 shadow-sticker outline-3 outline-solid outline-sticker-ink outline-offset-[-1.5px]">
            <h1 class="font-display text-[44px] font-extrabold leading-none text-sticker-ink">TaggingIt</h1>
          </div>

          <p class="text-center text-[15px] font-medium text-sticker-muted">
            Create a barcode/QR, Print, Label, Verify
          </p>

          <div class="mt-1 flex w-full items-start gap-2.5">
            <div :for={step <- @steps} class="flex flex-1 flex-col items-center gap-1.5 p-2">
              <div class={"flex h-[54px] w-[54px] items-center justify-center rounded-[17px] #{step.bg} outline-[2.5px] outline-solid outline-sticker-ink outline-offset-[-1.25px]"}>
                {icon(step.icon, "h-6 w-6 text-sticker-ink")}
              </div>
              <span class="text-[11.5px] font-semibold text-sticker-ink">{step.label}</span>
            </div>
          </div>

          <a
            href="/batches/new"
            class="mt-2 flex items-center gap-2 rounded-[40px] bg-sticker-coral px-7 py-3.5 shadow-sticker outline-3 outline-solid outline-sticker-ink outline-offset-[-1.5px] transition-transform hover:-translate-y-0.5"
          >
            {icon(:plus, "h-[18px] w-[18px] text-sticker-ink")}
            <span class="font-display text-lg font-semibold text-sticker-ink">Create batch</span>
          </a>

          <p class="text-[11.5px] font-medium text-sticker-muted">
            Free · Private · In your browser
          </p>
        </header>

        <!-- Recent batches -->
        <section id="recent-batches" class="relative flex flex-col gap-3.5">
          <svg class="absolute -left-3 -top-8 h-6 w-6 rotate-[8deg] text-sticker-yellow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path :for={p <- @icon_paths.sparkles} d={p} />
          </svg>

          <div class="flex flex-col gap-1.5">
            <div class="flex items-end justify-between">
              <h2 class="font-display text-2xl font-bold text-sticker-ink">Recent Batches</h2>
              <span class="text-[13px] font-semibold tracking-[0.2px] text-sticker-muted">
                View all →
              </span>
            </div>
            <div class="h-[9px] w-[66px] rounded-[5px] bg-sticker-yellow outline-2 outline-solid outline-sticker-ink outline-offset-[-1px]"></div>
          </div>

          <%= if @recent_batches == [] do %>
            <p
              id="recent-batches-empty"
              class="rounded-[20px] bg-white p-5 text-center text-sm font-medium text-sticker-muted shadow-sticker-card outline-3 outline-solid outline-sticker-ink outline-offset-[-1.5px]"
            >
              No batches yet — create your first label above.
            </p>
          <% else %>
            <ul class="flex flex-col gap-3">
              <li :for={batch <- @recent_batches} class="recent-row">
                <a
                  href={"/sheet/" <> batch["id"]}
                  class="flex items-center gap-3 rounded-[20px] bg-white p-3.5 shadow-sticker-card outline-3 outline-solid outline-sticker-ink outline-offset-[-1.5px] transition-transform hover:-translate-y-0.5"
                >
                  {icon_bubble(batch["symbology"])}
                  <span class="flex min-w-0 flex-1 flex-col gap-[3px]">
                    <span class="truncate text-[16px] font-semibold text-sticker-ink">
                      {batch["name"]}
                    </span>
                    <span class="text-[12.5px] font-medium text-sticker-muted">
                      {batch["symbology"]} · {batch["count"]} labels
                    </span>
                  </span>
                  <span class="flex shrink-0 flex-col items-end gap-1.5">
                    <span class="rounded-[11px] bg-sticker-yellow px-2.5 py-1 text-[11.5px] font-bold text-sticker-ink outline-2 outline-solid outline-sticker-ink outline-offset-[-1px]">
                      {batch["count"]} labels
                    </span>
                    <span class="text-[11.5px] font-semibold text-sticker-muted">
                      {batch["date"]}
                    </span>
                  </span>
                </a>
              </li>
            </ul>
          <% end %>
        </section>
      </div>
    </div>
    """
  end

  defp icon(name, class) do
    assigns = %{name: name, class: class, paths: @icon_paths[name]}
    ~H"""
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class={@class} aria-hidden="true">
      <path :for={p <- @paths} d={p} />
    </svg>
    """
  end

  defp icon_bubble(symbology) do
    {name, bg, fg} = Map.get(@bubble, symbology, @default_bubble)
    assigns = %{name: name, bg: bg, fg: fg, paths: @icon_paths}
    ~H"""
    <span class={"flex h-[52px] w-[52px] shrink-0 items-center justify-center rounded-[16px] #{@bg} #{@fg} outline-[2.5px] outline-solid outline-sticker-ink outline-offset-[-1.25px]"}>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="h-6 w-6" aria-hidden="true">
        <path :for={p <- @paths[@name]} d={p} />
      </svg>
    </span>
    """
  end
end
