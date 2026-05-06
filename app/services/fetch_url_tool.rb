class FetchUrlTool
  MAX_CHARS = 3000
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".freeze

  def self.call(url:)
    response = HTTParty.get(
      url,
      headers: { "User-Agent" => USER_AGENT },
      timeout: 10,
      follow_redirects: true
    )

    return "Failed to fetch URL: HTTP #{response.code}" unless response.success?

    text = strip_html(response.body.to_s)
    text.strip.first(MAX_CHARS)
  rescue StandardError => e
    "Failed to fetch URL: #{e.message}"
  end

  def self.strip_html(html)
    html
      .gsub(/<script[^>]*>.*?<\/script>/mi, " ")
      .gsub(/<style[^>]*>.*?<\/style>/mi, " ")
      .gsub(/<!--.*?-->/m, " ")
      .gsub(/<[^>]+>/, " ")
      .gsub(/&amp;/, "&").gsub(/&lt;/, "<").gsub(/&gt;/, ">").gsub(/&nbsp;/, " ").gsub(/&#\d+;/, " ")
      .gsub(/\s+/, " ")
  end
end
