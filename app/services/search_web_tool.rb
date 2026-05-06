class SearchWebTool
  PERPLEXITY_URL = "https://api.perplexity.ai/chat/completions".freeze

  def self.call(query:)
    response = HTTParty.post(
      PERPLEXITY_URL,
      headers: {
        "Authorization" => "Bearer #{ENV.fetch("PERPLEXITY_API_KEY", "")}",
        "Content-Type"  => "application/json"
      },
      body: {
        model: "sonar",
        messages: [{ role: "user", content: query }]
      }.to_json,
      timeout: 15
    )

    return "Search failed: HTTP #{response.code}" unless response.success?

    parsed    = response.parsed_response
    content   = parsed.dig("choices", 0, "message", "content") || ""
    citations = parsed["citations"] || []

    if citations.any?
      content + "\n\nSources:\n" + citations.first(5).map.with_index(1) { |url, i| "#{i}. #{url}" }.join("\n")
    else
      content
    end
  rescue StandardError => e
    "Search failed: #{e.message}"
  end
end
