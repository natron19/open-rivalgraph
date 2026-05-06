require "rails_helper"

RSpec.describe GeminiService, ".generate_with_tools" do
  let(:user) { create(:user) }
  let(:template) { create(:ai_template) }
  let(:tools) { [{ name: "search_web" }] }

  let(:text_response) do
    { "candidates" => [{ "content" => { "parts" => [{ "text" => '{"result":"ok"}' }] } }] }
  end

  let(:tool_call_response) do
    {
      "candidates" => [{
        "content" => {
          "parts" => [{ "functionCall" => { "name" => "search_web", "args" => { "query" => "acme pricing" } } }]
        }
      }]
    }
  end

  before do
    Current.user = user
    allow_any_instance_of(GeminiService).to receive(:call_gemini_with_tools).and_return(text_response)
    allow(SearchWebTool).to receive(:call).and_return("search result")
    allow(FetchUrlTool).to receive(:call).and_return("page content")
  end

  subject(:call) do
    GeminiService.generate_with_tools(
      template: template.name,
      variables: {},
      tools: tools
    )
  end

  describe "successful call with no tool steps" do
    it "returns a hash with text, tool_steps, and raw" do
      result = call
      expect(result).to include(:text, :tool_steps, :raw)
      expect(result[:text]).to eq('{"result":"ok"}')
      expect(result[:tool_steps]).to eq([])
    end

    it "sets LlmRequest status to success" do
      expect { call }.to change(LlmRequest, :count).by(1)
      expect(LlmRequest.last.status).to eq("success")
    end
  end

  describe "call with one tool step then final text" do
    before do
      allow_any_instance_of(GeminiService).to receive(:call_gemini_with_tools)
        .and_return(tool_call_response, text_response)
    end

    it "calls on_tool_call once per tool step" do
      callback = double("callback")
      expect(callback).to receive(:call).once.with("search_web", { query: "acme pricing" }, "search result")

      GeminiService.generate_with_tools(
        template: template.name,
        variables: {},
        tools: tools,
        on_tool_call: callback.method(:call)
      )
    end

    it "includes the tool step in tool_steps" do
      result = GeminiService.generate_with_tools(template: template.name, variables: {}, tools: tools)
      expect(result[:tool_steps].length).to eq(1)
      expect(result[:tool_steps].first[:tool]).to eq("search_web")
    end

    it "dispatches to SearchWebTool" do
      expect(SearchWebTool).to receive(:call).with(query: "acme pricing").and_return("result")
      GeminiService.generate_with_tools(template: template.name, variables: {}, tools: tools)
    end
  end

  describe "Gemini API error" do
    before do
      allow_any_instance_of(GeminiService).to receive(:call_gemini_with_tools)
        .and_raise(GeminiService::GeminiError, "API failed")
    end

    it "raises GeminiError" do
      expect { call }.to raise_error(GeminiService::GeminiError)
    end

    it "sets LlmRequest status to error" do
      call rescue nil
      expect(LlmRequest.last.status).to eq("error")
    end
  end
end
