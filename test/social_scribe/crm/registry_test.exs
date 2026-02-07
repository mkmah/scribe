defmodule SocialScribe.Crm.RegistryTest do
  use ExUnit.Case, async: true

  alias SocialScribe.Crm.Registry

  describe "adapter_for/1" do
    test "returns HubSpot adapter for 'hubspot'" do
      assert {:ok, SocialScribe.Crm.Adapters.Hubspot} = Registry.adapter_for("hubspot")
    end

    test "returns Salesforce adapter for 'salesforce'" do
      assert {:ok, SocialScribe.Crm.Adapters.Salesforce} = Registry.adapter_for("salesforce")
    end

    test "returns error for unknown provider" do
      assert {:error, {:unknown_provider, "pipedrive"}} = Registry.adapter_for("pipedrive")
    end
  end

  describe "adapter_for!/1" do
    test "returns adapter module directly for valid provider" do
      assert SocialScribe.Crm.Adapters.Hubspot = Registry.adapter_for!("hubspot")
      assert SocialScribe.Crm.Adapters.Salesforce = Registry.adapter_for!("salesforce")
    end

    test "raises for unknown provider" do
      assert_raise ArgumentError, ~r/unknown CRM provider/i, fn ->
        Registry.adapter_for!("pipedrive")
      end
    end
  end

  describe "crm_providers/0" do
    test "returns list of all registered CRM provider strings" do
      providers = Registry.crm_providers()

      assert is_list(providers)
      assert "hubspot" in providers
      assert "salesforce" in providers
    end
  end

  describe "provider_label/1" do
    test "returns 'HubSpot' for 'hubspot'" do
      assert "HubSpot" = Registry.provider_label("hubspot")
    end

    test "returns 'Salesforce' for 'salesforce'" do
      assert "Salesforce" = Registry.provider_label("salesforce")
    end

    test "returns capitalized provider name for unknown provider" do
      assert "Pipedrive" = Registry.provider_label("pipedrive")
    end
  end
end
