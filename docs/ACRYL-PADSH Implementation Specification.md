# ACRYL-PADSH Implementation Specification

## Prime Agent × Cordis × DeepSeek Harness Architectural PoC

**Project:** `acryl-padsh`  
**Repository:** `inboxxobni/acryl-padsh`  
**Temporary purpose:** experimental proof-of-concept before successful components are upstreamed/migrated into `acryldev/acryl`.

**Primary upstreams / architectural sources**

- `PrimeIntellect-ai/prime-agent`
- `earendil-works/pi`
- `deepseek-ai/deepseek-harness`
- existing `acryldev/acryl`

**License target:** MIT.

---

# 1. Mission

Create an experimental fork of Prime Agent that combines:

1. **Prime Agent's long-running RLM architecture**
   - persistent Python REPL;
   - recursive/background agents;
   - daemon-backed resident sessions;
   - direct agent messaging;
   - goals;
   - heartbeats/schedules;
   - autonomous mode;
   - Continual Harness;
   - Python-backed skills;
   - Pi-compatible TypeScript extensions and `/reload`.

2. **Cordis as the internal composition and lifecycle framework**
   - everything important represented as a plugin or service;
   - explicit capability dependencies;
   - reversible effects;
   - hot replacement;
   - service isolation;
   - per-agent scopes;
   - typed event buses and waterfall interception;
   - declarative runtime composition.

3. **The most valuable architectural ideas from DeepSeek Harness**
   - capability seams;
   - deterministic prompt and tool assembly;
   - Monotonic Prompt Architecture, defined below;
   - cache-conscious request construction;
   - append-only/event-sourced model-visible state;
   - reconstructable requests;
   - typed guarded tool pipeline;
   - programmatic tool/capability mode;
   - cache-aware compaction;
   - dynamic Cordis self-extension;
   - agent presets;
   - provider-neutral subagent/runtime interfaces;
   - output spilling;
   - guarded file mutation;
   - sandbox/approval policies;
   - session querying and diagnostics;
   - background jobs/workflows;
   - semantic LSP seam.

4. **Selected proven architecture from the existing ACRYL experiment**
   - host-neutral Cordis control plane;
   - provider-neutral agent control;
   - durable session/control boundaries;
   - multi-surface separation;
   - capability composition patterns.

The goal is **not** to run DeepSeek Harness inside Prime Agent.

The goal is to make Prime Agent inherit DSH's best architectural properties while retaining Prime's superior RLM/long-running-agent behavior.

---

# 2. Fundamental architectural decision

Do **not** build:

```text
DeepSeek Harness
      ↓
Prime Agent
      ↓
ACRYL
```

Do **not** build:

```text
Prime Agent
      ↓
embedded DSH runtime
      ↓
ACRYL
```

Build:

```text
                         ACRYL-PADSH
                              │
              ┌───────────────┴───────────────┐
              │                               │
        PRIME EXECUTION                 CORDIS COMPOSITION
              │                               │
        AgentSession                    services/plugins
        daemon worker                   effects/fibers
        RLM Python                      scopes/events
        subagents                       configuration
        goals                           lifecycle
        schedules                            │
              │                              │
              └──────────────┬───────────────┘
                             │
                       ACRYL RUNTIME
                             │
                  ┌──────────┴───────────┐
                  │                      │
            MPA Prompt Runtime     Capability Runtime
                  │                      │
                  └──────────┬───────────┘
                             │
                           LLM
```

Prime remains the execution host.

Cordis becomes the composition/runtime substrate.

ACRYL-owned services mediate between them.

---

# 3. Preserve Prime Agent

The following Prime systems MUST initially remain intact.

Do not rewrite them during the first PoC:

```text
packages/ai
packages/agent
packages/tui

Prime AgentConnection
Prime daemon supervisor
Prime resident session workers
Prime AgentSession
Prime Python kernel
Prime RLM child lifecycle
Prime skills
Prime TypeScript extensions
Prime /reload
Prime Continual Harness
Prime goals
Prime autonomous mode
Prime schedules/heartbeats
Prime provider integrations
```

Prime explicitly supports daemon-backed sessions, persistent Python, recursive agents, skills, refinement, goals and long-running work. 

## Critical implementation rule

**Do not begin by refactoring `agent-session.ts`.**

Prime currently concentrates substantial runtime behavior there. Replacing it before proving the new seams would turn this experiment into a rewrite.

Instead use:

```text
Prime implementation
       │
       ▼
ACRYL adapter
       │
       ▼
Cordis service
```

Then gradually invert ownership only after parity is proven.

---

# 4. Innovations matrix

The coding agent should treat this table as the feature inventory.

| Innovation | Origin | ACRYL-PADSH action |
|---|---|---|
| Persistent RLM Python | Prime | KEEP |
| Resident daemon workers | Prime | KEEP |
| Durable RLM children | Prime | KEEP |
| Pi TS extensions | Pi/Prime | KEEP |
| `/reload` | Pi/Prime | KEEP |
| Python-backed skills | Prime | KEEP |
| Continual Harness | Prime | KEEP, integrate with MPA |
| Goals/autonomy | Prime | KEEP |
| Cordis Context | DSH/Cordis | ADD |
| Services + `inject` | DSH/Cordis | ADD |
| Effects/fibers | DSH/Cordis | ADD |
| Typed events | DSH/Cordis | ADD |
| Waterfall interception | DSH/Cordis | ADD |
| `extend/isolate/intercept` | DSH/Cordis | ADD |
| HMR-aware plugin tree | DSH/Cordis | ADD |
| Capability seams | DSH | ADD |
| Declarative profiles/patches | DSH | ADD, simplified |
| Event-sourced sessions | DSH | ADD shadow-first |
| Reconstructable requests | DSH | ADD |
| Deterministic prompt ordering | DSH | ADD |
| Deterministic tool ordering | DSH | ADD |
| Append-only context | DSH | ADD |
| Cache-aware compaction | DSH | ADD |
| MPA | ACRYL synthesis of DSH principles | ADD |
| Tool execution pipeline | DSH | ADD |
| Programmatic tool mode/PTC idea | DSH | ADAPT to Prime Python |
| Dynamic Cordis plugins | DSH | ADD |
| Provider-neutral subagents | DSH + existing ACRYL | ADD |
| Sandboxing/approval seam | DSH | ADD later |
| Output spill | DSH | ADD |
| Read-before-write freshness | DSH | ADD |
| Session search/query | DSH | ADD |
| LSP seam | DSH | ADD later |
| Generic background jobs | DSH | MERGE with Prime concepts |
| Dynamic workflows | DSH | ADD later |

---

# 5. Cordis is the foundational change

DeepSeek Harness's strongest architectural idea is not an individual tool.

It is:

> there is no privileged feature core that every capability must patch.

DSH expresses sessions, tools, LLM adapters, the agent loop and other capabilities as plugins/services. Extension plugins depend on capability definitions rather than concrete implementations. 

Implement the same property in ACRYL-PADSH.

