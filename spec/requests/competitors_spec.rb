require "rails_helper"

RSpec.describe "Competitors", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:product) { create(:own_product, user: user) }
  let(:other_product) { create(:own_product, user: other_user) }

  describe "GET /own_products/:id/competitors/new" do
    it "redirects unauthenticated user to sign in" do
      get new_own_product_competitor_path(product)
      expect(response).to redirect_to(sign_in_path)
    end

    it "loads the form for the current user's product" do
      sign_in_as(user)
      get new_own_product_competitor_path(product)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for another user's product" do
      sign_in_as(user)
      get new_own_product_competitor_path(other_product)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /own_products/:id/competitors" do
    let(:valid_params) { { competitor: { company_name: "Acme", website: "https://acme.com", notes: "" } } }

    it "redirects unauthenticated user to sign in" do
      post own_product_competitors_path(product), params: valid_params
      expect(response).to redirect_to(sign_in_path)
    end

    it "creates competitor with current user's id" do
      sign_in_as(user)
      expect {
        post own_product_competitors_path(product), params: valid_params
      }.to change(Competitor, :count).by(1)
      expect(Competitor.last.user).to eq(user)
      expect(response).to redirect_to(own_product_competitor_path(product, Competitor.last))
    end

    it "re-renders new on missing company_name" do
      sign_in_as(user)
      post own_product_competitors_path(product), params: { competitor: { company_name: "", website: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /own_products/:id/competitors/:id" do
    it "redirects unauthenticated user to sign in" do
      competitor = create(:competitor, own_product: product, user: user)
      delete own_product_competitor_path(product, competitor)
      expect(response).to redirect_to(sign_in_path)
    end

    it "returns 404 when another user tries to delete" do
      sign_in_as(user)
      other_competitor = create(:competitor, own_product: other_product, user: other_user)
      delete own_product_competitor_path(other_product, other_competitor)
      expect(response).to have_http_status(:not_found)
    end
  end
end
