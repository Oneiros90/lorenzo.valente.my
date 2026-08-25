export function preloadImages(urls: Array<string | null | undefined>): Promise<void> {
  const unique = [...new Set(urls.filter((url): url is string => Boolean(url)))];
  if (!unique.length) return Promise.resolve();

  return Promise.all(
    unique.map(
      (src) =>
        new Promise<void>((resolve) => {
          const img = new Image();
          img.referrerPolicy = 'no-referrer';
          img.onload = () => resolve();
          img.onerror = () => resolve();
          img.src = src;
        })
    )
  ).then(() => undefined);
}
