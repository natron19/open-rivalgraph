class AgentRunJob < ApplicationJob
  queue_as :default

  SEARCH_WEB_TOOL = {
    name: "search_web",
    description: "Search the live web for current information. Returns a synthesized answer with sources.",
    parameters: {
      type: "OBJECT",
      properties: {
        query: { type: "STRING", description: "The search query string" }
      },
      required: ["query"]
    }
  }.freeze

  FETCH_URL_TOOL = {
    name: "fetch_url",
    description: "Fetch the text content of a URL. Returns the first 3000 characters of the page body.",
    parameters: {
      type: "OBJECT",
      properties: {
        url: { type: "STRING", description: "The URL to fetch" }
      },
      required: ["url"]
    }
  }.freeze

  def perform(analysis_id)
    @analysis   = CompetitorAnalysis.find(analysis_id)
    @competitor = @analysis.competitor
    @own_product = @competitor.own_product
    Current.user = @analysis.user

    @analysis.update!(status: "running")
    broadcast_status("Research started...")

    result = GeminiService.generate_with_tools(
      template: "rivalgraph_battlecard_v1",
      variables: {
        competitor_name:    @competitor.company_name,
        competitor_website: @competitor.website.to_s,
        own_product_name:   @own_product.name,
        differentiator_1:   @own_product.differentiator_1,
        differentiator_2:   @own_product.differentiator_2,
        differentiator_3:   @own_product.differentiator_3
      },
      tools: [SEARCH_WEB_TOOL, FETCH_URL_TOOL],
      on_tool_call: method(:broadcast_step),
      max_rounds: 6
    )

    battlecard_json = JSON.parse(result[:text].gsub(/\A```json\n?/, "").gsub(/\n?```\z/, ""))

    @analysis.update!(
      status:        "complete",
      battlecard:    battlecard_json.to_json,
      gemini_raw:    result[:raw],
      agent_trace:   result[:tool_steps].to_json,
      researched_at: Time.current
    )

    broadcast_complete

  rescue JSON::ParserError
    @analysis.update!(status: "error", error_message: "Battlecard response was not valid JSON.")
    broadcast_error("Battlecard response was not valid JSON.")
  rescue GeminiService::GeminiError => e
    @analysis.update!(status: "error", error_message: e.message)
    broadcast_error(e.message)
  rescue StandardError => e
    @analysis.update!(status: "error", error_message: "Unexpected error: #{e.message}")
    broadcast_error("An unexpected error occurred.")
  end

  private

  def broadcast_step(tool_name, args, result)
    Turbo::StreamsChannel.broadcast_append_to(
      @analysis,
      target: "agent-progress-feed",
      partial: "competitor_analyses/progress_step",
      locals: { tool_name: tool_name, args: args, result: result }
    )
  end

  def broadcast_status(message)
    Turbo::StreamsChannel.broadcast_update_to(
      @analysis,
      target: "analysis-status",
      html: message
    )
  end

  def broadcast_complete
    Turbo::StreamsChannel.broadcast_update_to(
      @analysis,
      target: "analysis-container",
      partial: "competitor_analyses/battlecard",
      locals: { analysis: @analysis.reload }
    )
  end

  def broadcast_error(message)
    Turbo::StreamsChannel.broadcast_update_to(
      @analysis,
      target: "analysis-container",
      partial: "competitor_analyses/error_state",
      locals: { analysis: @analysis.reload, message: message }
    )
  end
end
