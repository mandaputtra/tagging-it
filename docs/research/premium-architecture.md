# Premium Tier Architecture: Auth, Payments, Sync

**Issue:** mandaputtra/tagging-it#6 · **Status:** research summary
**App baseline:** Phoenix 1.7.24 + LiveView 1.2.10 (locked in `mix.lock`), free tier is 100% client-side (browser storage, no server).

---

## 1. Auth

### Recommendation: `mix phx.gen.auth` (password + email confirmation), Ueberauth later if social login is wanted

`mix phx.gen.auth Accounts User users` generates a complete, battle-tested auth system into the app: registration, email confirmation, login/logout, session + remember-me tokens, password reset. It is the Phoenix-recommended baseline (verified against [hexdocs: mix phx.gen.auth](https://hexdocs.pm/phoenix/mix_phx_gen_auth.html)). For this app the generated parts we actually need are:

- `users` + `user_tokens` tables (token contexts: `session`, `reset_password`, `confirm`).
- Session-cookie auth for the LiveView UI (account page, billing page).
- **API tokens for the sync client** — the generated `UserToken` design (SHA-256-hashed token, context column) extends cleanly: issue a token with context `"api"` per device/browser, return it once (e.g. `POST /api/tokens`), have the client store it in its browser storage next to the local data, and authenticate sync requests with `Authorization: Bearer <token>`.

**Ueberauth** ([hexdocs](https://hexdocs.pm/ueberauth/Ueberauth.html)) is a two-phase OAuth framework (request/callback) that works alongside — it only handles the provider handoff, not per-request auth. It is optional for v1; add it only if "Continue with Google/Apple" becomes a product requirement. It is NOT a replacement for `phx.gen.auth`; the standard pattern is phx.gen.auth as the core + Ueberauth strategies feeding the same `Accounts` context (upsert user by provider UID, then proceed as normal).

Hashing: generated code defaults to bcrypt; Phoenix docs recommend argon2 (`--hashing-lib argon2`) for robustness — worth taking at generation time.

> Note: Phoenix 1.8's generator replaces password auth with email magic links (password opt-in). This app is on 1.7.24, so generate with 1.7 semantics; the migration path to magic links is documented and non-breaking.

## 2. Payments

### Recommendation: Stripe Billing (subscription) via `stripity_stripe`, Checkout Session + webhooks + Customer Portal

**Provider choice:** Stripe is the default recommendation for a freemium Phoenix app: best test-mode ergonomics (test API keys, simulated cards, webhook forwarding), hosted Checkout (no PCI burden, no card data touches our server), and first-class subscriptions.

- **No official Stripe Elixir SDK exists** — verified: Stripe's official libraries page lists no Elixir, and `hex.pm/packages/stripe` is a dead 2014 package (0.0.1). The de-facto community standard is **`stripity_stripe` 3.3.2** ([hex.pm](https://hex.pm/packages/stripity_stripe), [github: beam-community/stripity-stripe](https://github.com/beam-community/stripity-stripe)), actively maintained and code-generated from Stripe's OpenAPI spec (`Stripe.Checkout.Session`, `Stripe.BillingPortal.Session`, `Stripe.Subscription`, webhook verification included). Configure with `config :stripity_stripe, api_key: System.get_env("STRIPE_SECRET_KEY")`.
- **Payment flow (subscription):**
  1. Authenticated user hits "Upgrade" → server creates a Checkout Session `mode: :subscription`, `line_items: [{price: <price_id>, quantity: 1}]`, `success_url` / `cancel_url`, `client_reference_id: user.id` (link Stripe → our user without trusting the callback) → 303 redirect to Stripe-hosted page.
  2. Stripe webhooks (verified against [docs.stripe.com/webhooks](https://docs.stripe.com/webhooks)) update our source of truth:
     - `checkout.session.completed` → create/attach Stripe Customer, mark user premium.
     - `customer.subscription.updated` / `customer.subscription.deleted` → refresh `users.subscription_status` / `premium_until` (handles renewals, cancellations, dunning/grace).
  3. "Manage subscription" → `Stripe.BillingPortal.Session.create` (customer can cancel/update payment method without us building UI).
- **Alternatives considered:** Paddle/Lemon Squeezy (merchant-of-record — nice for tax/VAT, but less standard Elixir integration and less test ergonomics), PayPal (weak subscription model), direct card capture (PCI scope — reject). Stripe wins for v1.

### Test-mode feasibility — fully supported, end-to-end (verified against [docs.stripe.com/test-mode](https://docs.stripe.com/test-mode))

1. Register a Stripe account → you land in a sandbox/test mode; copy `sk_test_...` (secret) and `pk_test_...` keys from the Dashboard → set `STRIPE_SECRET_KEY` env.
2. Create the Product + Recurring Price in test mode (`price_...`).
3. Pay with test card `4242 4242 4242 4242`, any future expiry, any CVC (declined scenarios: `4000000000000002` etc.).
4. **Local webhooks:** `stripe login` → `stripe listen --forward-to localhost:4000/webhooks/stripe` → prints a `whsec_...` signing secret; `stripe trigger customer.subscription.updated` to simulate events without a real payment.
5. Production parity: the exact same code paths run against live keys; only keys and the registered webhook endpoint differ.

## 3. Sync

### What syncs

The premium feature is server sync of the user's label/code library, so data-loss protection + multi-device access work even though the free tier runs entirely in the browser. Three entities:

| Entity | Description | Fields |
|---|---|---|
| `codes` | One barcode definition (a generated QR/barcode with its text label) | id (client UUID), type (qr, code128, code39, ean13, ean8, upca, pdf417, datamatrix, aztec), content, label, settings (JSON map), deleted, updated_at |
| `batches` | A bulk-generation job (reusable "make N codes from this template") | id, name, settings (JSON: template, count, numbering rule), deleted, updated_at |
| `batch_codes` | The materialized codes produced by a batch run (or, simpler for v1: store batch outputs as regular `codes` rows tagged `batch_id`) | — |

**v1 simplification:** treat batch outputs as `codes` rows with a nullable `batch_id`. One table to sync, one conflict rule. Split tables later only if batch output needs distinct behavior (e.g. regeneration).

### Payload shape

Every record carries a **client-generated UUID** (`crypto.randomUUID()` in the browser, `binary_id` on the server) and an **`updated_at` timestamp the client controls** (client clock, ISO-8601). Client timestamps are what make conflict resolution deterministic; server timestamps are only for the pull cursor.

```jsonc
// one code record
{
  "id": "018f9c2a-…-uuid",          // client-generated, stable across devices
  "type": "qr",                     // one of the v1 barcode set
  "content": "https://example.com/42",
  "label": "Inventory tag 42",
  "settings": { "size": 2, "margin": 4 },
  "batch_id": "018f9c2b-…" | null,
  "deleted": false,                 // tombstone; true = client deleted it
  "updated_at": "2026-08-22T09:41:00Z"  // CLIENT clock; used for LWW
}
```

### Endpoints (JSON REST, mounted under the API pipeline)

| Method | Route | Purpose |
|---|---|---|
| `POST` | `/api/tokens` | Issue an API token (auth: session) — the sync client's credential |
| `POST` | `/api/sync` | Single round-trip sync: client pushes its changed records + pull cursor; server returns server-changed records, conflicts, and new cursor |
| `GET` | `/api/me` | Returns `{user: …, plan: "premium"|"free"}` — lets the client check entitlement at startup |

`POST /api/sync` request:

```jsonc
{
  "since": "2026-08-22T08:00:00Z",        // pull cursor: server-changed-after this (server clock)
  "push": {                                 // records the client changed since its last push
    "codes":  [ /* code records, including deleted:true tombstones */ ],
    "batches": [ /* batch records */ ]
  }
}
```

`POST /api/sync` response:

```jsonc
{
  "cursor": "2026-08-22T09:42:00Z",        // new pull cursor (server now)
  "pull": {
    "codes":  [ /* records changed server-side after `since`, incl. tombstones */ ],
    "batches": [ /* same */ ]
  },
  "conflicts": [ /* records where client pushed but server version was newer */ ],
  "accepted": 12
}
```

**Upsert rule:** a pushed record is accepted when `client.updated_at >= server.updated_at` (or the record doesn't exist); otherwise it is returned in `conflicts`. After applying `pull` + `conflicts`, the client overwrites its local copy with the server's version — the next sync is guaranteed to converge (both sides converge to the highest `updated_at` per record).

**Deletes:** never hard-delete from the client; send `deleted: true` tombstones. Server purges tombstones older than a retention window (e.g. 90 days) so the sync table doesn't grow unbounded.

### Conflict strategy: per-record last-write-wins — CRDT is overkill

- **Why LWW is right here:** v1 is single-user-per-account (no teams/organizations — the generated auth has one user). The user edits whole records (a code's label/content/settings), not shared sub-fields. Two devices editing the *same* record is the rare case, and any lost edit is recoverable by re-editing. LWW is deterministic, trivially correct, and needs no new dependency.
- **Why not CRDT:** CRDTs (e.g. Automerge/Yjs-style) buy concurrent-merge semantics for collaborative or heavily concurrent editing of shared documents. We have neither — a single user on a few devices, whole-record writes. CRDT adds a library, larger payloads, and a different storage model for zero product value at this scale. Revisit only if multi-user collaboration on one batch ever ships.
- **Why not pure full-state sync:** pushing the entire library every sync is simpler to reason about but grows with the library and makes tombstones awkward; delta-with-cursor keeps payloads small and gives the pull side for free.

## 4. Gating: how free-vs-premium is enforced when the free app is client-side

**Principle: the server is the source of truth; the client gate is cosmetic, the server gate is enforcement.**

1. **Server truth:** `users.subscription_status` (`:free | :active | :past_due | :canceled`, plus `premium_until`) — updated only by verified Stripe webhooks, never by the client.
2. **Client entitlement:** the client learns its status from the server, not from local state:
   - LiveView UI: `current_scope.user` assign (phx.gen.auth scope) exposes `plan` — the "Sync" button renders only for premium.
   - Sync client: `GET /api/me` returns `plan`; if `free`, the client refuses to enable sync even if the user force-invokes it.
   - Since the free tier runs entirely in the browser, a stripped/copy-pasted client is irrelevant — nothing server-side depends on the client's honesty.
3. **Server enforcement:** a `require_premium_user` plug (modeled on the generated `require_authenticated_user`) on the API pipeline:

```elixir
# lib/tagging_it_web/plugs/require_premium_user.ex
def call(conn, _opts) do
  case conn.assigns.current_scope do
    %{user: %{subscription_status: :active}} -> conn
    _ -> conn |> put_status(:payment_required) |> json(%{error: "premium required"})
  end
end
```

   The API pipeline: `pipe_through [:api, :fetch_api_user, :require_authenticated_user, :require_premium_user]` — unauthenticated → 401, free → 402. The sync endpoints themselves double-check ownership (all queries scoped `where user_id == current_user.id`, per the generated Scopes guidance) so one user can never read another's records.
4. **Downgrade behavior:** when `customer.subscription.deleted` fires, the webhook flips the user to `:free`; their synced data stays in the database (no data loss — it's the sales pitch for re-subscribing), but `/api/sync` immediately returns 402. Local browser data is untouched either way.

## Recommended dependency deltas (for the implementation ticket)

```elixir
# mix.exs additions
{:stripity_stripe, "~> 3.3"}   # payments (community standard; no official Stripe SDK)
{:argon2_elixir, "~> 4.0"}     # phx.gen.auth --hashing-lib argon2 (recommended by Phoenix docs)
# + run: mix phx.gen.auth Accounts User users
```

Everything else (sync tables, API pipeline) is plain Ecto + Phoenix code — no new frameworks.

## Open questions to decide in implementation

- Batch model: `batch_codes` join vs. `codes.batch_id` (this doc recommends the latter for v1).
- Sync trigger: manual button vs. auto-sync on `visibilitychange`/interval (recommend: manual + on-sign-in).
- Token rotation/revocation UX for the API tokens screen.
