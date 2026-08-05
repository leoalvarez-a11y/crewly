/** Query accepted by the supplementary external Memory Layer. */
export interface ExternalMemoryQuery {
  objective: string;
  task: string;
  role: string;
  project: string;
}

/** One normalized external-memory snippet and its sanitized source reference. */
export interface ExternalMemoryReference {
  content: string;
  reference: string;
}

/** Non-blocking adapter result used by prompt assembly and observability. */
export interface ExternalMemoryResult {
  status: 'disabled' | 'success' | 'unavailable' | 'error';
  durationMs: number;
  references: ExternalMemoryReference[];
}

/** Injectable transport for tests and non-HTTP future interfaces. */
export type ExternalMemoryTransport = (
  url: string,
  init: RequestInit,
) => Promise<Response>;

const DEFAULT_TIMEOUT_MS = 2_000;
const DEFAULT_MAX_REFERENCES = 5;
const DEFAULT_MAX_CHARACTERS = 4_000;

/**
 * Supplementary HTTP-service adapter for an external Memory Layer.
 *
 * The adapter is disabled unless `CREWLY_EXTERNAL_MEMORY_URL` is configured.
 * It never throws to callers: timeouts, malformed responses, and transport
 * failures return a non-blocking result so Crewly Wiki and native memory continue.
 */
export class ExternalMemoryLayerAdapter {
  private readonly serviceUrl?: string;
  private readonly authToken?: string;
  private readonly timeoutMs: number;
  private readonly maxReferences: number;
  private readonly maxCharacters: number;
  private readonly transport: ExternalMemoryTransport;

  /** Create an adapter from explicit options or non-secret environment configuration. */
  constructor(options: {
    serviceUrl?: string;
    authToken?: string;
    timeoutMs?: number;
    maxReferences?: number;
    maxCharacters?: number;
    transport?: ExternalMemoryTransport;
  } = {}) {
    this.serviceUrl = options.serviceUrl ?? process.env.CREWLY_EXTERNAL_MEMORY_URL;
    this.authToken = options.authToken ?? process.env.CREWLY_EXTERNAL_MEMORY_TOKEN;
    this.timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
    this.maxReferences = options.maxReferences ?? DEFAULT_MAX_REFERENCES;
    this.maxCharacters = options.maxCharacters ?? DEFAULT_MAX_CHARACTERS;
    this.transport = options.transport ?? globalThis.fetch.bind(globalThis);
  }

  /**
   * Query external memory and return bounded, deduplicated, redacted context.
   *
   * @param query - Minimal objective/task/role/project query
   * @returns Non-blocking normalized result
   */
  async query(query: ExternalMemoryQuery): Promise<ExternalMemoryResult> {
    const startedAt = Date.now();
    if (!this.serviceUrl) {
      return { status: 'disabled', durationMs: 0, references: [] };
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const headers: Record<string, string> = { 'content-type': 'application/json' };
      if (this.authToken) headers.authorization = `Bearer ${this.authToken}`;
      const response = await this.transport(this.serviceUrl, {
        method: 'POST',
        headers,
        signal: controller.signal,
        body: JSON.stringify(query),
      });
      if (!response.ok) {
        return { status: 'unavailable', durationMs: Date.now() - startedAt, references: [] };
      }
      const payload = await response.json() as unknown;
      const references = this.normalize(payload);
      return { status: 'success', durationMs: Date.now() - startedAt, references };
    } catch {
      return { status: 'error', durationMs: Date.now() - startedAt, references: [] };
    } finally {
      clearTimeout(timeout);
    }
  }

  /** Normalize common service response shapes without binding to one vendor. */
  private normalize(payload: unknown): ExternalMemoryReference[] {
    const record = payload && typeof payload === 'object' ? payload as Record<string, unknown> : {};
    const raw = Array.isArray(record.references)
      ? record.references
      : Array.isArray(record.results)
        ? record.results
        : Array.isArray(payload)
          ? payload
          : [];
    const seen = new Set<string>();
    const output: ExternalMemoryReference[] = [];
    let characters = 0;

    for (const item of raw) {
      if (!item || typeof item !== 'object') continue;
      const candidate = item as Record<string, unknown>;
      const rawContent = candidate.content ?? candidate.text ?? candidate.snippet;
      if (typeof rawContent !== 'string' || !rawContent.trim()) continue;
      const content = this.redact(rawContent.trim());
      const dedupeKey = content.toLocaleLowerCase().replace(/\s+/g, ' ');
      if (seen.has(dedupeKey)) continue;
      const remaining = this.maxCharacters - characters;
      if (remaining <= 0) break;
      const bounded = content.slice(0, remaining);
      const referenceValue = candidate.reference ?? candidate.source ?? candidate.id ?? 'external-memory';
      const reference = this.redact(String(referenceValue)).slice(0, 300);
      output.push({ content: bounded, reference });
      seen.add(dedupeKey);
      characters += bounded.length;
      if (output.length >= this.maxReferences) break;
    }
    return output;
  }

  /** Redact common credential forms before context injection or telemetry. */
  private redact(value: string): string {
    return value
      .replace(/\b(Bearer\s+)[A-Za-z0-9._~+/=-]+/gi, '$1[REDACTED]')
      .replace(/\b(api[_-]?key|token|password|secret)\s*[:=]\s*[^\s,;]+/gi, '$1=[REDACTED]')
      .replace(/\b(sk-[A-Za-z0-9_-]{8,})\b/g, '[REDACTED]');
  }
}
