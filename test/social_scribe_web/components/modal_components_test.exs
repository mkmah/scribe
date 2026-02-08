defmodule SocialScribeWeb.Components.ModalComponentsTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  use SocialScribeWeb, :html

  # LiveView wrappers so ~H has assigns
  defmodule ContactSelectTestLive do
    use SocialScribeWeb, :live_view
    import SocialScribeWeb.ModalComponents

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:selected_contact, session["selected_contact"])
       |> Phoenix.LiveView.Utils.assign(:contacts, session["contacts"] || [])
       |> Phoenix.LiveView.Utils.assign(:loading, session["loading"] || false)
       |> Phoenix.LiveView.Utils.assign(:open, session["open"] || false)
       |> Phoenix.LiveView.Utils.assign(:query, session["query"] || "")
       |> Phoenix.LiveView.Utils.assign(:error, session["error"])}
    end

    def render(assigns) do
      ~H"""
      <.contact_select
        selected_contact={@selected_contact}
        contacts={@contacts}
        loading={@loading}
        open={@open}
        query={@query}
        error={@error}
      />
      """
    end
  end

  defmodule EmptyStateTestLive do
    use SocialScribeWeb, :live_view
    import SocialScribeWeb.ModalComponents

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:message, session["message"] || "No data")
       |> Phoenix.LiveView.Utils.assign(:submessage, session["submessage"])}
    end

    def render(assigns) do
      ~H"""
      <.empty_state message={@message} submessage={@submessage} />
      """
    end
  end

  defmodule SuggestionCardTestLive do
    use SocialScribeWeb, :live_view
    import SocialScribeWeb.ModalComponents

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:suggestion, session["suggestion"])}
    end

    def render(assigns) do
      ~H"""
      <.suggestion_card suggestion={@suggestion} />
      """
    end
  end

  defmodule ModalFooterTestLive do
    use SocialScribeWeb, :live_view
    import SocialScribeWeb.ModalComponents

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:cancel_patch, session["cancel_patch"])
       |> Phoenix.LiveView.Utils.assign(:cancel_click, session["cancel_click"])
       |> Phoenix.LiveView.Utils.assign(:submit_text, session["submit_text"] || "Submit")
       |> Phoenix.LiveView.Utils.assign(:loading, session["loading"] || false)
       |> Phoenix.LiveView.Utils.assign(:disabled, session["disabled"] || false)
       |> Phoenix.LiveView.Utils.assign(:info_text, session["info_text"])}
    end

    def render(assigns) do
      ~H"""
      <.modal_footer
        cancel_patch={@cancel_patch}
        cancel_click={@cancel_click}
        submit_text={@submit_text}
        loading={@loading}
        disabled={@disabled}
        info_text={@info_text}
      />
      """
    end
  end

  describe "contact_select" do
    test "renders search input when no contact selected", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, ContactSelectTestLive, session: %{})

      assert html =~ "Select Contact"
      assert html =~ "Search contacts..."
      assert html =~ "contact_query"
    end

    test "renders selected contact name when contact is set", %{conn: conn} do
      contact = %SocialScribe.Crm.Contact{display_name: "Jane Doe", email: "jane@example.com"}

      {:ok, _view, html} =
        live_isolated(conn, ContactSelectTestLive,
          session: %{"selected_contact" => contact, "open" => true}
        )

      assert html =~ "Jane Doe"
      assert html =~ "Clear selection"
    end

    test "renders selected contact from map with display_name", %{conn: conn} do
      contact = %{"display_name" => "Map User", "email" => "map@example.com"}

      {:ok, _view, html} =
        live_isolated(conn, ContactSelectTestLive,
          session: %{"selected_contact" => contact, "open" => true}
        )

      assert html =~ "Map User"
    end

    test "renders contact from map with firstname and lastname", %{conn: conn} do
      contact =
        %{"firstname" => "John", "lastname" => "Smith", "email" => "j@e.com"} |> Map.put(:id, 1)

      {:ok, _view, html} =
        live_isolated(conn, ContactSelectTestLive,
          session: %{"selected_contact" => contact, "contacts" => [contact], "open" => true}
        )

      assert html =~ "John Smith"
    end

    test "renders contact from map with first_name and last_name", %{conn: conn} do
      contact = %{id: 2, first_name: "Alice", last_name: "Jones", email: "a@e.com"}

      {:ok, _view, html} =
        live_isolated(conn, ContactSelectTestLive,
          session: %{"selected_contact" => contact, "contacts" => [contact], "open" => true}
        )

      assert html =~ "Alice Jones"
    end

    test "renders contact list in open listbox", %{conn: conn} do
      contact = %SocialScribe.Crm.Contact{
        id: 42,
        display_name: "List User",
        email: "list@example.com"
      }

      {:ok, _view, html} =
        live_isolated(conn, ContactSelectTestLive,
          session: %{"contacts" => [contact], "open" => true}
        )

      assert html =~ "List User"
      assert html =~ "list@example.com"
    end

    test "renders map contact with email only as fallback", %{conn: conn} do
      contact = %{"email" => "only@example.com"} |> Map.put(:id, 3)

      {:ok, _view, html} =
        live_isolated(conn, ContactSelectTestLive,
          session: %{"selected_contact" => contact, "open" => true}
        )

      assert html =~ "only@example.com"
    end

    test "open listbox shows No contacts found when query non-empty and no results", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ContactSelectTestLive,
          session: %{"open" => true, "query" => "xyz", "loading" => false, "contacts" => []}
        )

      assert html =~ "No contacts found"
    end

    test "open listbox shows Searching when loading", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ContactSelectTestLive, session: %{"open" => true, "loading" => true})

      assert html =~ "Searching..."
    end

    test "shows loading state", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ContactSelectTestLive, session: %{"loading" => true})

      assert html =~ "animate-spin"
    end

    test "shows error message when error is set", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ContactSelectTestLive, session: %{"error" => "Something went wrong"})

      assert html =~ "Something went wrong"
      assert html =~ "text-destructive"
    end
  end

  describe "empty_state" do
    test "renders message and optional submessage", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, EmptyStateTestLive,
          session: %{"message" => "No contacts", "submessage" => "Connect your CRM"}
        )

      assert html =~ "No contacts"
      assert html =~ "Connect your CRM"
    end
  end

  describe "suggestion_card" do
    test "renders suggestion with label and values", %{conn: conn} do
      suggestion = %{
        field: :company,
        label: "Company",
        current_value: "Old Co",
        new_value: "New Co",
        apply: true
      }

      {:ok, _view, html} =
        live_isolated(conn, SuggestionCardTestLive, session: %{"suggestion" => suggestion})

      assert html =~ "Company"
      assert html =~ "Old Co"
      assert html =~ "New Co"
    end

    test "renders No value when current_value is nil", %{conn: conn} do
      suggestion = %{
        field: :phone,
        label: "Phone",
        current_value: nil,
        new_value: "555-1234",
        apply: false
      }

      {:ok, _view, html} =
        live_isolated(conn, SuggestionCardTestLive, session: %{"suggestion" => suggestion})

      assert html =~ "Phone"
      assert html =~ "No value"
      assert html =~ "555-1234"
    end
  end

  describe "modal_footer" do
    test "renders submit and cancel", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, ModalFooterTestLive, session: %{})

      assert html =~ "Submit"
      assert html =~ "Cancel"
    end

    test "renders custom submit text and loading", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ModalFooterTestLive,
          session: %{"submit_text" => "Save", "loading" => true}
        )

      assert html =~ "Processing..."
    end

    test "renders cancel with cancel_click", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ModalFooterTestLive, session: %{"cancel_click" => "cancel_clicked"})

      assert html =~ "Cancel"
      assert html =~ "phx-click"
    end

    test "renders info_text when set", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ModalFooterTestLive, session: %{"info_text" => "Optional note here"})

      assert html =~ "Optional note here"
    end

    test "renders disabled submit when disabled true", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, ModalFooterTestLive, session: %{"disabled" => true})

      assert html =~ "disabled"
    end
  end
end
