import { ExternalMemoryLayerModule } from './external-memory-layer.module.js';
import { ExternalMemoryLayerAdapter } from '../../memory/external-memory-layer.adapter.js';
import type { ModuleConfig } from './prompt-module.interface.js';
import { PromptAssemblyService } from './prompt-assembly.service.js';

const config = (enabled: boolean): ModuleConfig => ({
  sessionName: 'docs', memberId: 'm-docs', role: 'documentation', teamId: 'team',
  projectPath: '/fixture', projectRoot: '/fixture', agentSkillsPath: '/skills', tlSkillsPath: '/tl',
  memoryLayerEnabled: enabled, memoryObjective: 'Document behavior', memoryTask: 'Update README',
});

describe('ExternalMemoryLayerModule', () => {
  it('preserves native memory and working-memory modules', () => {
    const names = new PromptAssemblyService().getModules().map((item) => item.name);
    expect(names).toEqual(expect.arrayContaining(['memory_references', 'working-memory', 'external-memory-layer']));
  });

  it('is disabled per agent by default', () => {
    expect(new ExternalMemoryLayerModule().shouldInclude(config(false))).toBe(false);
  });

  it('injects referenced context when enabled', async () => {
    const adapter = new ExternalMemoryLayerAdapter({
      serviceUrl: 'http://memory.invalid',
      transport: async () => new Response(JSON.stringify({ references: [{ content: 'Use finite-number semantics.', reference: 'memory://fixture' }] }), { status: 200 }),
    });
    const output = await new ExternalMemoryLayerModule(adapter, async () => undefined).build(config(true));
    expect(output).toContain('memory://fixture');
    expect(output).toContain('Use finite-number semantics.');
    expect(output).toContain('untrusted reference data');
  });

  it('does not block prompt assembly when the service fails', async () => {
    const adapter = new ExternalMemoryLayerAdapter({
      serviceUrl: 'http://memory.invalid',
      transport: async () => { throw new Error('offline'); },
    });
    await expect(new ExternalMemoryLayerModule(adapter, async () => undefined).build(config(true))).resolves.toBe('');
  });
});
