# Local Crewly acceptance evidence

Date: 2026-08-04

Baseline: `a11a964fbef818f2fc3c98402f501f3e5843918b`

Planning branch: `plan/crewly-adoption-windows-vps`

Outcome: `LOCAL_CREWLY_ACCEPTANCE_PASS`

## Scope and platform

The complete upstream checkout was evaluated without removing dependencies, tests, routes, services, or product components. The official Windows runtime selected by this acceptance is WSL2. The reproducible test environment used the Docker Desktop WSL2 engine with a Debian-based Node.js 22 container, an isolated `CREWLY_HOME`, repository-local dependency volumes, and loopback-only dashboard exposure to Windows.

No production repository, BOS service, VPS, CDNTeams runtime, or globally configured Codex state was changed. The short-lived Codex authentication file used by the isolated runtime was not copied into this repository or retained in the evidence.

## Commands and acceptance results

The principal commands were:

```text
npm install
npm run build
npm run test:unit -- --forceExit --json --outputFile=<local-evidence>/baseline-unit-tests.json
npm run test:unit -- <30 essential suite paths> --forceExit --json --outputFile=<local-evidence>/essential-tests.json
npm start -- --port 8787 --no-browser
node --expose-gc --max-old-space-size=2048 dist/backend/backend/src/index.js
curl http://127.0.0.1:8787/api/health
npm test
```

The native CLI start command reached its 30-second client timeout during a cold WSL2 startup. The same compiled backend started successfully from an isolated home after approximately 47 seconds. This was recorded as an environment/startup repair, not hidden by changing product code. The health endpoint returned `status=healthy`, version `1.0.0`.

The `Crewly AI Studio` dashboard loaded from the Windows browser at the loopback URL. Its Dashboard, Projects, Teams, and related navigation rendered successfully. Browser access remained local and no public listener was created.

## Functional flow

A real three-member Crewly team was created with Codex CLI runtimes:

- Eva Leader: delegated implementation, accepted the developer evidence, required independent QA, and issued the final response.
- Dora Developer: corrected the fixture, added edge coverage, documented the behavior, and reported test evidence.
- Quinn QA: independently inspected the diff, ran the fixture tests, and issued an explicit `PASS` verdict.

The live PTY path created real Codex sessions, accepted input, routed Crewly messages, recorded task activity, and completed the targeted work items. The fixture changed a broken finite-number sum implementation, added a non-finite input test, and documented empty-array and non-finite behavior. Final verification was 2 passed tests, 0 failed, plus a clean diff check.

The final visible response recorded:

```text
Completed with explicit QA acceptance.
- Corrected sum() to add finite values and ignore NaN/infinities.
- Added a non-finite-values edge-case test.
- Documented behavior, including empty arrays returning 0.
- QA verdict: PASS; no repairs required.
- Final verification: 2/2 tests passed, git diff --check passed.
```

After stopping all three agent sessions, Crewly was stopped and restarted using the same isolated home. The project, team, three members, completed Developer and QA work items, Leader completion, result payloads, and QA verdict persisted. All members restored as inactive. The team was stopped again, the browser tab was closed, and the evaluation container and dependency volumes were removed. No Crewly product component was removed.

## Essential suites

The focused set contained 30 suites and 1,104 tests:

- 25 suites passed and 5 failed;
- 1,094 tests passed, 8 failed, and 2 were skipped;
- startup, configuration, storage, persistence, session, isolated PTY, team routes/controller, runtime factory, Codex runtime, task-pool services, request service, terminal WebSocket, and Chat V2 WebSocket coverage passed;
- the five failing suites matched already classified baseline issues: isolated-home path expectations, stale event/mock assertions, and Vitest route files invoked by Jest.

The three PTY suites that failed in the parallel baseline run passed in the focused isolated run and were also validated through real Codex PTYs.

## Complete baseline failure classification

The unmodified baseline reproduction produced 66 failed suites and 513 passed suites; 276 failed tests, 14,267 passed, 2 skipped, and 6 todo, for 14,551 tests total.

### Group A: Jest/Vitest runner incompatibility

14 suites, 0 executed failed assertions. Vitest-only tests or the `vi` namespace were invoked by Jest:

- `backend/src/services/v3/trigger-engine.service.test.ts`
- `backend/src/services/wiki/wiki-lint.service.test.ts`
- `backend/src/services/wiki/wiki-reflect-trigger.service.test.ts`
- `backend/src/controllers/request/request.controller.test.ts`
- `backend/src/services/wiki/wiki-backlinks.service.test.ts`
- `backend/src/services/ai/self-improvement/prediction-calibration.service.test.ts`
- `backend/src/services/ai/self-improvement/attention.service.test.ts`
- `backend/src/services/ai/self-improvement/growth-areas.service.test.ts`
- `backend/src/services/wiki/wiki-recent.service.test.ts`
- `backend/src/services/v3/request-tracker.service.test.ts`
- `backend/src/services/ai/self-improvement/memory-consolidation.service.test.ts`
- `backend/src/services/ai/self-improvement/self-model.service.test.ts`
- `backend/src/controllers/request/request.routes.test.ts`
- `backend/src/controllers/task-pool/task-pool.routes.test.ts`

