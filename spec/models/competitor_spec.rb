require "rails_helper"

RSpec.describe Competitor, type: :model do
  subject(:competitor) { build(:competitor) }

  describe "associations" do
    it { is_expected.to belong_to(:own_product) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:competitor_analyses).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:company_name) }

    it "is valid with a blank website" do
      competitor.website = ""
      expect(competitor).to be_valid
    end

    it "is valid with an https website" do
      competitor.website = "https://example.com"
      expect(competitor).to be_valid
    end

    it "is valid with an http website" do
      competitor.website = "http://example.com"
      expect(competitor).to be_valid
    end

    it "is invalid when website does not start with http:// or https://" do
      competitor.website = "not-a-url"
      expect(competitor).not_to be_valid
      expect(competitor.errors[:website]).to include("must start with http:// or https://")
    end
  end
end
