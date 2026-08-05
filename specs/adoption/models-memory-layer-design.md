# Per-agent models and external Memory Layer design

## Inspected baseline flow

- `TeamMember` is defined in `backend/src/types/index.ts` and mirrored in `frontend/src/types/index.ts`. `runtimeType` is required after load; `modelId` is optional and currently only consumed by `crewly-agent`.
- `TeamModel.fromJSON()` in `backend/src/models/Team.ts` preserves unknown optional member properties and supplies only the legacy `runtimeType=claude-code` default. `StorageService.getTeams()` and `saveTeam()` persist the complete member objects as JSON, so additive optional properties round-trip without a destructive migration.
- Team creation and editing are handled by `TeamModal.tsx` and `team.controller.ts`. The modal currently exposes runtime and a Crewly-Agent-only model dropdown, but its submit mapper omits `modelId`; the controller creation/update mappers also omit it.
- Templates use `TemplateRole.runtimeOverride` and `TeamTemplate.defaultRuntime` in `team-template.types.ts`. `template.controller.ts` materializes those values into normal members, so optional template execution fields can be added without replacing the existing defaults.
- `AgentRegistrationService.createAgentSession()` resolves the persisted member runtime, creates a runtime through `RuntimeServiceFactory`, and passes runtime flags into the existing initialization path. `RuntimeServiceFactory` remains the authority for choosing the Claude, Gemini, Codex, or Crewly-Agent adapter.
- `ModelManager` in `packages/crewly-agent/src/runtime/model-manager.ts` remains the provider SDK factory for the in-process runtime. The adaptation supplies a resolved model configuration to that existing manager; it does not replace it.
- API-key configuration remains in the existing settings service and runtime environment injection. New catalog configuration is non-secret and must never contain credentials.
- Existing token parsing and budget services remain authoritative. The new execution receipt accepts nullable tokens and cost instead of manufacturing values when a runtime does not report them.
- Native memory lives under `backend/src/services/memory`; native Wiki lives under `backend/src/services/wiki`; `memory-reference.module.ts` preserves the existing routing rules; `working-memory.module.ts` preserves the fail-soft wake card. None is removed or reinterpreted.
- Production prompts use `PromptBuilderService` -> `PromptAssemblyService`. A new compactable module is the minimum live extension point for supplementary external context.

## Minimum additive extension

1. Add optional per-member execution fields while leaving `runtimeType` and `modelId` semantics intact.
2. Add a versioned JSON model catalog and a deterministic selector that runs before runtime initialization. An explicit `modelId` always wins; otherwise the lowest available `relativeCostTier` satisfying the declared capability class wins.
3. Translate the selected model into the existing CLI model flag or the existing Crewly-Agent `ModelManager` input. Keep `RuntimeServiceFactory` unchanged.
4. Persist a sanitized execution receipt on the member for dashboard and restart visibility. Missing tokens/cost remain `null`.
5. Add `ExternalMemoryLayerAdapter` as an HTTP-service adapter configured only through environment variables. The detected machine interface is a service URL plus credential variable; because BOS integration is explicitly out of scope, acceptance uses a local non-production stub and never reads or sends the pre-existing BOS credential.
6. Add a compactable, fail-soft prompt module after native memory/working-memory modules. It queries only when `memoryLayerEnabled=true`, caps and deduplicates snippets, redacts secret-like values, records references and latency, and returns an empty section on failure.
7. Expose the optional fields in the existing team modal and member row; do not create another dashboard.

## Compatibility and precedence

Resolution precedence is:

1. explicit member `modelId` (`manual_override`);
2. template-supplied `modelId` carried into the member;
3. automatic selection from `capabilityClass`;
4. native Crewly/runtime default when no new field is present.

Legacy members load exactly as before. Undefined `provider`, `capabilityClass`, `optionalFallbackModel`, `optionalBudget`, and `memoryLayerEnabled` do not alter startup. Existing templates without new fields continue to materialize their original runtime configuration.

## Fallback policy

Fallback is allowed only after an objective classification of insufficient capability, context limit, rate limit, model unavailability, or timeout. Network, credential, permission, and tool failures are explicitly non-escalating. Every decision records requested/executed provider, runtime and model, selection reason, fallback flag/classification, nullable telemetry, and the catalog version.

## External Memory Layer boundary

The adapter accepts objective, task, role, and project and sends a bounded query to a configured HTTP service. Responses are normalized into `{content, reference}` snippets. Duplicate normalized content is removed; secret/token/key/password-like material and bearer tokens are redacted; both snippet count and total characters are capped. Only status, duration, and sanitized references are logged. Failure returns a non-blocking status and native prompt assembly continues.