---

# 6. Cordis Worker Runtime

## 6.1 Context ownership

Create **one root Cordis context per Prime resident worker tree**.

Do not create it in the TUI.

Do not create it in the daemon supervisor.

```text
Prime supervisor
      │
      ▼
resident worker
      │
      ├── Root AgentSession
      ├── Python kernel
      ├── RLM children
      │
      └── AcrylRuntimeHost
              │
              ▼
         Root Cordis Context
```

This matches Prime's existing lifecycle:

```text
terminal closes
       ↓
TUI detaches

worker remains
       ↓
Cordis remains
       ↓
plugins remain
       ↓
Python remains
       ↓
children remain
```

---

# 7. `AcrylRuntimeHost`

Add an ACRYL-owned integration object.

Suggested location initially:

```text
packages/coding-agent/src/acryl/runtime/
```

Do not prematurely create ten npm packages.

Start:

```text
src/acryl/
├── runtime/
├── cordis/
├── prompt/
├── session/
├── capabilities/
├── extensions/
├── diagnostics/
└── adapters/
```

Extract packages after the PoC proves boundaries.

Core interface:

```ts
interface AcrylRuntimeHost {
  readonly ctx: Context

  mountSession(
    session: AgentSession,
    metadata: AcrylAgentMetadata,
  ): Promise<AcrylSessionRuntime>

  dispose(): Promise<void>
}
```

`mountSession()` creates an agent child context.

```text
WorkerContext
   │
   ├── RootAgentContext
   │       ├── RLMChildContext A
   │       └── RLMChildContext B
   │
   └── shared worker services
```

---

# 8. Cordis concepts that MUST be implemented

## 8.1 Services

A runtime capability has a stable name:

```ts
ctx.acrPrompt
ctx.acrCapabilities
ctx.acrSessionLog
ctx.acrAgentControl
ctx.acrSandbox
ctx.acrApproval
ctx.acrJobs
ctx.acrQuery
```

Consumers ask for the capability.

They MUST NOT import a specific implementation.

Example:

```ts
export const inject = ['acrCapabilities']

export function apply(ctx: Context) {
  ctx.acrCapabilities.register(...)
}
```

Cordis holds a consumer in `PENDING` until its declared dependencies are present and automatically unloads/reloads the consumer if a required service disappears.

---

# 9. Effects

Every plugin-owned side effect must be owned by its Fiber.

Use `ctx.effect()` for:

```text
event subscriptions
file watchers
timers
Python bridge handlers
daemon listeners
IPC listeners
temporary files
registered capabilities
registered prompt blocks
registered providers
background jobs
```

Example:

```ts
ctx.effect(() => {
  const off = prime.on(...)
  return () => off()
})
```

Do not manually scatter cleanup across shutdown paths.

Cordis effects guarantee that unloading a plugin unwinds its registrations/resources; child plugins unload recursively.

---

# 10. Fiber lifecycle

Every plugin instance must have the lifecycle:

```text
PENDING
   ↓
LOADING
   ↓
ACTIVE
   ↓
UNLOADING
   ↓
DISPOSED

LOADING ─────→ FAILED
```

Expose this state in diagnostics.

Add:

```text
/acryl-runtime
```

or equivalent debugging command showing:

```text
plugin
fiber state
missing dependencies
service registrations
effects
children
```

This should make:

> “why didn't this plugin start?”

answerable without reading logs.

---

# 11. Context scoping

Implement and actively use:

```text
ctx.extend()
ctx.isolate()
ctx.intercept()
```

Cordis allows child contexts to inherit the parent while isolating selected services or intercepting service configuration.

Use these for:

### Per-agent configuration

```text
worker context
   │
   ├── root agent
   │   model = Claude
   │   tool policy = coding
   │
   └── reviewer agent
       model = DeepSeek
       tool policy = read-only
```

### Per-agent tool visibility

### Per-agent prompt composition

### Per-agent sandbox policy

### Per-agent subagent provider

### Per-agent preset/persona

No global mutable singleton should be necessary for those concerns.

---

# 12. Typed Cordis events

Services are for direct capability calls.

Events are for cross-cutting behavior.

Create typed events such as:

```ts
interface Events {
  'acr/session/event'(...): void

  'acr/agent/pre-step'(...): Promise<...>
  'acr/agent/request'(...): Promise<...>
  'acr/agent/requested'(...): void

  'acr/tool/pre-execute'(...): Promise<...>
  'acr/tool/execute'(...): Promise<...>
  'acr/tool/post-execute'(...): Promise<...>
  'acr/tool/result'(...): void

  'acr/prompt/assembled'(...): void
  'acr/cache/epoch-changed'(...): void

  'acr/approval/request'(...): Promise<...>
}
```

---

# 13. Waterfall interception

Implement DSH's waterfall pattern for decisions.

Example:

```text
tool call
   ↓
permission plugin
   ↓
sandbox plugin
   ↓
timeout plugin
   ↓
metrics plugin
   ↓
actual execution
```

Each middleware either:

```ts
return next()
```

or deliberately short-circuits.

Use waterfalls for:

```text
model request modification
approval decisions
tool policy
context injection
retry policy
sandbox escalation
```

Cordis waterfalls support transformation and deliberate veto/short-circuit semantics.

---

# 14. Capability Seam Architecture

This DSH principle MUST become an ACRYL architecture rule.

A capability has up to three roles:

```text
1. Service Definition
2. Service Provider
3. Consumer
```

DSH uses this specifically so changing a provider does not force changes to the model-facing contract. 

Example:

```text
FileSystem capability

Service Definition
    AcrylFileSystem

Providers
    LocalFsProvider
    SandboxFsProvider
    RemoteFsProvider

Consumers
    Python capability gateway
    optional native read/edit tools
```

Never write:

```text
tool
  ↓
LocalFsImplementation
```

Write:

```text
tool
  ↓
FileSystem service
  ↓
selected provider
```

---

# 15. Preserve Prime/Pi TypeScript extensions

Prime still has the Pi TypeScript extension system.

Do not replace it.

Create:

```text
PrimeExtensionAdapter
```

which bridges existing Prime registrations into Cordis ownership where practical.

Target experience must continue working:

```text
agent writes TypeScript extension
        ↓
/reload
        ↓
extension loaded
```

Prime's current extension API still exposes tools, lifecycle events, commands, UI elements and runtime `reload()`. 

---

# 16. `/reload` becomes a unified reload transaction

Eventually `/reload` should perform:

```text
/reload
   │
   ├── reload Pi/Prime TS extensions
   ├── reload skills
   ├── reload prompt files
   ├── reload ACRYL Cordis composition
   └── reload project Cordis plugins
```

Requirements:

1. old Fiber enters `UNLOADING`;
2. all effects unwind;
3. registrations disappear;
4. new plugin code loads;
5. dependencies resolve;
6. dependent plugins restart;
7. request-cache epoch changes only if model-facing ABI changed.

---

# 17. Declarative Cordis configuration

