import { ModelSelectionService, type ModelCatalog } from './model-selection.service.js';
import type { TeamMember } from '../../types/index.js';

const catalog: ModelCatalog = {
  version: 'test-v1',
  models: [
    { provider: 'openai', runtime: 'codex-cli', modelId: 'cheap', supportedCapabilities: ['strong_coding', 'long_context'], contextWindow: null, nativeImageInput: false, relativeCostTier: 1, availability: true },
    { provider: 'openai', runtime: 'codex-cli', modelId: 'vision', supportedCapabilities: ['strong_coding', 'multimodal', 'long_context'], contextWindow: null, nativeImageInput: true, relativeCostTier: 2, availability: true },
    { provider: 'openai', runtime: 'codex-cli', modelId: 'offline', supportedCapabilities: ['deep_reasoning'], contextWindow: null, nativeImageInput: false, relativeCostTier: 0, availability: false },
  ],
};

const member = (updates: Partial<TeamMember> = {}): TeamMember => ({
  id: 'm1', name: 'Developer', sessionName: 'dev', role: 'developer', systemPrompt: 'test',
  agentStatus: 'inactive', workingStatus: 'idle', runtimeType: 'codex-cli',
  createdAt: '2026-08-04T00:00:00.000Z', updatedAt: '2026-08-04T00:00:00.000Z',
  ...updates,
});

describe('ModelSelectionService', () => {
  const service = new ModelSelectionService(undefined, catalog);

  it('preserves the native default for legacy members', async () => {
    const result = await service.select(member());
    expect(result.receipt.selectionReason).toBe('native_default');
    expect(result.receipt.executedModel).toBeNull();
  });

  it('gives an explicit manual model priority', async () => {
    const result = await service.select(member({ modelId: 'openai/vision', capabilityClass: 'strong_coding' }));
    expect(result.receipt.selectionReason).toBe('manual_override');
    expect(result.receipt.executedModel).toBe('openai/vision');
  });

  it('selects the cheapest available sufficient model', async () => {
    const result = await service.select(member({ modelSelectionMode: 'automatic', capabilityClass: 'strong_coding' }));
    expect(result.receipt.executedModel).toBe('openai/cheap');
    expect(result.receipt.selectionReason).toBe('automatic_cheapest_sufficient');
  });

  it('excludes models without multimodal capability', async () => {
    const result = await service.select(member({ modelSelectionMode: 'automatic', capabilityClass: 'multimodal' }));
    expect(result.receipt.executedModel).toBe('openai/vision');
  });

  it('supports long-context selection', async () => {
    const result = await service.select(member({ modelSelectionMode: 'automatic', capabilityClass: 'long_context' }));
    expect(result.receipt.executedModel).toBe('openai/cheap');
  });

  it('does not choose unavailable models', async () => {
    await expect(service.select(member({ modelSelectionMode: 'automatic', capabilityClass: 'deep_reasoning' })))
      .rejects.toThrow('No available model');
  });

  it.each(['invalid API key', 'network connection reset', 'permission denied', 'tool failed'])(
    'does not fallback for non-model failure: %s',
    async (message) => {
      const initial = await service.select(member({ modelId: 'openai/cheap', optionalFallbackModel: 'openai/vision' }));
      expect(service.applyFallback(initial, new Error(message)).receipt.fallbackUsed).toBe(false);
    },
  );

  it('uses fallback for a compatible classified failure', async () => {
    const initial = await service.select(member({ modelId: 'openai/cheap', optionalFallbackModel: 'openai/vision' }));
    const fallback = service.applyFallback(initial, new Error('context length exceeded'));
    expect(fallback.receipt.fallbackUsed).toBe(true);
    expect(fallback.receipt.executedModel).toBe('openai/vision');
    expect(fallback.receipt.fallbackClassification).toBe('context_limit');
  });

  it('keeps unknown telemetry null', async () => {
    const result = await service.select(member({ modelId: 'openai/cheap' }));
    expect(result.receipt.inputTokens).toBeNull();
    expect(result.receipt.costUsd).toBeNull();
  });

  it('builds a safe CLI model flag', () => {
    expect(ModelSelectionService.runtimeModelFlags('codex-cli', 'openai/cheap')).toEqual(['--model', 'cheap']);
    expect(() => ModelSelectionService.runtimeModelFlags('codex-cli', 'openai/bad value')).toThrow('Unsafe model');
  });
});
