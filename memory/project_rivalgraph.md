---
name: RivalGraph Demo Build Plan
description: 10-phase implementation plan for RivalGraph — a competitive intelligence battlecard app built on Open Demo Starter v2.0
type: project
---

RivalGraph Demo is a competitive intelligence tool using a Gemini function-calling agent to research competitors and produce structured battlecards.

**Why:** Open-source demo of the author's multi-tenant SaaS platform. Core insight: AI from training data alone confabulates stale pricing; grounding via live web search (Serper.dev) and URL fetching (HTTParty) produces accurate output.

**Key files:**
- Full spec: `docs/open-rivalgraph/rivalgraph-demo-spec.md`
- Phase-by-phase implementation guide: `docs/open-rivalgraph/phase-specs.md`
- Progress tracker (checkboxes): `tasks.md`

**Architecture additions over boilerplate:**
- 3 new models: OwnProduct, Competitor, CompetitorAnalysis
- New service: `GeminiService.generate_with_tools` (agent loop with function calling)
- 2 new tool services: SearchWebTool (Serper.dev), FetchUrlTool (HTTParty)
- Background job: AgentRunJob (Solid Queue) — agent takes 30–90s, cannot be synchronous
- Live progress via Turbo Streams broadcasts from AgentRunJob
- Gem added: httparty
- New env vars: SERPER_API_KEY, AI_GLOBAL_TIMEOUT_SECONDS=90
- Accent color: #dc2626 (red)

**10 build phases:**
1. Project customization (env, gem, accent, navbar)
2. Data models + factories
3. OwnProducts CRUD
4. Competitors CRUD
5. GeminiService agent extension (most complex)
6. AgentRunJob + CompetitorAnalysesController
7. Analysis views + Turbo Streams progress
8. Home/dashboard overrides + seeds
9. README
10. Full test suite + end-to-end validation

**Critical implementation note:** Use `gemini-2.5-flash` (not `gemini-2.0-flash` as written in the original spec — that model is deprecated for new API keys).

**How to apply:** Reference tasks.md for current progress. Always check which phase is next before starting work.