Implement a simplified DSH-style plugin tree.

Initial:

```text
.acryl/
├── cordis.yml
├── cordis.patch.yml
└── plugins/
```

Core distribution:

```text
config/
├── base.cordis.yml
└── profiles/
    ├── default/
    ├── minimal/
    └── research/
```

Composition order:

```text
base
 ↓
profile
 ↓
project patch
 ↓
user patch
 ↓
CLI patch
```

Rows MUST have stable `id`s.

Example:

```yaml
- id: capabilities
  name: ./plugins/capabilities.ts

- id: session-log
  name: ./plugins/session-log.ts

- id: cache-observer
  name: ./plugins/cache-observer.ts
```

Stable row IDs allow HMR/recomposition to distinguish updates from remove+add operations. Cordis's Loader already relies on this model.

Add:

```text
acryl-padsh --dump-config
```

It should print the final effective plugin tree.

---

# 18. Monotonic Prompt Architecture — MPA

## 18.1 Definition

In this project, **MPA** means:

> During one cache epoch, once model-facing prompt content has been emitted, previously emitted prefix content must never be modified, reordered or regenerated differently unless an explicit cache-breaking transition occurs.

Instead:

```text
existing context
      +
new information
      ↓
APPEND
```

not:

```text
rebuild entire prompt from current mutable state
```

DSH already documents that append-only session surface entries preserve reusable prefixes, while replacements invalidate reuse from the first shadowed message. 

---

# 19. MPA is an invariant, not a provider promise

Do NOT state:

```text
ACRYL guarantees a 97% provider cache hit rate.
```

Provider eviction, routing, TTLs and cache implementation are external.

Guarantee this instead:

```text
When no cache-epoch-changing event occurs,
ACRYL will preserve the complete previously emitted
request prefix exactly and only append new model-visible content.
```

Provider cache hit rate is an outcome to measure.

Real DSH workloads have reported >98% cache-hit ratios, and ordering alone has been measured producing roughly 42% versus 99.8% reuse in one controlled experiment.

Our performance target is therefore:

```text
90–97%+ provider cache reuse
during stable long-running coding sessions
where the provider/cache route supports it.
```

But CI tests structural prefix stability rather than pretending to control provider caches.

---

# 20. Replace Prime's monolithic prompt construction with blocks

Prime currently builds system text by combining RLM doctrine, subagent guidance, harness state, MCP information, project context, skills and appended prompt material. 

Introduce:

```ts
interface PromptBlock {
  id: string
  source: string

  plane:
    | 'system'
    | 'context'
    | 'history'

  stability:
    | 'immutable'
    | 'epoch'
    | 'append-only'
    | 'ephemeral-tail'

  order: number
  content: ModelContent
  hash: string
}
```

And:

```ts
interface PromptSnapshot {
  epoch: string
  blocks: readonly PromptBlock[]
  systemHash: string
  toolHash: string
  historyHash: string
}
```

---

# 21. Prompt planes

The request should be constructed approximately as:

```text
┌──────────────────────────────────────┐
│ IMMUTABLE GLOBAL PREFIX              │
│                                      │
│ Prime/ACRYL identity                 │
│ RLM programming doctrine             │
│ stable capability ABI                │
│ immutable behavioral rules           │
├──────────────────────────────────────┤
│ PROJECT-STABLE PREFIX                │
│                                      │
│ stable AGENTS.md                     │
│ project conventions                  │
│ accepted durable harness knowledge   │
├──────────────────────────────────────┤
│ STABLE TOOL INTERFACE                │
│                                      │
│ deterministic native schemas         │
├──────────────────────────────────────┤
│ INITIAL CONTEXT                      │
│                                      │
│ deterministic workspace context      │
│ skill catalogue                      │
│ session startup context              │
├──────────────────────────────────────┤
│ USER PROMPT                          │
├──────────────────────────────────────┤
│ ASSISTANT / TOOL / CONTEXT EVENTS    │
│                                      │
│ append only                          │
├──────────────────────────────────────┤
│ CURRENT TURN                         │
└──────────────────────────────────────┘
```

---

# 22. Deterministic ordering is mandatory

Every source of repeated prompt content requires a canonical order.

For prompt sections:

```text
order
then stable name
```

For tool schemas:

```text
explicit configured order
or canonical lexicographic fallback
```

For skills:

```text
stable identifier
```

For capability catalogs:

```text
stable identifier
```

For project files:

```text
well-defined path/order rules
```

Never depend on:

```text
Map insertion timing
plugin startup race
filesystem enumeration order
object property accident
```

DSH's system-prompt subsystem explicitly canonicalizes section and tool ordering for this reason. 

---

# 23. Cache epochs

Some changes legitimately break prefix identity.

Introduce:

```ts
interface CacheEpoch {
  id: string
  fingerprint: string
  reason: CacheEpochReason
}
```

Fingerprint should include at minimum:

```text
provider
model
base-prompt-version
stable project prompt hash
model-facing tool schema hash
model-facing runtime ABI version
```

Epoch-breaking changes include:

```text
model/provider switch
base prompt upgrade
native tool schema change
native tool order change
project stable prompt rebuild
AGENTS.md promoted into stable prefix
major capability ABI change
compaction surface replacement
```

Append-safe events do NOT bump the epoch:

```text
new user prompt
assistant response
tool call
tool result
agent message
goal progress update
test result
new runtime observation
dynamic context update
new Cordis capability hidden behind stable Python ABI
```

---

# 24. Supersede by append

Never rewrite an earlier dynamic context message merely because its state changed.

Example:

BAD:

```text
SYSTEM:
Goal: build auth

then mutate to:

SYSTEM:
Goal: build auth, tests failing
```

GOOD:

```text
<context type="goal" version="1">
Build auth
</context>

...

<context type="goal" version="2" supersedes="1">
Tests currently failing: ...
</context>
```

The model interprets the latest version.

The previous token sequence remains unchanged.

---

# 25. Stable context MUST precede variable first prompts

On first turn:

BAD:

```text
user prompt
AGENTS.md
skill catalogue
runtime context
```

GOOD:

```text
AGENTS.md
skill catalogue
stable runtime context
user prompt
```

This matters for **cross-session prefix reuse** in the same repository.

DSH community measurements demonstrated how placing identical context after a variable first prompt destroyed otherwise reusable cache prefix.

---

# 26. Request monotonicity guard

Implement a developer/runtime diagnostic:

```ts
assertMonotonicRequest(previous, next)
```

For an append-safe transition:

```text
previous request prefix
MUST equal
the same range in next request
```

If not:

```text
MPA VIOLATION

firstDifference:
  plane: tools
  block: capability:foo
  previousHash: ...
  currentHash: ...

reason:
  tool enumeration order changed
```

In tests:

```text
throw
```

In production:

```text
log diagnostic
mark unexpected epoch break
```

---

# 27. Capture actual request shape

Instrument the last boundary before the provider API call.

Record:

