export type Theme = 'dark' | 'light';

const KEY = 'valente-theme';

export function getInitialTheme(): Theme {
  try {
    const stored = localStorage.getItem(KEY);
    if (stored === 'dark' || stored === 'light') return stored;
  } catch {
    /* private mode */
  }
  return 'dark';
}

export function applyTheme(theme: Theme) {
  document.documentElement.dataset.theme = theme;
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute('content', theme === 'dark' ? '#000000' : '#e4ddd4');
  try {
    localStorage.setItem(KEY, theme);
  } catch {
    /* ignore */
  }
}
