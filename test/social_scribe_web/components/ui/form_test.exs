defmodule SocialScribeWeb.Components.UI.FormTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule FormFieldTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:label, session["label"] || "Email")
       |> Phoenix.LiveView.Utils.assign(:error, session["error"] || [])}
    end

    def render(assigns) do
      ~H"""
      <.form_field label={@label} error={@error}>
        <.input type="text" name="email" value="" />
      </.form_field>
      """
    end
  end

  defmodule FormFieldWithErrorsTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Phoenix.LiveView.Utils.assign(:label, session["label"] || "Field")
       |> Phoenix.LiveView.Utils.assign(:errors, session["errors"] || [])}
    end

    def render(assigns) do
      ~H"""
      <.form_field label={@label} error={@errors}>
        <.input type="text" name="name" value="" />
      </.form_field>
      """
    end
  end

  defmodule FormLabelRequiredTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.form_label for="x" required={true}>Required field</.form_label>
      """
    end
  end

  defmodule FormInputTypesTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.input type="checkbox" name="agree" value="true" />
      <.input type="radio" name="choice" value="a" />
      <.input type="file" name="upload" />
      """
    end
  end

  defmodule FormSelectTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.select name="item" prompt="Choose" options={[{"Option A", "a"}, {"Option B", "b"}]} value="" />
      """
    end
  end

  defmodule FormDescriptionTestLive do
    use SocialScribeWeb, :live_view

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      <.form_description>Helper text</.form_description>
      """
    end
  end

  describe "UI.Form" do
    test "form_field renders label and input", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, FormFieldTestLive, session: %{"label" => "Email"})

      assert html =~ "Email"
      assert html =~ "name=\"email\""
    end

    test "form_field with errors renders form_errors", %{conn: conn} do
      {:ok, _view, html} =
        live_isolated(conn, FormFieldWithErrorsTestLive,
          session: %{"label" => "Name", "errors" => [{"can't be blank", []}]}
        )

      assert html =~ "Name"
      assert html =~ "can&#39;t be blank"
    end

    test "form_label with required shows asterisk", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, FormLabelRequiredTestLive, [])
      assert html =~ "text-destructive"
    end

    test "input type checkbox and radio and file", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, FormInputTypesTestLive, [])
      assert html =~ "checkbox"
      assert html =~ "radio"
      assert html =~ "file"
    end

    test "select with prompt and options", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, FormSelectTestLive, [])
      assert html =~ "select"
      assert html =~ "Choose"
      assert html =~ "Option A"
    end

    test "form_description renders", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, FormDescriptionTestLive, [])
      assert html =~ "Helper text"
    end
  end
end
