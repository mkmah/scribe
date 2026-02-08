defmodule SocialScribeWeb.UI.Form do
  @moduledoc """
  Form components including input, textarea, select, label, and error.

  ## Examples

      <.form_field label="Email" error={@form[:email].errors}>
        <.input type="email" field={@form[:email]} placeholder="Enter your email" />
      </.form_field>

      <.form_field label="Description">
        <.textarea field={@form[:description]} rows={4} />
      </.form_field>

      <.form_field label="Country">
        <.select field={@form[:country]} options={@countries} />
      </.form_field>
  """
  use Phoenix.Component

  alias SocialScribeWeb.UI.Icon

  # ============================================================================
  # FORM FIELD (Wrapper)
  # ============================================================================

  attr :label, :string, default: nil
  attr :error, :list, default: []
  attr :class, :string, default: nil
  attr :required, :boolean, default: false

  slot :inner_block, required: true

  def form_field(assigns) do
    ~H"""
    <div class={["flex flex-col space-y-2", @class]}>
      <%= if @label do %>
        <.form_label for={nil} required={@required}>
          {@label}
        </.form_label>
      <% end %>

      {render_slot(@inner_block)}

      <%= if @error != [] do %>
        <.form_errors errors={@error} />
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # FORM LABEL
  # ============================================================================

  attr :for, :string, default: nil
  attr :required, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def form_label(assigns) do
    ~H"""
    <label
      for={@for}
      class={[
        "text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
      <%= if @required do %>
        <span class="text-destructive">*</span>
      <% end %>
    </label>
    """
  end

  # ============================================================================
  # INPUT
  # ============================================================================

  attr :id, :any, default: nil
  attr :name, :any
  attr :value, :any
  attr :type, :string, default: "text"
  attr :field, Phoenix.HTML.FormField
  attr :errors, :list, default: []
  attr :placeholder, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :required, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="flex items-center space-x-2">
      <input type="hidden" name={@name} value="false" />
      <input
        type="checkbox"
        id={@id}
        name={@name}
        value="true"
        checked={@checked}
        disabled={@disabled}
        class={[
          "peer h-4 w-4 shrink-0 rounded-sm border border-primary ring-offset-background",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
          "disabled:cursor-not-allowed disabled:opacity-50",
          "data-[state=checked]:bg-primary data-[state=checked]:text-primary-foreground",
          @class
        ]}
        {@rest}
      />
    </div>
    """
  end

  def input(%{type: "radio"} = assigns) do
    ~H"""
    <input
      type="radio"
      id={@id}
      name={@name}
      value={@value}
      disabled={@disabled}
      class={[
        "h-4 w-4 border-primary text-primary ring-offset-background",
        "focus:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
        "disabled:cursor-not-allowed disabled:opacity-50",
        @class
      ]}
      {@rest}
    />
    """
  end

  def input(%{type: "file"} = assigns) do
    ~H"""
    <input
      type="file"
      id={@id}
      name={@name}
      disabled={@disabled}
      class={[
        "flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background",
        "file:border-0 file:bg-transparent file:text-sm file:font-medium",
        "placeholder:text-muted-foreground",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
        "disabled:cursor-not-allowed disabled:opacity-50",
        @class
      ]}
      {@rest}
    />
    """
  end

  def input(assigns) do
    ~H"""
    <input
      type={@type}
      id={@id}
      name={@name}
      value={Phoenix.HTML.Form.normalize_value(@type, @value)}
      placeholder={@placeholder}
      disabled={@disabled}
      required={@required}
      class={[
        "flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background",
        "placeholder:text-muted-foreground",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
        "disabled:cursor-not-allowed disabled:opacity-50",
        @class
      ]}
      {@rest}
    />
    """
  end

  # ============================================================================
  # TEXTAREA
  # ============================================================================

  attr :id, :any, default: nil
  attr :name, :any
  attr :value, :any
  attr :field, Phoenix.HTML.FormField
  attr :placeholder, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :required, :boolean, default: false
  attr :rows, :integer, default: 3
  attr :class, :string, default: nil
  attr :rest, :global

  def textarea(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> textarea()
  end

  def textarea(assigns) do
    ~H"""
    <textarea
      id={@id}
      name={@name}
      rows={@rows}
      placeholder={@placeholder}
      disabled={@disabled}
      required={@required}
      class={[
        "flex min-h-[80px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background",
        "placeholder:text-muted-foreground",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
        "disabled:cursor-not-allowed disabled:opacity-50",
        @class
      ]}
      {@rest}
   >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
    """
  end

  # ============================================================================
  # SELECT
  # ============================================================================

  attr :id, :any, default: nil
  attr :name, :any
  attr :value, :any
  attr :field, Phoenix.HTML.FormField
  attr :options, :list, default: []
  attr :prompt, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :required, :boolean, default: false
  attr :multiple, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  def select(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> select()
  end

  def select(assigns) do
    ~H"""
    <div class="relative">
      <select
        id={@id}
        name={@name}
        multiple={@multiple}
        disabled={@disabled}
        required={@required}
        class={[
          "flex h-10 w-full appearance-none rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
          "disabled:cursor-not-allowed disabled:opacity-50",
          @class
        ]}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <Icon.chevron_down class="absolute w-4 h-4 opacity-50 pointer-events-none right-3 top-3" />
    </div>
    """
  end

  # ============================================================================
  # FORM ERRORS
  # ============================================================================

  attr :errors, :list, required: true
  attr :class, :string, default: nil

  def form_errors(assigns) do
    ~H"""
    <div class={["text-sm font-medium text-destructive", @class]}>
      <%= for error <- @errors do %>
        <p>{error}</p>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # FORM DESCRIPTION
  # ============================================================================

  attr :class, :string, default: nil

  slot :inner_block, required: true

  def form_description(assigns) do
    ~H"""
    <p class={["text-sm text-muted-foreground", @class]}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  defp translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(SocialScribeWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(SocialScribeWeb.Gettext, "errors", msg, opts)
    end
  end
end
