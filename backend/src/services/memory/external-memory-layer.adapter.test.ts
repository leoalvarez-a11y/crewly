import { ExternalMemoryLayerAdapter } from './external-memory-layer.adapter.js';

describe('ExternalMemoryLayerAdapter', () => {
  it('stays disabled without configuration', async () => {
    const adapter = new ExternalMemoryLayerAdapter({ serviceUrl: '' });
    expect((await adapter.query({ objective: 'o', task: 't', role: 'r', project: 'p' })).status).toBe('disabled');
  });

  it('deduplicates, redacts, bounds, and preserves references', async () => {
    const adapter = new ExternalMemoryLayerAdapter({
      serviceUrl: 'http://memory.invalid/query',
      maxReferences: 2,
      maxCharacters: 80,
      transport: async () => new Response(JSON.stringify({ references: [
        { content: 'Use the stable adapter. api_key=super-secret', reference: 'memory://one' },
        { content: 'Use the stable adapter. api_key=super-secret', reference: 'memory://duplicate' },
        { content: 'Second fact with Bearer abcdefghijklmnop', reference: 'memory://two' },
      ] }), { status: 200 }),
    });
    const result = await adapter.query({ objective: 'o', task: 't', role: 'docs', project: 'p' });
    expect(result.status).toBe('success');
    expect(result.references).toHaveLength(2);
    expect(result.references[0].content).toContain('[REDACTED]');
    expect(result.references[0].reference).toBe('memory://one');
    expect(result.references.map((item) => item.content).join('')).not.toContain('super-secret');
  });

  it('fails non-blockingly', async () => {
    const adapter = new ExternalMemoryLayerAdapter({
      serviceUrl: 'http://memory.invalid/query',
      transport: async () => { throw new Error('offline'); },
    });
    const result = await adapter.query({ objective: 'o', task: 't', role: 'r', project: 'p' });
    expect(result).toMatchObject({ status: 'error', references: [] });
  });
});
