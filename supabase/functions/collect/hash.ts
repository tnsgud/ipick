/** djb2 기반 결정적 해시 → 16진 문자열. 암호학적 용도 아님(중복키 폴백용). */
export function stableHash(input: string): string {
  let h = 5381;
  for (let i = 0; i < input.length; i++) {
    h = ((h << 5) + h + input.charCodeAt(i)) >>> 0;
  }
  return h.toString(16);
}