```ts
interface RequestShape {
  requestId: string
  epoch: string

  provider: string
  model: string

  systemHash: string
  toolHash: string

  messageIds: readonly string[]

  estimatedTokens: number

  lcpTokensWithPrevious?: number
  lcpRatioWithPrevious?: number

  firstDifference?: RequestDifference
}
```

Do not derive cache diagnostics only from the internal prompt builder.

Capture the **actual request handed to the adapter**.

---

# 28. Cache diagnostics command

Implement:

```text
/cache
```

or:

```text
/acryl-cache
```

Output:

```text
Epoch:              12
Provider:           deepseek
Model:              deepseek-v4
Input tokens:       61,442
Provider cache read:58,912
Provider hit ratio: 95.9%

Structural prefix reuse:
  system            100%
  tools             100%
  previous history  100%

First difference:
  message[47]
  new user/context block
```

Also expose JSON for benchmark scripts.

---

# 29. Stable model-facing ABI

This is one of the most important combined Prime + DSH ideas.

Dynamic capabilities MUST NOT automatically become new native schemas.

Otherwise:

```text
Cordis plugin loaded
      ↓
new tool schema
      ↓
tool prefix changes
      ↓
cache epoch broken
```

Instead keep a stable programmable bridge.

Prime already has exactly the ideal host for this:

```text
ipython
```

Expose:

```python
await acryl.capabilities.list()
await acryl.capabilities.describe("filesystem.search")
await acryl.capabilities.call(
    "filesystem.search",
    {"query": "AgentSession"}
)
```

Model-visible tool schema:

```text
ipython
```

remains unchanged.

Cordis capabilities may change underneath it.

---

# 30. Core ACRYL invariant

Document prominently:

> **Capabilities may evolve dynamically. The model-facing ABI should not.**

A new capability behind:

```python
acryl.capabilities.call(...)
```

does not require a prompt epoch.

A new native JSON tool does.

---

# 31. Typed host-request bridge

Use Prime's existing Python ↔ TypeScript host-request pattern.

Add operations like:

```text
acryl.capability.list
acryl.capability.describe
acryl.capability.call

acryl.cordis.inspect
acryl.cordis.define
acryl.cordis.run
acryl.cordis.stop

acryl.session.query
acryl.agent.list
acryl.agent.message
```

TypeScript remains authoritative.

Python is only the programmable model-facing control layer.

---

# 32. Capability Runtime

Create:

```ts
interface AcrylCapabilityDefinition<I, O> {
  name: string
  description: string

  input: JsonSchema
  output: JsonSchema

  executionMode:
    | 'parallel-safe'
    | 'exclusive'

  timeoutMs?: number

  execute(
    input: I,
    execution: AcrylExecutionContext,
  ): Promise<O>
}
```

Cordis service:

```ts
ctx.acrCapabilities
```

Methods:

```ts
register()
list()
describe()
get()
execute()
restrict()
guard()
```

---

# 33. DSH-style tool execution pipeline

Every capability/tool execution should eventually flow through:

```text
arguments received
       ↓
validate
       ↓
freeze arguments
       ↓
pre-execute waterfall
       ↓
monotonic guards
       ↓
execution wrappers
       ↓
provider execute
       ↓
post-execute
       ↓
result finalization
       ↓
spill policy
       ↓
immutable result
       ↓
observe-only result event
```

DSH's tool runtime uses this exact separation between policy, execution wrappers, result transformation and final observation. 

---

# 34. Monotonic security guards

Policy denial must be monotonic.

If a strict guard says:

```text
DENIED
```

a later plugin must not be able to change it into:

```text
ALLOW
```

Use:

```text
extensible pre-execute waterfall
         ↓
monotonic hard guards
         ↓
execution
```

Hard policy belongs after flexible extension hooks.

---

# 35. Parallel-safe versus exclusive tools

Every capability should optionally classify itself.

Example:

```text
read file             parallel-safe
grep                  parallel-safe
LSP query             parallel-safe

write file            exclusive
git commit            exclusive
database mutation     exclusive
```

Scheduling rule:

```text
parallel-safe calls
       ↓
bounded pool

exclusive call
       ↓
ordering barrier
```

DSH uses this to parallelize safe calls while preserving mutation order. 

---

# 36. PTC / Code Mode idea

DSH's PTC mode replaces many native tool schemas with one `run_code` transport plus a generated SDK. 

Prime's persistent Python REPL already gives us something even more powerful.

Therefore:

## Do not port DSH `run_code` literally in P0.

Implement its architectural principle:

```text
many host capabilities
       ↓
one programmable model-facing environment
```

Prime Python becomes ACRYL's primary PTC-like layer.

Later add:

```python
from acryl import capabilities
```

with generated typed wrappers.

---

# 37. Event-sourced session model

DSH's other major innovation is:

> model-visible state derives from one append-only event log.

The log is authoritative.

Messages are projections.

DSH stores conversation state as append-only typed events and derives the model message surface instead of keeping an independent mutable message array. 

Implement this in stages.

---

# 38. Do NOT replace Prime persistence immediately

Use a migration strategy:

```text
Phase A
Prime session remains authoritative
ACRYL event log shadows it

Phase B
compare ACRYL projection vs Prime request history

Phase C
MPA request builder consumes ACRYL projection

Phase D
ACRYL event log becomes authoritative model-surface source
```

This dramatically reduces risk.

---

# 39. Initial ACRYL session events

Define:

```ts
type AcrylSessionEvent =
  | SessionCreated
  | SessionClosed

  | TurnStarted
  | TurnEnded

  | UserMessage
  | AssistantMessage

  | ToolCall
  | ToolResult

  | ContextMessage

  | RequestHeader

  | AgentCreated
  | AgentMessage
  | AgentDisposed

  | GoalChanged

  | ApprovalRequested
  | ApprovalResolved

  | PluginMounted
  | PluginDisposed

  | CompactionSummary
  | SurfaceReplace
```

Every event:

```ts
interface EventEnvelope<T> {
  seq: number
  id: string
  time: number
  type: string
  data: T
}
```

`seq` must be monotonically increasing.

Payloads must be immutable/lossless JSON.

---

# 40. Surface operations

Message-producing events have:

```ts
surfaceOp:
  | { kind: 'append' }
  | {
      kind: 'replace'
      start: number
      end: number
    }
```

Ordinary operation:

```text
append
append
append
append
```

Compaction:

```text
raw event log stays intact

surface:
A B C D E F
    ↓

A SUMMARY E F
```

The log retains B/C/D.

Only the derived model surface changes.

---

# 41. Request headers

Log canonical request headers.

```ts
interface AcrylRequestHeader {
  provider: string
  model: string

  system: string | null
  tools: readonly ToolSchema[]

  reasoningEffort?: string
  maxTokens?: number

  cacheEpoch: string
  startsSeries: boolean
}
```

Write one when:

```text
initial request
resume
model/provider changes
tool ABI changes
prompt epoch changes
new message series after compaction
```

Do not duplicate it every step if unchanged.

This makes requests reconstructable.

