export const BIO_PICK = 1;
export const CHESS_PICK = 2;
export const GITHUB_PICK = 3;
export const COMPANY_PICK_BASE = 4;
export const MAX_COMPANY_ORBS = 8;
export const SOCIAL_PICK_BASE = COMPANY_PICK_BASE + MAX_COMPANY_ORBS;

export function isCompanyPick(id: number, count: number): boolean {
  return id >= COMPANY_PICK_BASE && id < COMPANY_PICK_BASE + count;
}

export function companyIndexFromPick(id: number): number {
  return id - COMPANY_PICK_BASE;
}

export function companyPickId(index: number): number {
  return COMPANY_PICK_BASE + index;
}
