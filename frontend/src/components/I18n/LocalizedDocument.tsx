import { useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { LEGACY_ES_MX_PHRASES } from '../../i18n/resources';

const RAW_SELECTORS = 'pre, code, .xterm, [data-i18n-skip], [data-terminal], textarea, input';

/** Adds Spanish coverage to legacy text nodes while excluding raw and third-party content. */
export function LocalizedDocument(): null {
  const { i18n } = useTranslation();
  useEffect(() => {
    if (i18n.language !== 'es-MX') return;
    const localize = (root: Node): void => {
      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      let node: Node | null;
      while ((node = walker.nextNode())) {
        const parent = node.parentElement;
        if (!parent || parent.closest(RAW_SELECTORS)) continue;
        const value = node.textContent?.trim();
        if (value && LEGACY_ES_MX_PHRASES[value]) node.textContent = (node.textContent ?? '').replace(value, LEGACY_ES_MX_PHRASES[value]);
      }
    };
    localize(document.body);
    const observer = new MutationObserver((mutations) => mutations.forEach((mutation) => mutation.addedNodes.forEach(localize)));
    observer.observe(document.body, { childList: true, subtree: true });
    return () => observer.disconnect();
  }, [i18n.language]);
  return null;
}
