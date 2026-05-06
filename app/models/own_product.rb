class OwnProduct < ApplicationRecord
  belongs_to :user
  has_many :competitors, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :differentiator_1, presence: true, length: { maximum: 200 }
  validates :differentiator_2, presence: true, length: { maximum: 200 }
  validates :differentiator_3, presence: true, length: { maximum: 200 }
end
