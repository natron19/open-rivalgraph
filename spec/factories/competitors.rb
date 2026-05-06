FactoryBot.define do
  factory :competitor do
    own_product
    user { own_product.user }
    company_name { "Acme Corp" }
    website { "https://acme.example.com" }
    notes { "Main competitor." }
  end
end
