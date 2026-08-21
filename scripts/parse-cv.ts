/**
 * Parse a Canva-exported CV PDF into bio + work history.
 *
 * Expected layout (two columns): experience/education on the left,
 * name/headline/about on the right. Jobs are "Role @ Company" with a
 * date ("YYYY - YYYY|Now") on the same baseline. Education rows
 * (University …) are dropped. Phone, email, and GDPR lines are never
 * copied into the site payload.
 *
 * If the Canva template changes substantially, adjust the heuristics here
 * rather than committing the PDF to the repo.
 */
import type { BioConfig, CompanyConfig, Vec3 } from '../src/lib/webgl/types.ts';
import { MAX_COMPANY_ORBS } from '../src/lib/webgl/picks.ts';

export interface CvColors {
  colorA: Vec3;
  colorB: Vec3;
}

export interface CvFetchConfig {
  archiveId: string;
  status: string;
  maxCompanies?: number;
  colors?: Record<string, CvColors>;
}

export interface CvProfile {
  bio: BioConfig;
  companies: CompanyConfig[];
}

export interface PdfTextItem {
  str: string;
  x: number;
  y: number;
}

const ROLE_AT = /^(.+?)\s+@\s+(.+?)(?:\s+(19\d{2}|20\d{2})\s*[-–—]\s*(19\d{2}|20\d{2}|Now|Present|Ongoing))?$/i;
const DATE_RANGE = /^(19\d{2}|20\d{2})\s*[-–—]\s*(19\d{2}|20\d{2}|Now|Present|Ongoing)$/i;
const EDUCATION_RE =
  /\buniversity\b|\buniversit[aà]\b|\bcollege\b|\bthesis\b|\bbachelor\b|\bmaster of\b/i;
const PII_RE =
  /(\+?\d[\d\s.-]{7,}\d)|([A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,})|(gdpr)|(legislative decree)|(\bI hereby authorize\b)|(\babout\.me\b)/i;
const SECTION_RE = /^(experience|education|technical skills|languages|proficient|familiar with)$/i;
const SPACED_LETTERS = /^(?:[A-Za-z]\s+){2,}[A-Za-z]$/;
const COLUMN_X = 360;

