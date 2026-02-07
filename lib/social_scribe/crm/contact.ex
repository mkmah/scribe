defmodule SocialScribe.Crm.Contact do
  @moduledoc """
  Normalized contact struct used across all CRM providers.

  Every CRM adapter maps its provider-specific response to this struct,
  which uses canonical field names. The UI and AI layers only work with
  this struct, never with provider-specific data.
  """

  @fields [
    :id,
    :first_name,
    :last_name,
    :email,
    :phone,
    :mobile_phone,
    :company,
    :job_title,
    :address,
    :city,
    :state,
    :zip,
    :country,
    :website,
    :linkedin_url,
    :twitter_handle,
    :display_name,
    :provider,
    :provider_data
  ]

  defstruct @fields

  @type t :: %__MODULE__{
          id: String.t() | nil,
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          email: String.t() | nil,
          phone: String.t() | nil,
          mobile_phone: String.t() | nil,
          company: String.t() | nil,
          job_title: String.t() | nil,
          address: String.t() | nil,
          city: String.t() | nil,
          state: String.t() | nil,
          zip: String.t() | nil,
          country: String.t() | nil,
          website: String.t() | nil,
          linkedin_url: String.t() | nil,
          twitter_handle: String.t() | nil,
          display_name: String.t() | nil,
          provider: String.t() | nil,
          provider_data: map() | nil
        }

  @doc """
  Creates a new Contact from a map of canonical field names.
  Automatically computes `display_name` if not provided.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    contact = struct(__MODULE__, atomize_keys(attrs))

    if contact.display_name do
      contact
    else
      %{contact | display_name: compute_display_name(contact)}
    end
  end

  @doc """
  Gets a field value from the contact by canonical field name (string).
  Returns nil if the field doesn't exist or is not set.
  """
  @spec get_field(t(), String.t()) :: any()
  def get_field(%__MODULE__{} = contact, field_name) when is_binary(field_name) do
    case safe_to_atom(field_name) do
      nil -> nil
      atom -> Map.get(contact, atom)
    end
  end

  defp compute_display_name(%__MODULE__{first_name: first, last_name: last, email: email}) do
    name =
      [first, last]
      |> Enum.reject(&(is_nil(&1) or &1 == ""))
      |> Enum.join(" ")
      |> String.trim()

    if name == "" do
      email || ""
    else
      name
    end
  end

  defp atomize_keys(attrs) do
    Enum.reduce(attrs, %{}, fn
      {key, value}, acc when is_atom(key) ->
        Map.put(acc, key, value)

      {key, value}, acc when is_binary(key) ->
        case safe_to_atom(key) do
          nil -> acc
          atom -> Map.put(acc, atom, value)
        end
    end)
  end

  defp safe_to_atom(string) do
    String.to_existing_atom(string)
  rescue
    ArgumentError -> nil
  end
end
