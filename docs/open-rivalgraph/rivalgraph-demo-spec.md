# RivalGraph Demo - Spec Document

**Document Version:** 1.0
**Built on:** Open Demo Starter v2.0
**Accent Color:** `#dc2626` (red)
**License:** MIT

---

## 1. App Overview

RivalGraph Demo is a competitive intelligence tool that uses a Gemini agent to research a competitor and produce a structured battlecard. The user enters a competitor's company name and their own product's top three differentiators. Instead of generating a response from Gemini's potentially stale training data, the app runs a Gemini agent with two live research tools: web search and URL fetch. The agent autonomously locates and reads the competitor's actual pricing page, finds real customer reviews on G2 and Capterra, and scans for recent news before synthesizing a battlecard.

The battlecard output contains: what the competitor actually offers (sourced from their site), real pricing tiers (sourced from their pricing page), top customer complaints (sourced from review platforms), recent news that affects competitive positioning, three talking points for why the user's product wins, and one honest risk where the competitor is genuinely stronger.

This demo is one tool from a larger multi-tenant SaaS platform the author is building. The production version adds team collaboration, organization-scoped competitor libraries, saved battlecard histories, and export options. This open source demo isolates the single most valuable action - running the research agent and seeing the result - as a clean, locally-runnable Rails app scoped to a single signed-in user.

The core engineering demonstration is the distinction between AI that guesses and AI that researches. A competitive analysis tool powered only by Gemini's training data is limited by a cutoff date and confabulation risk on specifics like pricing. With a function-calling agent loop that reads live pages, the output is grounded in current reality.

This demo is open source under the MIT license. Visitors who clone it can swap in their own GEMINI_API_KEY and SERPER_API_KEY and use it against any competitor in minutes.

---

## 2. Customizations Applied to the Boilerplate

The following changes are made on top of the Open Demo Starter v2.0 boilerplate:

- **App name:** `RivalGraph Demo` (set via `APP_NAME` in `.env.example`)
- **Tagline:** `Type a competitor's name. The agent researches them. You get a battlecard.` (set via `APP_TAGLINE`)
- **App description:** A short paragraph describing competitive intelligence via agent-powered research (set via `APP_DESCRIPTION`)
- **Accent color:** `#dc2626` (red) set in `app/assets/stylesheets/_accent.scss`
- **Navbar links added:** Products (links to `/own_products`); Battlecards (links to `/competitor_analyses`)
- **Home page:** `home/index.html.erb` replaced with a two-column pitch: left side describes the problem (AI confabulating stale pricing), right side shows a sample battlecard card to illustrate the output
- **Dashboard page:** `dashboard/show.html.erb` replaced with a stat summary (count of own products, competitors tracked, battlecards generated) plus a "Recent Battlecards" list linking to the three most recently completed analyses
- **UX pattern:** Form-then-agent-trace with battlecard output. User fills a form, the agent runs with a live progress feed, the result is a persistent battlecard card with a collapsible research trace below it
- **Additional env var:** `SERPER_API_KEY` for the search_web tool (Serper.dev free tier)
- **Additional gem:** `httparty` for the fetch_url tool implementation
- **Solid Queue enabled:** Required for the background job that runs the agent loop (the agent can take 30 to 90 seconds; synchronous controller calls are not viable)
- **AI templates seeded:** `rivalgraph_battlecard_v1` (full content in Section 7)

---

## 3. Data Model

Three domain models are added on top of `User`, `AiTemplate`, and `LlmRequest`.

### OwnProduct

Represents the user's own product. The user defines it once and can track multiple competitors against it.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `user_id` | uuid | Foreign key; `belongs_to :user` |
| `name` | string | Required; **(template variable)** |
| `differentiator_1` | string | Required; the first key differentiator **(template variable)** |
| `differentiator_2` | string | Required; the second key differentiator **(template variable)** |
| `differentiator_3` | string | Required; the third key differentiator **(template variable)** |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Associations:** `belongs_to :user`, `has_many :competitors, dependent: :destroy`

**Validations:** `name`, `differentiator_1`, `differentiator_2`, `differentiator_3` all present; `name` maximum 100 characters; differentiators each maximum 200 characters

### Competitor

