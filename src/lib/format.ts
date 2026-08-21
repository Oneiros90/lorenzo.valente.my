export function displayUrl(url: string): string {
  try {
    const parsed = new URL(url);
    return `${parsed.host.replace(/^www\./, '')}${parsed.pathname}`.replace(/\/$/, '');
  } catch {
    return url.replace(/^https?:\/\//, '').replace(/\/$/, '');
  }
}

export function formatMonthYear(date: Date, locale: string): string {
  return date.toLocaleDateString(locale, { year: 'numeric', month: 'short' });
}