DSH uses durable request/header snapshots for exactly this purpose. 

---

# 42. Crash repair

If process recovery sees:

```text
tool call requested
but no recorded start
```

append an explicit interrupted result.

If it sees:

```text
tool was recorded as started
but no durable result exists
```

do NOT blindly retry.

Record:

```text
TOOL_OUTCOME_UNKNOWN
```

and make the agent reason about idempotency/external state.

This distinction prevents duplicated destructive actions.

---

# 43. Durable context

Context must enter the same event log.

Sources include:

```text
AGENTS.md
CLAUDE.md
skill catalogue
file reference
session reference
goal update
agent message
runtime state
time
tmux/terminal context
test results
deployment results
```

Each context event records:

```text
source
version
content
supersedes?
```

DSH deliberately stores context as durable user-role history so it survives replay and compaction. 

---

# 44. Prime Continual Harness + MPA

Prime `/refine` must not destroy current-session cache stability.

Prime already keeps its immutable base prompt separate from supplemental harness state. 

Change current-session behavior to:

```text
/refine
   ↓
create HarnessState V24
   ↓
append harness-update context event
```

Do NOT rebuild old prompt blocks mid-session.

At the next fresh session:

```text
accepted V24
      ↓
may become part of stable initial project/harness context
```

Thus:

```text
current session:
V23 prefix
...
append V24 update

next session:
V24 stable prefix/context
```

---

# 45. Cache-aware compaction

Prime already compacts.

Modify its summarizer call.

BAD:

```text
special summarizer system prompt
+
flattened conversation
```

GOOD:

```text
same system
+
same tool schemas
+
same warm conversation prefix
+
trailing user message:
"Summarize the conversation above..."
```

DeepSeek Harness changed its compaction implementation specifically to replay the already-warm request prefix and append the summarization instruction at the tail. 

Requirements:

```text
summary call provider = active provider by default
summary call model    = active model by default
system                = exact routed system
tools                 = exact routed tools
history               = exact routed prefix
instruction           = trailing message
```

A user-configured separate summarization model may sacrifice cache reuse intentionally.

---

# 46. Compaction constitutes an explicit epoch transition

After compaction:

```text
old:
A B C D E F G

new:
A SUMMARY F G
```

the model request is no longer a pure prefix extension.

Therefore:

```text
cacheEpoch++
```

This is expected.

Metrics should identify:

```text
epoch break reason = compaction
```

not classify it as an MPA bug.

---

# 47. Tool-result pruning before compaction

Before summarizing massive history:

```text
large tool outputs
       ↓
spill/prune
       ↓
then summarize conversation
```

Preserve important structured metadata and artifact references.

Avoid wasting a summarizer call condensing megabytes of logs that could simply have been externalized.

---

# 48. Spill store

Implement:

```ts
ctx.acrSpill
```

When output exceeds configured bytes:

```text
full output
      ↓
artifact store

model sees:
preview
+
locator
+
instructions for reading/searching it
```

DSH uses this specifically to keep full data recoverable without retaining oversized results in every future model request. 

Suggested local path:

```text
~/.prime/agent/session-artifacts/<session>/acryl-spill/
```

---

# 49. Dynamic Cordis self-extension

Implement DSH's self-referential runtime idea.

DSH lets an agent inspect the running Cordis environment, define a versioned package, run it, stop it and replace it. 

In ACRYL expose this through Prime Python rather than seven permanent native tool schemas.

Target:

```python
await acryl.cordis.inspect.services()
await acryl.cordis.inspect.events()
await acryl.cordis.inspect.capabilities()

plugin = await acryl.cordis.define(...)
await acryl.cordis.run(plugin.id)

await acryl.cordis.stop(plugin.id)
```

---

# 50. Two self-extension modes

## 50.1 Ephemeral dynamic plugin

For a current task.

```text
session
  ↓
define plugin V1
  ↓
run
  ↓
update V2
  ↓
stop
```

Properties:

```text
versioned
reversible
process/session scoped
not automatically committed
```

## 50.2 Persistent project plugin

Agent decides functionality is generally useful.

Create:

```text
.acryl/plugins/code-graph/
├── index.ts
├── package.json
├── README.md
└── index.test.ts
```

Then:

```text
write
 ↓
typecheck
 ↓
tests
 ↓
/reload
 ↓
Cordis mounts plugin
```

This combines DSH's dynamic-runtime idea with Pi's excellent TypeScript extension philosophy.

---

# 51. Immutable plugin versions

Dynamic plugin version history must be append-only.

```text
Plugin abc

V1 immutable
V2 immutable
V3 immutable

current → V3
```

Update means:

```text
dispose current Fiber
      ↓
mount selected immutable version
```

Never mutate V2 source in-place while calling it V2.

---

# 52. Runtime inspection

Agent should be able to discover exact APIs rather than hallucinate them.

Expose:

```python
await acryl.cordis.services()
await acryl.cordis.service("acrSessionLog")
await acryl.cordis.events()
await acryl.capabilities.list()
await acryl.capabilities.describe("...")
```

Generate introspection from actual live service registrations/types where possible.

---

# 53. Subagent capability seam

Prime RLM must remain the primary provider.

But expose a generic service:

```ts
ctx.acrSubagents
```

Provider API:

```ts
interface AcrylSubagentProvider {
  id: string

  spawn(request): Promise<SubagentHandle>
  continue(handle, message): Promise<void>
  interrupt(handle): Promise<void>
  observe(handle): Promise<SubagentSnapshot>
}
```

Providers:

```text
prime-rlm
ACP
Codex
Claude Code
future ACRYL runtime
```

DSH demonstrates that one delegation contract can support both in-process and external agent providers. 

---

# 54. Migrate existing ACRYL `acrAgentControl`

The existing `acryldev/acryl` already contains a provider-neutral Cordis `acrAgentControl` service with provider registration, capabilities, worker identity and dispatch. 

Port its concepts.

Do NOT duplicate Prime's `AgentConnection`.

The distinction is:

```text
AgentConnection
   =
surface → Prime resident worker

AcrAgentControl
   =
worker → agent/provider
```

These are different layers.

---

# 55. Agent presets

Implement per-agent Cordis composition.

Example:

```text
.acryl/agents/reviewer/
└── agent.cordis.yml
```

Could define:

```text
persona
model preferences
tool restrictions
sandbox policy
skills
Cordis plugins
subagent provider
```

Two sessions in the same process may therefore have completely different compositions.

DSH presets implement this exact idea with per-session Cordis configuration. 

---

# 56. Sandboxing as a capability seam

Prime explicitly states its normal worker/kernel processes are not a security sandbox. 

Introduce:

```ts
ctx.acrSandbox
ctx.acrSandboxPolicy
```

Modes:

```text
read-only
workspace-write
danger-full-access
```

Future providers:

```text
macOS Seatbelt
Linux bwrap/Landlock
Windows restricted token/ACL
container
remote sandbox
```

DSH separates same-host confinement from remote/container execution and supports one-shot policy escalation. 

