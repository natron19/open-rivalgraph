require "rails_helper"

RSpec.describe OwnProduct, type: :model do
  subject(:product) { build(:own_product) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:competitors).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:differentiator_1) }
    it { is_expected.to validate_presence_of(:differentiator_2) }
    it { is_expected.to validate_presence_of(:differentiator_3) }

    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_length_of(:differentiator_1).is_at_most(200) }
    it { is_expected.to validate_length_of(:differentiator_2).is_at_most(200) }
    it { is_expected.to validate_length_of(:differentiator_3).is_at_most(200) }
  end

  describe "dependent destroy" do
    it "destroys associated competitors when destroyed" do
      product = create(:own_product)
      create(:competitor, own_product: product, user: product.user)
      expect { product.destroy }.to change(Competitor, :count).by(-1)
    end
  end
end
