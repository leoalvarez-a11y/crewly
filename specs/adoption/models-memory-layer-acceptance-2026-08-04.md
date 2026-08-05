# Crewly Models and External Memory Layer Local Acceptance

Date: 2026-08-04
Baseline: `a11a964fbef818f2fc3c98402f501f3e5843918b`
Branch: `feat/crewly-models-memory-layer`

## Scope and boundaries

This acceptance covers only the additive per-agent provider/runtime/model policy and supplementary external Memory Layer. No Crewly component was removed, replaced, or reduced. CDNTeams and BOS were not accessed or integrated. Nothing was deployed to a VPS.

The evaluation ran in Docker Desktop's WSL2 Linux runtime with a repository-local isolated Crewly home. The product source remained the Windows checkout named above; temporary runtime dependencies and processes were isolated from it.

## Build and focused verification

- Full production build: backend TypeScript, frontend TypeScript/Vite, and CLI TypeScript passed.
- Model/runtime/persistence tests: seven focused backend suites passed, 338 tests total.
- UI acceptance tests: the new Team modal controls and Team member execution summary passed as focused Vitest cases.
- Native preservation tests: `memory.service`, `working-memory.service`, and `wiki.controller` passed, 118 tests total.
- Previously green essential acceptance inventory: all 25 previously-passing suites remained passing. The five known baseline-failing suites and the prior full baseline inventory of 66 suites / 276 failures remain documented in `local-acceptance-2026-08-04.md`; they were classified as unrelated and were not repaired.
- `git diff --check` passed. Production build emitted only the existing Vite large-chunk warning.

## Isolated four-agent acceptance

Crewly started with an isolated home at `evaluation-artifacts/crewly-home-adaptation-20260804`. Health and the existing dashboard API were available. A real persisted team (`0b540700-4df2-4328-a575-d37136c5f01a`) ran against the independent `evaluation-fixture-adaptation` repository:

| Agent | Requested configuration | Executed configuration | Recorded reason |
| --- | --- | --- | --- |
| Leader | OpenAI, Codex CLI, manual `openai/gpt-5.6-sol`, `balanced_reasoning` | `openai/gpt-5.6-sol` | `manual_override` |
| Developer | OpenAI, Codex CLI, automatic `strong_coding` | `openai/gpt-5.6-terra` | `automatic_cheapest_sufficient` |
| QA | OpenAI, Codex CLI, manual `openai/gpt-5.6-sol`, `deep_reasoning` | `openai/gpt-5.6-sol` | `manual_override` |
| Documentation | OpenAI, Codex CLI, manual `openai/gpt-5.6-terra`, external memory enabled | `openai/gpt-5.6-terra` | `manual_override` |

The versioned catalog selected `gpt-5.6-terra` for Developer because it was the available compatible `strong_coding` entry with the lowest relative cost tier. Actual PTY startup output contained `codex -a never -s danger-full-access --model gpt-5.6-sol` for the manual agents and the corresponding `--model gpt-5.6-terra` command for the automatic Developer and Documentation agents. Unknown token and cost values remained `null` and render as `No disponible`.

The Leader inspected and delegated native WorkItems for implementation, independent QA, and documentation. Developer repaired the invoice fixture quantity calculation. QA independently reviewed the diff and reported PASS. Documentation updated the fixture README. The final fixture command passed 2 of 2 tests.

## Supplementary Memory Layer and native preservation

No compatible MCP or local-command contract was present in the Crewly checkout. A configurable generic HTTP service boundary was therefore the least invasive detected interface. The local acceptance stub returned the sanitized reference `memory://crewly-adaptation/documentation-guidance`; Documentation received it and its execution receipt persisted `memoryLayerConsulted: true` plus that reference. The adapter remained disabled for agents without the opt-in flag.

The external layer was inserted after Crewly's native working-memory prompt module. Its context is bounded, deduplicated, redacted, reference-bearing, and explicitly treated as untrusted data. Disabled, timeout, malformed, and unavailable responses do not block prompt construction or task execution.

Native Crewly memory and Wiki continued operating during the same task. The Leader recorded native memory entry `d93760b5-018a-4ed3-ba97-6ef89c379a96`. The isolated native Wiki vault `acceptance-vault` accepted and retained `llm-curated/log.md`. Existing Wiki, project/agent memory, working memory, and memory-reference modules were not removed or semantically replaced.

## Final response and restart

The visible Leader response reported the code repair, README update, independent QA PASS, Documentation's memory reference, final 2/2 test result, native memory/Wiki recording, and successful completion. Parent WorkItem `9c172d23-6679-4de3-a8f4-ae8c3b0305ef` persisted as `done` with its result.

All four sessions were stopped cleanly. Crewly was stopped and restarted with the same isolated home. After restart, health was good; all four members retained provider, runtime, requested/executed model, selection reason, nullable telemetry, and inactive status; Documentation retained the external-memory receipt/reference; the completed parent WorkItem, native memory files, and Wiki page remained present.

## Review rounds and cleanup

1. Compatibility/persistence review: legacy members resolve to the native default without new runtime flags; optional fields round-trip through team storage and templates; existing runtime factory and ModelManager paths remain intact.
2. Security/failure review: runtime model IDs are allowlisted to safe CLI characters; external content is bounded/redacted/untrusted; only capability, context, rate-limit, model-unavailable, and timeout classes are fallback-eligible; network, credential, permission, tool, and unknown failures do not escalate.
3. Regression/scope review: full build and focused suites passed; native preservation suites passed; no tracked deletion, secret, BOS integration, CDNTeams code, VPS change, or unrelated baseline repair was introduced.

The isolated team sessions and Crewly backend were stopped. Disposable WSL2 evaluation processes, copied authentication material, container, and dependency volumes were removed after verification. The independent fixture and sanitized acceptance documentation remain as local reproducible evidence; no runtime-generated file is committed.