---

# 57. Human approval plane

Create:

```ts
ctx.acrApproval
ctx.acrQuestions
```

Sensitive operation:

```text
tool call
   ↓
policy says ASK
   ↓
human interaction
   ↓
ALLOW / DENY
```

Approval is a capability independent of the TUI.

Therefore future:

```text
TUI
Desktop
Web
ACP
```

can all implement the same answerer contract.

---

# 58. One-shot privilege escalation

If a workspace-write operation fails because stronger permissions are required:

```text
blocked operation
       ↓
agent sees real denial
       ↓
agent retries with explicit escalation
       ↓
justification
       ↓
human approval
       ↓
ONE CALL executes with wider scope
```

Never let the agent silently raise the whole session's permissions.

---

# 59. File observation / stale-write protection

Port one of DSH's particularly useful coding-agent safety ideas.

Before destructive edit/write:

```text
read file
   ↓
record version/hash/stat
   ↓
edit(expectedVersion)
```

If changed externally:

```text
FS_STALE_VERSION
```

Agent must:

```text
re-read
reconcile
retry
```

DSH separates observation policy from the filesystem provider and performs atomic guarded writes.

Implement as optional policy.

---

# 60. Semantic LSP seam

Later add:

```ts
ctx.acrLsp
```

Keep model-facing semantics provider-neutral:

```text
definition
references
implementation
hover
```

Do not expose generic LSP JSON-RPC to the model.

Providers:

```text
stdio language server
remote service
editor host
```

DSH uses exactly this closed semantic seam so changing language-server implementations does not alter the model contract.

---

# 61. Generic background job service

Prime has long-running agent facilities, but arbitrary background operations deserve a generic abstraction.

Add:

```ts
ctx.acrJobs
```

Operations:

```text
start
list
snapshot
wait
read output
cancel
```

Use for:

```text
test suite
dev server
build
benchmark
long shell command
workflow
browser task
```

Do not invent separate background protocols for each tool.

DSH uses one owner-scoped job service for these purposes.

---

# 62. Dynamic workflows

P2 feature.

Add:

```ts
ctx.acrWorkflow
```

A workflow is model-authored orchestration over:

```text
capabilities
jobs
subagents
verification gates
```

Initially execute in worker thread.

Example:

```ts
const architecture = await agents.spawn(...)
const tests = await agents.spawn(...)

const [a, t] = await Promise.all([
  architecture.wait(),
  tests.wait(),
])

return synthesize(a, t)
```

Do not treat worker threads as a security boundary.

---

# 63. Session querying

Create:

```ts
ctx.acrSessionQuery
```

Operations:

```text
eventRead
eventSearch
eventTrace
sessionSearch
sessionTrace
```

Use SQLite FTS5 later.

This allows the model to inspect its historical sessions without injecting entire transcripts into context.

DSH separates session retrieval from compaction and supports exact bounded reads plus full-text retrieval. 

---

# 64. Context Relay implication

This is particularly important for future ACRYL.

Instead of:

```text
copy 80k tokens from old agent
into new agent prompt
```

future ACRYL can do:

```text
new agent
   ↓
session search
   ↓
bounded historical reads
   ↓
select relevant evidence
   ↓
append compressed handoff context
```

This supports ACRYL's eventual persistent-room/context-relay architecture much better than transcript dumping.

---

# 65. Loop hygiene guards

Implement small Cordis policy plugins:

```text
repeat-call detector
tool timeout
runaway-turn detector
token budget
wall-clock budget
```

DSH already uses repeat-tool reminders and timeout policy to prevent simple stuck loops. 

Prime's autonomous-mode bounds should feed into the same policy layer rather than becoming separate duplicated mechanisms.

---

# 66. What to migrate from existing `acryldev/acryl`

## P0: migrate concepts/code

### `acryl-control`

Current package describes itself as a host-neutral Cordis control plane and directly depends on `@deepseek-ai/cordis`. 

Port:

```text
agent/agent-control
provider capability vocabulary
provider-neutral worker identities
provider registry
lifecycle ownership patterns
contracts
events
```

### `acryl-harness-runtime/session-bridge.ts`

Reuse its principle:

> presentation derives from durable runtime/session state, not the surface.

The current bridge subscribes to durable session events and projects transcript/tool state from them. 

Adapt it to Prime rather than DSH types.

### `durable-message.ts`

Retain:

```text
surface
   ↓
durable runtime message port
   ↓
session
```

The current ACRYL contract already explicitly says the durable runtime owner belongs outside presentation surfaces. 

### `coding-capabilities.ts`

Reuse the concept of repository-owned composition layered over upstream capabilities. 

---

# 67. What NOT to migrate from old ACRYL during PoC

Do not initially move:

```text
Electron desktop
Web UI
development canvas
DSH web client
DSH-specific patched client packages
marketplace UI
desktop packaging
```

Those are not necessary to prove the architecture.

The PoC surface is:

```text
Prime TUI
+
Prime CLI
```

Once runtime architecture works, ACRYL proper can consume it.

---

# 68. What NOT to port from DSH

Do not recreate things Prime already does well.

### Do not port DSH's LLM adapters wholesale

Prime `pi-ai` already has broad provider support.

Wrap it behind Cordis if necessary.

### Do not port DSH's concrete agent loop

Prime's RLM-aware `AgentSession` is the product we want.

Expose it as a provider/service.

### Do not port DSH's web client

Not relevant to runtime PoC.

### Do not port DSH goals/schedules merely to duplicate Prime

Represent Prime's existing implementation behind Cordis services.

### Do not embed DSH itself as a sub-runtime

The entire purpose is architectural synthesis.

---

# 69. New source structure

Recommended PoC layout:

```text
packages/coding-agent/src/acryl/
│
├── runtime/
│   ├── runtime-host.ts
│   ├── session-runtime.ts
│   └── metadata.ts
│
├── cordis/
│   ├── context.ts
│   ├── events.ts
│   ├── composition.ts
│   └── diagnostics.ts
│
├── prompt/
│   ├── blocks.ts
│   ├── assembler.ts
│   ├── cache-epoch.ts
│   ├── monotonicity.ts
│   ├── request-shape.ts
│   └── diagnostics.ts
│
├── session/
│   ├── events.ts
│   ├── log.ts
│   ├── surface.ts
│   ├── projection.ts
│   ├── request-header.ts
│   └── repair.ts
│
├── capabilities/
│   ├── service.ts
│   ├── registry.ts
│   ├── execution.ts
│   ├── guards.ts
│   ├── python-bridge.ts
│   └── spill.ts
│
├── agent-control/
│
├── extensions/
│   ├── prime-adapter.ts
│   ├── dynamic-runner.ts
│   ├── inspection.ts
│   └── version-store.ts
│
├── policy/
│   ├── approval.ts
│   ├── sandbox.ts
│   ├── timeout.ts
│   └── repeat-call.ts
│
├── query/
│
└── adapters/
    ├── prime-session.ts
    ├── prime-tools.ts
    ├── prime-prompt.ts
    └── prime-subagents.ts
```

