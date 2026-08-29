import github from '$lib/config/github.json';
import type { GithubProfile, ProjectConfig } from '$lib/webgl/types';

const FETCH_TIMEOUT_MS = 8000;
const README_TIMEOUT_MS = 5000;
const USER_URL = `https://api.github.com/users/${github.username}`;
const REPOS_URL = `https://api.github.com/users/${github.username}/repos?per_page=100&type=owner`;

export const EMPTY_GITHUB_PROFILE: GithubProfile = {
  name: '',
  username: github.username,
  avatar: null,
  url: `https://github.com/${github.username}`,
  location: '',
  company: '',
  followers: null,
  joined: null,
  publicRepos: null
};

const MD_IMG = /!\[[^\]]*]\(\s*<?([^)\s>]+)>?(?:\s+(?:"[^"]*"|'[^']*'))?\s*\)/g;
const HTML_IMG = /<img\b[^>]*?\bsrc\s*=\s*(?:"([^"]+)"|'([^']+)')[^>]*>/gi;
const BADGE_RE =
  /shields\.io|badgen\.net|badge|travis-ci|codecov|coveralls|appveyor|circleci|dependabot|github\.com\/[^/]+\/[^/]+\/(?:actions|workflows)|commitizen|snyk\.io/i;

interface GithubUser {
  name: string | null;
  login: string;
  avatar_url: string;
  html_url: string;
  location: string | null;
  company: string | null;
  followers: number;
  created_at: string;
  public_repos: number;
}

interface GithubRepo {
  name: string;
  description: string | null;
  html_url: string;
  stargazers_count: number;
  language: string | null;
  topics?: string[];
  fork: boolean;
  updated_at: string;
  default_branch: string;
}

export interface GithubPayload {
  profile: GithubProfile;
  projects: ProjectConfig[];
}

function toProfile(user: GithubUser): GithubProfile {
  return {
    name: user.name ?? '',
    username: user.login,
    avatar: user.avatar_url || null,
    url: user.html_url,
    location: user.location ?? '',
    company: user.company?.replace(/^@/, '') ?? '',
    followers: user.followers,
    joined: user.created_at,
    publicRepos: user.public_repos
  };
}

function toProject(repo: GithubRepo, imageUrl: string | null): ProjectConfig {
  return {
    id: repo.name,
    name: repo.name,
    description: repo.description ?? '',
    url: repo.html_url,
    stars: repo.stargazers_count,
    lang: repo.language ?? '—',
    tags: repo.topics ?? [],
    imageUrl
  };
}

function combineSignals(parent?: AbortSignal): { signal: AbortSignal; cleanup: () => void } {
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), FETCH_TIMEOUT_MS);
  const onAbort = () => ac.abort();
  parent?.addEventListener('abort', onAbort);
  return {
    signal: ac.signal,
    cleanup: () => {
      clearTimeout(timer);
      parent?.removeEventListener('abort', onAbort);
    }
  };
}

function mergeSignals(parent: AbortSignal | undefined, timeoutMs: number): AbortSignal {
  const timeout = AbortSignal.timeout(timeoutMs);
  if (!parent) return timeout;
  if (typeof AbortSignal.any === 'function') return AbortSignal.any([parent, timeout]);
  return timeout;
}

function isBadge(src: string): boolean {
  return BADGE_RE.test(src) || src.startsWith('data:');
}

function isGenericCover(src: string): boolean {
  return /opengraph\.githubassets\.com|socialify\.git\.ci|github-readme-stats/i.test(src);
}

export function firstReadmeImageSrc(markdown: string): string | null {
  const found: { index: number; src: string }[] = [];
  for (const re of [MD_IMG, HTML_IMG]) {
    re.lastIndex = 0;
    let match: RegExpExecArray | null;
    while ((match = re.exec(markdown))) {
      const src = match[1] || match[2];
      if (src) found.push({ index: match.index, src });
    }
  }
  found.sort((a, b) => a.index - b.index);
  for (const item of found) {
    if (!isBadge(item.src) && !isGenericCover(item.src)) return item.src;
  }
  return null;
}

export function resolveReadmeImage(
  src: string,
  owner: string,
  repo: string,
  branch: string
): string {
  const decoded = src.replace(/&amp;/g, '&').trim();
  const blob = decoded.match(
    /^https?:\/\/github\.com\/([^/]+)\/([^/]+)\/blob\/([^/]+)\/(.+?)(?:\?.*)?$/i
  );
  if (blob) {
    const [, o, r, b, path] = blob;
    return `https://raw.githubusercontent.com/${o}/${r}/${b}/${path}`;
  }
  if (/^https?:\/\//i.test(decoded)) return decoded;
  const path = decoded.replace(/^\.\//, '').replace(/^\//, '');
  return `https://raw.githubusercontent.com/${owner}/${repo}/${branch}/${path}`;
}

async function fetchReadmeMarkdown(
  repo: GithubRepo,
  signal?: AbortSignal
): Promise<string | null> {
  const branch = repo.default_branch || 'main';
  const urls = [
    `https://raw.githubusercontent.com/${github.username}/${repo.name}/${branch}/README.md`,
    `https://cdn.jsdelivr.net/gh/${github.username}/${repo.name}@${branch}/README.md`
  ];
  for (const url of urls) {
    try {
      const res = await fetch(url, { signal: mergeSignals(signal, README_TIMEOUT_MS) });
      if (res.ok) return await res.text();
    } catch {
      /* try next source */
    }
  }
  return null;
}

async function readmeImageUrl(repo: GithubRepo, signal?: AbortSignal): Promise<string | null> {
  const markdown = await fetchReadmeMarkdown(repo, signal);
  if (!markdown) return null;
  const src = firstReadmeImageSrc(markdown);
  if (!src) return null;
  return resolveReadmeImage(src, github.username, repo.name, repo.default_branch || 'main');
}

export async function fetchGithubProjects(signal?: AbortSignal): Promise<GithubPayload> {
  const { signal: combined, cleanup } = combineSignals(signal);
  const headers = { Accept: 'application/vnd.github+json' };
  try {
    const [userRes, reposRes] = await Promise.all([
      fetch(USER_URL, { signal: combined, headers }),
      fetch(REPOS_URL, { signal: combined, headers })
    ]);
    if (!reposRes.ok) throw new Error(`GitHub ${reposRes.status}`);
    const repos = (await reposRes.json()) as GithubRepo[];
    const profile = userRes.ok
      ? toProfile((await userRes.json()) as GithubUser)
      : EMPTY_GITHUB_PROFILE;
    const selected = repos
      .filter((repo) => !repo.fork)
      .sort((a, b) => {
        if (b.stargazers_count !== a.stargazers_count) {
          return b.stargazers_count - a.stargazers_count;
        }
        return Date.parse(b.updated_at) - Date.parse(a.updated_at);
      });
    const projects = await Promise.all(
      selected.map(async (repo) => toProject(repo, await readmeImageUrl(repo, signal)))
    );
    return { profile, projects };
  } finally {
    cleanup();
  }
}
