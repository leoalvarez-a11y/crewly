import { describe, expect, it, vi } from 'vitest';

vi.mock('../../settings/settings.service.js', () => ({
  getSettingsService: () => ({
    getSettings: async () => ({ general: { agentLanguageInstruction: 'Responde en espanol.' } }),
  }),
}));

import { LanguagePreferenceModule } from './language-preference.module.js';

describe('LanguagePreferenceModule', () => {
  it('injects the configured global language instruction', async () => {
    const module = new LanguagePreferenceModule();
    await expect(module.build({} as never)).resolves.toContain('Responde en espanol.');
    expect(module.compactable).toBe(false);
  });
});