function slugify(name: string): string {
  return (
    name
      .normalize('NFKD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '') || 'company'
  );
}

function hash32(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function hslToRgb(h: number, s: number, l: number): Vec3 {
  const a = s * Math.min(l, 1 - l);
  const f = (n: number): number => {
    const k = (n + h * 12) % 12;
    return l - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
  };
  return [f(0), f(8), f(4)];
}

export function colorsForCompany(id: string, overrides?: Record<string, CvColors>): CvColors {
  if (overrides?.[id]) return overrides[id];
  const hue = (hash32(id) % 360) / 360;
  return {
    colorA: hslToRgb(hue, 0.72, 0.52),
    colorB: hslToRgb((hue + 0.18) % 1, 0.55, 0.28)
  };
}

function collapseSpaced(s: string): string {
  const t = s.trim();
  if (SPACED_LETTERS.test(t)) return t.replace(/\s+/g, '');
  return t.replace(/\s+/g, ' ');
}

function toTitleCase(s: string): string {
  return s
    .toLowerCase()
    .replace(/\b[a-z]/g, (c) => c.toUpperCase());
}

export function linesFromItems(items: PdfTextItem[]): string[] {
  const usable = items
    .map((it) => ({ ...it, str: collapseSpaced(it.str) }))
    .filter((it) => it.str.length > 0);
  usable.sort((a, b) => (Math.abs(b.y - a.y) > 2 ? b.y - a.y : a.x - b.x));

  const rows: { y: number; parts: { x: number; str: string }[] }[] = [];
  for (const it of usable) {
    const last = rows[rows.length - 1];
    if (last && Math.abs(last.y - it.y) < 4) {
      last.parts.push({ x: it.x, str: it.str });
    } else {
      rows.push({ y: it.y, parts: [{ x: it.x, str: it.str }] });
    }
  }

  return rows
    .map((row) => {
      row.parts.sort((a, b) => a.x - b.x);
      const merged: string[] = [];
      for (const part of row.parts) {
        const prev = merged[merged.length - 1];
        if (prev && /^[A-Za-z]$/.test(prev) && /^[A-Za-z]$/.test(part.str)) {
          merged[merged.length - 1] = prev + part.str;
        } else {
          merged.push(part.str);
        }
      }
      return merged.join(' ').replace(/\s+/g, ' ').trim();
    })
    .filter(Boolean);
}

function joinWrapped(lines: string[]): string {
  let out = '';
  for (const raw of lines) {
    const line = raw.replace(/\s+/g, ' ').trim();
    if (!line) continue;
    if (out.endsWith('-') && /^[a-z]/.test(line)) {
      out += line;
    } else if (out) {
      out += ' ' + line;
    } else {
      out = line;
    }
  }
  return out.replace(/\s+([,.;:])/g, '$1').replace(/\s+/g, ' ').trim();
}

function parseYearEnd(token: string): number | null {
  if (/^(now|present|ongoing)$/i.test(token)) return null;
  const n = Number(token);
  return Number.isFinite(n) ? n : null;
}

function yearsBetween(start: number, end: number | null, nowYear: number): number {
  const last = end ?? nowYear;
  return Math.max(1, last - start);
}

function formatPeriod(start: number, end: number | null): string {
  return `${start} — ${end == null ? 'present' : end}`;
}

function isJunk(line: string): boolean {
  return PII_RE.test(line) || SECTION_RE.test(line) || /^\+?\d[\d\s.-]+$/.test(line);
}

interface RawJob {
  role: string;
  company: string;
  description: string;
  start: number;
  end: number | null;
}

function parseJobs(left: string[], nowYear: number): RawJob[] {
  const jobs: RawJob[] = [];
  for (let i = 0; i < left.length; i++) {
    const match = left[i].match(ROLE_AT);
    if (!match) continue;
    const role = match[1].trim();
    let company = match[2].trim();
    let start = match[3] ? Number(match[3]) : 0;
    let end = match[4] ? parseYearEnd(match[4]) : null;
    if (EDUCATION_RE.test(role) || EDUCATION_RE.test(company)) continue;

    const dateOnCompany = company.match(
      /^(.*?)\s+(19\d{2}|20\d{2})\s*[-–—]\s*(19\d{2}|20\d{2}|Now|Present|Ongoing)$/i
    );
    if (dateOnCompany) {
      company = dateOnCompany[1].trim();
      start = Number(dateOnCompany[2]);
      end = parseYearEnd(dateOnCompany[3]);
    }

    const descParts: string[] = [];
    for (let j = i + 1; j < left.length && j <= i + 14; j++) {
      if (ROLE_AT.test(left[j]) && /@/.test(left[j])) break;
      if (EDUCATION_RE.test(left[j]) && !/@/.test(left[j])) break;
      if (DATE_RANGE.test(left[j])) {
        if (!start) {
          const d = left[j].match(DATE_RANGE)!;
          start = Number(d[1]);
          end = parseYearEnd(d[2]);
        }
        continue;
      }
      if (isJunk(left[j])) continue;
      if (left[j].length > 8) descParts.push(left[j]);
    }
    if (!start) continue;
    jobs.push({
      role,
      company,
      description: joinWrapped(descParts),
      start,
      end
    });
  }
  jobs.sort((a, b) => {
    const ae = a.end ?? nowYear + 1;
    const be = b.end ?? nowYear + 1;
    if (be !== ae) return be - ae;
    return b.start - a.start;
  });
  return jobs;
}

function parseBio(right: string[], config: CvFetchConfig): BioConfig {
  let name = 'Lorenzo Valente';
  let specialization = 'Software Engineer';
  const nameIdx = right.findIndex(
    (line, i) => /^lorenzo$/i.test(line) && right[i + 1] && /^valente$/i.test(right[i + 1])
  );
  if (nameIdx >= 0) name = `${right[nameIdx]} ${right[nameIdx + 1]}`;

  const headlineIdx = right.findIndex((line, i) => {
    const next = right[i + 1] ?? '';
    return /^software$/i.test(line) && /^engineer$/i.test(next);
  });
  if (headlineIdx >= 0) {
    specialization = toTitleCase(`${right[headlineIdx]} ${right[headlineIdx + 1]}`);
  } else {
    const single = right.find((line) => /^software\s+engineer$/i.test(line));
    if (single) specialization = toTitleCase(single);
  }

  const aboutStart = right.findIndex((line) => /extensive background/i.test(line));
  let description = '';
  if (aboutStart >= 0) {
    const parts: string[] = [];
    for (let i = aboutStart; i < right.length; i++) {
      if (/technical skills|proficient|familiar with|^languages$/i.test(right[i])) break;
      if (isJunk(right[i])) continue;
      parts.push(right[i]);
    }
    description = joinWrapped(parts);
  }

  return {
    archiveId: config.archiveId,
    status: config.status,
    name,
    specialization,
    description
  };
}

export function parseCvItems(
  items: PdfTextItem[],
  config: CvFetchConfig,
  nowYear = new Date().getFullYear()
): CvProfile {
  const left = linesFromItems(items.filter((it) => it.x < COLUMN_X));
  const right = linesFromItems(items.filter((it) => it.x >= COLUMN_X));
  const jobs = parseJobs(left, nowYear);
  const max = Math.min(config.maxCompanies ?? MAX_COMPANY_ORBS, MAX_COMPANY_ORBS);
  const seen = new Set<string>();
  const companies: CompanyConfig[] = [];
  for (const job of jobs) {
    let id = slugify(job.company);
    if (seen.has(id)) id = `${id}-${job.start}`;
    seen.add(id);
    const { colorA, colorB } = colorsForCompany(id, config.colors);
    companies.push({
      id,
      years: yearsBetween(job.start, job.end, nowYear),
      colorA,
      colorB,
      name: job.company,
      role: job.role,
      period: formatPeriod(job.start, job.end),
      description: job.description
    });
    if (companies.length >= max) break;
  }

  return { bio: parseBio(right, config), companies };
}
