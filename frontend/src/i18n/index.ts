import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import { DEFAULT_LOCALE, FALLBACK_LOCALE, LOCALE_STORAGE_KEY, resources } from './resources';

const storedLocale = typeof window !== 'undefined' ? window.localStorage.getItem(LOCALE_STORAGE_KEY) : null;
const initialLocale = storedLocale === 'en-US' || storedLocale === 'es-MX' ? storedLocale : DEFAULT_LOCALE;

void i18n.use(initReactI18next).init({ resources, lng: initialLocale, fallbackLng: FALLBACK_LOCALE, interpolation: { escapeValue: false }, returnNull: false });

/** Persists and applies a supported locale. */
export async function setCrewlyLocale(locale: 'es-MX' | 'en-US'): Promise<void> {
  window.localStorage.setItem(LOCALE_STORAGE_KEY, locale);
  await i18n.changeLanguage(locale);
}

export default i18n;
