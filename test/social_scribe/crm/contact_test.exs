defmodule SocialScribe.Crm.ContactTest do
  use ExUnit.Case, async: true

  alias SocialScribe.Crm.Contact

  describe "new/1" do
    test "creates contact from map with canonical field names" do
      attrs = %{
        id: "123",
        first_name: "John",
        last_name: "Doe",
        email: "john@example.com",
        phone: "555-1234",
        company: "Acme Corp",
        job_title: "Engineer",
        provider: "hubspot"
      }

      contact = Contact.new(attrs)

      assert %Contact{} = contact
      assert contact.id == "123"
      assert contact.first_name == "John"
      assert contact.last_name == "Doe"
      assert contact.email == "john@example.com"
      assert contact.phone == "555-1234"
      assert contact.company == "Acme Corp"
      assert contact.job_title == "Engineer"
      assert contact.provider == "hubspot"
    end

    test "computes display_name from first_name + last_name" do
      contact = Contact.new(%{first_name: "John", last_name: "Doe", email: "john@example.com"})

      assert contact.display_name == "John Doe"
    end

    test "falls back to email for display_name when name is empty" do
      contact = Contact.new(%{first_name: "", last_name: "", email: "john@example.com"})
      assert contact.display_name == "john@example.com"

      contact2 = Contact.new(%{first_name: nil, last_name: nil, email: "jane@example.com"})
      assert contact2.display_name == "jane@example.com"
    end

    test "falls back to empty string when no name or email" do
      contact = Contact.new(%{id: "123"})
      assert contact.display_name == ""
    end

    test "stores provider and provider_data" do
      raw = %{"Id" => "abc", "FirstName" => "Jane"}

      contact =
        Contact.new(%{
          id: "abc",
          first_name: "Jane",
          provider: "salesforce",
          provider_data: raw
        })

      assert contact.provider == "salesforce"
      assert contact.provider_data == raw
    end
  end

  describe "get_field/2" do
    test "returns value for canonical field name" do
      contact = Contact.new(%{first_name: "John", phone: "555-1234"})

      assert Contact.get_field(contact, "first_name") == "John"
      assert Contact.get_field(contact, "phone") == "555-1234"
    end

    test "returns nil for unknown field" do
      contact = Contact.new(%{first_name: "John"})

      assert Contact.get_field(contact, "nonexistent_field") == nil
    end

    test "returns nil for field that is not set" do
      contact = Contact.new(%{first_name: "John"})

      assert Contact.get_field(contact, "phone") == nil
    end
  end
end