Do not create all files empty at once.

Create them milestone by milestone.

---

# 70. Implementation sequence

## Milestone 0 — establish upstream baseline

Goal:

```text
acryl-padsh == working Prime Agent
```

Tasks:

1. import current Prime Agent;
2. preserve MIT attribution;
3. configure `PrimeIntellect-ai/prime-agent` as upstream remote;
4. make no functional changes;
5. run complete Prime CI/test suite;
6. record upstream commit in:

```text
UPSTREAMS.md
```

Acceptance:

```text
Prime TUI starts
Python works
rlm() works
/reload works
daemon attach works
tests green
```

---

# 71. Milestone 1 — Cordis runtime with zero behavior change

Install/reuse:

```text
@deepseek-ai/cordis
```

Create:

```text
AcrylRuntimeHost
```

Mount one root context per worker.

Create session child context.

No model behavior changes.

Tests:

```text
worker starts → Cordis ACTIVE

TUI detach
→ worker remains
→ Cordis remains

worker shutdown
→ all Cordis fibers DISPOSED
→ no timer/listener leaks
```

---

# 72. Milestone 2 — migrate `acrAgentControl`

Port provider-neutral agent-control concepts from `acryldev/acryl`.

Prime itself becomes first provider:

```text
provider = prime
```

Do not use it to replace AgentConnection.

Tests:

```text
register provider
attach worker
dispatch
dispose provider
capabilities disappear
```

---

# 73. Milestone 3 — MPA observability BEFORE changing behavior

First instrument current Prime.

Capture each LLM request.

Implement:

```text
systemHash
toolHash
messageHash
longest common prefix
first difference
provider cache usage
```

Add:

```text
/cache
```

Establish baseline measurements.

Do not optimize yet.

This provides objective evidence.

---

# 74. Milestone 4 — PromptBlock assembler

Introduce MPA assembler behind feature flag:

```text
ACRYL_MPA=1
```

Initially reproduce current Prime prompt exactly.

Parity requirement:

```text
old rendered prompt
==
new rendered prompt
```

for static test cases.

Then progressively separate:

```text
immutable
project-stable
append-only
dynamic-tail
```

---

# 75. Milestone 5 — stable context ordering

Move stable session-start context before the variable user prompt.

Include:

```text
project instructions
stable skill catalogue
stable runtime information
```

Do NOT move dynamic per-turn observations into the stable prefix.

Run repeated fresh-session cache benchmark.

---

# 76. Milestone 6 — append-only context updates

Implement:

```text
ContextMessage
version
supersedes
```

Convert mutable runtime facts away from system-prompt rewriting.

Priority:

```text
goal state
harness refinement
skill catalogue changes
runtime capability changes
project instructions changed during session
```

---

# 77. Milestone 7 — stable capability gateway

Implement:

```python
acryl.capabilities.*
```

backed by:

```text
ctx.acrCapabilities
```

Prove:

```text
load new Cordis capability
       ↓
no native tool schema change
       ↓
cache epoch unchanged
       ↓
Python can discover/use capability
```

This is a core PoC success criterion.

---

# 78. Milestone 8 — shadow event log

Create ACRYL event log.

Mirror:

```text
user
assistant
tool calls
tool results
context
request headers
agent events
```

Prime remains authoritative.

Compare:

```text
Prime conversation/request history

vs

deriveMessages(acrylEventLog)
```

They must agree.

---

# 79. Milestone 9 — reconstructable requests

For every routed request record enough information to recreate:

```text
system
tools
message surface
provider/model
request settings
cache epoch
```

Create deterministic replay tests.

---

# 80. Milestone 10 — cache-aware compaction

Modify Prime compaction.

Test:

```text
last normal request:

SYSTEM
TOOLS
A B C D

summary request:

SYSTEM
TOOLS
A B C D
COMPACTION_INSTRUCTION
```

The original sequence must be an exact prefix.

---

# 81. Milestone 11 — dynamic Cordis plugins

Implement:

```python
acryl.cordis.inspect(...)
acryl.cordis.define(...)
acryl.cordis.run(...)
acryl.cordis.stop(...)
```

Then persistent TS project plugins and `/reload`.

Acceptance:

```text
agent invents capability
→ writes/mounts it
→ calls it
→ updates it
→ old effects disappear
→ new effects appear
→ session continues
```

---

# 82. Milestone 12 — execution policies

Add:

```text
timeout guard
repeat-call detector
parallel/exclusive scheduling
output spill
```

Do not add sandboxing until basic execution pipeline is stable.

---

# 83. Milestone 13 — filesystem observation guard

Introduce:

```text
read → observed version
edit → compare-and-edit
```

Tests must include external modification between read and edit.

Expected:

```text
FS_STALE_VERSION
```

not overwritten user content.

---

# 84. Milestone 14 — sandbox/approval

Add modes:

```text
read-only
workspace-write
danger-full-access
```

Implement one-shot escalation.

Test unauthorized side-effect paths extensively.

---

# 85. Milestone 15 — session query

Build bounded event/session queries.

Then optionally SQLite FTS.

Expose through Python first:

```python
await acryl.sessions.search(...)
await acryl.sessions.read(...)
```

Avoid adding five new native schemas until needed.

---

# 86. Milestone 16 — presets and profiles

Implement:

```text
base
minimal
coding
research
reviewer
```

Support:

```text
--profile
--dump-config
```

Then per-agent `agent.cordis.yml`.

---

# 87. MPA benchmark suite

Create:

```text
bench/cache/
├── steady-session.ts
├── cross-session.ts
├── plugin-load.ts
├── refine.ts
├── compaction.ts
└── report.ts
```

---

# 88. Benchmark A — ordinary long session

Sequence:

```text
prompt
tool
assistant
tool
assistant
prompt
...
```

Requirements:

```text
system hash unchanged
tool hash unchanged
previous history unchanged
cache epoch unchanged
```

Only new tail content differs.

---

# 89. Benchmark B — fresh sessions same repository

Session A:

```text
stable project context
"user prompt A"
```

Session B:

```text
stable project context
"user prompt B"
```

Longest common prefix should include:

```text
system
tools
project context
skill catalogue
runtime ABI
```

and stop only at the first differing user prompt.

---

# 90. Benchmark C — dynamic Cordis capability

```text
request N
↓
load dynamic Cordis capability behind Python ABI
↓
request N+1
```

Requirements:

```text
systemHash same
toolHash same
cacheEpoch same
```

---

# 91. Benchmark D — native tool registration

```text
request N
↓
register new native model tool
↓
request N+1
```

Expected:

```text
cache epoch changes
reason = native-tool-schema-change
```

This is intentional.

---

# 92. Benchmark E — `/refine`

```text
request N
↓
/refine
↓
HarnessState changes
↓
request N+1
```

Requirement:

```text
old prefix unchanged
new harness update appended
```

No system-prompt mutation in current epoch.

---

# 93. Benchmark F — compaction

