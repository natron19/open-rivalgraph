require "rails_helper"

RSpec.describe AgentRunJob, type: :job do
  let(:user)       { create(:user) }
  let(:product)    { create(:own_product, user: user) }
  let(:competitor) { create(:competitor, own_product: product, user: user) }
  let(:analysis)   { create(:competitor_analysis, competitor: competitor, user: user) }

  let(:success_result) do
    {
      text: '{"competitor_name":"Acme","what_they_offer":"A tool.","pricing_tiers":[],"top_customer_complaints":[],"recent_news":"None.","talking_points":["P1"],"competitor_strength":"Big user base."}',
      tool_steps: [
        { step: 1, tool: "search_web", args: { query: "Acme pricing" }, result_preview: "Found it", timestamp: Time.current.iso8601 }
      ],
      raw: "{}"
    }
  end

  before do
    allow(GeminiService).to receive(:generate_with_tools) do |**kwargs|
      kwargs[:on_tool_call]&.call("search_web", { query: "Acme pricing" }, "Found it")
      success_result
    end
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
  end

  describe "on success" do
    it "sets status to complete and stores battlecard and agent_trace" do
      described_class.perform_now(analysis.id)
      analysis.reload
      expect(analysis.status).to eq("complete")
      expect(analysis.researched_at).to be_present
      expect(analysis.battlecard).to be_present
      expect(analysis.agent_trace).to be_present
    end

    it "calls broadcast_append_to once per tool step" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).once
      described_class.perform_now(analysis.id)
    end
  end

  describe "on GeminiService::GeminiError" do
    before do
      allow(GeminiService).to receive(:generate_with_tools)
        .and_raise(GeminiService::GeminiError, "API failed")
    end

    it "sets status to error and stores error_message" do
      described_class.perform_now(analysis.id)
      analysis.reload
      expect(analysis.status).to eq("error")
      expect(analysis.error_message).to eq("API failed")
    end
  end

  describe "max_rounds enforcement" do
    it "dispatches at most 6 tool calls even if Gemini keeps returning function calls" do
      tool_call_response = {
        text: "",
        tool_steps: Array.new(7) { |i|
          { step: i + 1, tool: "search_web", args: { query: "q" }, result_preview: "r", timestamp: Time.current.iso8601 }
        },
        raw: "{}"
      }
      final_response = {
        text: '{"competitor_name":"Acme","what_they_offer":"A tool.","pricing_tiers":[],"top_customer_complaints":[],"recent_news":"None.","talking_points":["P1"],"competitor_strength":"Big."}',
        tool_steps: [],
        raw: "{}"
      }

      call_count = 0
      allow(GeminiService).to receive(:generate_with_tools) do |**kwargs|
        on_tool_call = kwargs[:on_tool_call]
        kwargs[:max_rounds].times { on_tool_call&.call("search_web", { query: "q" }, "result") if on_tool_call }
        call_count += 1
        final_response
      end

      described_class.perform_now(analysis.id)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).at_most(6).times
    end
  end
end