Represents a single competitor tracked against one OwnProduct.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `own_product_id` | uuid | Foreign key; `belongs_to :own_product` |
| `user_id` | uuid | Foreign key; `belongs_to :user` (denormalized for direct scoping) |
| `company_name` | string | Required; **(template variable)** |
| `website` | string | Optional URL; **(template variable)** |
| `notes` | text | Optional context the user adds manually |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Associations:** `belongs_to :own_product`, `belongs_to :user`, `has_many :competitor_analyses, dependent: :destroy`

**Validations:** `company_name` present and maximum 100 characters; `website` format-validated if present (must begin with `http://` or `https://`)

### CompetitorAnalysis

Represents a single agent research run and its resulting battlecard. Multiple analyses can exist per competitor; the most recent is shown by default.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `competitor_id` | uuid | Foreign key; `belongs_to :competitor` |
| `user_id` | uuid | Foreign key; `belongs_to :user` (denormalized for direct scoping) |
| `status` | string | `pending`, `running`, `complete`, `error` |
| `battlecard` | text | Parsed battlecard content rendered as HTML; nil until complete |
| `agent_trace` | text | JSON array of tool call steps; each entry is `{step, tool, args, result, timestamp}` |
| `gemini_raw` | text | Full raw JSON response from Gemini API **(Gemini output, used for Show raw response toggle)** |
| `error_message` | text | Populated on failure; nil otherwise |
| `researched_at` | datetime | Set to current time when status transitions to `complete` |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Associations:** `belongs_to :competitor`, `belongs_to :user`

**Validations:** `status` included in the allowed set; `competitor_id` and `user_id` present

**Scopes:** `scope :complete, -> { where(status: "complete") }`, `scope :recent, -> { order(created_at: :desc) }`

---

## 4. Routes

| Verb | Path | Controller#Action | Purpose |
|---|---|---|---|
| GET | `/own_products` | `own_products#index` | List user's own products |
| GET | `/own_products/new` | `own_products#new` | Form to define a new own product |
| POST | `/own_products` | `own_products#create` | Save a new own product |
| GET | `/own_products/:id` | `own_products#show` | Show product with competitors list |
| GET | `/own_products/:id/edit` | `own_products#edit` | Edit product details |
| PATCH | `/own_products/:id` | `own_products#update` | Save product edits |
| DELETE | `/own_products/:id` | `own_products#destroy` | Delete product and all nested records |
| GET | `/own_products/:own_product_id/competitors/new` | `competitors#new` | Form to add a competitor |
| POST | `/own_products/:own_product_id/competitors` | `competitors#create` | Save a new competitor |
| GET | `/own_products/:own_product_id/competitors/:id` | `competitors#show` | Show competitor with analyses list |
| GET | `/own_products/:own_product_id/competitors/:id/edit` | `competitors#edit` | Edit competitor details |
| PATCH | `/own_products/:own_product_id/competitors/:id` | `competitors#update` | Save competitor edits |
| DELETE | `/own_products/:own_product_id/competitors/:id` | `competitors#destroy` | Delete competitor and analyses |
| POST | `/own_products/:own_product_id/competitors/:competitor_id/analyses` | `competitor_analyses#create` | Create analysis record and enqueue agent job |
| GET | `/competitor_analyses` | `competitor_analyses#index` | All battlecards across all competitors (user-scoped) |
| GET | `/competitor_analyses/:id` | `competitor_analyses#show` | Show a battlecard (or in-progress state) |
| DELETE | `/competitor_analyses/:id` | `competitor_analyses#destroy` | Delete an analysis |

---

## 5. Controllers and Actions

### `OwnProductsController`

Inherits from `ApplicationController`. All queries scoped via `current_user.own_products`.

- **index:** Fetches all of `current_user.own_products` ordered by `created_at desc`. Renders the product list.
- **new:** Instantiates an unsaved `OwnProduct`. Renders the form.
- **create:** Builds an `OwnProduct` via `current_user.own_products.build(own_product_params)`. On success, redirects to the product show page. On failure, re-renders the form with inline errors.
- **show:** Finds the product by ID within `current_user.own_products`. Loads `@competitors` as `@own_product.competitors.order(created_at: :desc)` and `@recent_analysis` as the most recent complete analysis across all competitors of this product.
- **edit/update:** Standard update pattern. On success, redirects to show. On failure, re-renders edit with errors.
- **destroy:** Destroys the product (cascades to competitors and their analyses). Redirects to index with a flash notice.

