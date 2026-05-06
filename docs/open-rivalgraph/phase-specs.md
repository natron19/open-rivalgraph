# RivalGraph Demo — Phased Build Specifications

**Version:** 1.0  
**Built on:** Open Demo Starter v2.0  
**Source spec:** `docs/open-rivalgraph/rivalgraph-demo-spec.md`

---

## Overview

Ten sequential build phases. Each phase ends with a manual test checklist and an RSpec test list. Complete all tests before starting the next phase.

The biggest engineering novelty is **Phase 5** (GeminiService agent loop) and **Phase 6** (background job + Turbo Streams live progress). Everything else is standard Rails CRUD.

---

## Phase 1 — Project Customization

**Goal:** Apply all boilerplate-level configuration: app identity, accent color, gems, env vars, navbar.

### 1.1 Environment Variables

Update `.env.example` (and your local `.env`) with:

```bash
APP_NAME="RivalGraph Demo"
APP_TAGLINE="Type a competitor's name. The agent researches them. You get a battlecard."
APP_DESCRIPTION="RivalGraph Demo is a competitive intelligence tool powered by a Gemini agent. Enter a competitor's name and your product's top differentiators. The agent searches the live web for their pricing page, reads G2 and Capterra reviews, scans for recent news, and synthesizes a structured battlecard grounded in what it actually found rather than what an LLM guesses from training data."
SERPER_API_KEY=your_key_here
GEMINI_API_KEY=your_key_here
```

### 1.2 Gem

Add to `Gemfile`:

```ruby
gem "httparty"
```

Run `bundle install`.

### 1.3 Accent Color

Update `app/assets/stylesheets/application.css`:

```css
:root {
  --accent: #dc2626;
  --accent-hover: #b91c1c;
}
```

Add below the root block:

```css
/* Agent progress feed height cap */
#agent-progress-feed {
  max-height: 300px;
  overflow-y: auto;
}

/* Battlecard "Why You Win" talking points */
.talking-point {
  border-left: 3px solid var(--accent);
  padding-left: 0.75rem;
}
```

### 1.4 Navbar Links

Add to `app/views/layouts/application.html.erb` navbar section:

```erb
<%= link_to "Products", own_products_path, class: "nav-link" %>
<%= link_to "Battlecards", competitor_analyses_path, class: "nav-link" %>
```

These routes don't exist yet — they will produce an error until Phase 3/Phase 6. That is expected.

### Manual Tests — Phase 1

