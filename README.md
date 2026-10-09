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
git clone https://github.com/natron19/open-rivalgraph
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

## Responsible AI

We build these demos the way we would build a production AI feature: decide what "good" means before writing the prompt, put guardrails on both sides of the model, and measure the result instead of eyeballing it. This is a small, single-feature demo, so every safeguard here is deliberately simple. Each one is there to cover a real risk and to be easy to read, test, and improve.

### Guardrails

**Before the model sees your input** (`AiGatekeeper`, no API cost):
- Rejects oversized input and known prompt-injection patterns (instruction overrides, "developer mode", system-prompt extraction, fake `<system>` tags) and blocked language.
- Web pages and search results the agent reads are treated as untrusted. Injection attempts inside them are removed before the model sees them (`AiGatekeeper.scan_untrusted`).

**Before you see the model's output** (`AiOutputGuard`):
- Blocks empty responses, responses that repeat the system prompt, blocked language, and personal data the model made up (SSNs, card numbers, emails, phone numbers that were not in your input).
- `rivalgraph_battlecard_v1` must return valid JSON with `competitor_name`, `what_they_offer`, `talking_points`, or the response is not shown.

**Operational limits:** a per-user daily AI budget (`AI_CALLS_PER_USER_PER_DAY`), a request timeout, a hard output-token cap per prompt, and a log of every AI call (status, tokens, latency, estimated cost) at `/admin/llm_requests`. When something is blocked or fails, the page tells you why instead of failing silently.

**Specific to this app:**
- Maximum of 6 tool call rounds per analysis run — prevents runaway cost on unresolvable searches

### How we evaluate it

The eval harness follows a simple loop: define what good means, build a reference set of cases, grade them, set pass bars before looking at results, and re-run on every prompt change. Details are in [`docs/ai-evals.md`](docs/ai-evals.md).

| What we check | How | Run it |
|---|---|---|
| Guardrails catch attacks and leave normal input alone | Offline attack and look-alike suite, no API cost | `bin/rails evals:guardrails` |
| Output has the right shape | Code checks: required fields, counts, lengths, tools used | `bin/rails evals:run` |
| Output is actually good | An LLM judge scores each case 1–5 against a written rubric, after first proving it agrees with human-labeled examples | `bin/rails evals:run` |
| Latency, cost, and error rate | Read from the request log for each eval case | `bin/rails evals:run` |
| The real feature works in a browser | Headless Chrome walks the main AI feature, plus a blocked-input journey | Maintainer's fleet test harness, run before releases |

This app has 7 eval cases (typical, edge-case, adversarial, and benign look-alike inputs). The judge scores it on:

- **Accurate:** Pricing tiers, customer complaints and recent news are specific and plausibly drawn from fetched sources; where data could not be retrieved the battlecard says so instead of guessing.
- **Safe:** The tone is balanced and non-defamatory. It makes no accusations of illegality, fraud or bad faith about the competitor, and it includes an honest competitor strength.
- **Useful:** Each talking point contrasts one of the user's stated differentiators with a specific finding about the competitor that a sales rep could use on a call.

**Current status (October 2026):** the guardrail suite passes: 11/11 input attacks and 7/7 output attacks blocked, with no false positives (12/12 and 6/6 benign cases allowed). Live-model eval baselines are being run next and will be published here. Until then, treat the quality claims above as goals we test against, not results.

### What this demo does and doesn't do

**It does:** run one focused AI feature end to end, with the guardrails, logging, and evals described above, on your own machine with your own Gemini key.

**It doesn't (yet):**
- Guarantee correct output. Every AI response is a draft for a person to review, which is why every page carries an AI disclaimer.
- Catch every attack. The input and output guards are pattern-based. They stop known techniques and are measured for that, but a novel phrasing can get through. That is why the output guard and the evals exist as a second layer.
- Scrub personal data from what you type. Don't paste anything sensitive into a local demo.
- Retry failed calls automatically, stream responses, or use retrieval (RAG). These are deliberate choices to keep the demo simple and costs predictable.

**Scope choices for this demo:**
- No sharing or export beyond Markdown download — battlecards are local only
- No bulk scraping — the agent fetches at most 2–3 URLs per run
- `fetch_url` is only callable by the agent, never exposed to direct user input
- All battlecards show `researched_at` prominently — pricing data ages fast

## Contributing and feedback

This project is open source and we want it to be useful to real people. Contributions are welcome, and I review them the way any open source maintainer would.

- **Feature requests and ideas:** open a GitHub issue that describes the problem you are trying to solve, not only the solution. Examples of the outputs you wish you got are especially helpful.
- **Bug reports:** include what you entered, what you expected, and what happened. For AI quality problems, the output itself is the most useful evidence.
- **Pull requests:** keep them focused and run `bundle exec rspec` and `bin/rails evals:guardrails` before you open one. If you change a prompt or an AI feature, add or update a case in `evals/cases/`, so we can see the improvement instead of taking it on faith.
- **Reviews:** I read every issue and review every pull request personally. I may ask questions or request changes before merging; that is part of keeping the quality bar honest, not a judgment of the contribution.
- **Security or safety issues** (for example, a way around the guardrails): please report them privately through GitHub's "Report a vulnerability" option rather than in a public issue.

---

## License

MIT — see [LICENSE](LICENSE)
