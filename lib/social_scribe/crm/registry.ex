defmodule SocialScribe.Crm.Registry do
  @moduledoc """
  Maps CRM provider strings to their adapter modules.
  Single source of truth for all registered CRM providers.

  To add a new CRM, add a clause to `adapter_for/1` and
  include the provider string in `crm_providers/0`.
  """

  @providers %{
    "hubspot" => SocialScribe.Crm.Adapters.Hubspot,
    "salesforce" => SocialScribe.Crm.Adapters.Salesforce
  }

  @labels %{
    "hubspot" => "HubSpot",
    "salesforce" => "Salesforce"
  }

  @doc """
  Returns the adapter module for the given provider string.
  """
  @spec adapter_for(String.t()) :: {:ok, module()} | {:error, {:unknown_provider, String.t()}}
  def adapter_for(provider) when is_binary(provider) do
    case Map.fetch(@providers, provider) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, {:unknown_provider, provider}}
    end
  end

  @doc """
  Returns the adapter module for the given provider string, or raises.
  """
  @spec adapter_for!(String.t()) :: module()
  def adapter_for!(provider) when is_binary(provider) do
    case adapter_for(provider) do
      {:ok, module} -> module
      {:error, {:unknown_provider, p}} -> raise ArgumentError, "Unknown CRM provider: #{p}"
    end
  end

  @doc """
  Returns the list of all registered CRM provider strings.
  """
  @spec crm_providers() :: list(String.t())
  def crm_providers, do: Map.keys(@providers)

  @doc """
  Returns the human-readable label for a provider.
  Falls back to capitalizing the provider string.
  """
  @spec provider_label(String.t()) :: String.t()
  def provider_label(provider) when is_binary(provider) do
    Map.get(@labels, provider, String.capitalize(provider))
  end
end
