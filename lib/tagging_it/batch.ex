defmodule TaggingIt.Batch do
  @moduledoc """
  Batch aggregate — a group of codes created together from one batch template.

  `create/1` generates the code data per the template's strategy, stamps each
  code with the batch id, and pre-fills each code's field map from the
  template. New codes and the batch are marked dirty (pending premium sync).
  """

  alias TaggingIt.Batch.Template
  alias TaggingIt.Code
  alias TaggingIt.CodeData

  @enforce_keys [:id, :name, :template, :code_ids]
  defstruct id: nil,
            name: nil,
            template: nil,
            code_ids: [],
            created_at: nil,
            updated_at: nil,
            dirty: true

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          template: Template.t(),
          code_ids: [String.t()],
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          dirty: boolean()
        }

  @doc """
  Creates a batch and its codes from a template.

  Returns `{:ok, batch, codes}` or `{:error, :invalid_strategy}` when the
  template's strategy cannot generate code data.
  """
  @spec create(Template.t()) :: {:ok, Batch.t(), [Code.t()]} | {:error, atom()}
  def create(%Template{} = template) do
    with {:ok, code_data_list} <- CodeData.generate(template.strategy) do
      now = DateTime.utc_now()
      batch_id = TaggingIt.UUID.generate()

      codes =
        Enum.map(code_data_list, fn code_data ->
          %Code{
            id: TaggingIt.UUID.generate(),
            batch_id: batch_id,
            code_data: code_data,
            symbology: template.symbology,
            fields: template.fields,
            created_at: now,
            updated_at: now,
            dirty: true
          }
        end)

      batch = %__MODULE__{
        id: batch_id,
        name: template.name,
        template: template,
        code_ids: Enum.map(codes, & &1.id),
        created_at: now,
        updated_at: now,
        dirty: true
      }

      {:ok, batch, codes}
    end
  end
end
