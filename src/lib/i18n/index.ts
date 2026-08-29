import it from './it.json';
import en from './en.json';
import siteIt from './site/it.json';
import siteEn from './site/en.json';
import sceneConfig from '../config/scene.json';

export type Locale = 'it' | 'en';
export type LocaleData = typeof it;
export type SiteLocaleData = typeof siteEn;

const catalogs: Record<Locale, LocaleData> = { it, en };
const siteCatalogs: Record<Locale, SiteLocaleData> = { it: siteIt, en: siteEn };

export function getDefaultLocale(): Locale {
  const params = new URLSearchParams(globalThis.location?.search ?? '');
  const q = params.get('lang');
  if (q === 'it' || q === 'en') return q;
  const nav = globalThis.navigator?.language?.slice(0, 2);
  if (nav === 'it' || nav === 'en') return nav;
  return sceneConfig.defaultLocale as Locale;
}

export function getLocaleData(locale: Locale): LocaleData {
  return catalogs[locale];
}

export function getSiteStrings(locale: Locale): SiteLocaleData {
  return siteCatalogs[locale];
}

export function t(template: string, vars: Record<string, string | number> = {}): string {
  return template.replace(/\{(\w+)\}/g, (_, key: string) => String(vars[key] ?? `{${key}}`));
}

export function colorToHex(rgb: number[]): string {
  return '#' + rgb.map((v) => Math.round(v * 255).toString(16).padStart(2, '0')).join('');
}

export function loc(text: { en: string; it: string }, locale: Locale): string {
  return text[locale] ?? text.en;
}
