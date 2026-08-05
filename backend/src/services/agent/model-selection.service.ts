import { readFileSync } from 'fs';
import * as path from 'path';
import type {
  AgentExecutionReceipt,
  AgentModelProvider,
  CapabilityClass,
  TeamMember,
} from '../../types/index.js';

/** A non-secret model catalog entry used for deterministic selection. */
export interface ModelCatalogEntry {
  provider: AgentModelProvider;
  runtime: TeamMember['runtimeType'];
  modelId: string;
  supportedCapabilities: CapabilityClass[];
  contextWindow: number | null;
  nativeImageInput: boolean;
  relativeCostTier: number;
  availability: boolean;
}

/** Versioned, editable model catalog stored outside product source code. */
export interface ModelCatalog {
  version: string;
  models: ModelCatalogEntry[];
}

/** Selection result plus the optional eligible fallback target. */
export interface ModelSelectionResult {
  receipt: AgentExecutionReceipt;
  selected?: ModelCatalogEntry;
  fallback?: { provider: AgentModelProvider; modelId: string };
}

/** Failure classes that may trigger a model fallback. */
export type ModelFailureClass =
  | 'insufficient_capability'
  | 'context_limit'
  | 'rate_limit'
  | 'model_unavailable'
  | 'timeout'
  | 'network'
  | 'credential'
  | 'permission'
  | 'tool'
  | 'unknown';

const ELIGIBLE_FALLBACK_FAILURES = new Set<ModelFailureClass>([
  'insufficient_capability',
  'context_limit',
  'rate_limit',
  'model_unavailable',
  'timeout',
]);

/**
 * Selects the cheapest available model that satisfies an agent's declared capability.
 *
 * Explicit `modelId` always wins. Legacy members without new configuration receive a
 * native-default receipt and no runtime flags, preserving the baseline behavior.
 */
export class ModelSelectionService {
  private readonly catalogPath: string;
  private catalog?: ModelCatalog;

  /**
   * Create a selector.
   *
   * @param catalogPath - Optional catalog path; defaults to config/model-catalog.json
   * @param catalog - Optional injected catalog for deterministic tests
   */
  constructor(catalogPath?: string, catalog?: ModelCatalog) {
    this.catalogPath = catalogPath
      ?? process.env.CREWLY_MODEL_CATALOG_PATH
      ?? path.join(process.cwd(), 'config', 'model-catalog.json');
    this.catalog = catalog;
  }

  /**
   * Resolve the model decision for one member.
   *
   * @param member - Persisted team member configuration
   * @returns Selection receipt and optional selected/fallback entries
   */
  async select(member: TeamMember): Promise<ModelSelectionResult> {
    const catalog = await this.loadCatalog();
    const now = new Date().toISOString();
    const requestedModel = member.modelId ?? null;
    const requestedProvider = member.provider ?? this.providerFromModelId(member.modelId);

    if (member.modelId) {
      const parsedModel = this.modelName(member.modelId);
      const selected = catalog.models.find((entry) =>
        entry.runtime === member.runtimeType
        && entry.modelId === parsedModel
        && (!requestedProvider || entry.provider === requestedProvider));
      const provider = requestedProvider ?? selected?.provider ?? null;
      return {
        receipt: this.buildReceipt(member, {
          catalogVersion: catalog.version,
          provider,
          requestedModel: member.modelId,
          executedModel: member.modelId,
          reason: 'manual_override',
          now,
        }),
        selected,
        fallback: this.parseProviderModel(member.optionalFallbackModel),
      };
    }

    if (member.modelSelectionMode !== 'automatic' && !member.capabilityClass) {
      return {
        receipt: this.buildReceipt(member, {
          catalogVersion: catalog.version,
          provider: requestedProvider,
          requestedModel,
          executedModel: null,
          reason: 'native_default',
          now,
        }),
      };
    }

    if (!member.capabilityClass) {
      throw new Error('Automatic model selection requires capabilityClass');
    }

    const candidates = catalog.models
      .filter((entry) => entry.availability)
      .filter((entry) => entry.runtime === member.runtimeType)
      .filter((entry) => !member.provider || entry.provider === member.provider)
      .filter((entry) => entry.supportedCapabilities.includes(member.capabilityClass!))
      .sort((a, b) =>
        a.relativeCostTier - b.relativeCostTier
        || a.provider.localeCompare(b.provider)
        || a.modelId.localeCompare(b.modelId));

    const selected = candidates[0];
    if (!selected) {
      throw new Error(`No available model satisfies ${member.capabilityClass} on ${member.runtimeType}`);
    }

    const qualifiedModel = `${selected.provider}/${selected.modelId}`;
    return {
      receipt: this.buildReceipt(member, {
        catalogVersion: catalog.version,
        provider: selected.provider,
        requestedModel,
        executedModel: qualifiedModel,
        reason: 'automatic_cheapest_sufficient',
        now,
      }),
      selected,
      fallback: this.parseProviderModel(member.optionalFallbackModel),
    };
  }

