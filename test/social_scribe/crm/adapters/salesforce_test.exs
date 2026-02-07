defmodule SocialScribe.Crm.Adapters.SalesforceTest do
  use ExUnit.Case, async: true

  alias SocialScribe.Crm.Adapters.Salesforce
  alias SocialScribe.Crm.Adapters.SalesforceFields
  alias SocialScribe.Crm.Contact

  describe "provider_name/0" do
    test "returns 'salesforce'" do
      assert Salesforce.provider_name() == "salesforce"
    end
  end

  describe "field_mappings/0" do
    test "returns mappings for all standard contact fields" do
      mappings = Salesforce.field_mappings()

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

    test "maps canonical names to Salesforce PascalCase names" do
      mappings = Salesforce.field_mappings()

      first_name_mapping = Enum.find(mappings, &(&1.canonical == "first_name"))
      assert first_name_mapping.provider == "FirstName"

      last_name_mapping = Enum.find(mappings, &(&1.canonical == "last_name"))
      assert last_name_mapping.provider == "LastName"

      email_mapping = Enum.find(mappings, &(&1.canonical == "email"))
      assert email_mapping.provider == "Email"

      job_title_mapping = Enum.find(mappings, &(&1.canonical == "job_title"))
      assert job_title_mapping.provider == "Title"
    end
  end

  describe "to_contact/1" do
    test "converts Salesforce API response to Crm.Contact struct" do
      sf_response = %{
        "Id" => "003abc",
        "FirstName" => "Jane",
        "LastName" => "Smith",
        "Email" => "jane@example.com",
        "Phone" => "555-9876",
        "MobilePhone" => "555-4321",
        "Title" => "VP Sales",
        "Department" => "Sales",
        "MailingStreet" => "456 Oak Ave",
        "MailingCity" => "Chicago",
        "MailingState" => "IL",
        "MailingPostalCode" => "60601",
        "MailingCountry" => "USA"
      }

      contact = SalesforceFields.to_contact(sf_response)

      assert %Contact{} = contact
      assert contact.id == "003abc"
      assert contact.first_name == "Jane"
      assert contact.last_name == "Smith"
      assert contact.email == "jane@example.com"
      assert contact.phone == "555-9876"
      assert contact.mobile_phone == "555-4321"
      assert contact.job_title == "VP Sales"
      assert contact.address == "456 Oak Ave"
      assert contact.city == "Chicago"
      assert contact.state == "IL"
      assert contact.zip == "60601"
      assert contact.country == "USA"
    end

    test "maps Salesforce PascalCase fields to canonical names" do
      sf_response = %{
        "Id" => "003xyz",
        "FirstName" => "Bob",
        "LastName" => "Jones",
        "Title" => "CEO",
        "MobilePhone" => "555-0000"
      }

      contact = SalesforceFields.to_contact(sf_response)

      assert contact.first_name == "Bob"
      assert contact.last_name == "Jones"
      assert contact.job_title == "CEO"
      assert contact.mobile_phone == "555-0000"
    end

    test "sets provider to 'salesforce'" do
      contact = SalesforceFields.to_contact(%{"Id" => "003abc"})

      assert contact.provider == "salesforce"
    end

    test "preserves raw response in provider_data" do
      raw = %{"Id" => "003abc", "FirstName" => "Jane"}
      contact = SalesforceFields.to_contact(raw)

      assert contact.provider_data == raw
    end

    test "computes display_name" do
      contact =
        SalesforceFields.to_contact(%{
          "Id" => "003abc",
          "FirstName" => "Jane",
          "LastName" => "Smith"
        })

      assert contact.display_name == "Jane Smith"
    end
  end

  describe "to_provider_fields/1" do
    test "converts canonical field map to Salesforce PascalCase names" do
      canonical = %{"first_name" => "Jane", "last_name" => "Smith", "phone" => "555-9876"}

      provider_fields = SalesforceFields.to_provider_fields(canonical)

      assert provider_fields["FirstName"] == "Jane"
      assert provider_fields["LastName"] == "Smith"
      assert provider_fields["Phone"] == "555-9876"
    end

    test "skips unknown canonical fields" do
      canonical = %{"first_name" => "Jane", "nonexistent" => "value"}

      provider_fields = SalesforceFields.to_provider_fields(canonical)

      assert provider_fields["FirstName"] == "Jane"
      refute Map.has_key?(provider_fields, "nonexistent")
    end
  end
end
