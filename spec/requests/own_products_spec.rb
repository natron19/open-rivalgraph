require "rails_helper"

RSpec.describe "OwnProducts", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /own_products" do
    it "redirects unauthenticated user to sign in" do
      get own_products_path
      expect(response).to redirect_to(sign_in_path)
    end

    it "returns only the current user's products" do
      sign_in_as(user)
      own = create(:own_product, user: user, name: "My App")
      other = create(:own_product, user: other_user, name: "Their App")
      get own_products_path
      expect(response.body).to include(own.name)
      expect(response.body).not_to include(other.name)
    end
  end

  describe "POST /own_products" do
    let(:valid_params) do
      { own_product: { name: "My App", differentiator_1: "D1", differentiator_2: "D2", differentiator_3: "D3" } }
    end

    it "redirects unauthenticated user to sign in" do
      post own_products_path, params: valid_params
      expect(response).to redirect_to(sign_in_path)
    end

    it "creates product and redirects to show on valid params" do
      sign_in_as(user)
      expect {
        post own_products_path, params: valid_params
      }.to change(OwnProduct, :count).by(1)
      expect(response).to redirect_to(own_product_path(OwnProduct.last))
    end

    it "re-renders new with 422 on missing name" do
      sign_in_as(user)
      post own_products_path, params: { own_product: { name: "", differentiator_1: "D1", differentiator_2: "D2", differentiator_3: "D3" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /own_products/:id" do
    it "redirects unauthenticated user to sign in" do
      product = create(:own_product, user: user)
      delete own_product_path(product)
      expect(response).to redirect_to(sign_in_path)
    end

    it "destroys the product" do
      sign_in_as(user)
      product = create(:own_product, user: user)
      expect {
        delete own_product_path(product)
      }.to change(OwnProduct, :count).by(-1)
      expect(response).to redirect_to(own_products_path)
    end

    it "returns 404 for another user's product" do
      sign_in_as(user)
      other_product = create(:own_product, user: other_user)
      delete own_product_path(other_product)
      expect(response).to have_http_status(:not_found)
    end
  end
end
