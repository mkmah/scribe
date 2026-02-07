defmodule SocialScribe.AccountsSalesforceTest do
  use SocialScribe.DataCase

  alias SocialScribe.Accounts

  import SocialScribe.AccountsFixtures

  describe "find_or_create_salesforce_credential/2" do
    test "creates new credential when none exists" do
      user = user_fixture()

      attrs = %{
        user_id: user.id,
        provider: "salesforce",
        uid: "sf_001",
        token: "access_token",
        refresh_token: "refresh_token",
        expires_at: DateTime.add(DateTime.utc_now(), 7200, :second),
        email: "user@salesforce.com",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, credential} = Accounts.find_or_create_salesforce_credential(user, attrs)
      assert credential.provider == "salesforce"
      assert credential.uid == "sf_001"
      assert credential.token == "access_token"
      assert credential.instance_url == "https://myorg.my.salesforce.com"
    end

    test "updates existing credential when one exists" do
      user = user_fixture()
      _existing = salesforce_credential_fixture(%{user_id: user.id, uid: "sf_001"})

      attrs = %{
        user_id: user.id,
        provider: "salesforce",
        uid: "sf_001",
        token: "new_token",
        refresh_token: "new_refresh",
        expires_at: DateTime.add(DateTime.utc_now(), 7200, :second),
        email: "user@salesforce.com",
        instance_url: "https://myorg.my.salesforce.com"
      }

      assert {:ok, credential} = Accounts.find_or_create_salesforce_credential(user, attrs)
      assert credential.token == "new_token"
      assert credential.instance_url == "https://myorg.my.salesforce.com"
    end

    test "stores instance_url" do
      user = user_fixture()

      attrs = %{
        user_id: user.id,
        provider: "salesforce",
        uid: "sf_002",
        token: "access_token",
        refresh_token: "refresh_token",
        expires_at: DateTime.add(DateTime.utc_now(), 7200, :second),
        email: "user@salesforce.com",
        instance_url: "https://custom.my.salesforce.com"
      }

      assert {:ok, credential} = Accounts.find_or_create_salesforce_credential(user, attrs)
      assert credential.instance_url == "https://custom.my.salesforce.com"
    end
  end

  describe "get_user_crm_credential/2" do
    test "returns credential for hubspot provider" do
      user = user_fixture()
      _cred = hubspot_credential_fixture(%{user_id: user.id})

      result = Accounts.get_user_crm_credential(user.id, "hubspot")
      assert result != nil
      assert result.provider == "hubspot"
    end

    test "returns credential for salesforce provider" do
      user = user_fixture()
      _cred = salesforce_credential_fixture(%{user_id: user.id})

      result = Accounts.get_user_crm_credential(user.id, "salesforce")
      assert result != nil
      assert result.provider == "salesforce"
    end

    test "returns nil when no credential exists" do
      user = user_fixture()

      assert nil == Accounts.get_user_crm_credential(user.id, "salesforce")
    end
  end
end
