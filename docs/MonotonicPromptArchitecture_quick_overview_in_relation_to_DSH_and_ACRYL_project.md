# Technical Specification: `acryl-padsh` Architecture & Core Porting Plan

This specification outlines the technical design for merging the **DeepSeek Harness (DSH)** / **Cordis Kernel** architectural innovations from `acryl` (`@acryldev/acryl`) into `acryl-padsh` (a fork of `prime-agent` / `pi`). The core objective is enforcing a **Monotonic Prompt Architecture (MPA)** to guarantee 95–99% provider-side KV/prompt cache hits across long-running autonomous coding sessions.

---

## 1. System Overview & Invariant Contracts

`acryl-padsh` combines `prime-agent`'s programmatic IPython REPL runtime with DSH’s strict cache-friendly prompt geometry.

```
┌─────────────────────────────────────────────────────────┐
│                      EpochHeader                        │
│ 1. Deterministic System Prompt (Identity, Capabilities) │
│ 2. Deterministically Sorted Tool Schemas (Alphabetical) │
├─────────────────────────────────────────────────────────┤
│                Monotonic History Stream                 │
│ 3. Appended User/Assistant/Tool Turn Messages          │
│ 4. Appended Late-Ingested Context (<system-reminder>)   │
├─────────────────────────────────────────────────────────┤
│                   Warm-Prefix Suffix                    │
│ 5. New Action / Step Suffix OR Warm Compaction Instruction│
└─────────────────────────────────────────────────────────┘

```

### Core Invariant

For any two consecutive requests $R_n$ and $R_{n+1}$ in an active session:


$$R_{n+1} = R_n \oplus \Delta_{n+1}$$


where $\oplus$ represents string/token-level concatenation at the tail, and $\Delta_{n+1}$ is strictly the new delta.

---

## 2. Monotonic Prompt Architecture (MPA) Engine

### 2.1 Deterministic Head Assembly

To prevent token-0 cache invalidation, the harness head (System Prompt + Tool Schemas) must be compiled deterministically.

```typescript
// src/core/engine/prompt-builder.ts
export interface EpochHeaderConfig {
  identity: string;
  persona: string;
  guidelines: string[];
  tools: ToolSchema[];
  systemVariables: Record<string, string>;
}

export class DeterministicPromptEngine {
  public compileHead(config: EpochHeaderConfig): { systemPrompt: string; tools: ToolSchema[]; headerHash: string } {
    // 1. Enforce strict section ordering
    const sections = [
      `# IDENTITY\n${config.identity}`,
      `# PERSONA\n${config.persona}`,
      `# GUIDELINES\n${config.guidelines.join('\n')}`,
      `# SYSTEM VARS\n${Object.keys(config.systemVariables).sort().map(k => `${k}=${config.systemVariables[k]}`).join('\n')}`
    ];
    const systemPrompt = sections.join('\n\n');

    // 2. Alphabetically sort tool schemas by name
    const sortedTools = [...config.tools].sort((a, b) => a.name.localeCompare(b.name));

    // 3. Compute EpochHeader hash to detect prefix breakage
    const rawEnvelope = JSON.stringify({ systemPrompt, tools: sortedTools });
    const headerHash = crypto.createHash('sha256').update(rawEnvelope).digest('hex');

    return { systemPrompt, tools: sortedTools, headerHash };
  }
}

```

### 2.2 Late Ingestion via Append-Only System Reminders

When discovering workspace updates (e.g., new `AGENTS.md` files, updated `.env` files, or dynamic instructions), the harness **must not** rewrite the system prompt.

* **Forbidden Strategy:** Injecting instructions into the `systemPrompt` (invalidates cache at the insertion index).
* **Mandatory Strategy:** Appending a `<system-reminder>` turn into the history stream.

```typescript
// src/core/context/late-ingestion.ts
export function createLateIngestionMessage(contextPath: string, content: string): Message {
  return {
    role: 'user',
    content: `<system-reminder>\n[Context Discovered: ${contextPath}]\n${content}\n</system-reminder>`,
    metadata: { cacheBehavior: 'append-only', source: contextPath }
  };
}

```

---

## 3. Warm-Prefix Compaction Engine

When history reaches maximum token constraints (e.g., 150k tokens), traditional compaction creates a separate summarization request, causing a complete cache miss. `acryl-padsh` implements **Warm-Prefix Compaction**.

```typescript
// src/core/compaction/warm-compactor.ts
export class WarmPrefixCompactor {
  public async compact(session: SessionState, llmClient: LLMProviderClient): Promise<string> {
    // 1. Replay EXACT active prefix (System + Tools + History)
    const compactionPromptMessages = [
      ...session.messageHistory,
      {
        role: 'user',
        content: `<compaction-instruction>
You are acting as a compaction engine for this active session. 
Summarize the conversation above into a structured summary state. 
Retain crucial decisions, pending tasks, code modifications, and environment details.
</compaction-instruction>`
      }
    ];

    // 2. Execute call with 95%+ cache-hit on the 150k prefix
    const response = await llmClient.complete({
      system: session.epochHeader.systemPrompt,
      tools: session.epochHeader.tools,
      messages: compactionPromptMessages,
      // Maintain IDENTICAL model envelope configuration
      temperature: session.config.temperature,
      max_tokens: session.config.max_tokens
    });

    return response.text;
  }
}

