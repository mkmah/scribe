defmodule SocialScribe.Crm.Adapters.HubspotFields do
  @moduledoc """
  Field mapping between canonical and HubSpot field names.
  Provides conversion utilities between Crm.Contact and HubSpot API formats.
  """

  alias SocialScribe.Crm.Contact

  @mappings [
    %{canonical: "first_name", provider: "firstname", label: "First Name"},
    %{canonical: "last_name", provider: "lastname", label: "Last Name"},
    %{canonical: "email", provider: "email", label: "Email"},
    %{canonical: "phone", provider: "phone", label: "Phone"},
    %{canonical: "mobile_phone", provider: "mobilephone", label: "Mobile Phone"},
    %{canonical: "company", provider: "company", label: "Company"},
    %{canonical: "job_title", provider: "jobtitle", label: "Job Title"},
    %{canonical: "address", provider: "address", label: "Address"},
    %{canonical: "city", provider: "city", label: "City"},
    %{canonical: "state", provider: "state", label: "State"},
    %{canonical: "zip", provider: "zip", label: "ZIP Code"},
    %{canonical: "country", provider: "country", label: "Country"},
    %{canonical: "website", provider: "website", label: "Website"},
    %{canonical: "linkedin_url", provider: "hs_linkedin_url", label: "LinkedIn"},
    %{canonical: "twitter_handle", provider: "twitterhandle", label: "Twitter"}
  ]

  @doc """
  Returns the full list of field mappings.
  """
  def mappings, do: @mappings

  @doc """
  Returns the list of HubSpot property names to request from the API.
  """
  def contact_properties do
    Enum.map(@mappings, & &1.provider)
  end

  @doc """
  Converts a HubSpot API response into a Crm.Contact struct.
  """
  @spec to_contact(map()) :: Contact.t()
  def to_contact(%{"id" => id} = response) do
    properties = Map.get(response, "properties", %{})

    attrs =
      @mappings
      |> Enum.reduce(%{id: id, provider: "hubspot", provider_data: response}, fn mapping, acc ->
        value = Map.get(properties, mapping.provider)
        Map.put(acc, String.to_atom(mapping.canonical), value)
      end)

    Contact.new(attrs)
  end

  def to_contact(%{} = response) do
    # Handle case where response doesn't have "id" key
    Contact.new(%{provider: "hubspot", provider_data: response})
  end

  @doc """
  Converts a map of canonical field names to HubSpot provider field names.
  Skips fields that don't have a mapping.
  """
  @spec to_provider_fields(map()) :: map()
  def to_provider_fields(canonical_fields) when is_map(canonical_fields) do
    canonical_to_provider = Map.new(@mappings, fn m -> {m.canonical, m.provider} end)

    canonical_fields
    |> Enum.reduce(%{}, fn {canonical, value}, acc ->
      case Map.get(canonical_to_provider, canonical) do
        nil -> acc
        provider_field -> Map.put(acc, provider_field, value)
      end
    end)
  end
end
