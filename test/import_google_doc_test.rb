require "minitest/autorun"
require_relative "../scripts/import_google_doc"

class GoogleDocImporterTest < Minitest::Test
  def test_extracts_title_and_sanitizes_document_html
    title, content = GoogleDocImporter.extract_document(<<~HTML)
      <!doctype html>
      <html><head><title>Research Notes - Google Docs</title></head>
      <body><h1 onclick="alert(1)">Notes</h1>
      <p><strong>Useful</strong> <a href="https://example.com">link</a></p>
      <script>alert("no")</script>
      <a href="javascript:alert(1)">unsafe link</a></body></html>
    HTML

    assert_equal "Research Notes", title
    assert_includes content, "<h1>Notes</h1>"
    assert_includes content, "<strong>Useful</strong>"
    assert_includes content, 'href="https://example.com"'
    refute_includes content, "onclick"
    refute_includes content, "<script"
    refute_includes content, "javascript:"
  end

  def test_preserves_safe_google_doc_class_styles
    _title, content = GoogleDocImporter.extract_document(<<~HTML)
      <html><head><title>Styled</title>
      <style>.c0{font-weight:700;color:#123456;background:url(https://example.com)}</style>
      </head><body><p class="c0">Important</p></body></html>
    HTML

    assert_includes content, ".google-doc-import .gdoc-c0{font-weight:700;color:#123456}"
    assert_includes content, 'class="gdoc-c0"'
    refute_includes content, "url("
  end

  def test_refuses_non_google_urls
    assert_raises(GoogleDocImporter::ImportError) do
      GoogleDocImporter.document_url("https://example.com/document/d/abc/edit")
    end
  end

  def test_builds_export_urls_for_shared_and_published_documents
    shared = GoogleDocImporter.document_url("https://docs.google.com/document/d/abc123/edit?usp=sharing")
    published = GoogleDocImporter.document_url("https://docs.google.com/document/d/e/pub123/pub?embedded=true")

    assert_equal "/document/d/abc123/export?format=html", shared.request_uri
    assert_equal "/document/d/e/pub123/pub?embedded=true&output=html", published.request_uri
  end

  def test_builds_draft_front_matter
    date = Date.new(2026, 10, 2)
    draft = GoogleDocImporter.draft_content('Title: "Quoted"', date, "<p>Text</p>")

    assert_includes draft, 'title: "Title: \\"Quoted\\""'
    assert_includes draft, 'date: "2026-10-02"'
    assert_includes draft, "<p>Text</p>"
  end
end
