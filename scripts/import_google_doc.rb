#!/usr/bin/env ruby

require "date"
require "fileutils"
require "json"
require "net/http"
require "nokogiri"
require "openssl"
require "optparse"
require "uri"

module GoogleDocImporter
  class ImportError < StandardError; end

  ALLOWED_ELEMENTS = %w[
    a abbr b blockquote br caption cite code dd del div dl dt em h1 h2 h3 h4 h5 h6
    hr i img li ol p pre s span strong sub sup table tbody td tfoot th thead tr u ul
  ].freeze
  REMOVED_ELEMENTS = %w[iframe object script style].freeze
  ALLOWED_ATTRIBUTES = %w[alt colspan height href rowspan scope src title width].freeze
  SAFE_CSS_PROPERTIES = %w[
    background-color color font-family font-size font-style font-weight line-height
    margin-bottom margin-left margin-right margin-top text-align text-decoration
    text-indent vertical-align white-space
  ].freeze
  MAX_RESPONSE_BYTES = 15 * 1024 * 1024
  REDIRECT_LIMIT = 5
  GOOGLE_HOSTS = ["docs.google.com", "google.com"].freeze

  module_function

  def document_url(url)
    uri = URI.parse(url)
    unless uri.is_a?(URI::HTTPS) && uri.host == "docs.google.com" && uri.userinfo.nil?
      raise ImportError, "Use an HTTPS Google Docs sharing URL from docs.google.com."
    end

    published_path = %r{\A/document/d/e/[^/]+/pub\z}.match?(uri.path)
    document_id = uri.path.match(%r{/document/d/([^/]+)})&.captures&.first
    raise ImportError, "The URL does not look like a Google Docs document URL." unless document_id

    if published_path
      query = URI.decode_www_form(uri.query.to_s).reject { |key, _| key == "output" }
      uri.query = URI.encode_www_form(query + [["output", "html"]])
      uri
    else
      URI("https://docs.google.com/document/d/#{URI.encode_www_form_component(document_id)}/export?format=html")
    end
  rescue URI::InvalidURIError
    raise ImportError, "The Google Docs URL is invalid."
  end

  def fetch_document(url)
    uri = document_url(url)
    REDIRECT_LIMIT.times do
      response, body = request(uri)
      case response
      when Net::HTTPSuccess
        unless response["content-type"].to_s.downcase.include?("text/html")
          raise ImportError, "Google Docs returned a non-HTML response. Check the sharing settings and URL."
        end
        return body
      when Net::HTTPRedirection
        location = response["location"]
        raise ImportError, "Google Docs returned a redirect without a destination." unless location

        uri = URI.join(uri, location)
        unless uri.is_a?(URI::HTTPS) && google_host?(uri.host)
          raise ImportError, "Google Docs redirected to an unexpected host; refusing to follow it."
        end
      else
        raise ImportError, "Google Docs returned HTTP #{response.code}. Make sure anyone with the link can view the document."
      end
    end

    raise ImportError, "Google Docs redirected too many times."
  rescue SocketError, SystemCallError, Timeout::Error => e
    raise ImportError, "Could not fetch the Google Doc: #{e.message}"
  rescue URI::InvalidURIError
    raise ImportError, "Google Docs redirected to an invalid URL."
  rescue OpenSSL::SSL::SSLError => e
    raise ImportError, "Could not establish a secure connection to Google Docs: #{e.message}"
  end

  def request(uri)
    response_body = +""
    response = nil

    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = "DeToasty3-Google-Doc-Importer/1.0"
      http.request(request) do |result|
        response = result
        result.read_body do |chunk|
          response_body << chunk
          if response_body.bytesize > MAX_RESPONSE_BYTES
            raise ImportError, "The Google Doc export is larger than 15 MB."
          end
        end
      end
    end

    [response, response_body]
  end

  def google_host?(host)
    GOOGLE_HOSTS.include?(host) || host.end_with?(".googleusercontent.com") || host.end_with?(".google.com")
  end

  def extract_document(html)
    document = Nokogiri::HTML(html)
    title = document.at_css("title")&.text.to_s
    title = title.sub(/\s*-\s*Google Docs\z/i, "").strip
    body = document.at_css("body")
    class_styles = extract_class_styles(document)

    if title.match?(/sign in|google accounts/i) || body&.text.to_s.match?(/you need access to this document/i)
      raise ImportError, "Google Docs did not provide the document. Set sharing to anyone with the link can view."
    end
    raise ImportError, "The Google Doc export did not contain a document body." unless body

    sanitize_fragment(body, class_styles)
    css = class_styles.map { |name, declarations| ".google-doc-import .gdoc-#{name}{#{declarations}}" }.join
    fragment = body.inner_html.strip
    raise ImportError, "The Google Doc appears to be empty." if fragment.empty?

    content = +""
    content << "<style>#{css}</style>" unless css.empty?
    content << "<div class=\"google-doc-import\">#{fragment}</div>"

    [title, protect_liquid_syntax(content)]
  end

  def extract_class_styles(document)
    styles = {}
    document.css("style").each do |style_node|
      style_node.text.scan(/\.([a-zA-Z][\w-]*)\s*\{([^{}]*)\}/).each do |name, declarations|
        safe_declarations = declarations.split(";").filter_map do |declaration|
          property, value = declaration.split(":", 2).map { |part| part&.strip }
          next unless property && value && SAFE_CSS_PROPERTIES.include?(property.downcase)
          next unless safe_css_value?(property.downcase, value)

          "#{property.downcase}:#{value}"
        end
        styles[name] = safe_declarations.join(";") unless safe_declarations.empty?
      end
    end
    styles.delete_if { |_name, declarations| declarations.empty? }
  end

  def safe_css_value?(property, value)
    case property
    when "font-family"
      value.match?(/\A[\w\s,"'-]{1,100}\z/)
    when "font-size", "line-height", "margin-bottom", "margin-left", "margin-right", "margin-top", "text-indent"
      value.match?(/\A-?\d+(?:\.\d+)?(?:pt|px|em|rem|%)\z/i) ||
        (property == "line-height" && value.match?(/\A\d+(?:\.\d+)?\z/))
    when "font-weight"
      value.match?(/\A(?:normal|bold|[1-9]00)\z/i)
    when "font-style"
      %w[normal italic oblique].include?(value.downcase)
    when "text-decoration"
      %w[none underline line-through overline].include?(value.downcase)
    when "text-align"
      %w[left right center justify start end].include?(value.downcase)
    when "vertical-align"
      %w[baseline sub super top text-top middle bottom text-bottom].include?(value.downcase) ||
        value.match?(/\A-?\d+(?:\.\d+)?(?:pt|px|em|rem|%)\z/i)
    when "white-space"
      %w[normal nowrap pre pre-wrap pre-line].include?(value.downcase)
    when "color", "background-color"
      value.match?(/\A#[0-9a-f]{3}(?:[0-9a-f]{3}|[0-9a-f]{5})?\z/i) ||
        value.match?(/\Argb\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}\s*\)\z/i)
    else
      false
    end
  end

  def sanitize_fragment(body, class_styles)
    body.children.to_a.each { |node| sanitize_node(node, class_styles) }
  end

  def sanitize_node(node, class_styles)
    if node.element?
      name = node.name.downcase
      if REMOVED_ELEMENTS.include?(name)
        node.remove
        return
      end

      unless ALLOWED_ELEMENTS.include?(name)
        node.children.to_a.each { |child| sanitize_node(child, class_styles) }
        node.replace(node.children)
        return
      end

      node.attribute_nodes.each do |attribute|
        if attribute.name.downcase == "class"
          classes = attribute.value.split.select { |class_name| class_styles.key?(class_name) }
          if classes.empty?
            node.remove_attribute(attribute.name)
          else
            node[attribute.name] = classes.map { |class_name| "gdoc-#{class_name}" }.join(" ")
          end
          next
        end
        unless ALLOWED_ATTRIBUTES.include?(attribute.name.downcase) &&
               safe_attribute?(name, attribute.name.downcase, attribute.value)
          node.remove_attribute(attribute.name)
        end
      end

      if name == "img" && !node.key?("src")
        node.remove
        return
      end
    end

    node.children.to_a.each { |child| sanitize_node(child, class_styles) }
  end

  def safe_attribute?(element, attribute, value)
    return safe_link?(value) if element == "a" && attribute == "href"
    return safe_image?(value) if element == "img" && attribute == "src"
    return value.match?(/\A\d{1,4}\z/) if %w[height width colspan rowspan].include?(attribute)
    return %w[row col rowgroup colgroup].include?(value) if attribute == "scope"

    true
  end

  def safe_link?(value)
    return false if value.match?(/[\u0000-\u0020\\]/)
    return true if value.start_with?("#", "/", "./", "../") && !value.start_with?("//", "/\\")

    %w[http https mailto tel].include?(URI.parse(value).scheme&.downcase)
  rescue URI::InvalidURIError
    false
  end

  def safe_image?(value)
    return false if value.match?(/[\u0000-\u0020\\]/)

    %w[http https].include?(URI.parse(value).scheme&.downcase)
  rescue URI::InvalidURIError
    false
  end

  def protect_liquid_syntax(content)
    content.gsub("{{", "&#123;{").gsub("{%", "&#123;%")
  end

  def slug(title)
    value = title.downcase.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "")
    result = value.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
    result.empty? ? "google-doc" : result
  end

  def draft_content(title, date, html)
    <<~POST
      ---
      layout: post
      title: #{JSON.generate(title)}
      date: #{JSON.generate(date.iso8601)}
      ---

      #{html}
    POST
  end
