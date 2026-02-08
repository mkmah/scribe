defmodule SocialScribe.Crm.Adapters.SalesforceFields do
  @moduledoc """
  Field mapping between canonical and Salesforce field names.
  Provides conversion utilities between Crm.Contact and Salesforce API formats.

  Note: Salesforce Contact doesn't have a direct "Company" field.
  Company name comes from the related Account (Account.Name).
  """

  alias SocialScribe.Crm.Contact

  # Standard fields directly on the Contact object
  @mappings [
    %{canonical: "first_name", provider: "FirstName", label: "First Name"},
    %{canonical: "last_name", provider: "LastName", label: "Last Name"},
    %{canonical: "email", provider: "Email", label: "Email"},
    %{canonical: "phone", provider: "Phone", label: "Phone"},
    %{canonical: "mobile_phone", provider: "MobilePhone", label: "Mobile Phone"},
    %{canonical: "job_title", provider: "Title", label: "Job Title"},
    %{canonical: "address", provider: "MailingStreet", label: "Address"},
    %{canonical: "city", provider: "MailingCity", label: "City"},
    %{canonical: "state", provider: "MailingState", label: "State"},
    %{canonical: "zip", provider: "MailingPostalCode", label: "ZIP Code"},
    %{canonical: "country", provider: "MailingCountry", label: "Country"}
  ]

  # Company is a read-only relationship field (Account.Name) — cannot be updated on Contact directly
  @company_mapping %{canonical: "company", provider: "Account.Name", label: "Company"}

  @doc """
  Returns the full list of field mappings (including company).
  """
  def mappings, do: @mappings ++ [@company_mapping]

  @doc """
  Returns the list of Salesforce field names for SOSL/SOQL queries.
  Includes Account.Name for the company relationship.
  """
  def contact_fields do
    direct_fields = Enum.map(@mappings, & &1.provider)
    direct_fields ++ ["Account.Name"]
  end

  @doc """
  Returns only the directly updatable field names (excludes relationship fields).
  """
  def updatable_fields do
    Enum.map(@mappings, & &1.provider)
  end

  @doc """
  Converts a Salesforce API response into a Crm.Contact struct.
  Handles the nested Account.Name for company.
  """
  @spec to_contact(map()) :: Contact.t()
  def to_contact(%{} = response) do
    id = Map.get(response, "Id")

    # Build attrs from direct field mappings
    attrs =
      @mappings
      |> Enum.reduce(%{id: id, provider: "salesforce", provider_data: response}, fn mapping,
                                                                                    acc ->
        value = Map.get(response, mapping.provider)
        Map.put(acc, String.to_atom(mapping.canonical), value)
      end)

    # Extract company from nested Account relationship
    company =
      case Map.get(response, "Account") do
        %{"Name" => name} -> name
        _ -> nil
      end

    attrs = Map.put(attrs, :company, company)

    Contact.new(attrs)
  end

  @doc """
  Converts a map of canonical field names to Salesforce provider field names.
  Skips relationship fields (company) and fields without a mapping.
  """
  @spec to_provider_fields(map()) :: map()
  def to_provider_fields(canonical_fields) when is_map(canonical_fields) do
    # Only use directly updatable mappings (not relationship fields like Account.Name)
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