### Group B: parallel PTY mock/platform interference

3 suites, 18 tests. These passed when isolated:

- `backend/src/services/session/pty/pty-session-backend.test.ts` (6)
- `backend/src/services/session/pty/pty-session.test.ts` (5)
- `backend/src/services/session/pty/pty-input-reliability.test.ts` (7)

### Group C: stale contracts, fixtures, or mocks

45 suites, 199 tests:

- `backend/src/services/chat-v2/chat-v2.service.test.ts`
- `backend/src/services/agent/runtime-exit-monitor.service.test.ts`
- `backend/src/services/ai/prompt-builder.service.test.ts`
- `backend/src/services/skill/skill-catalog.service.test.ts`
- `backend/src/services/session/session-handoff.service.test.ts`
- `backend/src/services/agent/agent-registration.service.test.ts`
- `backend/src/services/agent/agent-heartbeat-monitor.service.test.ts`
- `backend/src/controllers/chat-v2/chat-v2.controller.test.ts`
- `backend/src/services/slack/notify-reconciliation.service.test.ts`
- `backend/src/services/cloud/cloud-sync.service.test.ts`
- `backend/src/controllers/settings/settings.controller.test.ts`
- `backend/src/controllers/chat/chat.controller.test.ts`
- `backend/src/controllers/intent-task/intent-task.controller.test.ts`
- `backend/src/services/quality/quality-gate.service.test.ts`
- `backend/src/services/project/active-projects.service.test.ts`
- `backend/src/services/messaging/message-replay.service.test.ts`
- `backend/src/services/data/schema-registry.service.test.ts`
- `backend/src/services/chat-v2/sqlite/channel.store.test.ts`
- `backend/src/services/v3/escalation.service.test.ts`
- `backend/src/controllers/project/git.controller.test.ts`
- `backend/src/services/chat/chat.service.test.ts`
- `backend/src/services/monitoring/teams-json-watcher.service.test.ts`
- `backend/src/websocket/chat.gateway.test.ts`
- `backend/src/services/whatsapp/whatsapp-orchestrator-bridge.test.ts`
- `backend/src/types/messaging.types.test.ts`
- `backend/src/services/monitoring/system-resource-alert.service.test.ts`
- `backend/src/controllers/system/errors.controller.test.ts`
- `backend/src/controllers/project/project.controller.test.ts`
- `backend/src/services/slack/slack-orchestrator-bridge.test.ts`
- `backend/src/controllers/agent-status-workflow.test.ts`
- `backend/src/services/ai/prompt-modules/communication.module.test.ts`
- `backend/src/services/whatsapp/whatsapp-initializer.test.ts`
- `backend/src/controllers/marketplace/marketplace.routes.test.ts`
- `backend/src/services/chat-v2/types.test.ts`
- `backend/src/services/cloud/cloud-initializer.test.ts`
- `backend/src/controllers/types.test.ts`
- `backend/src/controllers/cloud/cloud.routes.test.ts`
- `backend/src/services/ai/prompt-modules/anti-pattern-role-coverage.test.ts`
- `backend/src/services/ai/prompt-modules/decision-rights-role-coverage.test.ts`
- `backend/src/services/v3/request-notification.service.test.ts`
- `backend/src/services/ai/prompt-modules/operating-principles-role-coverage.test.ts`
- `backend/src/controllers/monitoring/monitoring.routes.test.ts`
- `backend/src/services/observability/observability-db.test.ts`
- `backend/src/utils/skill-md-files.regression.test.ts`
- `backend/src/services/slack/reproduce_no_text.test.ts`

### Group D: optional integration unavailable in the evaluation environment

3 suites, 58 tests:

- `config/skills/agent/computer-use/tests/computer-use.test.ts` (37)
- `config/skills/agent/desktop-app-control/tests/desktop-app-control.test.ts` (20)
- `backend/src/services/browser/chrome-discovery.service.test.ts` (1)

### Group E: timing/chunk-boundary sensitivity

1 suite, 1 test:

- `backend/src/services/agent/oauth-relogin-monitor.service.test.ts` (1)

### Groups F and G

- Group F, confirmed product-blocking failures: 0 suites, 0 tests.
- Group G, unclassified failures: 0 suites, 0 tests.

No baseline failure was made green by deleting a component, removing a dependency, disabling a mechanism, or altering product code. The unrelated 276 baseline failures remain outside the adaptation scope.