- [ ] `bin/dev` boots without errors
- [ ] Navbar shows the correct app name from `ENV.fetch("APP_NAME", "Open Demo Starter")`
- [ ] Accent color (#dc2626 red) appears on primary buttons
- [ ] `.env.example` has all four new variables with placeholder values and no real keys

### RSpec Tests — Phase 1

No new specs. Confirm existing suite still passes:

- [ ] `bundle exec rspec` — all pre-existing specs green

---

## Phase 2 — Data Models

**Goal:** Three new database tables with models, validations, associations, and scopes. Factories for all three.

### 2.1 OwnProduct Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_own_products.rb
create_table :own_products, id: :uuid do |t|
  t.references :user, null: false, foreign_key: true, type: :uuid
  t.string :name, null: false
  t.string :differentiator_1, null: false
  t.string :differentiator_2, null: false
  t.string :differentiator_3, null: false
  t.timestamps null: false
end
```

### 2.2 OwnProduct Model

```ruby
# app/models/own_product.rb
class OwnProduct < ApplicationRecord
  belongs_to :user
  has_many :competitors, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :differentiator_1, presence: true, length: { maximum: 200 }
  validates :differentiator_2, presence: true, length: { maximum: 200 }
  validates :differentiator_3, presence: true, length: { maximum: 200 }
end
```

### 2.3 Competitor Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_competitors.rb
create_table :competitors, id: :uuid do |t|
  t.references :own_product, null: false, foreign_key: true, type: :uuid
  t.references :user, null: false, foreign_key: true, type: :uuid
  t.string :company_name, null: false
  t.string :website
  t.text :notes
  t.timestamps null: false
end
```

### 2.4 Competitor Model

```ruby
# app/models/competitor.rb
class Competitor < ApplicationRecord
  belongs_to :own_product
  belongs_to :user
  has_many :competitor_analyses, dependent: :destroy

  validates :company_name, presence: true, length: { maximum: 100 }
  validates :website, format: { with: /\Ahttps?:\/\//i, message: "must start with http:// or https://" },
            allow_blank: true
end
```

### 2.5 CompetitorAnalysis Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_competitor_analyses.rb
create_table :competitor_analyses, id: :uuid do |t|
  t.references :competitor, null: false, foreign_key: true, type: :uuid
  t.references :user, null: false, foreign_key: true, type: :uuid
  t.string :status, null: false, default: "pending"
  t.text :battlecard
  t.text :agent_trace
  t.text :gemini_raw
  t.text :error_message
  t.datetime :researched_at
  t.timestamps null: false
end

add_index :competitor_analyses, :status
add_index :competitor_analyses, :created_at
```

### 2.6 CompetitorAnalysis Model

```ruby
# app/models/competitor_analysis.rb
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
```

### 2.7 Factories

**`spec/factories/own_products.rb`**

```ruby
FactoryBot.define do
  factory :own_product do
    user
    name { "My Product" }
    differentiator_1 { "Flat per-company pricing with no per-seat fees" }
    differentiator_2 { "All-in-one: tasks, docs, and chat in a single product" }
    differentiator_3 { "Opinionated and calm - no anxiety-inducing notifications" }
  end
end
```

**`spec/factories/competitors.rb`**

```ruby
FactoryBot.define do
  factory :competitor do
    own_product
    user { own_product.user }
    company_name { "Acme Corp" }
    website { "https://acme.example.com" }
    notes { "Main competitor." }
  end
end
```

**`spec/factories/competitor_analyses.rb`**

```ruby
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
```

### Manual Tests — Phase 2

- [ ] `rails db:migrate` runs without errors
- [ ] `rails console`: `OwnProduct.create!(user: User.first, name: "Test", differentiator_1: "D1", differentiator_2: "D2", differentiator_3: "D3")` succeeds
- [ ] `OwnProduct.new(name: "").valid?` returns false
- [ ] `Competitor.new(website: "not-a-url").valid?` returns false
- [ ] `CompetitorAnalysis.new(status: "bogus").valid?` returns false
- [ ] `CompetitorAnalysis.complete` scope returns only complete records

### RSpec Tests — Phase 2

Write `spec/models/own_product_spec.rb`:

- [ ] Validates presence of `name`, `differentiator_1`, `differentiator_2`, `differentiator_3`
- [ ] Validates max length of `name` (100 chars) and each differentiator (200 chars)
- [ ] `belongs_to :user`
- [ ] `has_many :competitors, dependent: :destroy` — destroying an OwnProduct destroys its competitors

Write `spec/models/competitor_spec.rb`:

- [ ] Validates presence of `company_name`
- [ ] Validates format of `website` when present (must start with http:// or https://)
- [ ] Allows blank `website` without error
- [ ] `belongs_to :own_product` and `belongs_to :user`
- [ ] `has_many :competitor_analyses, dependent: :destroy`

Write `spec/models/competitor_analysis_spec.rb`:

- [ ] Validates presence of `status`
- [ ] Validates `status` is included in STATUSES
- [ ] `belongs_to :competitor` and `belongs_to :user`
- [ ] `scope :complete` returns only `status: "complete"` records
- [ ] `scope :recent` returns records ordered by `created_at desc`

---

## Phase 3 — OwnProducts CRUD

**Goal:** Full CRUD for OwnProduct — routes, controller, five views, navbar link.

### 3.1 Routes

Add to `config/routes.rb`:

```ruby
resources :own_products
```

The Battlecards route (`/competitor_analyses`) will be added in Phase 6.

### 3.2 OwnProductsController

```ruby
# app/controllers/own_products_controller.rb
class OwnProductsController < ApplicationController
  before_action :set_own_product, only: [:show, :edit, :update, :destroy]

  def index
    @own_products = current_user.own_products.order(created_at: :desc)
  end

  def new
    @own_product = OwnProduct.new
  end

  def create
    @own_product = current_user.own_products.build(own_product_params)
    if @own_product.save
      redirect_to @own_product, notice: "Product created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @competitors = @own_product.competitors.order(created_at: :desc)
  end

  def edit; end

  def update
    if @own_product.update(own_product_params)
      redirect_to @own_product, notice: "Product updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @own_product.destroy
    redirect_to own_products_path, notice: "Product deleted."
  end

  private

  def set_own_product
    @own_product = current_user.own_products.find(params[:id])
  end

  def own_product_params
    params.require(:own_product).permit(:name, :differentiator_1, :differentiator_2, :differentiator_3)
  end
end
```

### 3.3 Views

**`app/views/own_products/index.html.erb`**

Bootstrap card grid of products. Each card: product name, competitor count, "View" button. Empty state: "Add your first product" CTA.

```erb
<div class="container py-4">
  <div class="row mb-3">
    <div class="col">
      <h1>Your Products</h1>
    </div>
    <div class="col-auto">
      <%= link_to "Add Product", new_own_product_path, class: "btn btn-primary" %>
    </div>
  </div>

  <% if @own_products.any? %>
    <div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
      <% @own_products.each do |product| %>
        <div class="col">
          <div class="card h-100">
            <div class="card-body">
              <h5 class="card-title"><%= product.name %></h5>
              <p class="card-text text-muted small"><%= pluralize(product.competitors.count, "competitor") %> tracked</p>
            </div>
            <div class="card-footer">
              <%= link_to "View", product, class: "btn btn-sm btn-outline-secondary" %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
  <% else %>
    <div class="text-center py-5">
      <p class="text-muted">No products yet.</p>
      <%= link_to "Add Your Product", new_own_product_path, class: "btn btn-primary" %>
    </div>
  <% end %>
</div>
```

**`app/views/own_products/_form.html.erb`**

```erb
<%= form_with model: own_product, class: "mt-3" do |f| %>
  <% if own_product.errors.any? %>
    <div class="alert alert-danger">
      <ul class="mb-0">
        <% own_product.errors.full_messages.each do |msg| %>
          <li><%= msg %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="mb-3">
    <%= f.label :name, class: "form-label" %>
    <%= f.text_field :name, class: "form-control #{"is-invalid" if own_product.errors[:name].any?}" %>
    <% own_product.errors[:name].each do |err| %>
      <div class="invalid-feedback"><%= err %></div>
    <% end %>
  </div>

  <div class="mb-3">
    <label class="form-label">Top 3 Differentiators</label>
    <p class="text-muted small">What makes your product distinctly better for your customers?</p>

    <%= f.text_field :differentiator_1, class: "form-control mb-2 #{"is-invalid" if own_product.errors[:differentiator_1].any?}",
        placeholder: "Differentiator 1" %>
    <%= f.text_field :differentiator_2, class: "form-control mb-2 #{"is-invalid" if own_product.errors[:differentiator_2].any?}",
        placeholder: "Differentiator 2" %>
    <%= f.text_field :differentiator_3, class: "form-control #{"is-invalid" if own_product.errors[:differentiator_3].any?}",
        placeholder: "Differentiator 3" %>
  </div>

  <%= f.submit class: "btn btn-primary" %>
  <%= link_to "Cancel", own_products_path, class: "btn btn-outline-secondary ms-2" %>
<% end %>
```

**`app/views/own_products/new.html.erb`**

```erb
<div class="container py-4">
  <div class="row">
    <div class="col-md-8 col-lg-6">
      <h1>Add Your Product</h1>
      <p class="text-muted">Define your product and its top three differentiators. These will be used to generate tailored battlecard talking points.</p>
      <%= render "form", own_product: @own_product %>
    </div>
  </div>
</div>
```

**`app/views/own_products/edit.html.erb`**

```erb
<div class="container py-4">
  <div class="row">
    <div class="col-md-8 col-lg-6">
      <h1>Edit <%= @own_product.name %></h1>
      <%= render "form", own_product: @own_product %>
    </div>
  </div>
</div>
```

**`app/views/own_products/show.html.erb`**

```erb
<div class="container py-4">
  <div class="row mb-4">
    <div class="col">
      <h1><%= @own_product.name %></h1>
      <p class="text-muted mb-1"><strong>Differentiator 1:</strong> <%= @own_product.differentiator_1 %></p>
      <p class="text-muted mb-1"><strong>Differentiator 2:</strong> <%= @own_product.differentiator_2 %></p>
      <p class="text-muted mb-1"><strong>Differentiator 3:</strong> <%= @own_product.differentiator_3 %></p>
    </div>
    <div class="col-auto">
      <%= link_to "Edit", edit_own_product_path(@own_product), class: "btn btn-outline-secondary btn-sm me-2" %>
      <%= link_to "Delete", @own_product,
          data: { turbo_method: :delete, turbo_confirm: "Delete #{@own_product.name} and all its competitors and battlecards?" },
          class: "btn btn-outline-danger btn-sm" %>
    </div>
  </div>

  <div class="d-flex justify-content-between align-items-center mb-3">
    <h2 class="h4 mb-0">Competitors</h2>
    <%= link_to "Add Competitor", new_own_product_competitor_path(@own_product), class: "btn btn-primary btn-sm" %>
  </div>

  <% if @competitors.any? %>
    <div class="table-responsive">
      <table class="table table-dark table-hover">
        <thead>
          <tr>
            <th>Company</th>
            <th>Website</th>
            <th>Analyses</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <% @competitors.each do |competitor| %>
            <tr>
              <td><%= competitor.company_name %></td>
              <td>
                <% if competitor.website.present? %>
                  <%= link_to competitor.website, competitor.website, target: "_blank", rel: "noopener noreferrer" %>
                <% else %>
                  <span class="text-muted">—</span>
                <% end %>
              </td>
              <td><%= competitor.competitor_analyses.count %></td>
              <td>
                <%= link_to "View", own_product_competitor_path(@own_product, competitor), class: "btn btn-sm btn-outline-secondary me-1" %>
                <%= link_to "Edit", edit_own_product_competitor_path(@own_product, competitor), class: "btn btn-sm btn-outline-secondary me-1" %>
                <%= link_to "Delete", own_product_competitor_path(@own_product, competitor),
                    data: { turbo_method: :delete, turbo_confirm: "Delete #{competitor.company_name}?" },
                    class: "btn btn-sm btn-outline-danger" %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  <% else %>
    <div class="text-center py-4">
      <p class="text-muted">No competitors tracked yet.</p>
      <%= link_to "Add Your First Competitor", new_own_product_competitor_path(@own_product), class: "btn btn-primary" %>
    </div>
  <% end %>
</div>
```

### 3.4 User Association

Ensure `app/models/user.rb` has:

```ruby
has_many :own_products, dependent: :destroy
has_many :competitors, dependent: :destroy
has_many :competitor_analyses, dependent: :destroy
```

### Manual Tests — Phase 3

- [ ] Navigate to `/own_products` — see empty state with "Add Product" CTA
- [ ] Create a product with all four fields — redirects to show page
- [ ] Create a product with a missing name — re-renders form with error
- [ ] Edit a product — updates and redirects to show
- [ ] Delete a product — redirects to index
- [ ] Navbar "Products" link navigates to `/own_products`
- [ ] A different user cannot access your product (returns 404)

### RSpec Tests — Phase 3

Write `spec/requests/own_products_spec.rb`:

- [ ] GET `/own_products` — authenticated user sees only their own products
- [ ] POST `/own_products` — creates product and redirects to show on valid params
- [ ] POST `/own_products` — re-renders new with errors on missing name
- [ ] DELETE `/own_products/:id` — destroys product; another user's product returns 404
- [ ] Unauthenticated request to any action redirects to sign in

---

## Phase 4 — Competitors CRUD

**Goal:** Nested CRUD for Competitor under OwnProduct.

### 4.1 Routes

Update `config/routes.rb`:

```ruby
resources :own_products do
  resources :competitors, only: [:new, :create, :show, :edit, :update, :destroy]
end
```

### 4.2 CompetitorsController

```ruby
# app/controllers/competitors_controller.rb
class CompetitorsController < ApplicationController
  before_action :set_own_product
  before_action :set_competitor, only: [:show, :edit, :update, :destroy]

  def new
    @competitor = @own_product.competitors.build
  end

  def create
    @competitor = @own_product.competitors.build(competitor_params.merge(user: current_user))
    if @competitor.save
      redirect_to own_product_competitor_path(@own_product, @competitor), notice: "Competitor added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @analyses = @competitor.competitor_analyses.order(created_at: :desc)
    @latest = @competitor.competitor_analyses.complete.order(researched_at: :desc).first
  end

  def edit; end

  def update
    if @competitor.update(competitor_params)
      redirect_to own_product_competitor_path(@own_product, @competitor), notice: "Competitor updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @competitor.destroy
    redirect_to @own_product, notice: "#{@competitor.company_name} removed."
  end

  private

  def set_own_product
    @own_product = current_user.own_products.find(params[:own_product_id])
  end

  def set_competitor
    @competitor = @own_product.competitors.find(params[:id])
  end

  def competitor_params
    params.require(:competitor).permit(:company_name, :website, :notes)
  end
end
```

### 4.3 Views

**`app/views/competitors/_form.html.erb`**

```erb
<%= form_with model: [@own_product, competitor], class: "mt-3" do |f| %>
  <% if competitor.errors.any? %>
    <div class="alert alert-danger">
      <ul class="mb-0">
        <% competitor.errors.full_messages.each do |msg| %>
          <li><%= msg %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="mb-3">
    <%= f.label :company_name, class: "form-label" %>
    <%= f.text_field :company_name, class: "form-control #{"is-invalid" if competitor.errors[:company_name].any?}" %>
    <% competitor.errors[:company_name].each do |err| %>
      <div class="invalid-feedback"><%= err %></div>
    <% end %>
  </div>

  <div class="mb-3">
    <%= f.label :website, "Website (optional)", class: "form-label" %>
    <%= f.url_field :website, class: "form-control #{"is-invalid" if competitor.errors[:website].any?}",
        placeholder: "https://competitor.com" %>
    <% competitor.errors[:website].each do |err| %>
      <div class="invalid-feedback"><%= err %></div>
    <% end %>
    <div class="form-text">If provided, the agent will use this as a starting point for research.</div>
  </div>

  <div class="mb-3">
    <%= f.label :notes, "Notes (optional)", class: "form-label" %>
    <%= f.text_area :notes, rows: 3, class: "form-control",
        placeholder: "Any context about this competitor..." %>
  </div>

  <%= f.submit class: "btn btn-primary" %>
  <%= link_to "Cancel", own_product_competitor_path(@own_product, @competitor || competitor), class: "btn btn-outline-secondary ms-2" %>
<% end %>
```

**`app/views/competitors/new.html.erb`**

```erb
<div class="container py-4">
  <div class="row">
    <div class="col-md-8 col-lg-6">
      <nav aria-label="breadcrumb">
        <ol class="breadcrumb">
          <li class="breadcrumb-item"><%= link_to @own_product.name, @own_product %></li>
          <li class="breadcrumb-item active">Add Competitor</li>
        </ol>
      </nav>
      <h1>Add Competitor</h1>
      <%= render "form", competitor: @competitor %>
    </div>
  </div>
</div>
```

**`app/views/competitors/edit.html.erb`**

```erb
<div class="container py-4">
  <div class="row">
    <div class="col-md-8 col-lg-6">
      <nav aria-label="breadcrumb">
        <ol class="breadcrumb">
          <li class="breadcrumb-item"><%= link_to @own_product.name, @own_product %></li>
          <li class="breadcrumb-item"><%= link_to @competitor.company_name, own_product_competitor_path(@own_product, @competitor) %></li>
          <li class="breadcrumb-item active">Edit</li>
        </ol>
      </nav>
      <h1>Edit <%= @competitor.company_name %></h1>
      <%= render "form", competitor: @competitor %>
    </div>
  </div>
</div>
```

**`app/views/competitors/show.html.erb`**

```erb
<div class="container py-4">
  <div class="row mb-4">
    <div class="col">
      <nav aria-label="breadcrumb">
        <ol class="breadcrumb">
          <li class="breadcrumb-item"><%= link_to @own_product.name, @own_product %></li>
          <li class="breadcrumb-item active"><%= @competitor.company_name %></li>
        </ol>
      </nav>
      <h1><%= @competitor.company_name %></h1>
      <% if @competitor.website.present? %>
        <p><%= link_to @competitor.website, @competitor.website, target: "_blank", rel: "noopener noreferrer" %></p>
      <% end %>
      <% if @competitor.notes.present? %>
        <p class="text-muted"><%= @competitor.notes %></p>
      <% end %>
    </div>
    <div class="col-auto d-flex align-items-start gap-2">
      <%= link_to "Edit", edit_own_product_competitor_path(@own_product, @competitor), class: "btn btn-outline-secondary btn-sm" %>
      <%= link_to "Delete", own_product_competitor_path(@own_product, @competitor),
          data: { turbo_method: :delete, turbo_confirm: "Delete #{@competitor.company_name} and all its battlecards?" },
          class: "btn btn-outline-danger btn-sm" %>
    </div>
  </div>

  <div class="mb-4">
    <%= form_with url: own_product_competitor_analyses_path(@own_product, @competitor), method: :post do |f| %>
      <%= f.submit "Research This Competitor Now", class: "btn btn-primary" %>
    <% end %>
  </div>

  <h2 class="h4 mb-3">Research History</h2>

  <% if @analyses.any? %>
    <div class="list-group">
      <% @analyses.each do |analysis| %>
        <div class="list-group-item d-flex justify-content-between align-items-center">
          <div>
            <span class="badge <%= analysis.status == 'complete' ? 'text-bg-danger' : analysis.status == 'error' ? 'text-bg-secondary' : 'text-bg-warning' %> me-2">
              <%= analysis.status %>
            </span>
            <% if analysis.researched_at.present? %>
              <span class="text-muted small">Researched <%= time_ago_in_words(analysis.researched_at) %> ago</span>
            <% else %>
              <span class="text-muted small"><%= time_ago_in_words(analysis.created_at) %> ago</span>
            <% end %>
          </div>
          <%= link_to "View Battlecard", competitor_analysis_path(analysis), class: "btn btn-sm btn-outline-secondary" %>
        </div>
      <% end %>
    </div>
  <% else %>
    <p class="text-muted">No research runs yet. Click "Research This Competitor Now" to start.</p>
  <% end %>
</div>
```

Note: The `own_product_competitor_analyses_path` route and `competitor_analysis_path` are added in Phase 6. The show view will error until then. That is expected.

### Manual Tests — Phase 4

- [ ] Add a competitor to a product — redirects to competitor show page
- [ ] Invalid website (no https://) shows validation error
- [ ] Blank website allowed — no error
- [ ] Edit competitor — updates and redirects to show
- [ ] Delete competitor from product show page — redirects to product show
- [ ] A different user's own_product_id in the URL returns 404

### RSpec Tests — Phase 4

Write `spec/requests/competitors_spec.rb`:

- [ ] GET `/own_products/:id/competitors/new` — loads form for current user's product
- [ ] GET `/own_products/:id/competitors/new` — returns 404 for another user's product
- [ ] POST `/own_products/:id/competitors` — creates competitor with `user_id: current_user.id`
- [ ] POST `/own_products/:id/competitors` — re-renders new on missing company_name
- [ ] DELETE competitor — another user cannot delete it (404)
- [ ] Unauthenticated request redirects to sign in

---

## Phase 5 — GeminiService Agent Extension

**Goal:** Add `GeminiService.generate_with_tools` — the function-calling agent loop that drives the battlecard research.

This is the most technically complex phase. The existing `GeminiService.generate` makes a single API call. The new method runs a multi-turn conversation loop, executing tool calls until Gemini produces a final text response or `max_rounds` is reached.

### 5.1 Tool Implementations

Create `app/services/search_web_tool.rb`:

```ruby
class SearchWebTool
  SERPER_URL = "https://google.serper.dev/search".freeze

  def self.call(query:)
    response = HTTParty.post(
      SERPER_URL,
      headers: {
        "X-API-KEY" => ENV.fetch("SERPER_API_KEY", ""),
        "Content-Type" => "application/json"
      },
      body: { q: query, num: 5 }.to_json,
      timeout: 10
    )

    return "Search failed: HTTP #{response.code}" unless response.success?

    results = response.parsed_response["organic"] || []
    results.first(5).map do |r|
      "Title: #{r["title"]}\nURL: #{r["link"]}\nSnippet: #{r["snippet"]}"
    end.join("\n\n")
  rescue StandardError => e
    "Search failed: #{e.message}"
  end
end
```

Create `app/services/fetch_url_tool.rb`:

```ruby
class FetchUrlTool
  MAX_CHARS = 3000
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".freeze

  def self.call(url:)
    response = HTTParty.get(
      url,
      headers: { "User-Agent" => USER_AGENT },
      timeout: 10,
      follow_redirects: true
    )

    return "Failed to fetch URL: HTTP #{response.code}" unless response.success?

    text = strip_html(response.body.to_s)
    text.strip.first(MAX_CHARS)
  rescue StandardError => e
    "Failed to fetch URL: #{e.message}"
  end

  def self.strip_html(html)
    html
      .gsub(/<script[^>]*>.*?<\/script>/mi, " ")
      .gsub(/<style[^>]*>.*?<\/style>/mi, " ")
      .gsub(/<!--.*?-->/m, " ")
      .gsub(/<[^>]+>/, " ")
      .gsub(/&amp;/, "&").gsub(/&lt;/, "<").gsub(/&gt;/, ">").gsub(/&nbsp;/, " ").gsub(/&#\d+;/, " ")
      .gsub(/\s+/, " ")
  end
end
```

### 5.2 Tool Definitions

The Gemini API expects tools as `functionDeclarations` in the request body. Define them as Ruby hashes:

```ruby
SEARCH_WEB_DEFINITION = {
  name: "search_web",
  description: "Search the live web for current information. Returns titles, URLs, and snippets for the top results.",
  parameters: {
    type: "OBJECT",
    properties: {
      query: { type: "STRING", description: "The search query string" }
    },
    required: ["query"]
  }
}.freeze

FETCH_URL_DEFINITION = {
  name: "fetch_url",
  description: "Fetch the text content of a URL. Returns the first 3000 characters of the page body.",
  parameters: {
    type: "OBJECT",
    properties: {
      url: { type: "STRING", description: "The URL to fetch" }
    },
    required: ["url"]
  }
}.freeze
```

These go in `app/jobs/agent_run_job.rb` (Phase 6) as private constants.

### 5.3 GeminiService.generate_with_tools

Add to `app/services/gemini_service.rb` as a new class method alongside `generate`:

```ruby
def self.generate_with_tools(template:, variables:, tools:, on_tool_call: nil, max_rounds: 6)
  new.generate_with_tools_instance(
    template: template, variables: variables,
    tools: tools, on_tool_call: on_tool_call, max_rounds: max_rounds
  )
end
```

Add the instance method:

```ruby
def generate_with_tools_instance(template:, variables:, tools:, on_tool_call:, max_rounds:)
  ai_template = AiTemplate.find_by!(name: template)
  rendered_prompt = ai_template.interpolate(variables)
  full_prompt = [ai_template.system_prompt.presence, rendered_prompt].compact.join("\n\n")

  AiGatekeeper.check!(rendered_prompt)
  AiBudgetChecker.check!(Current.user)

  llm_request = LlmRequest.create!(
    user: Current.user,
    ai_template: ai_template,
    template_name: template,
    status: "pending"
  )

  begin
    started_at = Time.current
    contents = [{ role: "user", parts: [{ text: full_prompt }] }]
    tool_steps = []
    step = 0

    loop do
      step += 1
      response = call_gemini_with_tools(ai_template, contents, tools)
      candidate = response.dig("candidates", 0, "content")

      function_call_part = candidate&.dig("parts")&.find { |p| p["functionCall"] }

      if function_call_part && step <= max_rounds
        fn = function_call_part["functionCall"]
        tool_name = fn["name"]
        tool_args = (fn["args"] || {}).transform_keys(&:to_sym)

        result = dispatch_tool(tool_name, tool_args)

        entry = {
          step: step,
          tool: tool_name,
          args: tool_args,
          result_preview: result.to_s.first(200),
          timestamp: Time.current.iso8601
        }
        tool_steps << entry
        on_tool_call&.call(tool_name, tool_args, result)

        contents << { role: "model", parts: [{ functionCall: { name: tool_name, args: fn["args"] } }] }
        contents << {
          role: "user",
          parts: [{ functionResponse: { name: tool_name, response: { content: result.to_s } } }]
        }
      else
        text = candidate&.dig("parts")&.find { |p| p["text"] }&.dig("text") || ""
        duration_ms = ((Time.current - started_at) * 1000).round
        llm_request.update!(status: "success", duration_ms: duration_ms)
        return { text: text, tool_steps: tool_steps, raw: response.to_json }
      end
    end
  rescue => e
    llm_request.update!(status: "error", error_message: e.message)
    raise GeminiError, e.message
  end
end
```

Add private helpers:

```ruby
def call_gemini_with_tools(ai_template, contents, tools)
  api_key = ENV.fetch("GEMINI_API_KEY")
  model = ai_template.model.presence || "gemini-2.5-flash"
  url = "https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{api_key}"

  body = {
    contents: contents,
    tools: [{ functionDeclarations: tools }],
    generationConfig: {
      maxOutputTokens: ai_template.max_output_tokens || 3000,
      temperature: ai_template.temperature&.to_f || 0.3
    }
  }

  response = Faraday.post(url) do |req|
    req.headers["Content-Type"] = "application/json"
    req.body = body.to_json
    req.options.timeout = ENV.fetch("AI_GLOBAL_TIMEOUT_SECONDS", "30").to_i
  end

  raise GeminiError, "Gemini API error: #{response.status}" unless response.success?
  JSON.parse(response.body)
end

def dispatch_tool(name, args)
  case name
  when "search_web" then SearchWebTool.call(**args)
  when "fetch_url"  then FetchUrlTool.call(**args)
  else "Unknown tool: #{name}"
  end
end
```

**Important:** The timeout for `generate_with_tools` should be higher than the standard 15s since the full agent loop takes 30–90 seconds. Use `AI_GLOBAL_TIMEOUT_SECONDS` default of 30 and update `.env.example` accordingly.

### 5.4 Model Note

The rivalgraph template uses `gemini-2.5-flash` (not `gemini-2.0-flash` as written in the original spec — `gemini-2.0-flash` is deprecated for new API keys per the boilerplate documentation). Update the seed in Phase 8.

### Manual Tests — Phase 5

- [ ] In rails console with a valid `GEMINI_API_KEY` and `SERPER_API_KEY`, call `SearchWebTool.call(query: "rails 8 pricing")` — returns result strings
- [ ] Call `FetchUrlTool.call(url: "https://example.com")` — returns stripped text
- [ ] Call `FetchUrlTool.call(url: "https://definitely-does-not-exist-404.com")` — returns "Failed to fetch URL: ..." without raising

### RSpec Tests — Phase 5

No RSpec for tool implementations in this phase (they make real HTTP calls). The job spec in Phase 6 will stub them.

Write `spec/services/gemini_service_generate_with_tools_spec.rb`:

- [ ] On success: returns `{ text:, tool_steps:, raw: }` hash with `LlmRequest` status "success"
- [ ] On `GeminiError`: raises and sets `LlmRequest` status to "error"
- [ ] Dispatches to correct tool implementation (stub both tool classes)
- [ ] Calls `on_tool_call` callback once per tool call step

---

## Phase 6 — Background Job + CompetitorAnalyses Controller

**Goal:** AgentRunJob (Solid Queue), CompetitorAnalysesController, routes for analyses, Turbo Streams broadcasts.

### 6.1 Routes

Update `config/routes.rb`:

```ruby
resources :own_products do
  resources :competitors, only: [:new, :create, :show, :edit, :update, :destroy] do
    resources :analyses, only: [:create], controller: "competitor_analyses"
  end
end

resources :competitor_analyses, only: [:index, :show, :destroy]
```

This gives:
- `POST /own_products/:own_product_id/competitors/:competitor_id/analyses` → `competitor_analyses#create`
- `GET /competitor_analyses` → `competitor_analyses#index`
- `GET /competitor_analyses/:id` → `competitor_analyses#show`
- `DELETE /competitor_analyses/:id` → `competitor_analyses#destroy`

Helper aliases in `config/routes.rb`:

```ruby
get "/competitor_analyses", to: "competitor_analyses#index", as: :competitor_analyses
```

Update the named helper used in the competitor show view accordingly. Verify `own_product_competitor_analyses_path` and `competitor_analysis_path` resolve correctly.

### 6.2 Solid Queue Configuration

Solid Queue is included in Rails 8. Confirm `config/application.rb` has:

```ruby
config.active_job.queue_adapter = :solid_queue
```

Ensure `db/schema.rb` includes the `solid_queue_*` tables. Run `rails db:migrate` if not present. For development, Solid Queue runs as part of `bin/dev` (Procfile.dev should include the worker). Add if missing:

```
# Procfile.dev
web: bin/rails server
worker: bin/rails solid_queue:start
```

### 6.3 AgentRunJob

```ruby
# app/jobs/agent_run_job.rb
class AgentRunJob < ApplicationJob
  queue_as :default

  SEARCH_WEB_TOOL = {
    name: "search_web",
    description: "Search the live web for current information. Returns titles, URLs, and snippets for the top results.",
    parameters: {
      type: "OBJECT",
      properties: {
        query: { type: "STRING", description: "The search query string" }
      },
      required: ["query"]
    }
  }.freeze

  FETCH_URL_TOOL = {
    name: "fetch_url",
    description: "Fetch the text content of a URL. Returns the first 3000 characters of the page body.",
    parameters: {
      type: "OBJECT",
      properties: {
        url: { type: "STRING", description: "The URL to fetch" }
      },
      required: ["url"]
    }
  }.freeze

  def perform(analysis_id)
    @analysis = CompetitorAnalysis.find(analysis_id)
    @competitor = @analysis.competitor
    @own_product = @competitor.own_product
    Current.user = @analysis.user

    @analysis.update!(status: "running")
    broadcast_status("Research started...")

    result = GeminiService.generate_with_tools(
      template: "rivalgraph_battlecard_v1",
      variables: {
        competitor_name: @competitor.company_name,
        competitor_website: @competitor.website.to_s,
        own_product_name: @own_product.name,
        differentiator_1: @own_product.differentiator_1,
        differentiator_2: @own_product.differentiator_2,
        differentiator_3: @own_product.differentiator_3
      },
      tools: [SEARCH_WEB_TOOL, FETCH_URL_TOOL],
      on_tool_call: method(:broadcast_step),
      max_rounds: 6
    )

    battlecard_json = JSON.parse(result[:text].gsub(/\A```json\n?/, "").gsub(/\n?```\z/, ""))

    @analysis.update!(
      status: "complete",
      battlecard: battlecard_json.to_json,
      gemini_raw: result[:raw],
      agent_trace: result[:tool_steps].to_json,
      researched_at: Time.current
    )

    broadcast_complete

  rescue JSON::ParserError
    @analysis.update!(status: "error", error_message: "Battlecard response was not valid JSON.")
    broadcast_error("Battlecard response was not valid JSON.")
  rescue GeminiService::GeminiError => e
    @analysis.update!(status: "error", error_message: e.message)
    broadcast_error(e.message)
  rescue StandardError => e
    @analysis.update!(status: "error", error_message: "Unexpected error: #{e.message}")
    broadcast_error("An unexpected error occurred.")
  end

  private

  def broadcast_step(tool_name, args, result)
    Turbo::StreamsChannel.broadcast_append_to(
      @analysis,
      target: "agent-progress-feed",
      partial: "competitor_analyses/progress_step",
      locals: { tool_name: tool_name, args: args, result: result }
    )
  end

  def broadcast_status(message)
    Turbo::StreamsChannel.broadcast_update_to(
      @analysis,
      target: "analysis-status",
      html: message
    )
  end

  def broadcast_complete
    Turbo::StreamsChannel.broadcast_update_to(
      @analysis,
      target: "analysis-container",
      partial: "competitor_analyses/battlecard",
      locals: { analysis: @analysis.reload }
    )
  end

  def broadcast_error(message)
    Turbo::StreamsChannel.broadcast_update_to(
      @analysis,
      target: "analysis-container",
      partial: "competitor_analyses/error_state",
      locals: { analysis: @analysis.reload, message: message }
    )
  end
end
```

### 6.4 CompetitorAnalysesController

```ruby
# app/controllers/competitor_analyses_controller.rb
class CompetitorAnalysesController < ApplicationController
  before_action :set_analysis, only: [:show, :destroy]

  def index
    @analyses = current_user.competitor_analyses
                            .complete
                            .includes(competitor: :own_product)
                            .order(researched_at: :desc)
  end

  def create
    @own_product = current_user.own_products.find(params[:own_product_id])
    @competitor = @own_product.competitors.find(params[:competitor_id])
    @analysis = @competitor.competitor_analyses.create!(
      user: current_user,
      status: "pending"
    )
    AgentRunJob.perform_later(@analysis.id)
    redirect_to competitor_analysis_path(@analysis), notice: "Research started. This may take up to 90 seconds."
  end

  def show; end

  def destroy
    @competitor = @analysis.competitor
    @own_product = @competitor.own_product
    @analysis.destroy
    redirect_to own_product_competitor_path(@own_product, @competitor), notice: "Battlecard deleted."
  end

  private

  def set_analysis
    @analysis = current_user.competitor_analyses.find(params[:id])
  end
end
```

### Manual Tests — Phase 6

- [ ] POST to create analysis — redirects to show page with "Research started" notice
- [ ] show page for a pending analysis renders the "in progress" state (spinner)
- [ ] `AgentRunJob.perform_now(analysis.id)` in console with real API keys — analysis reaches `complete` status
- [ ] Unauthenticated request to any analysis route redirects to sign in
- [ ] Another user's analysis is not accessible (404)

### RSpec Tests — Phase 6

Write `spec/requests/competitor_analyses_spec.rb`:

- [ ] POST create — creates analysis with status "pending" and enqueues AgentRunJob
- [ ] POST create — returns 404 if competitor belongs to a different user
- [ ] GET show — renders in-progress view for pending analysis
- [ ] GET show — renders battlecard for complete analysis
- [ ] GET `/competitor_analyses` — returns only the current user's complete analyses
- [ ] An LlmRequest record is created when AgentRunJob performs with a stubbed Gemini double

Write `spec/jobs/agent_run_job_spec.rb`:

- [ ] On success: sets status "complete", sets researched_at, stores battlecard JSON, stores agent_trace array
- [ ] On `GeminiService::GeminiError`: sets status "error", sets error_message
- [ ] `broadcast_append_to` called once per tool call step
- [ ] Agent loop terminates at max 6 rounds (stub Gemini to return function calls 7 times; verify only 6 tool dispatches occur)

---

## Phase 7 — Analysis Views + Turbo Streams Progress

**Goal:** Full `competitor_analyses` view set — three render states for show, battlecard partial, progress step partial, index.

### 7.1 competitor_analyses/show.html.erb

```erb
<div class="container py-4">
  <div class="row mb-3">
    <div class="col">
      <% competitor = @analysis.competitor %>
      <% own_product = competitor.own_product %>
      <nav aria-label="breadcrumb">
        <ol class="breadcrumb">
          <li class="breadcrumb-item"><%= link_to own_product.name, own_product %></li>
          <li class="breadcrumb-item"><%= link_to competitor.company_name, own_product_competitor_path(own_product, competitor) %></li>
          <li class="breadcrumb-item active">Battlecard</li>
        </ol>
      </nav>
    </div>
  </div>

  <% if @analysis.status.in?(["pending", "running"]) %>
    <%= turbo_stream_from @analysis %>

    <div id="analysis-container">
      <div class="card">
        <div class="card-body text-center py-5">
          <div class="spinner-border mb-3" style="border-top-color: var(--accent);" role="status">
            <span class="visually-hidden">Researching...</span>
          </div>
          <h5>Research in progress</h5>
          <p class="text-muted" id="analysis-status">The agent is searching and reading live sources...</p>
          <p class="text-muted small">This typically takes 30–90 seconds.</p>
        </div>

        <div class="card-footer">
          <h6 class="mb-2 text-muted small">Agent Progress</h6>
          <div class="list-group list-group-flush" id="agent-progress-feed">
            <%# Steps appended here via Turbo Stream broadcasts %>
          </div>
        </div>
      </div>
    </div>

  <% elsif @analysis.status == "complete" %>
    <div id="analysis-container">
      <%= render "battlecard", analysis: @analysis %>
    </div>

  <% else %>
    <div id="analysis-container">
      <%= render "error_state", analysis: @analysis, message: @analysis.error_message %>
    </div>
  <% end %>
</div>
```

### 7.2 competitor_analyses/_progress_step.html.erb

```erb
<div class="list-group-item list-group-item-action py-2">
  <% icon = tool_name == "search_web" ? "🔍" : "🔗" %>
  <span class="me-2"><%= icon %></span>
  <% if tool_name == "search_web" %>
    <span class="text-muted small">Searched for: <em><%= args[:query] || args["query"] %></em></span>
  <% else %>
    <span class="text-muted small">Read: <em><%= (args[:url] || args["url"]).to_s.truncate(60) %></em></span>
  <% end %>
</div>
```

### 7.3 competitor_analyses/_battlecard.html.erb

```erb
<%
  data = begin
    analysis.battlecard.is_a?(String) ? JSON.parse(analysis.battlecard) : analysis.battlecard
  rescue JSON::ParserError
    {}
  end
%>

<div class="card mb-4">
  <div class="card-header d-flex justify-content-between align-items-center">
    <div>
      <h4 class="mb-0"><%= data["competitor_name"] %> Battlecard</h4>
      <% if analysis.researched_at %>
        <small class="text-muted">Researched <%= time_ago_in_words(analysis.researched_at) %> ago</small>
      <% end %>
    </div>
    <div>
      <%= form_with url: own_product_competitor_analyses_path(analysis.competitor.own_product, analysis.competitor), method: :post do |f| %>
        <%= f.submit "Refresh Battlecard", class: "btn btn-sm btn-primary" %>
      <% end %>
    </div>
  </div>

  <div class="card-body">
    <h5 class="card-title text-muted small text-uppercase">What They Offer</h5>
    <p><%= data["what_they_offer"] %></p>

    <hr>

    <h5 class="card-title text-muted small text-uppercase">Pricing Tiers</h5>
    <% tiers = Array(data["pricing_tiers"]) %>
    <% if tiers.any? %>
      <ul class="list-group list-group-flush mb-3">
        <% tiers.each do |tier| %>
          <li class="list-group-item">
            <div class="d-flex justify-content-between">
              <strong><%= tier["tier_name"] %></strong>
              <span class="badge text-bg-secondary"><%= tier["price"] %></span>
            </div>
            <small class="text-muted"><%= tier["summary"] %></small>
          </li>
        <% end %>
      </ul>
    <% else %>
      <p class="text-muted">Could not retrieve current pricing data.</p>
    <% end %>

    <hr>

    <h5 class="card-title text-muted small text-uppercase">Top Customer Complaints (from reviews)</h5>
    <% complaints = Array(data["top_customer_complaints"]) %>
    <% if complaints.any? %>
      <ul class="list-group list-group-flush mb-3">
        <% complaints.each do |complaint| %>
          <li class="list-group-item">
            <span class="me-2">⚠️</span><%= complaint %>
          </li>
        <% end %>
      </ul>
    <% else %>
      <p class="text-muted">Could not retrieve review data.</p>
    <% end %>

    <hr>

    <h5 class="card-title text-muted small text-uppercase">Recent News</h5>
    <p><%= data["recent_news"] || "No recent news found." %></p>

    <hr>

    <h5 class="card-title text-muted small text-uppercase" style="color: var(--accent);">Why You Win</h5>
    <% talking_points = Array(data["talking_points"]) %>
    <% if talking_points.any? %>
      <div class="mb-3">
        <% talking_points.each do |point| %>
          <p class="talking-point mb-2"><%= point %></p>
        <% end %>
      </div>
    <% end %>

    <hr>

    <h5 class="card-title text-muted small text-uppercase">Where They Are Stronger</h5>
    <p class="text-muted"><%= data["competitor_strength"] %></p>
  </div>

  <div class="card-footer">
    <small class="text-muted">
      Battlecard sourced from live web pages on <%= analysis.researched_at&.strftime("%B %-d, %Y") %>.
      Pricing and availability change frequently. Verify all figures before using in sales or marketing materials.
      Customer complaint summaries reflect a sample of reviews, not all customers.
    </small>
  </div>
</div>

<%# Research trace accordion %>
<% if analysis.agent_trace.present? %>
  <%
    steps = begin
      JSON.parse(analysis.agent_trace)
    rescue JSON::ParserError
      []
    end
  %>
  <% if steps.any? %>
    <div class="accordion mb-3" id="research-trace">
      <div class="accordion-item">
        <h2 class="accordion-header">
          <button class="accordion-button collapsed" type="button"
                  data-bs-toggle="collapse" data-bs-target="#trace-body">
            How the agent researched this (<%= steps.length %> steps)
          </button>
        </h2>
        <div id="trace-body" class="accordion-collapse collapse">
          <div class="accordion-body p-0">
            <div class="list-group list-group-flush">
              <% steps.each do |step| %>
                <div class="list-group-item">
                  <div class="d-flex justify-content-between">
                    <strong>Step <%= step["step"] %>: <%= step["tool"] %></strong>
                    <small class="text-muted"><%= step["timestamp"] %></small>
                  </div>
                  <div class="text-muted small">Args: <%= step["args"].inspect %></div>
                  <div class="text-muted small mt-1">
                    Result preview: <em><%= step["result_preview"] %></em>
                  </div>
                </div>
              <% end %>
            </div>

            <div class="p-3">
              <button class="btn btn-sm btn-outline-secondary" type="button"
                      data-bs-toggle="collapse" data-bs-target="#raw-response">
                Show raw response
              </button>
              <div class="collapse mt-2" id="raw-response">
                <pre class="bg-dark border rounded p-2 small" style="overflow-x: auto; max-height: 300px;"><%= analysis.gemini_raw %></pre>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  <% end %>
<% end %>
```

### 7.4 competitor_analyses/_error_state.html.erb

```erb
<div class="alert alert-danger" role="alert">
  <h4 class="alert-heading">Research failed</h4>
  <p><%= message %></p>
  <hr>
  <%= form_with url: own_product_competitor_analyses_path(analysis.competitor.own_product, analysis.competitor), method: :post do |f| %>
    <%= f.submit "Try Again", class: "btn btn-danger" %>
  <% end %>
</div>
```

### 7.5 competitor_analyses/index.html.erb

```erb
<div class="container py-4">
  <h1>All Battlecards</h1>

  <% if @analyses.any? %>
    <div class="table-responsive">
      <table class="table table-dark table-hover">
        <thead>
          <tr>
            <th>Competitor</th>
            <th>Your Product</th>
            <th>Researched</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <% @analyses.each do |analysis| %>
            <tr>
              <td><%= analysis.competitor.company_name %></td>
              <td><%= analysis.competitor.own_product.name %></td>
              <td><%= time_ago_in_words(analysis.researched_at) %> ago</td>
              <td><%= link_to "View", competitor_analysis_path(analysis), class: "btn btn-sm btn-outline-secondary" %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  <% else %>
    <div class="text-center py-5">
      <p class="text-muted">No battlecards yet.</p>
      <%= link_to "Go to Products", own_products_path, class: "btn btn-primary" %>
    </div>
  <% end %>
</div>
```

### Manual Tests — Phase 7

- [ ] Pending analysis show page renders spinner and progress feed container
- [ ] Complete analysis show page renders the full battlecard with all six sections
- [ ] Research trace accordion expands and shows steps
- [ ] "Show raw response" collapse reveals raw JSON
- [ ] "Refresh Battlecard" button starts a new analysis
- [ ] Error state shows "Try Again" button
- [ ] Index page lists all complete battlecards with links

**End-to-end Turbo Streams test:**

1. Open two browser tabs: tab A on the competitor show page, tab B on the analysis show page (create the analysis first so the URL exists)
2. Click "Research This Competitor Now" in tab A — tab B's pending show page should display each step appending in real time as the agent runs
3. After ~60–90 seconds the battlecard should replace the spinner automatically

### RSpec Tests — Phase 7

These are covered by the request specs in Phase 6. Optionally add:

- [ ] GET show with `complete` analysis renders battlecard section headings
- [ ] GET show with `error` analysis renders error alert and "Try Again" button

---

## Phase 8 — Home Page, Dashboard, and Seeds

**Goal:** Replace home and dashboard views; create all seed data including the AI template.

### 8.1 db/seeds.rb

Add to the existing seeds file (after the demo user and health_ping template):

```ruby
# rivalgraph_battlecard_v1 template
AiTemplate.find_or_create_by!(name: "rivalgraph_battlecard_v1") do |t|
  t.description = "Gemini agent template for researching a competitor and producing a structured battlecard. Uses function calling with search_web and fetch_url tools."
  t.model = "gemini-2.5-flash"
  t.max_output_tokens = 3000
  t.temperature = 0.3
  t.notes = "Called by AgentRunJob via GeminiService.generate_with_tools. Output is JSON. See docs/open-rivalgraph/rivalgraph-demo-spec.md Section 7 for full details."

  t.system_prompt = <<~PROMPT.strip
    You are a competitive intelligence researcher. Your job is to research a competitor and produce a structured battlecard grounded in current, sourced information - not guesses or training-data recall.

    You have two tools available:

    - search_web(query): searches the live web and returns a list of result titles, URLs, and snippets. Use this to find URLs worth reading.
    - fetch_url(url): fetches the content of a URL and returns up to 3000 characters of the page body text. Use this to read what is actually on a page.

    Follow this research sequence. Adapt it if a step yields no useful result:

    Step 1: search_web("[competitor name] pricing") to find their pricing page URL.
    Step 2: fetch_url([pricing page URL from step 1]) to read their actual current pricing tiers.
    Step 3: search_web("[competitor name] reviews site:g2.com OR site:capterra.com") to find a review page.
    Step 4: fetch_url([review page URL from step 3]) to read what real customers say about weaknesses.
    Step 5: search_web("[competitor name] [current year] news OR funding OR launch OR feature") to find recent activity.
    Step 6: Synthesize everything you found into a battlecard.

    Important constraints:
    - You have a maximum of 6 tool call rounds. If you exhaust them, proceed to synthesis with whatever you have gathered.
    - Base pricing tiers only on what you read in step 2. If you could not fetch the pricing page, say so explicitly. Do not guess at pricing.
    - Base customer complaints only on what you read in step 4. If you could not fetch a review page, say so explicitly. Do not fabricate reviews.
    - Do not confabulate. If a section requires information you did not find, write "Could not retrieve current data" for that section.

    Output format: Respond with a single JSON object matching this schema exactly:

    {
      "competitor_name": "string",
      "what_they_offer": "string - one paragraph description of their product based on what you found",
      "pricing_tiers": [
        { "tier_name": "string", "price": "string", "summary": "string" }
      ],
      "top_customer_complaints": ["string", "string", "string"],
      "recent_news": "string - one sentence summary of the most relevant recent finding, or 'No recent news found'",
      "talking_points": ["string", "string", "string"],
      "competitor_strength": "string - one honest sentence about where the competitor is genuinely stronger"
    }

    The talking_points must be grounded in the differentiators the user provides. Each talking point must contrast a specific differentiator against something you actually found about the competitor. Do not invent advantages; derive them from the research.
  PROMPT

  t.user_prompt_template = <<~PROMPT.strip
    Competitor company name: {{competitor_name}}
    Competitor website (if known, use as a starting point): {{competitor_website}}

    My product name: {{own_product_name}}
    My product's top 3 differentiators:
    1. {{differentiator_1}}
    2. {{differentiator_2}}
    3. {{differentiator_3}}

    Research {{competitor_name}} using your tools. Produce a battlecard in the JSON format specified in your instructions. Ground every section in what your tools return. If a step fails, note it and continue to synthesis.
  PROMPT
end

# Domain seeds for demo user
demo_user = User.find_by!(email: "demo@example.com")

own_product = OwnProduct.find_or_create_by!(user: demo_user, name: "Basecamp") do |p|
  p.differentiator_1 = "Flat per-company pricing with no per-seat fees - teams of any size pay the same"
  p.differentiator_2 = "All-in-one: message boards, to-dos, schedules, docs, and chat in a single product"
  p.differentiator_3 = "Opinionated and calm - no notifications designed to create anxiety or urgency"
end

competitor = Competitor.find_or_create_by!(own_product: own_product, company_name: "Asana") do |c|
  c.user = demo_user
  c.website = "https://asana.com"
  c.notes = "Main competitor in project management. Known for per-seat pricing."
end

# Pre-populated sample battlecard — illustrative content, not live-researched
sample_battlecard = {
  competitor_name: "Asana",
  what_they_offer: "Asana is a work management platform that helps teams organize, track, and manage their work. It offers project views including lists, boards, timelines, and calendars, along with workflow automation and reporting features.",
  pricing_tiers: [
    { tier_name: "Personal", price: "Free", summary: "Basic task management for individuals and small teams up to 10 users." },
    { tier_name: "Starter", price: "$10.99/user/month", summary: "Timeline views, unlimited projects, and basic automation." },
    { tier_name: "Advanced", price: "$24.99/user/month", summary: "Advanced workflows, portfolios, goals, and workload management." }
  ],
  top_customer_complaints: [
    "Per-seat pricing becomes very expensive as teams grow beyond 20-30 people",
    "Steep learning curve - teams report needing weeks to fully adopt the platform",
    "Mobile app is significantly less capable than the desktop version"
  ],
  recent_news: "Asana launched AI Studio in early 2026, adding AI-powered workflow builders to its enterprise tier.",
  talking_points: [
    "While Asana charges per seat (from $11/user), Basecamp's flat $299/month covers unlimited users — a team of 50 saves over $15,000/year",
    "Asana requires training programs and onboarding plans; Basecamp's opinionated design means most teams are productive within a day",
    "Asana's notification system is designed to keep users engaged constantly; Basecamp is built around async-first communication that respects focus time"
  ],
  competitor_strength: "Asana offers more granular project views (timeline, portfolio, workload) that large enterprise teams managing complex dependencies genuinely benefit from."
}.to_json

sample_trace = [
  { step: 1, tool: "search_web", args: { query: "Asana pricing 2026" }, result_preview: "Found: Asana pricing page at asana.com/pricing showing three tiers", timestamp: Time.current.iso8601 },
  { step: 2, tool: "fetch_url", args: { url: "https://asana.com/pricing" }, result_preview: "Personal: Free. Starter: $10.99/user/month billed annually. Advanced: $24.99...", timestamp: Time.current.iso8601 },
  { step: 3, tool: "search_web", args: { query: "Asana reviews site:g2.com" }, result_preview: "Found: G2 Asana review page with 9,500+ reviews", timestamp: Time.current.iso8601 },
  { step: 4, tool: "fetch_url", args: { url: "https://www.g2.com/products/asana/reviews" }, result_preview: "Common complaints: pricing too high for small teams, complex setup, mobile app limitations", timestamp: Time.current.iso8601 },
  { step: 5, tool: "search_web", args: { query: "Asana 2026 news launch feature" }, result_preview: "Asana launched AI Studio workflow builder for enterprise customers", timestamp: Time.current.iso8601 },
  { step: 6, tool: "search_web", args: { query: "Asana vs Basecamp comparison 2026" }, result_preview: "Multiple comparison articles noting pricing and complexity differences", timestamp: Time.current.iso8601 }
].to_json

CompetitorAnalysis.find_or_create_by!(competitor: competitor, user: demo_user, status: "complete") do |a|
  a.battlecard = sample_battlecard
  a.agent_trace = sample_trace
  a.gemini_raw = sample_battlecard
  a.researched_at = Time.current
end
```

### 8.2 home/index.html.erb

```erb
<div class="container py-5">
  <div class="row align-items-center g-5">
    <div class="col-lg-6">
      <h1 class="display-5 fw-bold">AI that researches, not guesses</h1>
      <p class="lead text-muted mb-4">
        Most competitive intelligence from AI is stale training data with made-up pricing.
        RivalGraph runs a live research agent: it finds your competitor's actual pricing page,
        reads real G2 reviews, and scans for recent news — then writes the battlecard.
      </p>

      <div class="mb-4">
        <div class="d-flex align-items-start mb-3">
          <span class="badge rounded-pill me-3 mt-1" style="background-color: var(--accent);">1</span>
          <div>
            <strong>Enter your competitor</strong>
            <p class="text-muted small mb-0">Name your competitor and add your product's top three differentiators.</p>
          </div>
        </div>
        <div class="d-flex align-items-start mb-3">
          <span class="badge rounded-pill me-3 mt-1" style="background-color: var(--accent);">2</span>
          <div>
            <strong>Agent researches live</strong>
            <p class="text-muted small mb-0">The agent searches the web, reads their pricing page, fetches G2 reviews, and scans for news.</p>
          </div>
        </div>
        <div class="d-flex align-items-start">
          <span class="badge rounded-pill me-3 mt-1" style="background-color: var(--accent);">3</span>
          <div>
            <strong>Get a sourced battlecard</strong>
            <p class="text-muted small mb-0">Real pricing tiers, actual customer complaints, tailored talking points — with the full research trace visible.</p>
          </div>
        </div>
      </div>

      <%= link_to "Get Started — It's Free", sign_up_path, class: "btn btn-lg btn-primary" %>
    </div>

    <div class="col-lg-6">
      <%# Static mock battlecard %>
      <div class="card">
        <div class="card-header d-flex justify-content-between">
          <div>
            <strong>CompetitorCo Battlecard</strong><br>
            <small class="text-muted">Researched just now</small>
          </div>
          <span class="badge text-bg-danger align-self-start">complete</span>
        </div>
        <div class="card-body">
          <p class="small text-muted text-uppercase mb-1">What They Offer</p>
          <p class="small">A project management platform with board and timeline views, priced per seat.</p>

          <p class="small text-muted text-uppercase mb-1 mt-3">Pricing Tiers</p>
          <ul class="list-group list-group-flush list-group-sm mb-3">
            <li class="list-group-item py-1 small">Starter — $12/user/month</li>
            <li class="list-group-item py-1 small">Business — $28/user/month</li>
          </ul>

          <p class="small text-muted text-uppercase mb-1">Top Customer Complaints</p>
          <ul class="list-group list-group-flush list-group-sm mb-3">
            <li class="list-group-item py-1 small">⚠️ Gets expensive fast as teams grow</li>
            <li class="list-group-item py-1 small">⚠️ Steep onboarding curve</li>
          </ul>

          <p class="small text-uppercase mb-1" style="color: var(--accent);">Why You Win</p>
          <p class="talking-point small mb-1">Our flat pricing saves a 50-person team $12,000/year vs. their per-seat model.</p>
          <p class="talking-point small mb-0">Our all-in-one design eliminates the integrations their customers say are painful.</p>
        </div>
        <div class="card-footer">
          <small class="text-muted">Sourced from live web pages · Verify before use in sales materials</small>
        </div>
      </div>
    </div>
  </div>
</div>
```

### 8.3 dashboard/show.html.erb

```erb
<div class="container py-4">
  <h1>Welcome back, <%= current_user.first_name %>.</h1>

  <div class="row row-cols-1 row-cols-md-3 g-4 mb-4">
    <div class="col">
      <div class="card text-center">
        <div class="card-body">
          <div class="display-6"><%= current_user.own_products.count %></div>
          <p class="text-muted mb-0">Products tracked</p>
        </div>
      </div>
    </div>
    <div class="col">
      <div class="card text-center">
        <div class="card-body">
          <div class="display-6"><%= current_user.competitors.count %></div>
          <p class="text-muted mb-0">Competitors tracked</p>
        </div>
      </div>
    </div>
    <div class="col">
      <div class="card text-center">
        <div class="card-body">
          <div class="display-6"><%= current_user.competitor_analyses.complete.count %></div>
          <p class="text-muted mb-0">Battlecards generated</p>
        </div>
      </div>
    </div>
  </div>

  <% recent = current_user.competitor_analyses.complete.includes(competitor: :own_product).order(researched_at: :desc).limit(3) %>
  <% if recent.any? %>
    <h2 class="h4 mb-3">Recent Battlecards</h2>
    <div class="list-group mb-4">
      <% recent.each do |analysis| %>
        <div class="list-group-item d-flex justify-content-between align-items-center">
          <div>
            <strong><%= analysis.competitor.company_name %></strong>
            <span class="text-muted small ms-2">vs. <%= analysis.competitor.own_product.name %></span><br>
            <small class="text-muted">Researched <%= time_ago_in_words(analysis.researched_at) %> ago</small>
          </div>
          <%= link_to "View Battlecard", competitor_analysis_path(analysis), class: "btn btn-sm btn-outline-secondary" %>
        </div>
      <% end %>
    </div>
  <% end %>

  <% if current_user.own_products.none? %>
    <div class="text-center py-4 border rounded">
      <p class="text-muted mb-3">Start by defining your product and its differentiators.</p>
      <%= link_to "Add Your Product", new_own_product_path, class: "btn btn-primary" %>
    </div>
  <% end %>
</div>
```

### Manual Tests — Phase 8

- [ ] `rails db:seed` completes without errors
- [ ] Sign in as `demo@example.com` / `password123` — dashboard shows stats (1 product, 1 competitor, 1 battlecard)
- [ ] Dashboard "Recent Battlecards" links to the seeded complete analysis
- [ ] Viewing the seeded analysis shows the Asana battlecard correctly
- [ ] Home page (unauthenticated) renders the two-column layout with mock battlecard
- [ ] Admin → AI Templates shows `rivalgraph_battlecard_v1` seeded correctly

### RSpec Tests — Phase 8

- [ ] `db/seeds.rb` is idempotent: running `rails db:seed` twice produces the same number of records

---

## Phase 9 — README Updates

**Goal:** Update `README.md` to match the RivalGraph Demo identity.

### 9.1 Required Sections

Replace or update the README with:

1. **App name and tagline** from the spec (Section 11)
2. **One-paragraph description** (Section 11)
3. **Screenshot placeholder** (`[screenshot: battlecard view...]`)
4. **Why I Built This** (Section 11)
5. **Standard setup** (existing `bin/setup` instructions)
6. **Additional setup: Serper.dev API key** (Section 11)
7. **Demo credentials**: `demo@example.com` / `password123`
8. **Template editing note** (Section 11)
9. **MIT License** mention

### Manual Tests — Phase 9

- [ ] README renders correctly on GitHub (headings, code blocks, links)
- [ ] Setup instructions are accurate — a fresh `git clone` + `bin/setup` works

---

## Phase 10 — Full Test Suite + End-to-End Validation

**Goal:** All tests green; full end-to-end flow validated manually.

### 10.1 Complete RSpec Suite

Run:

```bash
bundle exec rspec --format documentation
```

Expected result: zero failures, no real API calls in output.

### 10.2 End-to-End Manual Test Flow

Work through this flow on a fresh `rails db:seed` database:

1. **Unauthenticated home page** — renders correctly, CTA links to sign up
2. **Sign up** with a new email — redirects to dashboard with empty state
3. **Create an OwnProduct** — define a real product with three real differentiators
4. **Add a Competitor** — use a real company with a known pricing page (e.g., Notion, Linear, Asana)
5. **Research the competitor** — click "Research This Competitor Now"
6. **Watch the progress feed** — each step appears in real time (requires Solid Queue worker running in `bin/dev`)
7. **View the complete battlecard** — all six sections populated; pricing attributed to their page
8. **Check the research trace** — accordion expands showing step-by-step tool calls
9. **Check raw response** — toggle reveals the Gemini JSON
10. **Refresh Battlecard** — runs a new analysis; old one remains in history
11. **Dashboard** — stats reflect the new product, competitor, and battlecard counts
12. **Battlecards index** (`/competitor_analyses`) — lists completed analyses
13. **Admin panel** → LlmRequests — shows the analysis run logged correctly
14. **Sign out** — redirects to home

### 10.3 Edge Case Manual Tests

- [ ] Research a competitor with a heavily JS-rendered site — battlecard shows "Could not retrieve current data" in affected sections rather than crashing
- [ ] Input a competitor name in a non-Latin script — agent handles it gracefully
- [ ] Start an analysis; immediately view the show page — spinner renders without error
- [ ] Delete a battlecard from its show page — redirects to competitor show
- [ ] Delete an OwnProduct with 2+ competitors and analyses — all cascade-deleted

---

## Implementation Notes Across All Phases

### Model: Use `gemini-2.5-flash`, not `gemini-2.0-flash`

The original spec says `gemini-2.0-flash` for function calling. **Use `gemini-2.5-flash` instead.** The boilerplate documentation explicitly states `gemini-2.0-flash` is unavailable on new API keys in v1beta. `gemini-2.5-flash` supports function calling.

### Turbo Streams + ActionCable

The live progress feed requires ActionCable. Solid Cable (the Rails 8 Solid Stack adapter) handles this without Redis. Verify `config/cable.yml` uses the Solid Cable adapter in production and development.

### AiGatekeeper and `generate_with_tools`

The gatekeeper runs on the rendered user prompt (the interpolated `user_prompt_template`). The tool results (search snippets, fetched page content) are **not** passed through the gatekeeper — they are added to the Gemini conversation as function responses, which the user never directly controls. This is safe by design (see spec Section 8).

### Background Job Timeouts

The standard `AI_GLOBAL_TIMEOUT_SECONDS` (15s) is too short for a 6-round agent loop. Update the default to 90 in `.env.example` and document it in the README. The timeout in `call_gemini_with_tools` applies per-API-call, not for the entire job.

### JSON Parsing Robustness

Gemini sometimes wraps JSON output in markdown code fences (` ```json ... ``` `). The `AgentRunJob` strips these before parsing:

```ruby
clean = result[:text].gsub(/\A```json\n?/, "").gsub(/\n?```\z/, "")
battlecard_json = JSON.parse(clean)
```

Add this cleanup and rescue `JSON::ParserError` as shown in the job spec.
