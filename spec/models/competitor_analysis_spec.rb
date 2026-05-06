require "rails_helper"

RSpec.describe CompetitorAnalysis, type: :model do
  subject(:analysis) { build(:competitor_analysis) }

  describe "associations" do
    it { is_expected.to belong_to(:competitor) }
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:status) }

    it "is valid with a known status" do
      competitor = create(:competitor)
      CompetitorAnalysis::STATUSES.each do |s|
        a = build(:competitor_analysis, status: s, competitor: competitor, user: competitor.user)
        expect(a).to be_valid
      end
    end

    it "is invalid with an unknown status" do
      analysis.status = "bogus"
      expect(analysis).not_to be_valid
      expect(analysis.errors[:status]).to be_present
    end
  end

  describe "scopes" do
    it ".complete returns only complete analyses" do
      complete = create(:competitor_analysis, :complete)
      _pending = create(:competitor_analysis)
      expect(CompetitorAnalysis.complete).to contain_exactly(complete)
    end

    it ".recent orders by created_at desc" do
      older = create(:competitor_analysis, :complete, created_at: 2.days.ago)
      newer = create(:competitor_analysis, :complete, created_at: 1.day.ago)
      expect(CompetitorAnalysis.recent.first).to eq(newer)
      expect(CompetitorAnalysis.recent.last).to eq(older)
    end
  end
end
