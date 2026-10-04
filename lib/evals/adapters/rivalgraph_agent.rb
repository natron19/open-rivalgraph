module Evals
  module Adapters
    # Runs the battlecard research agent the same way AgentRunJob does
    # (GeminiService.generate_with_tools with search_web + fetch_url), synchronously
    # and without a CompetitorAnalysis record. Each tool call becomes a trace entry
    # for the A (max_tool_calls) and F (tools_subset_of, called_tool) checks.
    class RivalgraphAgent
      MAX_ROUNDS = 6

      def initialize(template_name)
        @template_name = template_name
      end

      def call(variables:, user:)
        trace  = []
        result = GeminiService.generate_with_tools(
          template:     @template_name,
          variables:    variables.symbolize_keys,
          tools:        [AgentRunJob::SEARCH_WEB_TOOL, AgentRunJob::FETCH_URL_TOOL],
          on_tool_call: ->(tool, args, _result) { trace << { tool: tool, args: args } },
          max_rounds:   MAX_ROUNDS,
          user:         user
        )
        Result.new(output: result[:text], trace: trace)
      end
    end
  end
end
