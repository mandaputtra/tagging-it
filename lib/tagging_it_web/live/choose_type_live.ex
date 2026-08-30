defmodule TaggingItWeb.ChooseTypeLive do
  use TaggingItWeb, :live_view

  import Phoenix.Component

  # Symbology cards: {sym id, name, desc, bubble bg, icon color, icon, chip bg, chip label}.
  # Icon color is ink on light bubbles (white on yellow/sky/pink is unreadable), white on dark.
  @cards [
    %{sym: "qrcode", name: "QR Code", desc: "Any text or URL — scans with any phone camera", bubble: "bg-sticker-yellow", fg: "text-sticker-ink", icon: :qr, chip: "bg-sticker-coral", label: "2D"},
    %{sym: "code128", name: "Code 128", desc: "Dense alphanumeric — shipping & inventory", bubble: "bg-sticker-teal", fg: "text-white", icon: :barcode, chip: "bg-sticker-sky", label: "Linear"},
    %{sym: "code39", name: "Code 39", desc: "Legacy industrial — uppercase & digits", bubble: "bg-sticker-grape", fg: "text-white", icon: :barcode, chip: "bg-sticker-pink", label: "Linear"},
    %{sym: "ean13", name: "EAN-13", desc: "Worldwide retail products (13 digits)", bubble: "bg-sticker-coral", fg: "text-white", icon: :scan_line, chip: "bg-sticker-yellow", label: "Retail"},
    %{sym: "ean8", name: "EAN-8", desc: "Small retail packs (8 digits)", bubble: "bg-sticker-pink", fg: "text-sticker-ink", icon: :scan_line, chip: "bg-sticker-sky", label: "Retail"},
    %{sym: "upca", name: "UPC-A", desc: "US & Canada retail (12 digits)", bubble: "bg-sticker-sky", fg: "text-sticker-ink", icon: :scan_line, chip: "bg-sticker-coral", label: "Retail"},
    %{sym: "pdf417", name: "PDF417", desc: "IDs & tickets — lots of data in 2D", bubble: "bg-sticker-ink", fg: "text-white", icon: :grid_3x3, chip: "bg-sticker-yellow", label: "2D"},
    %{sym: "datamatrix", name: "DataMatrix", desc: "Tiny marks for small parts", bubble: "bg-sticker-teal", fg: "text-sticker-ink", icon: :grid_2x2, chip: "bg-sticker-grape", label: "2D"},
    %{sym: "azteccode", name: "Aztec", desc: "Transit tickets & boarding passes", bubble: "bg-sticker-yellow", fg: "text-sticker-ink", icon: :target, chip: "bg-sticker-pink", label: "2D"}
  ]

  # Lucide icon path data (24px stroke set), keyed by the atoms above.
  @icon_paths %{
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
    scan_line: [
      "M3 7v5a4 4 0 0 0 8 0V7",
      "M7 3v.01",
      "M7 21v.01",
      "M11 3v.01",
      "M11 21v.01",
      "M15 3v.01",
      "M15 21v.01",
      "M19 3v.01",
      "M19 21v.01"
    ],
    grid_3x3: ["M12 3v18", "M3 12h18", "M3 3h.01", "M21 3h.01", "M3 21h.01", "M21 21h.01"],
    grid_2x2: ["M12 3v18", "M3 12h18"],
    target: [
      "M12 12m-10 0a10 10 0 1 0 20 0a10 10 0 1 0-20 0",
      "M12 12m-6 0a6 6 0 1 0 12 0a6 6 0 1 0-12 0",
      "M12 12m-2 0a2 2 0 1 0 4 0a2 2 0 1 0-4 0"
    ],
    arrow_left: ["M19 12H5", "m12 19-7-7 7-7"],
    sparkle: [
      "M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z"
    ]
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, cards: @cards, icon_paths: @icon_paths)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="choose-type-view" class="min-h-screen bg-sticker-cream font-body text-sticker-ink">
      <div class="relative mx-auto flex min-h-screen w-full max-w-[420px] flex-col gap-8 px-6 py-12">
        <svg class="absolute right-3 top-8 h-[18px] w-[18px] rotate-[-12deg] text-sticker-sky" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path :for={p <- @icon_paths.sparkle} d={p} />
        </svg>

        <!-- Header -->
        <header class="flex flex-col gap-5">
          <div class="flex items-center justify-between">
            <a
              href="/"
              class="flex h-11 w-11 items-center justify-center rounded-[14px] bg-white shadow-sticker-soft outline-3 outline-solid outline-sticker-ink outline-offset-[-1.5px] transition-transform hover:-translate-y-0.5"
              aria-label="Back to home"
            >
              {icon(:arrow_left, "h-5 w-5 text-sticker-ink")}
            </a>
            <span class="flex items-center gap-[6px] rounded-[999px] bg-sticker-pink p-[8px_14px] outline-[2.5px] outline-solid outline-sticker-ink outline-offset-[-1.25px]">
              {icon(:sparkle, "h-[13px] w-[13px] text-sticker-ink")}
              <span class="text-[12.5px] font-bold text-sticker-ink">9 formats</span>
            </span>
          </div>

          <div class="flex flex-col items-center gap-[10px]">
            <div class="rotate-[1.5deg] rounded-[16px] bg-sticker-yellow p-[7px_16px_9px] shadow-sticker outline-3 outline-solid outline-sticker-ink outline-offset-[-1.5px]">
              <h1 class="font-display text-[28px] font-extrabold text-sticker-ink">Choose a code type</h1>
            </div>
            <p class="text-center text-[14px] font-medium text-sticker-muted">
              Pick a barcode or QR format to get started
            </p>
          </div>
        </header>

        <a
          href="/codes/new"
          class="flex items-center justify-center gap-2 rounded-[40px] bg-white px-4 py-3 text-sm font-semibold text-sticker-ink shadow-sticker-card outline-3 outline-solid outline-sticker-ink outline-offset-[-1.5px]"
        >
          Need just one? Create a single code →
        </a>

        <!-- Code list -->
        <ul class="flex flex-col gap-[14px]">
          <li :for={card <- @cards} class="code-card">
            <a
              href={"/batches/new/" <> card.sym}
              class="flex items-center gap-3 rounded-[20px] bg-white p-3 shadow-sticker-card outline-3 outline-solid outline-sticker-ink outline-offset-[-1.5px] transition-transform hover:-translate-y-0.5"
            >
              <span class={"flex h-11 w-11 shrink-0 items-center justify-center rounded-[14px] #{card.bubble} #{card.fg} outline-[2.5px] outline-solid outline-sticker-ink outline-offset-[-1.25px]"}>
                {icon(card.icon, "h-5 w-5")}
              </span>
              <span class="flex min-w-0 flex-1 flex-col gap-[2px]">
                <span class="truncate text-[16px] font-semibold text-sticker-ink">{card.name}</span>
                <span class="w-full text-[11.5px] font-medium leading-[14px] text-sticker-muted">{card.desc}</span>
              </span>
              <span class={"shrink-0 rounded-[11px] px-[10px] py-[4px] text-[11.5px] font-bold text-sticker-ink outline-2 outline-solid outline-sticker-ink outline-offset-[-1px] #{card.chip}"}>
                {card.label}
              </span>
            </a>
          </li>
        </ul>
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
end
