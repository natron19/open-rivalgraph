require "faraday"
require "json"

class GeminiService
  class GeminiError         < StandardError; end
  class GatekeeperError     < GeminiError;   end
  class BudgetExceededError < GeminiError;   end
  class TimeoutError        < GeminiError;   end

  TIMEOUT_SECONDS = ENV.fetch("AI_GLOBAL_TIMEOUT_SECONDS", "15").to_i
  BASE_URL        = "https://generativelanguage.googleapis.com/v1beta"

  def self.generate(template:, variables: {}, user: Current.user)
    new(template:, variables:, user:).generate
  end

  def self.generate_with_tools(template:, variables:, tools:, on_tool_call: nil, max_rounds: 6)
    new(template:, variables:, user: Current.user).generate_with_tools_instance(
      tools: tools, on_tool_call: on_tool_call, max_rounds: max_rounds
    )
  end

  def initialize(template:, variables: {}, user:)
    @template_name = template
    @variables     = variables
    @user          = user
  end

  def generate
    ai_template     = AiTemplate.find_by!(name: @template_name)
    rendered_prompt = ai_template.interpolate(@variables)

    begin
      AiGatekeeper.check!(rendered_prompt, @user)
    rescue GatekeeperError => e
      LlmRequest.create!(
        user: @user, ai_template: ai_template, template_name: ai_template.name,
        status: "gatekeeper_blocked", error_message: e.message
      ) if @user
      raise
    end

    if @user
      begin
        AiBudgetChecker.check!(@user)
      rescue BudgetExceededError => e
        LlmRequest.create!(
          user: @user, ai_template: ai_template, template_name: ai_template.name,
          status: "budget_exceeded", error_message: e.message
        )
        raise
      end
    end

    log = LlmRequest.create!(
      user:          @user,
      ai_template:   ai_template,
      template_name: ai_template.name,
      status:        "pending"
    )

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    begin
      response_text, prompt_tokens, response_tokens = call_gemini(ai_template, rendered_prompt)
      duration_ms = elapsed_ms(start_time)

      log.update!(
        status:               "success",
        prompt_token_count:   prompt_tokens,
        response_token_count: response_tokens,
        duration_ms:          duration_ms,
        cost_estimate_cents:  estimate_cost(prompt_tokens, response_tokens, ai_template.model)
      )

      response_text

    rescue Timeout::Error
      log.update!(
        status:        "timeout",
        duration_ms:   elapsed_ms(start_time),
        error_message: "Gemini call timed out after #{TIMEOUT_SECONDS}s"
      )
      raise TimeoutError, "The AI request timed out. Please try again."

    rescue GeminiError
      raise

    rescue => e
      api_body = e.respond_to?(:response) && e.response ? e.response[:body].to_s : ""
      log.update!(
        status:        "error",
        duration_ms:   elapsed_ms(start_time),
        error_message: (api_body.presence || e.message).truncate(500)
      )
      raise GeminiError, "An error occurred while generating a response."
    end
  end

  def generate_with_tools_instance(tools:, on_tool_call:, max_rounds:)
    ai_template     = AiTemplate.find_by!(name: @template_name)
    rendered_prompt = ai_template.interpolate(@variables)
    full_prompt     = [ai_template.system_prompt.presence, rendered_prompt].compact.join("\n\n")

    AiGatekeeper.check!(rendered_prompt, @user)
    AiBudgetChecker.check!(@user) if @user

    llm_request = LlmRequest.create!(
      user: @user, ai_template: ai_template, template_name: @template_name, status: "pending"
    )

    begin
      started_at = Time.current
      contents   = [{ role: "user", parts: [{ text: full_prompt }] }]
      tool_steps = []
      step       = 0

      loop do
        step += 1
        response  = call_gemini_with_tools(ai_template, contents, tools)
        candidate = response.dig("candidates", 0, "content")

        function_call_part = candidate&.dig("parts")&.find { |p| p["functionCall"] }

        if function_call_part && step <= max_rounds
          fn        = function_call_part["functionCall"]
          tool_name = fn["name"]
          tool_args = (fn["args"] || {}).transform_keys(&:to_sym)

          result = dispatch_tool(tool_name, tool_args)

          tool_steps << {
            step: step, tool: tool_name, args: tool_args,
            result_preview: result.to_s.first(200), timestamp: Time.current.iso8601
          }
          on_tool_call&.call(tool_name, tool_args, result)

          contents << { role: "model", parts: [{ functionCall: { name: tool_name, args: fn["args"] } }] }
          contents << { role: "user", parts: [{ functionResponse: { name: tool_name, response: { content: result.to_s } } }] }
        else
          text        = candidate&.dig("parts")&.find { |p| p["text"] }&.dig("text") || ""
          duration_ms = ((Time.current - started_at) * 1000).round
          llm_request.update!(status: "success", duration_ms: duration_ms)
          return { text: text, tool_steps: tool_steps, raw: response.to_json }
        end
      end
    rescue GeminiError => e
      llm_request.update!(status: "error", error_message: e.message)
      raise
    rescue => e
      llm_request.update!(status: "error", error_message: e.message)
      raise GeminiError, e.message
    end
  end

  private

  def call_gemini(ai_template, rendered_prompt)
    full_prompt = [ai_template.system_prompt.presence, rendered_prompt].compact.join("\n\n")

    http = Faraday.new do |conn|
      conn.request  :json
      conn.response :json
      conn.adapter  Faraday.default_adapter
    end

    response = Timeout.timeout(TIMEOUT_SECONDS) do
      http.post("#{BASE_URL}/models/#{ai_template.model}:generateContent") do |req|
        req.params["key"] = ENV.fetch("GEMINI_API_KEY")
        req.body = {
          contents: [{ parts: [{ text: full_prompt }] }],
          generationConfig: {
            maxOutputTokens: ai_template.max_output_tokens,
            temperature:     ai_template.temperature.to_f
          }
        }
      end
    end

    unless response.success?
      raise StandardError, response.body.to_json
    end

    body    = response.body
    text    = (body.dig("candidates", 0, "content", "parts") || [])
                .map { |p| p["text"].to_s }
                .join

    prompt_tokens   = body.dig("usageMetadata", "promptTokenCount")     || estimate_tokens(full_prompt)
    response_tokens = body.dig("usageMetadata", "candidatesTokenCount") || estimate_tokens(text)

    [text, prompt_tokens, response_tokens]
  end

  def estimate_tokens(text)
    (text.to_s.length / 4.0).ceil
  end

  def estimate_cost(prompt_tokens, response_tokens, model)
    input_rate  = 7.5
    output_rate = 30.0
    ((prompt_tokens * input_rate) + (response_tokens * output_rate)) / 1_000_000.0
  end

  def elapsed_ms(start)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
  end

  def call_gemini_with_tools(ai_template, contents, tools)
    api_key = ENV.fetch("GEMINI_API_KEY")
    model   = ai_template.model.presence || "gemini-2.5-flash"
    url     = "#{BASE_URL}/models/#{model}:generateContent?key=#{api_key}"

    body = {
      contents: contents,
      tools: [{ functionDeclarations: tools }],
      generationConfig: {
        maxOutputTokens: ai_template.max_output_tokens || 3000,
        temperature:     ai_template.temperature&.to_f || 0.3
      }
    }

    response = Faraday.post(url) do |req|
      req.headers["Content-Type"] = "application/json"
      req.body                     = body.to_json
      req.options.timeout          = ENV.fetch("AI_GLOBAL_TIMEOUT_SECONDS", "30").to_i
    end

    raise GeminiError, "Gemini API error: #{response.status}" unless response.success?
    JSON.parse(response.body)
  end

  def dispatch_tool(name, args)
    case name
    when "search_web" then SearchWebTool.call(**args)
    when "fetch_url"  then FetchUrlTool.call(**args)
    else "Unknown tool: #{name}"
    end
  end
end
