require "rails_helper"

RSpec.describe "CompetitorAnalyses", type: :request do
  let(:user)        { create(:user) }
  let(:other_user)  { create(:user) }
  let(:product)     { create(:own_product, user: user) }
  let(:competitor)  { create(:competitor, own_product: product, user: user) }

  describe "POST /own_products/:own_product_id/competitors/:competitor_id/analyses" do
    it "redirects unauthenticated user to sign in" do
      post own_product_competitor_analyses_path(product, competitor)
      expect(response).to redirect_to(sign_in_path)
    end

    it "creates a pending analysis and enqueues AgentRunJob" do
      sign_in_as(user)
      expect(AgentRunJob).to receive(:perform_later).once
      expect {
        post own_product_competitor_analyses_path(product, competitor)
      }.to change(CompetitorAnalysis, :count).by(1)
      expect(CompetitorAnalysis.last.status).to eq("pending")
      expect(response).to redirect_to(competitor_analysis_path(CompetitorAnalysis.last))
    end

    it "returns 404 when competitor belongs to another user" do
      sign_in_as(user)
      other_product    = create(:own_product, user: other_user)
      other_competitor = create(:competitor, own_product: other_product, user: other_user)
      post own_product_competitor_analyses_path(other_product, other_competitor)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /competitor_analyses/:id" do
    it "redirects unauthenticated user to sign in" do
      analysis = create(:competitor_analysis, competitor: competitor, user: user)
      get competitor_analysis_path(analysis)
      expect(response).to redirect_to(sign_in_path)
    end

    it "renders 200 for a pending analysis" do
      sign_in_as(user)
      analysis = create(:competitor_analysis, competitor: competitor, user: user)
      get competitor_analysis_path(analysis)
      expect(response).to have_http_status(:ok)
    end

    it "renders 200 for a complete analysis" do
      sign_in_as(user)
      analysis = create(:competitor_analysis, :complete, competitor: competitor, user: user)
      get competitor_analysis_path(analysis)
      expect(response).to have_http_status(:ok)
    end

    it "includes battlecard content for a complete analysis" do
      sign_in_as(user)
      analysis = create(:competitor_analysis, :complete, competitor: competitor, user: user)
      get competitor_analysis_path(analysis)
      expect(response.body).to include("What They Offer")
    end

    it "includes Try Again for an error analysis" do
      sign_in_as(user)
      analysis = create(:competitor_analysis, :error, competitor: competitor, user: user)
      get competitor_analysis_path(analysis)
      expect(response.body).to include("Try Again")
    end

    it "returns 404 for another user's analysis" do
      sign_in_as(user)
      other_product    = create(:own_product, user: other_user)
      other_competitor = create(:competitor, own_product: other_product, user: other_user)
      other_analysis   = create(:competitor_analysis, competitor: other_competitor, user: other_user)
      get competitor_analysis_path(other_analysis)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /competitor_analyses" do
    it "redirects unauthenticated user to sign in" do
      get competitor_analyses_path
      expect(response).to redirect_to(sign_in_path)
    end

    it "returns only the current user's complete analyses" do
      sign_in_as(user)
      my_competitor    = create(:competitor, own_product: product, user: user, company_name: "My Rival")
      _pending         = create(:competitor_analysis, competitor: competitor, user: user)
      _complete        = create(:competitor_analysis, :complete, competitor: my_competitor, user: user)
      other_product    = create(:own_product, user: other_user)
      other_competitor = create(:competitor, own_product: other_product, user: other_user, company_name: "Their Rival")
      _other           = create(:competitor_analysis, :complete, competitor: other_competitor, user: other_user)
      get competitor_analyses_path
      expect(response.body).to include(my_competitor.company_name)
      expect(response.body).not_to include(other_competitor.company_name)
    end
  end
end