Validate two things separately.

### Auxiliary summary request

Must reuse warm prefix.

### Post-compaction conversation request

Must start a new cache epoch.

Both are correct.

---

# 94. Structural cache metrics

Report:

```text
totalInputTokens
newInputTokens
reusablePrefixTokens
structuralReuseRatio

providerCacheReadTokens
providerCacheWriteTokens
providerReportedHitRatio

epochCount
unexpectedEpochBreaks
```

Use provider metrics only where available.

---

# 95. Hard architecture invariants

The coding agent MUST preserve these.

## Invariant 1

```text
TUI never owns durable execution.
```

## Invariant 2

```text
Cordis worker context survives TUI detach.
```

## Invariant 3

```text
Every plugin-owned side effect has one lifecycle owner.
```

## Invariant 4

```text
Consumers depend on capability definitions, not providers.
```

## Invariant 5

```text
Model-visible state must eventually be reconstructable from durable events.
```

## Invariant 6

```text
Ordinary conversation progress is append-only.
```

## Invariant 7

```text
An append-safe transition may not modify an earlier request prefix.
```

## Invariant 8

```text
Prompt/tool order is deterministic.
```

## Invariant 9

```text
Dynamic runtime capability != dynamic model schema.
```

## Invariant 10

```text
Python is a programmable facade.
TypeScript/Cordis remains authoritative.
```

## Invariant 11

```text
/reload must dispose old registrations before mounting replacements.
```

## Invariant 12

```text
A hard security denial cannot be relaxed by downstream middleware.
```

## Invariant 13

```text
Unknown side-effect outcome after crash must not be blindly replayed.
```

## Invariant 14

```text
Large data should be addressable externally instead of repeatedly injected.
```

---

# 96. Coding-agent execution discipline

Do NOT implement this as one giant architecture branch.

Use vertical slices.

For every milestone:

```text
1. inspect current Prime path
2. write/update architecture test
3. implement smallest seam
4. preserve existing behavior
5. add unit tests
6. add integration test
7. run Prime regression suite
8. run cache/request-shape tests
9. document what changed
10. commit
```

Every milestone must leave:

```text
npm/pnpm build green
typecheck green
tests green
Prime basic TUI functional
Prime Python functional
Prime RLM functional
```

---

# 97. Feature flags

All high-risk migrations start behind flags.

Examples:

```text
ACRYL_CORDIS=1
ACRYL_MPA=1
ACRYL_EVENT_LOG=1
ACRYL_CAPABILITY_GATEWAY=1
ACRYL_DYNAMIC_CORDIS=1
```

Remove flags only after parity tests.

---

# 98. Architecture tests

Create tests that fail on structural regression.

Examples:

```text
Prime TUI package may not import dynamic plugin runner.

Cordis providers may not import presentation UI.

Capability Consumers may not import concrete Providers.

Prompt runtime may not import TUI.

Session event log may not import provider implementations.

Dynamic Cordis capability may not mutate native schema
unless explicitly promoted.

Surface code may not own AgentSession.
```

These should be executable dependency-direction tests, not only documentation.

---

# 99. Upstream strategy

Keep three conceptual sources:

```text
Prime upstream
    =
execution/RLM/product base

DSH upstream
    =
architectural reference + selectively ported MIT code

acryldev/acryl
    =
our already-proven Cordis/control-plane experiments
```

Maintain:

```text
UPSTREAMS.md
```

Record:

```text
Prime base commit
DSH reference commit
ACRYL source commit
ported files/concepts
local modifications
```

---

# 100. Licensing

Prime Agent is MIT. 

DeepSeek Harness is MIT. 

The existing ACRYL package is also MIT. 

Therefore ACRYL-PADSH can remain MIT.

When substantial source is copied or adapted, retain required copyright/license notices.

Add:

```text
THIRD_PARTY_NOTICES.md
```

with at minimum:

```text
Prime Agent / Pi
DeepSeek Harness / Cordis
```

---

# 101. PoC success criteria

The experiment succeeds when all of the following are true.

### Prime capabilities remain intact

```text
✓ Prime TUI
✓ daemon sessions
✓ detach/attach
✓ persistent Python
✓ RLM children
✓ /reload
✓ TS extensions
✓ Python skills
✓ /refine
✓ /goal
✓ autonomous mode
```

### Cordis works as runtime substrate

```text
✓ services
✓ inject
✓ fibers
✓ effects
✓ typed events
✓ waterfall
✓ scope
✓ hot replacement
✓ diagnostics
```

### MPA works

```text
✓ deterministic system sections
✓ deterministic tool schemas
✓ stable context before user prompt
✓ append-only runtime updates
✓ explicit cache epochs
✓ request-shape recorder
✓ monotonicity tests
✓ cache-aware compaction
```

### Self-extension works

```text
✓ model can inspect Cordis runtime
✓ model can create capability
✓ model can mount capability
✓ capability accessible through Python
✓ model ABI remains unchanged
✓ plugin can be updated/disposed safely
```

### Session architecture works

```text
✓ append-only event log
✓ derived model surface
✓ request headers
✓ deterministic replay
✓ crash semantics
```

---

# 102. The core architectural outcome

The resulting system should be understood as:

```text
              Prime Agent
       long-running RLM runtime
                   │
                   ▼
            ACRYL Runtime Host
                   │
                   ▼
                 Cordis
     lifecycle + composition + services
                   │
     ┌─────────────┼──────────────┐
     │             │              │
     ▼             ▼              ▼
 Session Log      MPA        Capabilities
     │             │              │
     │             │              ▼
     │             │       stable Python ABI
     │             │              │
     │             └──────┬───────┘
     │                    │
     ▼                    ▼
 durable truth          LLM
                         │
                         ▼
               high prefix-cache reuse
```

And its self-extension loop becomes:

```text
agent encounters missing capability
             ↓
inspects live Cordis runtime
             ↓
creates capability/plugin
             ↓
tests it
             ↓
mounts via Cordis
             ↓
uses through stable Python ABI
             ↓
model-facing schema remains stable
             ↓
MPA prefix remains reusable
             ↓
successful repeated capability
             ↓
promote to persistent TS Cordis plugin
```

That combination is the central research/product hypothesis of ACRYL-PADSH.

---

# 103. Final design principle

The project should optimize simultaneously for:

```text
Prime:
persistent computational agent

+

Cordis:
spatiotemporally composable runtime

+

DeepSeek Harness:
deterministic, event-sourced,
cache-conscious harness architecture

+

Pi:
simple self-written TypeScript extensions
```

The two rules that must dominate implementation decisions are:

> **Capabilities may evolve dynamically; the model-facing ABI should remain stable whenever possible.**

and:

> **During a cache epoch, previously emitted model context is immutable. New knowledge is appended, not rewritten.**

If these two rules survive throughout implementation, ACRYL-PADSH gains the most valuable DSH property — extremely high prefix-cache locality — without giving up Prime's RLM, persistent workers, self-improvement or Pi's extensibility.