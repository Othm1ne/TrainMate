/** French SIRET: 14 digits passing the Luhn check (La Poste establishments excepted). */
export function isValidSiret(raw: string): boolean {
  const s = raw.replace(/\s/g, "");
  if (!/^\d{14}$/.test(s)) return false;
  // La Poste (SIREN 356000000) uses a different checksum: digit sum % 5 == 0.
  if (s.startsWith("356000000")) {
    return s.split("").reduce((a, c) => a + Number(c), 0) % 5 === 0;
  }
  let sum = 0;
  for (let i = 0; i < 14; i++) {
    let d = Number(s[13 - i]);
    if (i % 2 === 1) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return sum % 10 === 0;
}