```

---

## 4. Cordis Kernel Integration in `acryl-padsh`

`acryl-padsh` integrates DSH's **Cordis plugin kernel** into `prime-agent`'s REPL/daemon architecture.

```
  ┌────────────────────────────────────────────────────────┐
  │                     Cordis Kernel                      │
  │     (Event Bus, Service Registry, Lifecycle Hooks)     │
  └───────────────────┬────────────────────────────────────┘
                      │
   ┌──────────────────┼──────────────────┬─────────────────┐
   │                  │                  │                 │
┌──▼──────────┐    ┌──▼──────────┐    ┌──▼──────────┐   ┌──▼──────────┐
│ ModelPlugin │    │ ToolsPlugin │    │ CacheAudit  │   │ IPython     │
│  (DeepSeek) │    │ (Cordis/PI) │    │   Plugin    │   │ Kernel      │
└─────────────┘    └─────────────┘    └─────────────┘   └─────────────┘

```

### 4.1 Plugin Interface Standard

```typescript
// src/kernel/cordis-plugin.ts
export type CacheBehavior = 'append-only' | 'prefix-stable' | 'replacing' | 'independent';

export interface CordisPlugin {
  name: string;
  version: string;
  cacheContract: {
    tokenEffect: 'static' | 'dynamic-append' | 'dynamic-replace';
    expectedBehavior: CacheBehavior;
  };
  mount(kernel: CordisKernel): Promise<void>;
  unmount(kernel: CordisKernel): Promise<void>;
}

```

---

## 5. EpochHeader & Envelope Tracking

To ensure request parameters do not unintentionally break provider cache keys, `acryl-padsh` logs an `EpochHeader` alongside each request.

| Key | Description | Cache Sensitivity |
| --- | --- | --- |
| `model` | Exact LLM deployment name | High (Miss across models) |
| `system_hash` | SHA256 of compiled system prompt | High (Miss on change) |
| `tool_hash` | SHA256 of sorted tool schema string | High (Miss on reordering) |
| `temperature` | Sampling parameter | High (Provider-dependent) |
| `max_tokens` | Max response tokens | High (Provider-dependent) |

```typescript
// src/core/telemetry/epoch-tracker.ts
export interface EpochHeader {
  epochId: string;
  model: string;
  systemHash: string;
  toolHash: string;
  requestConfigHash: string;
  timestamp: number;
}

export class EnvelopeAuditor {
  private currentEpoch?: EpochHeader;

  public validateTransition(nextHeader: EpochHeader): { cacheMaintained: boolean; reason?: string } {
    if (!this.currentEpoch) {
      this.currentEpoch = nextHeader;
      return { cacheMaintained: true };
    }

    if (this.currentEpoch.systemHash !== nextHeader.systemHash) {
      return { cacheMaintained: false, reason: 'System prompt changed in token 0-N range.' };
    }
    if (this.currentEpoch.toolHash !== nextHeader.toolHash) {
      return { cacheMaintained: false, reason: 'Tool schemas changed or were reordered.' };
    }
    if (this.currentEpoch.requestConfigHash !== nextHeader.requestConfigHash) {
      return { cacheMaintained: false, reason: 'LLM configuration parameters altered.' };
    }

    return { cacheMaintained: true };
  }
}

```

---

## 6. Telemetry & Metrics Accounting

`acryl-padsh` explicitly computes and logs KV cache metrics per step to verify MPA efficiency.

```typescript
// src/telemetry/cache-metrics.ts
export interface StepCacheTelemetry {
  step: number;
  promptTokensTotal: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
  uncachedTokens: number;
  hitRatio: number;
}

export function calculateHitRatio(read: number, total: number): number {
  if (total === 0) return 0;
  return Number(((read / total) * 100).toFixed(2));
}

```

### Telemetry Terminal Output Example

```text
[acryl-padsh] Step 42 | Tokens: 168,420 | Cache Read: 165,120 | Cache Write: 3,300 | Hit Ratio: 98.04%

```

---

## 7. Migration & Porting Roadmap

The porting from `acryl` to `acryl-padsh` is structured into four phased milestones:

| Phase | Milestone | Deliverables |
| --- | --- | --- |
| **Phase 1** | **Core Determinism** | Port `DeterministicPromptEngine` and sorted tool schema builder from `@acryldev/acryl`. Replace legacy prompt assembly in `prime-agent`. |
| **Phase 2** | **Monotonic Ingestion** | Implement `<system-reminder>` late-ingestion pipeline. Convert `AGENTS.md` and workspace discoveries to append-only history entries. |
| **Phase 3** | **Warm Compaction** | Replace standard summarizer with `WarmPrefixCompactor`. Enforce warm prefix replay during history truncation. |
| **Phase 4** | **Auditing & Cordis Kernel** | Integrate Cordis kernel into `prime-agent`'s daemon/REPL loop, add `EnvelopeAuditor`, and report step-by-step cache telemetry. |