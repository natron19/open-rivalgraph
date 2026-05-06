# RivalGraph Demo

> Type a competitor's name. The agent researches them. You get a battlecard.

RivalGraph Demo is a competitive intelligence tool powered by a Gemini agent. Enter a competitor's name and your product's top differentiators. The agent searches the live web for their pricing page, reads G2 and Capterra reviews, scans for recent news, and synthesizes a structured battlecard grounded in what it actually found — not what an LLM guesses from training data.

The battlecard shows real pricing tiers, top customer complaints from actual reviews, a recent news summary, three talking points grounded in your differentiators, and one honest risk where the competitor is genuinely stronger. The full research trace is always visible so you can see exactly what the agent read and in what order.

![Battlecard screenshot placeholder](docs/screenshot-placeholder.png)

---

## Why I Built This

I'm building a multi-tenant competitive intelligence SaaS platform where sales and marketing teams track competitors across their entire organization. The core insight behind the product is that competitive intelligence from LLMs alone is unreliable: pricing changes, companies pivot, and training data is always stale.

The fix is grounding AI output in live sources via function calling. This demo isolates that single insight as a clean, open source Rails app anyone can clone and run in under 10 minutes.

This demo is MIT licensed. Clone it, fork it, extend it. If you improve it, open a PR.

---

## Quick Start

```bash
git clone https://github.com/your-handle/open-rivalgraph
cd open-rivalgraph
bin/setup
cp .env.example .env
```

Edit `.env` and add your API keys (see [Environment Variables](#environment-variables) below), then:

```bash
bin/rails db:seed
bin/rails server
```

Visit [http://localhost:3000](http://localhost:3000) and sign in with the demo credentials below.

---

## Demo Credentials

| Field | Value |
|---|---|
| Email | `demo@example.com` |
| Password | `password123` |
| Admin | Yes — access `/admin` for the AI template editor and request log |

The seed data includes a pre-populated Asana battlecard so you can see the output immediately without running the agent.

---

## Environment Variables

Copy `.env.example` to `.env` and fill in the required values.

| Variable | Required | Description |
|---|---|---|
| `GEMINI_API_KEY` | Yes | Google Gemini API key — get one free at [aistudio.google.com](https://aistudio.google.com/app/apikey) |
| `PERPLEXITY_API_KEY` | Yes | Perplexity API key for the web search tool — sign up at [perplexity.ai/settings/api](https://www.perplexity.ai/settings/api) |
| `APP_NAME` | No | Displayed in navbar and page title (default: `"Open Demo Starter"`) |
| `APP_TAGLINE` | No | Shown in footer |
| `APP_DESCRIPTION` | No | Shown on landing page |
| `AI_CALLS_PER_USER_PER_DAY` | No | Daily AI call budget per user (default: `50`) |
| `AI_GLOBAL_TIMEOUT_SECONDS` | No | Per-request timeout in seconds (default: `90` — the agent loop takes 30–90s) |

---

## How the Agent Works

Each battlecard is produced by a Gemini function-calling agent that follows a fixed research sequence:

1. `search_web("Asana pricing")` — finds the pricing page URL
2. `fetch_url("https://asana.com/pricing")` — reads actual current pricing tiers
3. `search_web("Asana reviews site:g2.com OR site:capterra.com")` — finds a review page
4. `fetch_url("https://g2.com/products/asana/reviews")` — reads real customer complaints
5. `search_web("Asana 2025 news OR funding OR launch")` — finds recent activity
6. Synthesizes everything into a structured JSON battlecard

The agent runs as a background job (Active Job with the async adapter in development). The show page subscribes to the job's progress via Turbo Streams and appends each step to a live feed as it completes.

---

## Editing the AI Prompt

The prompt that drives the research agent is stored as an editable template in the database. Sign in as `demo@example.com` and visit [/admin/ai_templates](http://localhost:3000/admin/ai_templates) to view and edit it. The admin template editor has a live test panel where you can enter sample variable values and run Gemini with the current draft without saving.

The template is named `rivalgraph_battlecard_v1`. Key settings:

| Setting | Value | Reason |
|---|---|---|
| Model | `gemini-2.5-flash` | Function calling support, fast, generous free tier |
| Temperature | `0.3` | Lower than default to reduce schema drift and pricing confabulation |
| Max output tokens | `3000` | The full JSON battlecard schema reliably exceeds the 2000-token default |
| Max tool rounds | `6` | Bounds cost; forces synthesis after 6 tool calls even if incomplete |

---

## Stack

| Layer | Choice |
|---|---|
| Framework | Rails 8.1 |
| Database | PostgreSQL with UUID primary keys |
| Auth | Rails native (`has_secure_password`, sessions) |
| CSS | Bootstrap 5 dark mode (CDN) |
| JavaScript | Stimulus + Turbo via importmap |
| AI | Google Gemini via `gemini-ai` gem |
| Web search | Perplexity API (`sonar` model) |
| URL fetching | HTTParty |
| Queue / Cache / Cable | Solid Stack (no Redis required) |
| Testing | RSpec |

---

## AI Safety Posture

**What this app enforces:**
- Per-user daily call cap (default: 50/day via `AI_CALLS_PER_USER_PER_DAY`)
- Pre-flight gatekeeper: input length limit, prompt injection pattern matching, profanity filter
- Hard output token cap per template
- Configurable request timeout
- Full request log with status, tokens, duration, and cost estimate (Admin → LLM Requests)
- Fail-soft UI: errors render an inline alert with a retry button, never crash the page
- AI disclaimer in the footer and inline on every battlecard
- Maximum of 6 tool call rounds per analysis run — prevents runaway cost on unresolvable searches

**Deliberate constraints on this demo:**
- No sharing or export beyond Markdown download — battlecards are local only
- No bulk scraping — the agent fetches at most 2–3 URLs per run
- `fetch_url` is only callable by the agent, never exposed to direct user input
- All battlecards show `researched_at` prominently — pricing data ages fast

---

## License

MIT — see [LICENSE](LICENSE)
