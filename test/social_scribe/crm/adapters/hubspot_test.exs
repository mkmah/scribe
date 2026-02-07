defmodule SocialScribe.Crm.Adapters.HubspotTest do
  use ExUnit.Case, async: true

  alias SocialScribe.Crm.Adapters.Hubspot
  alias SocialScribe.Crm.Adapters.HubspotFields
  alias SocialScribe.Crm.Contact

  describe "provider_name/0" do
    test "returns 'hubspot'" do
      assert Hubspot.provider_name() == "hubspot"
    end
  end

  describe "field_mappings/0" do
    test "returns mappings for all standard contact fields" do
      mappings = Hubspot.field_mappings()

      assert is_list(mappings)
      assert length(mappings) > 0

      canonical_fields = Enum.map(mappings, & &1.canonical)
      assert "first_name" in canonical_fields
      assert "last_name" in canonical_fields
      assert "email" in canonical_fields
      assert "phone" in canonical_fields
      assert "company" in canonical_fields
      assert "job_title" in canonical_fields
    end

    test "each mapping has canonical, provider, and label keys" do
      mappings = Hubspot.field_mappings()

      for mapping <- mappings do
        assert Map.has_key?(mapping, :canonical)
        assert Map.has_key?(mapping, :provider)
        assert Map.has_key?(mapping, :label)
        assert is_binary(mapping.canonical)
        assert is_binary(mapping.provider)
        assert is_binary(mapping.label)
      end
    end
  end

  describe "to_contact/1" do
    test "converts HubSpot API response to Crm.Contact struct" do
      hubspot_response = %{
        "id" => "123",
        "properties" => %{
          "firstname" => "John",
          "lastname" => "Doe",
          "email" => "john@example.com",
          "phone" => "555-1234",
          "mobilephone" => "555-5678",
          "company" => "Acme Corp",
          "jobtitle" => "Engineer",
          "address" => "123 Main St",
          "city" => "Springfield",
          "state" => "IL",
          "zip" => "62704",
          "country" => "USA",
          "website" => "https://acme.com",
          "hs_linkedin_url" => "https://linkedin.com/in/johndoe",
          "twitterhandle" => "@johndoe"
        }
      }

      contact = HubspotFields.to_contact(hubspot_response)

      assert %Contact{} = contact
      assert contact.id == "123"
      assert contact.first_name == "John"
      assert contact.last_name == "Doe"
      assert contact.email == "john@example.com"
      assert contact.phone == "555-1234"
      assert contact.mobile_phone == "555-5678"
      assert contact.company == "Acme Corp"
      assert contact.job_title == "Engineer"
      assert contact.address == "123 Main St"
      assert contact.city == "Springfield"
      assert contact.state == "IL"
      assert contact.zip == "62704"
      assert contact.country == "USA"
      assert contact.website == "https://acme.com"
      assert contact.linkedin_url == "https://linkedin.com/in/johndoe"
      assert contact.twitter_handle == "@johndoe"
    end

    test "maps HubSpot field names to canonical names" do
      hubspot_response = %{
        "id" => "456",
        "properties" => %{
          "firstname" => "Jane",
          "lastname" => "Smith",
          "jobtitle" => "CTO",
          "mobilephone" => "555-9999"
        }
      }

      contact = HubspotFields.to_contact(hubspot_response)

      # HubSpot uses lowercase, Contact uses snake_case canonical
      assert contact.first_name == "Jane"
      assert contact.last_name == "Smith"
      assert contact.job_title == "CTO"
      assert contact.mobile_phone == "555-9999"
    end

    test "sets provider to 'hubspot'" do
      contact = HubspotFields.to_contact(%{"id" => "123", "properties" => %{}})

      assert contact.provider == "hubspot"
    end

    test "preserves raw response in provider_data" do
      raw = %{"id" => "123", "properties" => %{"firstname" => "John"}}
      contact = HubspotFields.to_contact(raw)

      assert contact.provider_data == raw
    end

    test "computes display_name" do
      contact =
        HubspotFields.to_contact(%{
          "id" => "123",
          "properties" => %{"firstname" => "John", "lastname" => "Doe"}
        })

      assert contact.display_name == "John Doe"
    end
  end

  describe "to_provider_fields/1" do
    test "converts canonical field map to HubSpot field names" do
      canonical = %{"first_name" => "John", "last_name" => "Doe", "phone" => "555-1234"}

      provider_fields = HubspotFields.to_provider_fields(canonical)

      assert provider_fields["firstname"] == "John"
      assert provider_fields["lastname"] == "Doe"
      assert provider_fields["phone"] == "555-1234"
    end

    test "skips unknown canonical fields" do
      canonical = %{"first_name" => "John", "nonexistent" => "value"}

      provider_fields = HubspotFields.to_provider_fields(canonical)

      assert provider_fields["firstname"] == "John"
      refute Map.has_key?(provider_fields, "nonexistent")
    end
  end
end
