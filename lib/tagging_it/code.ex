defmodule TaggingIt.Code do
  @moduledoc """
  A single generated barcode or QR code: its code data string, symbology, and
  resolved label field map.

  The field map is fully resolved at creation (template + any per-code
  overrides) — no merge happens at render time. `dirty` marks codes pending
  premium sync.
  """

  alias TaggingIt.Fields.Field

  @enforce_keys [:id, :batch_id, :code_data, :fields]
  defstruct id: nil,
            batch_id: nil,
            code_data: "",
            symbology: "code128",
            fields: [],
            created_at: nil,
            updated_at: nil,
            dirty: true

  @type t :: %__MODULE__{
          id: String.t(),
          batch_id: String.t(),
          code_data: String.t(),
          symbology: String.t(),
          fields: [Field.t()],
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          dirty: boolean()
        }
end
