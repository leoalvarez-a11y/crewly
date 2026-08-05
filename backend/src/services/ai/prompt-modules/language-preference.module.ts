import { getSettingsService } from '../../settings/settings.service.js';
import { ModuleConfig, PromptModule } from './prompt-module.interface.js';

/** Adds the administrator-configured response language without translating code. */
export class LanguagePreferenceModule implements PromptModule {
  name = 'language-preference';
  priority = 10.5;
  maxTokens = 120;
  compactable = false;

  /** Language policy applies to every real agent prompt. */
  shouldInclude(_config: ModuleConfig): boolean {
    return true;
  }

  /** Builds a short trusted language policy from persisted settings. */
  async build(_config: ModuleConfig): Promise<string> {
    const settings = await getSettingsService().getSettings();
    const instruction = settings.general.agentLanguageInstruction ?? 'Responde y documenta en espanol de Mexico, excepto el codigo y los terminos tecnicos que deban conservarse.';
    return `## Idioma de trabajo\n${instruction}`;
  }
}
