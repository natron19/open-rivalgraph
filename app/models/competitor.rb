class Competitor < ApplicationRecord
  belongs_to :own_product
  belongs_to :user
  has_many :competitor_analyses, dependent: :destroy

  validates :company_name, presence: true, length: { maximum: 100 }
  validates :website, format: { with: /\Ahttps?:\/\//i, message: "must start with http:// or https://" },
            allow_blank: true
end
