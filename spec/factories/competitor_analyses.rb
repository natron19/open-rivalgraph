FactoryBot.define do
  factory :competitor_analysis do
    competitor
    user { competitor.user }
    status { "pending" }

    trait :running do
      status { "running" }
    end

    trait :complete do
      status { "complete" }
      researched_at { Time.current }
      battlecard { '{"competitor_name":"Acme","what_they_offer":"A project management tool.","pricing_tiers":[],"top_customer_complaints":[],"recent_news":"No recent news found.","talking_points":["Point 1","Point 2","Point 3"],"competitor_strength":"They have a larger user base."}' }
      agent_trace { '[{"step":1,"tool":"search_web","args":{"query":"Acme pricing"},"result_preview":"Found pricing page","timestamp":"2026-01-01T00:00:00Z"}]' }
      gemini_raw { battlecard }
    end

    trait :error do
      status { "error" }
      error_message { "Something went wrong during research." }
    end
  end
end
