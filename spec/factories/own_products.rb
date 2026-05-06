FactoryBot.define do
  factory :own_product do
    user
    name { "My Product" }
    differentiator_1 { "Flat per-company pricing with no per-seat fees" }
    differentiator_2 { "All-in-one: tasks, docs, and chat in a single product" }
    differentiator_3 { "Opinionated and calm - no anxiety-inducing notifications" }
  end
end