### `CompetitorsController`

Inherits from `ApplicationController`. Nested under `OwnProduct`. Scoped through `current_user.own_products.find(params[:own_product_id])` before any action.

- **new:** Instantiates an unsaved `Competitor` against `@own_product`. Renders the form.
- **create:** Builds a competitor via `@own_product.competitors.build(competitor_params.merge(user: current_user))`. On success, redirects to the competitor show page. On failure, re-renders the form.
- **show:** Loads `@analyses` as `@competitor.competitor_analyses.order(created_at: :desc)`. Loads `@latest` as the most recent complete analysis, if any.
- **edit/update:** Standard update pattern.
- **destroy:** Destroys the competitor (cascades to analyses). Redirects to `@own_product` show.

### `CompetitorAnalysesController`

Inherits from `ApplicationController`.

- **index:** Fetches `current_user.competitor_analyses.complete.includes(competitor: :own_product).order(researched_at: :desc)`. Renders a browsable list of all completed battlecards.
- **create:** Resolves `@competitor` through `current_user`. Creates a `CompetitorAnalysis` record with `status: "pending"`. Enqueues `AgentRunJob.perform_later(@analysis.id)`. Redirects to `competitor_analysis_path(@analysis)`. This is the action that eventually triggers `GeminiService.generate_with_tools(template: "rivalgraph_battlecard_v1", variables: {...}, tools: [...])` via the background job (not inline in this action).
- **show:** Finds `current_user.competitor_analyses.find(params[:id])`. Renders the battlecard if status is `complete`. Renders a live progress view with a Turbo Streams subscription if status is `pending` or `running`. Renders an error state with a retry button if status is `error`.
- **destroy:** Destroys the analysis. Redirects to the competitor show page.

### `AgentRunJob` (Solid Queue job, not a controller)

This job is the only place `GeminiService.generate_with_tools` is called.

- Loads the `CompetitorAnalysis` by ID. Sets status to `running` and broadcasts the initial progress message via `Turbo::StreamsChannel`.
- Calls `GeminiService.generate_with_tools` with the `rivalgraph_battlecard_v1` template, the resolved variable hash, the tool definitions, an `on_tool_call` callback that broadcasts each step to the analysis's Turbo stream channel, and `max_rounds: 6`.
- On success: sets `battlecard` to the parsed output, `gemini_raw` to the raw response, `agent_trace` to the JSON-encoded tool call array, `status` to `complete`, `researched_at` to the current time. Broadcasts a final Turbo Stream update that replaces the progress feed with the battlecard.
- On `GeminiService::GeminiError`: sets `status` to `error`, `error_message` to the exception message. Broadcasts a Turbo Stream update that shows the error state with a retry button.
- Catches `StandardError` as a fallback: sets `status` to `error`, `error_message` to a generic message.

---

## 6. Views

### `own_products/index.html.erb`

Renders a Bootstrap card grid of the user's own products. Each card shows the product name, the count of competitors tracked, and a "View" button. Includes an "Add your product" call-to-action card if the list is empty. No Turbo or Stimulus behavior.

### `own_products/new.html.erb` and `own_products/edit.html.erb`

Both render `own_products/_form.html.erb`. The form has fields for `name` and three labeled text inputs for the differentiators. Inline validation errors rendered via `field_with_errors`. Submit button uses `--accent` background color.

### `own_products/show.html.erb`

Two sections: an info header showing the product name and differentiators, and a competitors table listing each competitor with their company name, website link, count of analyses, and actions (View, Edit, Delete). An "Add Competitor" button links to the nested competitor new path. No Stimulus behavior.

### `competitors/new.html.erb` and `competitors/edit.html.erb`

Both render `competitors/_form.html.erb`. Fields: `company_name`, `website`, `notes`. Inline validation errors.

### `competitors/show.html.erb`

Two sections: a header with competitor name, website link, and notes; and an analyses list. The analyses list shows each analysis as a row with `researched_at`, a status badge, and a "View Battlecard" link. A prominent "Research This Competitor Now" button is at the top. Clicking it posts to `competitor_analyses#create` via a standard form. No inline Stimulus needed; the button is a regular form submit.

### `competitor_analyses/index.html.erb`

