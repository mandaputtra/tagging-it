defmodule TaggingIt.Batch.Template do
  @moduledoc """
  The shared definition that pre-fills a batch: field names + shared values,
  the code-data generation strategy, and the label symbology.

  Label size is a UI concern and lives on the batch/session, not here.
  """

  alias TaggingIt.CodeData.{PatternStrategy, UlidStrategy}
  alias TaggingIt.Fields.Field

  @enforce_keys [:name, :strategy]
  defstruct name: nil,
            fields: [],
            strategy: nil,
            symbology: "code128",
            label_size: "avery5160"

  @type t :: %__MODULE__{
          name: String.t(),
          fields: [Field.t()],
          strategy: PatternStrategy.t() | UlidStrategy.t(),
          symbology: String.t(),
          label_size: String.t()
        }
end
