import { describe, expect, it } from 'vitest';
import { DEFAULT_LOCALE, FALLBACK_LOCALE, LEGACY_ES_MX_PHRASES, resources } from './resources';

describe('i18n resources', () => {
  it('defaults to es-MX and preserves en-US with matching keyed structure', () => {
    expect(DEFAULT_LOCALE).toBe('es-MX');
    expect(FALLBACK_LOCALE).toBe('en-US');
    expect(Object.keys(resources['es-MX'].translation.nav)).toEqual(Object.keys(resources['en-US'].translation.nav));
  });

  it('covers principal visible surfaces in Spanish', () => {
    for (const label of ['Dashboard', 'Projects', 'Teams', 'Agents', 'Tasks', 'Requests', 'Activity', 'Memory', 'Settings', 'Approvals', 'Backups', 'Health']) {
      expect(LEGACY_ES_MX_PHRASES[label]).toBeTruthy();
    }
  });
});
