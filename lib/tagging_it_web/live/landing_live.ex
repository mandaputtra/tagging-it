defmodule TaggingItWeb.LandingLive do
  use TaggingItWeb, :live_view

  import Phoenix.Component

  alias TaggingItWeb.BatchFormLive

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, recent_batches: [])}
  end

  @impl true
  def handle_event("recent:loaded", %{"batches" => batches}, socket) do
    {:noreply, assign(socket, recent_batches: batches)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="landing-view" phx-hook="RecentBatches">
      <!-- Hero: navy band, purple CTA. Mobile-first single column. -->
      <header class="bg-navy text-on-dark">
        <div class="mx-auto max-w-5xl px-4 py-16 sm:py-24">
          <nav class="mb-16 flex items-center justify-between">
            <span class="text-lg font-semibold tracking-tight">Tagging It</span>
            <a href="/batches/new" class="text-sm text-on-dark-muted hover:text-on-dark">
              Create batch →
            </a>
          </nav>

          <div class="mx-auto max-w-2xl text-center">
            <h1 class="text-4xl font-semibold leading-tight tracking-tight sm:text-5xl md:text-6xl">
              QR codes and barcodes, ready to print in minutes
            </h1>
            <p class="mt-4 text-lg text-on-dark-muted">
              Generate sequences or paste your own values, add label fields, and print full
              sheets — right from your browser. Nothing leaves your device.
            </p>
            <div class="mt-8 flex flex-col items-center gap-3 sm:flex-row sm:justify-center">
              <a
                href="#create"
                class="rounded-md bg-brand px-5 py-2.5 text-sm font-medium text-on-brand shadow-card transition-colors hover:bg-brand-pressed"
              >
                Create your first batch
              </a>
              <a
                href="#recent"
                class="rounded-md border border-on-dark-muted px-5 py-2.5 text-sm font-medium text-on-dark hover:border-on-dark"
              >
                See your labels
              </a>
            </div>
          </div>
        </div>
      </header>

      <!-- Embedded batch form (server LiveView, same as /batches/new). -->
      <section id="create" class="bg-surface-soft py-12 sm:py-16">
        <div class="mx-auto max-w-5xl px-4">
          <div class="rounded-xl bg-canvas p-4 shadow-card sm:p-8">
            {live_render(@socket, BatchFormLive, id: "landing-batch-form", session: %{})}
          </div>
        </div>
      </section>

      <!-- Recent batches: client reads IndexedDB, pushes to server, server renders. -->
      <section id="recent" class="py-12 sm:py-16">
        <div class="mx-auto max-w-5xl px-4">
          <h2 class="text-2xl font-semibold tracking-tight">Your recent batches</h2>
          <p class="mt-1 text-sm text-steel">
            Stored in this browser — nothing is uploaded.
          </p>

          <%= if @recent_batches == [] do %>
            <p class="mt-8 text-sm text-muted" id="recent-batches-empty">
              No batches yet. Create your first one above.
            </p>
          <% else %>
            <ul id="recent-batches-list" class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <li :for={batch <- @recent_batches} class="rounded-lg border border-hairline bg-canvas p-5">
                <div class="flex items-start justify-between gap-3">
                  <a href={"/sheet/" <> batch["id"]} class="group block min-w-0">
                    <h3 class="truncate font-semibold text-ink group-hover:text-brand">
                      <%= batch["name"] %>
                    </h3>
                    <p class="mt-1 text-sm text-steel">
                      <%= batch["code_count"] %> <%= if batch["code_count"] == 1, do: "label", else: "labels" %>
                    </p>
                  </a>
                  <button
                    type="button"
                    id={"delete-" <> batch["id"]}
                    phx-hook="BatchDelete"
                    data-batch-id={batch["id"]}
                    class="shrink-0 rounded-md border border-hairline px-2 py-1 text-xs font-medium text-steel hover:border-error hover:text-error"
                    aria-label={"Delete " <> batch["name"]}
                  >
                    Delete
                  </button>
                </div>
              </li>
            </ul>
          <% end %>
        </div>
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
