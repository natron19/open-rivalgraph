# RivalGraph Demo — Build Tasks

**App:** RivalGraph Demo (competitive intelligence battlecard generator)  
**Built on:** Open Demo Starter v2.0  
**Full spec:** `docs/open-rivalgraph/rivalgraph-demo-spec.md`  
**Phase specs:** `docs/open-rivalgraph/phase-specs.md`

Complete all tasks and tests in a phase before starting the next.

---

## Phase 1 — Project Customization

- [x] Update `.env.example` with `APP_NAME`, `APP_TAGLINE`, `APP_DESCRIPTION`, `SERPER_API_KEY`
- [x] Add `httparty` gem to `Gemfile` and run `bundle install`
- [x] Set accent color `--accent: #dc2626` and `--accent-hover: #b91c1c` in `application.css`
- [x] Add `#agent-progress-feed` CSS (max-height: 300px, overflow-y: auto)
- [x] Add `.talking-point` CSS (border-left: 3px solid var(--accent), padding-left: 0.75rem)
- [x] Add Products and Battlecards nav links to `layouts/application.html.erb`

### Manual Tests — Phase 1

- [x] `bin/dev` boots without errors
- [x] Navbar shows app name from `ENV.fetch("APP_NAME", ...)`
- [x] Primary buttons display red (#dc2626) accent color
- [x] `.env.example` has all new variables with placeholder values, no real keys

### RSpec Tests — Phase 1

- [x] `bundle exec rspec` — all pre-existing specs pass

---

## Phase 2 — Data Models

- [x] Generate and run migration: `create_own_products` (uuid PK, user_id, name, 3 differentiators, timestamps)
- [x] Create `app/models/own_product.rb` with `belongs_to :user`, `has_many :competitors`, validations
- [x] Generate and run migration: `create_competitors` (uuid PK, own_product_id, user_id, company_name, website, notes, timestamps)
- [x] Create `app/models/competitor.rb` with associations, website format validation, allows blank
- [x] Generate and run migration: `create_competitor_analyses` (uuid PK, competitor_id, user_id, status, battlecard, agent_trace, gemini_raw, error_message, researched_at, timestamps + indexes)
- [x] Create `app/models/competitor_analysis.rb` with associations, STATUSES constant, validations, `complete` and `recent` scopes
- [x] Add `has_many :own_products`, `has_many :competitors`, `has_many :competitor_analyses` to `User` model
- [x] Create `spec/factories/own_products.rb`
- [x] Create `spec/factories/competitors.rb`
- [x] Create `spec/factories/competitor_analyses.rb` (with `:running`, `:complete`, `:error` traits)

### Manual Tests — Phase 2

- [x] `rails db:migrate` runs clean
- [x] Rails console: create valid OwnProduct — succeeds
- [x] Rails console: `OwnProduct.new(name: "").valid?` → false
- [x] Rails console: `Competitor.new(website: "not-a-url").valid?` → false
- [x] Rails console: `Competitor.new(website: "").valid?` → true
- [x] Rails console: `CompetitorAnalysis.new(status: "bogus").valid?` → false
- [x] Rails console: `CompetitorAnalysis.complete` scope works

### RSpec Tests — Phase 2

- [x] `spec/models/own_product_spec.rb` — presence validations for all 4 fields
- [x] `spec/models/own_product_spec.rb` — max length: name 100 chars, differentiators 200 chars each
- [x] `spec/models/own_product_spec.rb` — `belongs_to :user`
- [x] `spec/models/own_product_spec.rb` — `has_many :competitors, dependent: :destroy`
- [x] `spec/models/competitor_spec.rb` — presence of `company_name`
- [x] `spec/models/competitor_spec.rb` — website format validation (http/https required when present)
- [x] `spec/models/competitor_spec.rb` — blank website passes
- [x] `spec/models/competitor_spec.rb` — `belongs_to :own_product` and `belongs_to :user`
- [x] `spec/models/competitor_spec.rb` — `has_many :competitor_analyses, dependent: :destroy`
- [x] `spec/models/competitor_analysis_spec.rb` — presence of `status`
- [x] `spec/models/competitor_analysis_spec.rb` — status inclusion validation
- [x] `spec/models/competitor_analysis_spec.rb` — `belongs_to :competitor` and `belongs_to :user`
- [x] `spec/models/competitor_analysis_spec.rb` — `scope :complete` returns only complete records
- [x] `spec/models/competitor_analysis_spec.rb` — `scope :recent` ordered by `created_at desc`

---

## Phase 3 — OwnProducts CRUD

- [x] Add `resources :own_products` to `config/routes.rb`
- [x] Create `app/controllers/own_products_controller.rb` (index, new, create, show, edit, update, destroy)
- [x] Create `app/views/own_products/index.html.erb` (card grid, empty state)
- [x] Create `app/views/own_products/_form.html.erb` (name + 3 differentiator fields, inline errors)
- [x] Create `app/views/own_products/new.html.erb`
- [x] Create `app/views/own_products/edit.html.erb`
- [x] Create `app/views/own_products/show.html.erb` (product info header + competitors table)

### Manual Tests — Phase 3

- [ ] Navigate to `/own_products` — empty state renders
- [ ] Create product with all fields — redirects to show
- [ ] Create product with missing name — re-renders form with error
- [ ] Edit product — updates and redirects to show
- [ ] Delete product — redirects to index
- [ ] Navbar "Products" link works
- [ ] Another user's product URL returns 404

### RSpec Tests — Phase 3

- [x] `spec/requests/own_products_spec.rb` — GET index: user sees only their products
- [x] `spec/requests/own_products_spec.rb` — POST create: valid params → redirect to show
- [x] `spec/requests/own_products_spec.rb` — POST create: missing name → re-renders new (422)
- [x] `spec/requests/own_products_spec.rb` — DELETE: destroys product; another user's product → 404
- [x] `spec/requests/own_products_spec.rb` — unauthenticated request → redirects to sign in

---

## Phase 4 — Competitors CRUD

- [x] Add nested competitors routes under `own_products` to `config/routes.rb`
- [x] Create `app/controllers/competitors_controller.rb` (new, create, show, edit, update, destroy)
- [x] Create `app/views/competitors/_form.html.erb` (company_name, website, notes)
- [x] Create `app/views/competitors/new.html.erb` (with breadcrumb)
- [x] Create `app/views/competitors/edit.html.erb` (with breadcrumb)
- [x] Create `app/views/competitors/show.html.erb` (header, "Research Now" form, analyses list)

### Manual Tests — Phase 4

- [ ] Add competitor to product — redirects to competitor show
- [ ] Invalid website (no https://) shows validation error
- [ ] Blank website — no error
- [ ] Edit competitor — updates
- [ ] Delete competitor from product show — redirects to product show
- [ ] Another user's `own_product_id` in URL → 404

### RSpec Tests — Phase 4

- [x] `spec/requests/competitors_spec.rb` — GET new: loads form for current user's product
- [x] `spec/requests/competitors_spec.rb` — GET new: another user's product → 404
- [x] `spec/requests/competitors_spec.rb` — POST create: competitor gets `user_id: current_user.id`
- [x] `spec/requests/competitors_spec.rb` — POST create: missing company_name → re-renders (422)
- [x] `spec/requests/competitors_spec.rb` — DELETE: another user cannot delete → 404
- [x] `spec/requests/competitors_spec.rb` — unauthenticated → redirect to sign in

---

## Phase 5 — GeminiService Agent Extension

- [x] Create `app/services/search_web_tool.rb` (Serper.dev POST, returns top 5 result strings, rescues errors)
- [x] Create `app/services/fetch_url_tool.rb` (HTTParty GET, strips HTML, returns first 3000 chars, rescues errors)
- [x] Add `GeminiService.generate_with_tools` class method to `gemini_service.rb`
- [x] Add `generate_with_tools_instance` method: gatekeeper → budget → LlmRequest → agent loop → return
- [x] Add `call_gemini_with_tools` private method (Faraday POST with tool definitions)
- [x] Add `dispatch_tool` private method (routes to SearchWebTool or FetchUrlTool)
- [x] Update `.env.example`: set `AI_GLOBAL_TIMEOUT_SECONDS=90` (agent loop needs more time than 15s default)

### Manual Tests — Phase 5

- [x] Rails console: `SearchWebTool.call(query: "rails pricing")` returns result string
- [x] Rails console: `FetchUrlTool.call(url: "https://example.com")` returns stripped text
- [x] Rails console: `FetchUrlTool.call(url: "https://definitely-404.invalid")` returns error string, does not raise
- [x] Rails console: `FetchUrlTool.call(url: "https://heavy-js-site.example.com")` returns text or graceful error

### RSpec Tests — Phase 5

- [x] `spec/services/gemini_service_generate_with_tools_spec.rb` — success: returns `{text:, tool_steps:, raw:}` with LlmRequest status "success"
- [x] `spec/services/gemini_service_generate_with_tools_spec.rb` — GeminiError: raises and sets LlmRequest status "error"
- [x] `spec/services/gemini_service_generate_with_tools_spec.rb` — calls `on_tool_call` once per tool step
- [x] `spec/services/gemini_service_generate_with_tools_spec.rb` — dispatches to correct tool class

---

## Phase 6 — Background Job + Analyses Controller

- [x] Add nested analyses routes under competitors + standalone `competitor_analyses` resources to `config/routes.rb`
- [x] Confirm Solid Queue is active: `config.active_job.queue_adapter = :solid_queue` in `development.rb`
- [x] Enable ActionCable and create `config/cable.yml`
- [x] Create `app/jobs/agent_run_job.rb` with SEARCH_WEB_TOOL and FETCH_URL_TOOL constants, `perform` method, broadcast helpers
- [x] Create `app/controllers/competitor_analyses_controller.rb` (index, create, show, destroy)

### Manual Tests — Phase 6

- [ ] POST to create analysis — redirects to show with "Research started" notice
- [ ] Show page for pending analysis renders spinner
- [ ] Rails console: `AgentRunJob.perform_now(analysis.id)` with real API keys — analysis reaches "complete"
- [ ] Unauthenticated request → redirects to sign in
- [ ] Another user's analysis → 404

### RSpec Tests — Phase 6

- [x] `spec/requests/competitor_analyses_spec.rb` — POST create: creates analysis (pending) and enqueues AgentRunJob
- [x] `spec/requests/competitor_analyses_spec.rb` — POST create: competitor from another user → 404
- [x] `spec/requests/competitor_analyses_spec.rb` — GET show: pending analysis → in-progress view
- [x] `spec/requests/competitor_analyses_spec.rb` — GET show: complete analysis → battlecard content
- [x] `spec/requests/competitor_analyses_spec.rb` — GET index: only current user's complete analyses
- [x] `spec/jobs/agent_run_job_spec.rb` — success: status "complete", researched_at set, battlecard stored, agent_trace stored
- [x] `spec/jobs/agent_run_job_spec.rb` — GeminiService::GeminiError: status "error", error_message set
- [x] `spec/jobs/agent_run_job_spec.rb` — broadcast_append_to called once per tool step
- [x] `spec/jobs/agent_run_job_spec.rb` — max rounds respected: stub 7 tool call responses, verify only 6 dispatches

---

## Phase 7 — Analysis Views + Turbo Streams Progress

- [x] Create `app/views/competitor_analyses/show.html.erb` (3 render states: pending/running, complete, error)
- [x] Create `app/views/competitor_analyses/_progress_step.html.erb` (list-group-item with tool icon and args)
- [x] Create `app/views/competitor_analyses/_battlecard.html.erb` (all 6 sections + research trace accordion + raw response collapse)
- [x] Create `app/views/competitor_analyses/_error_state.html.erb` (danger alert + "Try Again" form)
- [x] Create `app/views/competitor_analyses/index.html.erb` (table of complete battlecards)
- [x] Verify Solid Cable / ActionCable is configured for Turbo Streams (`config/cable.yml`)

### Manual Tests — Phase 7

- [ ] Pending show page: spinner renders, `turbo_stream_from @analysis` tag present
- [ ] Complete show page: all six battlecard sections visible
- [ ] Research trace accordion expands showing steps
- [ ] "Show raw response" collapse reveals raw JSON
- [ ] "Refresh Battlecard" button posts new analysis
- [ ] Error state: danger alert + "Try Again" button visible
- [ ] Index page lists complete battlecards with competitor name, product name, researched time
- [ ] **End-to-end Turbo test:** Start analysis → watch steps appear live → battlecard replaces spinner automatically

### RSpec Tests — Phase 7

- [x] GET show complete analysis — response body includes "What They Offer" (or equivalent heading)
- [x] GET show error analysis — response body includes "Try Again"

---

## Phase 8 — Home Page, Dashboard, and Seeds

- [x] Update `db/seeds.rb`: add `rivalgraph_battlecard_v1` template (full system prompt + user prompt)
- [x] Update `db/seeds.rb`: add OwnProduct seed (Basecamp with 3 differentiators) for demo user
- [x] Update `db/seeds.rb`: add Competitor seed (Asana) for the Basecamp product
- [x] Update `db/seeds.rb`: add CompetitorAnalysis seed (pre-populated complete battlecard for Asana)
- [x] Replace `app/views/home/index.html.erb` with two-column pitch + mock battlecard
- [x] Replace `app/views/dashboard/show.html.erb` with 3 stat cards + recent battlecards list + CTA

### Manual Tests — Phase 8

- [ ] `rails db:seed` completes without errors
- [ ] `rails db:seed` run a second time — no duplicate records created
- [ ] Sign in as `demo@example.com` / `password123` — dashboard shows 1 product, 1 competitor, 1 battlecard
- [ ] Dashboard "Recent Battlecards" links to seeded Asana analysis
- [ ] Seeded analysis show page renders full Asana battlecard
- [ ] Home page (unauthenticated): two-column layout with mock battlecard visible
- [ ] Admin → AI Templates: `rivalgraph_battlecard_v1` is present with correct model and temperature

### RSpec Tests — Phase 8

- [ ] Seeds are idempotent (run `rails db:seed` twice in test; record counts unchanged)

---

## Phase 9 — README

- [x] Update `README.md` with RivalGraph app name, tagline, description
- [x] Add "Why I Built This" section
- [x] Add Perplexity API setup instructions (`PERPLEXITY_API_KEY`)
- [x] Add demo credentials section (`demo@example.com` / `password123`)
- [x] Add template editing note (admin panel URL)
- [x] Add MIT license mention

### Manual Tests — Phase 9

- [ ] README renders correctly (headings, code blocks, links)
- [ ] Setup instructions: `git clone` + `bin/setup` + `.env` configuration works on a clean machine

---

## Phase 10 — Full Test Suite + End-to-End Validation

### RSpec Full Suite

- [ ] `bundle exec rspec --format documentation` — zero failures
- [ ] Zero real API calls in test output (check for Gemini/Serper.dev network requests)

### End-to-End Manual Flow

- [ ] Unauthenticated home page renders correctly
- [ ] Sign up with new email — redirects to dashboard with empty state
- [ ] Create OwnProduct with real differentiators
- [ ] Add a real competitor (e.g., Notion, Linear, Asana) with website
- [ ] Click "Research This Competitor Now"
- [ ] Watch progress feed populate in real time (Solid Queue worker must be running)
- [ ] Battlecard appears with all six sections after ~60–90 seconds
- [ ] Research trace accordion shows step-by-step tool calls
- [ ] "Show raw response" toggle reveals raw Gemini JSON
- [ ] Click "Refresh Battlecard" — new analysis starts, old one preserved in history
- [ ] Dashboard stats updated correctly
- [ ] `/competitor_analyses` index lists the completed battlecard
- [ ] Admin → LlmRequests shows the analysis logged
- [ ] Sign out → redirects to home

### Edge Case Manual Tests

- [ ] Competitor with JS-rendered site — battlecard shows "Could not retrieve current data" gracefully, no crash
- [ ] Start analysis; immediately view show page — spinner renders without error
- [ ] Delete a battlecard from show page — redirects to competitor show
- [ ] Delete OwnProduct with multiple competitors and analyses — all cascade-deleted cleanly

---

## Progress Summary

| Phase | Status | Notes |
|---|---|---|
| 1 — Customization | ✅ Complete | |
| 2 — Data Models | ✅ Complete | |
| 3 — OwnProducts CRUD | ✅ Complete | |
| 4 — Competitors CRUD | ✅ Complete | |
| 5 — GeminiService Extension | ✅ Complete | |
| 6 — Background Job + Controller | ✅ Complete | |
| 7 — Analysis Views | ✅ Complete | |
| 8 — Home, Dashboard, Seeds | ✅ Complete | |
| 9 — README | ✅ Complete | |
| 10 — Full Validation | ⬜ Not started | |

**Legend:** ⬜ Not started · 🔄 In progress · ✅ Complete