Table of all completed battlecards across the user's competitors. Columns: competitor name, own product name, researched at, age indicator. Each row links to the battlecard show page.

### `competitor_analyses/show.html.erb`

This view has three conditional render paths based on `@analysis.status`:

**Pending or running:** Shows a "Research in progress" panel with a spinner. Uses `turbo_stream_from @analysis` to subscribe to live broadcast updates. A Bootstrap list group below the spinner displays the agent progress feed: each tool call step appears as a new list item as the job broadcasts it ("Searching for pricing page...", "Reading pricing page...", "Searching G2 for reviews...", "Reading G2 review page...", "Searching for recent news...", "Synthesizing battlecard...").

**Complete:** Shows the battlecard rendered as a Bootstrap card (detailed below). Below the battlecard, a collapsible Bootstrap accordion section titled "How the agent researched this" renders the `agent_trace` JSON array as a readable timeline: each entry shows the step number, tool name, the arguments passed, and a truncated preview of the result. At the bottom of the collapsible section, a "Show raw response" Bootstrap collapse reveals the `gemini_raw` field content verbatim.

**Error:** Shows a Bootstrap danger alert with the `error_message`. Includes a "Try Again" button that posts to `competitor_analyses#create` to create a new analysis for the same competitor.

### `competitor_analyses/_battlecard.html.erb`

The battlecard partial, used in the show view. Renders a structured Bootstrap card with the following labeled sections:
- What They Offer (paragraph)
- Pricing Tiers (Bootstrap list group)
- Top Customer Complaints (Bootstrap list group with warning badge icons)
- Recent News (paragraph with date if available)
- Why You Win (three Bootstrap badge-labeled talking points, accented in `--accent` color)
- Where They Are Stronger (a single paragraph styled in muted text, honest risk acknowledgment)

At the top right of the card: a small "Researched [relative time]" badge and a "Regenerate" button (posts to `competitor_analyses#create`).

### `home/index.html.erb` (override)

Two-column Bootstrap row. Left column: headline ("AI that researches, not guesses"), subheadline explaining the agent loop concept, a brief three-step explainer (Enter competitor, Agent researches live, Get a battlecard), and a "Get Started" CTA button linking to sign-up. Right column: a static mock battlecard card styled identically to the real output, showing realistic placeholder content for a fictional competitor.

### `dashboard/show.html.erb` (override)

Three stat cards at the top: Products tracked, Competitors tracked, Battlecards generated. Below: a "Recent Battlecards" list linking to the three most recent complete analyses. Below that: an "Add Your Product" CTA if the user has no own products yet.

---

## 7. AI Templates and Gemini Integration

### Template: `rivalgraph_battlecard_v1`

**Description:** Gemini agent template for researching a competitor and producing a structured battlecard. Uses function calling with search_web and fetch_url tools.

**System prompt (full text):**

```
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
```

**User prompt template (full text):**

```
Competitor company name: {{competitor_name}}
Competitor website (if known, use as a starting point): {{competitor_website}}

My product name: {{own_product_name}}
My product's top 3 differentiators:
1. {{differentiator_1}}
2. {{differentiator_2}}
3. {{differentiator_3}}

Research {{competitor_name}} using your tools. Produce a battlecard in the JSON format specified in your instructions. Ground every section in what your tools return. If a step fails, note it and continue to synthesis.
```

**Variables consumed:**

- `{{competitor_name}}` - from `Competitor#company_name`
- `{{competitor_website}}` - from `Competitor#website` (empty string if blank)
- `{{own_product_name}}` - from `OwnProduct#name` (via `competitor.own_product.name`)
- `{{differentiator_1}}` - from `OwnProduct#differentiator_1`
- `{{differentiator_2}}` - from `OwnProduct#differentiator_2`
- `{{differentiator_3}}` - from `OwnProduct#differentiator_3`

**Model:** `gemini-2.0-flash` (function calling is supported on this model; no upgrade required)

**max_output_tokens:** `3000` (higher than the boilerplate default of 2000 because the JSON battlecard schema with six sections plus three tiers and three talking points reliably exceeds 2000 tokens on well-researched competitors)

**temperature:** `0.3` (lower than the boilerplate default of 0.7 - this template produces structured JSON output; lower temperature reduces schema drift and confabulation risk on factual sections like pricing)

