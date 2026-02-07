defmodule SocialScribe.Crm.Behaviour do
  @moduledoc """
  Behaviour that all CRM adapters must implement.

  Provides a unified interface for contact operations across different
  CRM providers (HubSpot, Salesforce, etc.).
  """

  alias SocialScribe.Accounts.UserCredential

  @type contact :: map()

  @callback search_contacts(credential :: UserCredential.t(), query :: String.t()) ::
              {:ok, list(contact())} | {:error, any()}

  @callback get_contact(credential :: UserCredential.t(), contact_id :: String.t()) ::
              {:ok, contact()} | {:error, any()}

  @callback update_contact(
              credential :: UserCredential.t(),
              contact_id :: String.t(),
              updates :: map()
            ) ::
              {:ok, contact()} | {:error, any()}

  @callback refresh_token(credential :: UserCredential.t()) ::
              {:ok, UserCredential.t()} | {:error, any()}

  @callback provider_name() :: String.t()

  @callback field_mappings() ::
              list(%{canonical: String.t(), provider: String.t(), label: String.t()})
end
