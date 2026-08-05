import { useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { translateLegacyEsMx } from '../../i18n/resources';

const RAW_SELECTORS = 'pre, code, .xterm, [data-i18n-skip], [data-terminal], textarea, input';

/** Adds Spanish coverage to legacy text nodes while excluding raw and third-party content. */
export function LocalizedDocument(): null {
  const { i18n } = useTranslation();
  useEffect(() => {
    if (i18n.language !== 'es-MX') return;
    const localize = (root: Node): void => {
      const localizeTextNode = (textNode: Node): void => {
        const parent = textNode.parentElement;
        if (!parent || parent.closest(RAW_SELECTORS)) return;
        const value = textNode.textContent?.trim();
        if (!value) return;
        const translated = translateLegacyEsMx(value);
        if (translated !== value) textNode.textContent = (textNode.textContent ?? '').replace(value, translated);
      };

      if (root.nodeType === Node.TEXT_NODE) localizeTextNode(root);
      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      let node: Node | null;
      while ((node = walker.nextNode())) localizeTextNode(node);

      const element = root.nodeType === Node.ELEMENT_NODE ? root as Element : root.parentElement;
      const elements = element ? [element, ...Array.from(element.querySelectorAll('*'))] : [];
      for (const candidate of elements) {
        if (candidate.closest(RAW_SELECTORS)) continue;
        for (const attribute of ['title', 'aria-label']) {
          const value = candidate.getAttribute(attribute);
          if (!value) continue;
          const translated = translateLegacyEsMx(value);
          if (translated !== value) candidate.setAttribute(attribute, translated);
        }
      }
    };
    localize(document.body);
    const observer = new MutationObserver((mutations) => mutations.forEach((mutation) => {
      mutation.addedNodes.forEach(localize);
      if (mutation.type === 'characterData') localize(mutation.target);
    }));
    observer.observe(document.body, { childList: true, characterData: true, subtree: true });
    return () => observer.disconnect();
  }, [i18n.language]);
  return null;
}
