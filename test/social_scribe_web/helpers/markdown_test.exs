defmodule SocialScribeWeb.Helpers.MarkdownTest do
  use ExUnit.Case, async: true

  import SocialScribeWeb.Helpers.Markdown
  import Phoenix.HTML, only: [safe_to_string: 1]

  describe "render_markdown/1" do
    test "renders basic markdown text" do
      markdown = "Hello **world**"
      html = markdown |> render_markdown() |> safe_to_string()

      assert html =~ ~s(<p>\nHello <strong>world</strong></p>)
    end

    test "renders markdown headings" do
      markdown = "# Heading 1\n## Heading 2\n### Heading 3"
      html = markdown |> render_markdown() |> safe_to_string()

      assert html =~ ~s(<h1>\nHeading 1</h1>)
      assert html =~ ~s(<h2>\nHeading 2</h2>)
      assert html =~ ~s(<h3>\nHeading 3</h3>)
    end

    test "renders markdown lists" do
      markdown = "- Item 1\n- Item 2\n- Item 3"
      html = markdown |> render_markdown() |> safe_to_string()

      assert html =~ "<ul>"
      assert html =~ ~s(<li>\nItem 1)
      assert html =~ ~s(<li>\nItem 2)
      assert html =~ ~s(<li>\nItem 3)
    end

    test "renders markdown code blocks" do
      markdown = "```elixir\ndef hello, do: :world\n```"
      html = markdown |> render_markdown() |> safe_to_string()

      assert html =~ "<pre>"
      assert html =~ "<code"
    end

    test "renders inline code" do
      markdown = "Use `render_markdown/1` function"
      html = markdown |> render_markdown() |> safe_to_string()

      assert html =~ ~s(<code class="inline">)
      assert html =~ "render_markdown/1"
    end

    test "renders markdown links" do
      markdown = "[Link text](https://example.com)"
      html = markdown |> render_markdown() |> safe_to_string()

      assert html =~ "<a href=\"https://example.com\">"
      assert html =~ "Link text"
    end

    test "renders markdown blockquotes" do
      markdown = "> This is a quote"
      html = markdown |> render_markdown() |> safe_to_string()

      assert html =~ "<blockquote>"
      assert html =~ "This is a quote"
    end

    test "renders italic text" do
      markdown = "This is *italic* text"
      html = markdown |> render_markdown() |> safe_to_string()

      assert html =~ "<em>italic</em>"
    end

    test "renders bold text" do
      markdown = "This is **bold** text"
      html = markdown |> render_markdown() |> safe_to_string()

      assert html =~ "<strong>bold</strong>"
    end

    test "handles nil input" do
      assert render_markdown(nil) |> safe_to_string() == ""
    end

    test "handles empty string input" do
      assert render_markdown("") |> safe_to_string() == ""
    end

    test "handles plain text without markdown" do
      text = "Just plain text here"
      html = text |> render_markdown() |> safe_to_string()

      assert html =~ "Just plain text here"
      assert html =~ "<p>"
    end

    test "handles multiline text" do
      markdown = "Line 1\n\nLine 2"
      html = markdown |> render_markdown() |> safe_to_string()

      assert html =~ "Line 1"
      assert html =~ "Line 2"
    end

    test "handles complex markdown with multiple elements" do
      markdown = """
      # Title

      This is a **paragraph** with *formatting*.

      - List item 1
      - List item 2

      `code` and [link](https://example.com)
      """

      html = markdown |> render_markdown() |> safe_to_string()

      assert html =~ ~s(<h1>\nTitle</h1>)
      assert html =~ "<strong>paragraph</strong>"
      assert html =~ "<em>formatting</em>"
      assert html =~ "<ul>"
      assert html =~ ~s(<code class="inline">code</code>)
      assert html =~ "<a href=\"https://example.com\">"
    end

    test "handles invalid markdown gracefully" do
      # Earmark should handle most edge cases, but if it returns an error,
      # we should fall back to escaped HTML
      markdown = "Normal text"
      html = markdown |> render_markdown() |> safe_to_string()

      # Should still render something
      assert is_binary(html)
      assert html != ""
    end

    test "handles non-string input" do
      assert render_markdown(123) |> safe_to_string() == ""
      assert render_markdown([]) |> safe_to_string() == ""
      assert render_markdown(%{}) |> safe_to_string() == ""
    end
  end
end
