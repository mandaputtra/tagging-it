defmodule TaggingIt.Batch do
  @moduledoc """
  Batch aggregate — a group of codes created together from one batch template.

  `create/1` generates each code's **Sequence** per the template's strategy and
  sets the **Value** (`code_data`) to the sequence by default (#14);
  `create_from_values/2` builds codes from user-supplied values (paste mode),
  numbering their sequences `1..N`. Both stamp each code with the batch id and
  pre-fill each code's field map from the template. New codes and the batch are
  marked dirty (pending premium sync).
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

  The generator fills each code's **Sequence** (unique per code); the **Value**
  (`code_data`) defaults to the sequence and is editable apart per code (#14).

  Returns `{:ok, batch, codes}` or `{:error, :invalid_strategy}` when the
  template's strategy cannot generate code data.
  """
  @spec create(Template.t()) :: {:ok, Batch.t(), [Code.t()]} | {:error, atom()}
  def create(%Template{} = template) do
    with {:ok, sequences} <- CodeData.generate(template.strategy) do
      build(template, Enum.map(sequences, &{&1, &1}))
    end
  end

  @doc """
  Creates a batch whose codes carry the given code data values (paste mode).

  Values are trimmed; blank lines are dropped. Sequences default to `1..N`
  (#14). Returns `{:ok, batch, codes}`.
  """
  @spec create_from_values(Template.t(), [String.t()]) :: {:ok, Batch.t(), [Code.t()]}
  def create_from_values(%Template{} = template, values) do
    code_data_list =
      values
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    pairs =
      code_data_list
      |> Enum.with_index(1)
      |> Enum.map(fn {code_data, i} -> {Integer.to_string(i), code_data} end)

    build(template, pairs)
  end

  # pairs = [{sequence, code_data}] — one per code.
  defp build(template, pairs) do
    now = DateTime.utc_now()
    batch_id = TaggingIt.UUID.generate()

    codes =
      Enum.map(pairs, fn {sequence, code_data} ->
        %Code{
          id: TaggingIt.UUID.generate(),
          batch_id: batch_id,
          sequence: sequence,
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