  /**
   * Apply a configured fallback only for explicitly eligible failure classes.
   *
   * @param selection - Original selection
   * @param error - Runtime failure
   * @returns Updated selection, or the original selection when escalation is forbidden
   */
  applyFallback(selection: ModelSelectionResult, error: unknown): ModelSelectionResult {
    const classification = this.classifyFailure(error);
    if (!selection.fallback || !ELIGIBLE_FALLBACK_FAILURES.has(classification)) {
      return selection;
    }
    const qualified = `${selection.fallback.provider}/${selection.fallback.modelId}`;
    return {
      ...selection,
      receipt: {
        ...selection.receipt,
        provider: selection.fallback.provider,
        executedModel: qualified,
        fallbackUsed: true,
        fallbackClassification: classification,
        recordedAt: new Date().toISOString(),
      },
    };
  }

  /**
   * Classify a runtime error without exposing its original text in telemetry.
   *
   * @param error - Runtime error or message
   * @returns Stable failure class
   */
  classifyFailure(error: unknown): ModelFailureClass {
    const message = (error instanceof Error ? error.message : String(error)).toLowerCase();
    if (/api key|credential|authentication|unauthorized|401/.test(message)) return 'credential';
    if (/permission|forbidden|403|access denied/.test(message)) return 'permission';
    if (/network|dns|econn|socket|connection/.test(message)) return 'network';
    if (/tool|mcp|command not found/.test(message)) return 'tool';
    if (/context|token limit|max_tokens/.test(message)) return 'context_limit';
    if (/rate limit|429|quota/.test(message)) return 'rate_limit';
    if (/unavailable|not available|not found/.test(message)) return 'model_unavailable';
    if (/timeout|timed out/.test(message)) return 'timeout';
    if (/capability|unsupported modality|vision required/.test(message)) return 'insufficient_capability';
    return 'unknown';
  }

  /**
   * Convert a selected provider/model ID into an existing CLI model flag.
   *
   * @param runtimeType - Target runtime
   * @param qualifiedModel - Provider/model ID
   * @returns CLI flags, or an empty array when the native default should be used
   */
  static runtimeModelFlags(runtimeType: TeamMember['runtimeType'], qualifiedModel: string | null): string[] {
    if (!qualifiedModel || runtimeType === 'crewly-agent') return [];
    const model = qualifiedModel.includes('/') ? qualifiedModel.slice(qualifiedModel.indexOf('/') + 1) : qualifiedModel;
    if (!/^[A-Za-z0-9._:-]+$/.test(model)) {
      throw new Error('Unsafe model ID rejected');
    }
    return ['--model', model];
  }

  /** Load and validate the configured catalog. */
  private async loadCatalog(): Promise<ModelCatalog> {
    if (this.catalog) return this.catalog;
    const parsed = JSON.parse(readFileSync(this.catalogPath, 'utf8')) as ModelCatalog;
    if (!parsed.version || !Array.isArray(parsed.models)) {
      throw new Error('Invalid model catalog');
    }
    this.catalog = parsed;
    return parsed;
  }

  /** Build a telemetry-safe receipt with unknown token/cost values kept null. */
  private buildReceipt(
    member: TeamMember,
    input: {
      catalogVersion: string;
      provider: AgentModelProvider | null;
      requestedModel: string | null;
      executedModel: string | null;
      reason: AgentExecutionReceipt['selectionReason'];
      now: string;
    },
  ): AgentExecutionReceipt {
    return {
      catalogVersion: input.catalogVersion,
      provider: input.provider,
      requestedRuntime: member.runtimeType,
      executedRuntime: member.runtimeType,
      requestedModel: input.requestedModel,
      executedModel: input.executedModel,
      capabilityClass: member.capabilityClass ?? null,
      selectionReason: input.reason,
      fallbackUsed: false,
      fallbackClassification: null,
      inputTokens: null,
      outputTokens: null,
      totalTokens: null,
      costUsd: null,
      memoryLayerConsulted: false,
      memoryReferences: [],
      recordedAt: input.now,
    };
  }

  /** Parse provider/model syntax. */
  private parseProviderModel(value?: string): { provider: AgentModelProvider; modelId: string } | undefined {
    if (!value?.includes('/')) return undefined;
    const [provider, ...parts] = value.split('/');
    if (!['anthropic', 'openai', 'google', 'deepseek', 'ollama'].includes(provider)) return undefined;
    return { provider: provider as AgentModelProvider, modelId: parts.join('/') };
  }

  /** Derive provider from a qualified model ID. */
  private providerFromModelId(value?: string): AgentModelProvider | null {
    return this.parseProviderModel(value)?.provider ?? null;
  }

  /** Remove the provider prefix from a qualified model ID. */
  private modelName(value: string): string {
    return value.includes('/') ? value.slice(value.indexOf('/') + 1) : value;
  }
}
