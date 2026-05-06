class CompetitorAnalysis < ApplicationRecord
  belongs_to :competitor
  belongs_to :user

  STATUSES = %w[pending running complete error].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :competitor_id, presence: true
  validates :user_id, presence: true

  scope :complete, -> { where(status: "complete") }
  scope :recent, -> { order(created_at: :desc) }
end