end

def run_importer_cli
  options = { date: Date.today }
  parser = OptionParser.new do |opts|
    opts.banner = "Usage: bundle exec ruby scripts/import_google_doc.rb [options] GOOGLE_DOC_URL"
    opts.on("--title TITLE", "Override the title read from the Google Doc") { |title| options[:title] = title }
    opts.on("--date YYYY-MM-DD", "Set the draft date (defaults to today)") do |date|
      options[:date] = Date.iso8601(date)
    rescue Date::Error
      raise OptionParser::InvalidArgument, "date must use YYYY-MM-DD format"
    end
  end

  begin
    parser.parse!
    abort(parser.to_s) unless ARGV.length == 1

    source_url = ARGV.fetch(0)
    html = GoogleDocImporter.fetch_document(source_url)
    extracted_title, content = GoogleDocImporter.extract_document(html)
    title = options[:title].to_s.strip
    title = extracted_title if title.empty?
    raise GoogleDocImporter::ImportError, "Add --title TITLE because the Google Doc has no title." if title.empty?

    filename = "#{options[:date].iso8601}-#{GoogleDocImporter.slug(title)}.html"
    draft_path = File.expand_path("../_drafts/#{filename}", __dir__)
    raise GoogleDocImporter::ImportError, "A draft already exists at #{draft_path}; refusing to overwrite it." if File.exist?(draft_path)

    FileUtils.mkdir_p(File.dirname(draft_path))
    File.write(draft_path, GoogleDocImporter.draft_content(title, options[:date], content), mode: "w:UTF-8")
    puts "Imported draft: #{draft_path}"
    puts "Review it with: bundle exec jekyll serve --drafts"
  rescue OptionParser::ParseError, GoogleDocImporter::ImportError, SystemCallError => e
    warn "Import failed: #{e.message}"
    exit 1
  end
end

run_importer_cli if $PROGRAM_NAME == __FILE__
