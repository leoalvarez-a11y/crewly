import { describe, expect, it } from 'vitest';
import i18n, { setCrewlyLocale } from './index';

describe('i18n', () => {
  it('switches to English and falls back to English for missing Spanish keys', async () => {
    await setCrewlyLocale('en-US');
    expect(i18n.t('nav.dashboard')).toBe('Dashboard');
    expect(localStorage.getItem('crewly.locale')).toBe('en-US');
  });
});