**Notes (author's notes):**

The prompt has two failure modes to watch for: (1) schema drift where Gemini omits a key or nests an array incorrectly - if this happens, lower temperature further or add JSON schema enforcement in the system prompt; (2) the pricing section confabulating tiers when fetch_url fails to return a readable pricing page - the constraint "do not guess at pricing" and the explicit "Could not retrieve current data" escape valve address this, but verify on edge cases. For competitors with heavily JS-rendered sites, fetch_url will return sparse content; the prompt handles this gracefully by allowing "Could not retrieve current data" in affected sections. The talking points are the most sensitive section - verify they derive from the differentiators provided, not from generic advantages Gemini has learned about similar products.

**Where it is called:** `AgentRunJob#perform`, via `GeminiService.generate_with_tools(template: "rivalgraph_battlecard_v1", variables: {...}, tools: [...])`.

**Expected output format:** JSON matching the schema in the system prompt. The keys are fixed and must be present. `pricing_tiers` is an array of objects with `tier_name`, `price`, and `summary`. `top_customer_complaints`, `talking_points` are arrays of strings. All other values are strings.

**How the response is parsed and rendered:**

`AgentRunJob` calls `JSON.parse(gemini_raw)` on the raw response. The parsed hash is stored as the `battlecard` field (serialized back to JSON for storage). The `_battlecard.html.erb` partial reads sections from the parsed hash and renders each section using Bootstrap components. If `JSON.parse` raises, the job sets status to `error` with message "Battlecard response was not valid JSON."

**Which domain field stores the raw response:** `CompetitorAnalysis#gemini_raw`

### Agent-Specific Details

**Tool definitions passed to `GeminiService.generate_with_tools`:**

```
search_web(query: string)
  Description: "Search the live web for current information. Returns titles, URLs, and snippets for the top results."
  Parameters: { query: { type: string, description: "The search query string" } }
  Implementation: Calls Serper.dev JSON API (GET https://google.serper.dev/search) with the query and the SERPER_API_KEY env var. Returns top 5 results as an array of {title, link, snippet}.

fetch_url(url: string)
  Description: "Fetch the text content of a URL. Returns the first 3000 characters of the page body."
  Parameters: { url: { type: string, description: "The URL to fetch" } }
  Implementation: Calls HTTParty.get with a 10-second timeout and a desktop User-Agent header. Strips HTML tags using a simple regex (no gem required at this scale). Returns the first 3000 characters of the resulting text. On timeout or HTTP error, returns "Failed to fetch URL: [error message]" so the agent can continue rather than crash.
```

**Maximum loop count:** 6 rounds. After 6 tool call rounds, `generate_with_tools` forces the agent into synthesis by sending the accumulated context without any further tool availability. This prevents runaway cost in edge cases where the agent loops on unresolvable searches.

**Intermediate state broadcast via Turbo Streams:**

The `on_tool_call` callback in `AgentRunJob` receives `(tool_name, args, result)` after each tool call completes. It calls `Turbo::StreamsChannel.broadcast_append_to(@analysis, target: "agent-progress-feed", partial: "competitor_analyses/progress_step", locals: { tool_name:, args:, result: })`. The progress step partial renders a single Bootstrap list group item showing the tool name and a short description derived from the args (e.g., "Searched for: [query]" or "Read: [url]"). The analysis show page subscribes with `turbo_stream_from @analysis` and appends each step to the `agent-progress-feed` div as it arrives.

**Storage of `agent_trace`:**

Each tool call step is collected by `generate_with_tools` into an array of hashes:
```
{ step: integer, tool: string, args: hash, result_preview: string (first 200 chars), timestamp: ISO8601 string }
```
After synthesis completes, this array is stored as `JSON.dump(steps)` in `CompetitorAnalysis#agent_trace`. The show view parses and renders it as a timeline.

**Calling pattern:**

```ruby
# Inside AgentRunJob#perform:
result = GeminiService.generate_with_tools(
  template: "rivalgraph_battlecard_v1",
  variables: {
    competitor_name: competitor.company_name,
    competitor_website: competitor.website.to_s,
    own_product_name: own_product.name,
    differentiator_1: own_product.differentiator_1,
    differentiator_2: own_product.differentiator_2,
    differentiator_3: own_product.differentiator_3
  },
  tools: [search_web_tool_definition, fetch_url_tool_definition],
  on_tool_call: method(:broadcast_step),
  max_rounds: 6
)
```

---

## 8. AI Safety Considerations (Specific to This App)

### Content Sensitivity

RivalGraph produces competitive intelligence about real companies. The output includes characterizations of a competitor's weaknesses and customer complaints. This is standard business analysis content - it falls in the same sensitivity tier as analyst reports or sales enablement materials. It is not a regulated domain and does not touch health, legal, or financial advice. The content sensitivity is low.

The one edge case is defamatory output. If the agent surfaces a review with a severe negative characterization (e.g., fraud allegations), and the user forwards the battlecard as a marketing document, the AI-generated label and disclaimer in the layout provide important context. The app-specific disclaimer below reinforces this.

### Consequential Outputs

A user acting on battlecard output could quote incorrect pricing in a sales call. This is mildly consequential: it damages credibility if the pricing is stale or wrong but causes no physical or financial harm. The root cause is mitigated by the agent's sourcing approach (it reads live pages, not training data) and by the explicit "Could not retrieve current data" escape valve in the prompt. The battlecard output always shows `researched_at` so the user knows how old the data is.

### Domain Accuracy Requirements

Pricing information changes frequently. A battlecard that reads a competitor's pricing page today may be inaccurate next week. The UI shows the `researched_at` timestamp prominently and the "Regenerate" button is labeled "Refresh Battlecard" to communicate that battlecards age. The app deliberately does not cache or reuse a competitor's battlecard when a new one is requested - each run hits live sources.

Customer complaint summaries depend on what the agent found on a single review page. G2 and Capterra reviews are real user-submitted content but represent a sample, not a census, of customer sentiment. The battlecard labels the section "Top Customer Complaints (from reviews)" to set accurate scope expectations.

### App-Specific Disclaimers

In addition to the boilerplate's footer note ("AI-generated content can be incorrect. Verify before acting."), the battlecard partial displays a small inline note directly below the battlecard card:

> "Battlecard sourced from live web pages on [researched_at date]. Pricing and availability change frequently. Verify all figures before using in sales or marketing materials. Customer complaint summaries reflect a sample of reviews, not all customers."

This note is rendered unconditionally on every complete battlecard, not hidden behind a toggle.

### Tightened Settings

- **Temperature:** 0.3 (below the boilerplate default of 0.7) to reduce confabulation on structured output sections, particularly pricing tiers
- **max_output_tokens:** 3000 (increased from the default 2000 to accommodate the JSON schema reliably)
- **Daily call cap:** The boilerplate default of 50 per user per day is appropriate. Each battlecard run costs roughly 5 to 12 tool call rounds plus synthesis. At 50 calls per day, a user could run approximately 5 to 10 full battlecards. This is reasonable for a demo.
- **Max rounds:** 6 tool call rounds before forced synthesis. This bounds cost on any single analysis run.

### What This Demo Deliberately Does NOT Do (for safety reasons)

- **Does not email or share battlecards.** No sharing, export, or email features. Sharing competitive intelligence output raises questions about accuracy and context that this demo does not address.
- **Does not store or re-surface pricing claims as authoritative facts.** The battlecard is displayed as AI-researched analysis, not as verified data. The disclaimer copy makes this explicit.
- **Does not scrape competitors' sites in bulk.** The agent fetches at most two or three URLs per analysis run. This is within normal browser-equivalent usage and is not a scraping operation.
- **Does not allow the user to specify arbitrary URLs to fetch.** The `fetch_url` tool is called only by the agent, not exposed to direct user input. This prevents the user from using the tool as a proxy to fetch arbitrary internal URLs.
- **Does not store Serper.dev results raw.** Search result snippets are included in `agent_trace` only as short previews (first 200 characters), not as full content, to avoid copyright concerns with cached search snippets.

---

## 9. RSpec Outline

### `spec/models/own_product_spec.rb`

1. Validates presence of `name`, `differentiator_1`, `differentiator_2`, `differentiator_3`
2. Validates maximum length of `name` (100 characters)
3. Validates maximum length of each differentiator (200 characters)
4. `belongs_to :user` association is present
5. `has_many :competitors, dependent: :destroy` - destroying an OwnProduct destroys its competitors

### `spec/models/competitor_spec.rb`

1. Validates presence of `company_name`
2. Validates format of `website` when present (must start with http:// or https://)
3. Allows blank `website` without validation error
4. `belongs_to :own_product` and `belongs_to :user` associations are present
5. `has_many :competitor_analyses, dependent: :destroy` - destroying a Competitor destroys its analyses

### `spec/models/competitor_analysis_spec.rb`

1. Validates presence of `status`
2. Validates `status` is included in the allowed set (pending, running, complete, error)
3. `belongs_to :competitor` and `belongs_to :user` associations are present
4. `scope :complete` returns only records with status "complete"
5. `scope :recent` returns records ordered by `created_at desc`

### `spec/requests/own_products_spec.rb`

1. GET /own_products - authenticated user sees their own products and no other user's products
2. POST /own_products - creates a product and redirects to show on valid params
3. POST /own_products - re-renders new with errors on invalid params (missing name)
4. DELETE /own_products/:id - destroys the product and redirects; a different user's product returns 404
5. Access control: an unauthenticated request redirects to sign in

### `spec/requests/competitors_spec.rb`

1. GET /own_products/:id/competitors/new - loads the form for a product owned by the current user
2. GET /own_products/:id/competitors/new - returns 404 for a product owned by a different user
3. POST /own_products/:id/competitors - creates a competitor with user_id set to current_user
4. POST /own_products/:id/competitors - re-renders new on invalid params (missing company_name)
5. DELETE competitor - a different user cannot delete another user's competitor

### `spec/requests/competitor_analyses_spec.rb`

1. POST create - creates a CompetitorAnalysis record with status "pending" and enqueues AgentRunJob (stub the job with `have_enqueued_job(AgentRunJob)`)
2. POST create - returns 404 if the competitor belongs to a different user
3. GET show - renders the battlecard for a complete analysis
4. GET show - renders the in-progress view for a pending analysis
5. An LlmRequest record is created when `AgentRunJob` performs with a stubbed Gemini double
6. GET /competitor_analyses - returns only the current user's complete analyses; another user's analyses are not visible

### `spec/jobs/agent_run_job_spec.rb`

1. On success: sets `status` to "complete", sets `researched_at`, stores `battlecard` as parsed JSON, stores `agent_trace` as a JSON array
2. On `GeminiService::GeminiError`: sets `status` to "error", sets `error_message`
3. Agent loop terminates within the configured maximum of 6 rounds (stub the Gemini double to return function_call responses for 7 rounds; verify the job forces synthesis at round 6 and does not make a 7th tool call)
4. Tool calls are recorded in `agent_trace` (each simulated tool call in the stub produces one entry in the trace)
5. The broadcast_append_to call is made once per tool call step (use `assert_broadcasts` or equivalent)

---

## 10. Seed Data

### AiTemplate Seeds

`db/seeds.rb` creates the `rivalgraph_battlecard_v1` template with the full `system_prompt`, `user_prompt_template`, `description`, `model`, `max_output_tokens`, `temperature`, and `notes` values specified in Section 7. The seed uses `AiTemplate.find_or_create_by(name: "rivalgraph_battlecard_v1")` so re-running seeds does not duplicate the record.

### Domain Seeds

The seed file creates three domain records for the seeded demo user (`demo@example.com`) so the app has realistic content on first run:

**OwnProduct seed:**

```
name: "Basecamp"
differentiator_1: "Flat per-company pricing with no per-seat fees - teams of any size pay the same"
differentiator_2: "All-in-one: message boards, to-dos, schedules, docs, and chat in a single product"
differentiator_3: "Opinionated and calm - no notifications designed to create anxiety or urgency"
```

**Competitor seed (against the above OwnProduct):**

```
company_name: "Asana"
website: "https://asana.com"
notes: "Main competitor in project management. Known for per-seat pricing."
```

**CompetitorAnalysis seed (one complete sample):**

A pre-populated `CompetitorAnalysis` record with `status: "complete"`, a realistic `battlecard` JSON string, a sample `agent_trace` JSON array with six steps, and `researched_at` set to seed time. This ensures visitors see a finished battlecard immediately without needing to run the agent themselves. The seed includes a comment noting that the battlecard content is illustrative, not live-researched.

---

## 11. README Additions

### App Name and Tagline

**RivalGraph Demo** - Type a competitor's name. The agent researches them. You get a battlecard.

### One-Paragraph Description

RivalGraph Demo is a competitive intelligence tool powered by a Gemini agent. Enter a competitor's name and your product's top differentiators. The agent searches the live web for their pricing page, reads G2 and Capterra reviews, scans for recent news, and synthesizes a structured battlecard grounded in what it actually found rather than what an LLM guesses from training data. The battlecard shows their real pricing tiers, top customer complaints, recent activity, three talking points for why your product wins, and one honest risk where they are stronger. The full research trace is always visible so you can see exactly what the agent read and in what order.

### Screenshot Placeholder

`[screenshot: battlecard view showing structured output with collapsible research trace below]`

### Why I Built This

I am building a multi-tenant competitive intelligence SaaS platform where sales and marketing teams track competitors across their entire organization. The core insight behind the product is that competitive intelligence from LLMs alone is unreliable: pricing changes, companies pivot, and training data is always stale. The fix is grounding AI output in live sources via function calling.

This demo isolates that single insight as a clean, open source Rails app anyone can clone and run in under 10 minutes. If you want the production version with team workspaces, shared competitor libraries, battlecard history, and Slack export, it is at [production URL placeholder].

This demo is MIT licensed. Clone it, fork it, extend it. If you improve it, open a PR.

### Additional Setup Step

Beyond `bin/setup`, this demo requires a Serper.dev API key for the web search tool:

1. Sign up for a free account at https://serper.dev
2. Copy your API key from the Serper.dev dashboard
3. Add it to your `.env` file: `SERPER_API_KEY=your_key_here`

Without this key, the agent will fail at the `search_web` step. The `fetch_url` tool works independently without this key.

### Template Editing Note

The AI prompt that drives the research agent is stored as an editable template in the database. Sign in as `demo@example.com` (password: `password123`) and visit `/admin/ai_templates` to edit it. The admin template editor has a live test panel where you can type sample variable values and run Gemini with the current draft without saving.

---

## 12. Bootstrap Dark Mode and Accent Color Notes

### UX Pattern

Form-then-agent-trace with battlecard output. The primary interaction is a compact form (competitor name, product differentiators - filled once per own product) followed by a progress feed, followed by a persistent structured output card.

### Accent Color Application

`--accent: #dc2626` (red) and `--accent-hover: #b91c1c` are set in `app/assets/stylesheets/_accent.scss`. The accent color is applied consistently to:

- Primary buttons (`btn-primary` overridden with `background-color: var(--accent)`)
- The active navbar link (`border-bottom: 2px solid var(--accent)`)
- The "Research This Competitor Now" call-to-action button
- The "Regenerate" button on the battlecard card
- The "Why You Win" talking points section badges in the battlecard partial
- The status badge for `complete` analyses (Bootstrap `text-bg-danger` variant, consistent with the red accent)
- The progress feed spinner (`border-top-color: var(--accent)` on the Bootstrap spinner)

All other buttons use Bootstrap's secondary or outline variants. The accent color is not used decoratively beyond the above list.

### Component Choices

- **Battlecard:** A single `card` with nested `list-group` for pricing tiers and customer complaints. No custom card CSS beyond standard Bootstrap dark mode.
- **Research trace:** Bootstrap `accordion` with a single panel ("How the agent researched this"). Each step is a `list-group-item` with a small icon indicating the tool type (magnifying glass for search, link icon for fetch).
- **Progress feed:** A `list-group` with `list-group-item` appended via Turbo Streams as steps complete. A Bootstrap spinner component above the list indicates the agent is still running.
- **Stat cards on dashboard:** Three Bootstrap `card` elements with large `display-6` numbers and muted subtitles. No custom CSS.
- **Own product and competitor tables:** Standard Bootstrap `table table-dark table-hover`. Responsive wrapper via `table-responsive`.

### Custom CSS Beyond the Boilerplate

Minimal additions in `application.css`:

- The `agent-progress-feed` list group has `max-height: 300px; overflow-y: auto` so it does not expand the page indefinitely during long agent runs
- The battlecard "Why You Win" section talking points use `border-left: 3px solid var(--accent); padding-left: 0.75rem` to visually distinguish them from the rest of the card content
- No other custom CSS is added; all other styling uses Bootstrap utility classes directly in the view markup

---

*v1.0 - RivalGraph demo spec. Built on Open Demo Starter v2.0. Open source under MIT license.*
