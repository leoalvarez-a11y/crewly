/**
 * Repairs the two encoding failures observed at Crewly's Windows PTY boundary:
 * UTF-8 decoded as Latin-1, and common Spanish characters replaced by U+FFFD
 * or `?` before the HTTP request reaches the backend.
 */

const REVERSIBLE_MOJIBAKE_MARKERS = /[\u00c2\u00c3\u00e2]/u;
const DAMAGE_MARKERS = /[\ufffd]|(?:\p{L})\?(?:\p{L})/u;

const SPANISH_REPAIRS: ReadonlyArray<readonly [RegExp, string]> = [
  [/([A-ZÁÉÍÓÚÑ]+CI)ón\b/gu, '$1ÓN'],
  [/\b(no los )toquó/giu, '$1toqué'],
  [/Postgres[\ufffd?]Shopify[\ufffd?]p[\ufffd?]gina/giu, 'Postgres–Shopify–página'],
  [/(actualizaci|verificaci|aceptaci|afirmaci|publicaci|ejecuci|operaci|recuperaci|configuraci|comprobaci|conciliaci|adquisici|descripci|distribuci|documentaci|evaluaci|funci|homologaci|migraci|producci|atenci|correcci|contradicci|precisi|recomendaci|revisi|soluci|autorizaci|clasificaci|colaboraci|confirmaci|multiplicaci|materializaci|decisi|secci|sesi|acci)[\ufffd?]n/giu, '$1ón'],
  [/(tambi)[\ufffd?]n/giu, '$1én'],
  [/(despu)[\ufffd?]s/giu, '$1és'],
  [/(adem)[\ufffd?]s/giu, '$1ás'],
  [/(p)[\ufffd?](ginas?)/giu, '$1á$2'],
  [/(hu)[\ufffd?](rfanas?)/giu, '$1é$2'],
  [/(c)[\ufffd?](lculo)/giu, '$1á$2'],
  [/(hist)[\ufffd?](rico|rica)/giu, '$1ó$2'],
  [/(s)[\ufffd?](lo)/giu, '$1ó$2'],
  [/(categor|auditor|gu|todav)[\ufffd?]a/giu, '$1ía'],
  [/(matr)[\ufffd?](cula)/giu, '$1í$2'],
  [/(autom)[\ufffd?](ticamente|tico)/giu, '$1á$2'],
  [/(aut)[\ufffd?](nomamente|nomas?|nomos?)/giu, '$1ó$2'],
  [/(can)[\ufffd?](nico|nicos)/giu, '$1ó$2'],
  [/(m)[\ufffd?](nimo|nimos|nimo:|nimo\.)/giu, '$1í$2'],
  [/(im)[\ufffd?](genes)/giu, '$1á$2'],
  [/(p)[\ufffd?](blica)/giu, '$1ú$2'],
  [/(gen)[\ufffd?](ricos)/giu, '$1é$2'],
  [/(ning)[\ufffd?](n)/giu, '$1ú$2'],
  [/(vac)[\ufffd?](o)/giu, '$1í$2'],
  [/(dise)[\ufffd?](ada)/giu, '$1ñ$2'],
  [/(espa)[\ufffd?](ol)/giu, '$1ñ$2'],
  [/\b(T)[\ufffd?](?=\s|[,.:;])/gu, '$1ú'],
  [/(l)[\ufffd?](der)/giu, '$1í$2'],
  [/(t)[\ufffd?](cnico)/giu, '$1é$2'],
  [/(espec)[\ufffd?](ficas?)/giu, '$1í$2'],
  [/(Correg)[\ufffd?](?=\s)/gu, '$1í'],
  [/(agregu)[\ufffd?](?=\s)/giu, '$1é'],
  [/(hab)[\ufffd?](a)/giu, '$1í$2'],
  [/(revis|regres|decidi|debi)[\ufffd?](?=\s)/giu, '$1ó'],
  [/(ampl)[\ufffd?](a)/giu, '$1í$2'],
  [/(enga)[\ufffd?](oso)/giu, '$1ñ$2'],
  [/(m)[\ufffd?](todo)/giu, '$1é$2'],
  [/(se)[\ufffd?](alar)/giu, '$1ñ$2'],
  [/(cat)[\ufffd?](logo)/giu, '$1á$2'],
  [/(p)[\ufffd?](rdida)/giu, '$1é$2'],
  [/(a)[\ufffd?](n)(?=\b)/giu, '$1ú$2'],
  [/\b(aqu)[\ufffd?](?=\b|\s|[,.:;])/giu, '$1í'],
  [/\b(qu)[\ufffd?](?=\b|\s|[,.:;])/giu, '$1é'],
  [/\b(as)[\ufffd?](?=\b|\s|[,.:;])/giu, '$1í'],
  [/\b(s)[\ufffd?](?=\b|\s|[,.:;])/giu, '$1í'],
  [/\b(m)[\ufffd?](s)(?=\b|\s|[,.:;])/giu, '$1á$2'],
  [/\b(est)[\ufffd?](n?)(?=\b|\s|[,.:;])/giu, '$1á$2'],
  [/(har)[\ufffd?](?=\b|\s|[,.:;])/giu, '$1é'],
  [/(mant)[\ufffd?](n)/giu, '$1é$2'],
  [/(lim)[\ufffd?](tate)/giu, '$1í$2'],
  [/(ejecut|complet)[\ufffd?](?=\s+únicamente)/giu, '$1é'],
  [/(reasign)[\ufffd?](?=\s+al)/giu, '$1é'],
  [/(entend)[\ufffd?](?=\s+que)/giu, '$1í'],
  [/(no\s+)(ejecut)[\ufffd?](?=\s+la\s+verificación)/giu, '$1$2é'],
  [/(responder|ajustar|continuar|revisar|contrastar|esperar|consultar|repetir|usar|seguir|avisar|confirmar|cambiar)[\ufffd?](?=\b|\s|[,.!:;])/giu, '$1é'],
  [/(ser|publicar)[\ufffd?](?=\b|\s|[,.!:;])/giu, '$1á'],
  [/(incluir|corresponder)[\ufffd?](n)/giu, '$1á$2'],
  [/(termin|confirm|complet|ejecut|escribi|fall|qued|modific|report|toqu|agot|avanz|arranc|cambi|choc|detect|entend|entreg|encontr|lleg|pas|reactiv|reasign|rechaz|recuper|resolvi|result|tom|dej|dividi|alter|duplic|intent|bloque)[\ufffd?](?=\b|\s|[,.!:;])/giu, '$1ó'],
  [/(contin)[\ufffd?](a)/giu, '$1ú$2'],
  [/(env)[\ufffd?](a)/giu, '$1í$2'],
  [/(expl)[\ufffd?](ci)/giu, '$1í$2'],
  [/(reg)[\ufffd?](strate)/giu, '$1í$2'],
  [/(c)[\ufffd?](digo)/giu, '$1ó$2'],
  [/(l)[\ufffd?](nea)/giu, '$1í$2'],
  [/(M)[\ufffd?](xico)/gu, '$1é$2'],
  [/(exist)[\ufffd?](a)/giu, '$1í$2'],
  [/(pr)[\ufffd?](xima)/giu, '$1ó$2'],
  [/(patr)[\ufffd?](n)/giu, '$1ó$2'],
  [/(v)[\ufffd?](lido)/giu, '$1á$2'],
  [/(se)[\ufffd?](ales)/giu, '$1ñ$2'],
  [/(t)[\ufffd?](tulo)/giu, '$1í$2'],
  [/(A)[\ufffd?](adir)/gu, '$1ñ$2'],
  [/[\ufffd]3\.0/gu, '§3.0'],
  [/[\ufffd?]ltim/giu, 'últim'],
  [/\ufffdnic/giu, 'únic'],
  [/\ufffdnicos/giu, 'únicos'],
  [/(b65af8)[\ufffd?](?=\b|[,.;])/giu, '$1…'],
  [/(\belegibles)[\ufffd](?=\r?\n|$)/gium, '$1?'],
  [/(\d)[\ufffd](\d)/gu, '$1–$2'],
  [/\s[\ufffd]\s/gu, ' — '],
  [/^[?]{1,2}\s+/gmu, '• '],
];

function damageScore(value: string): number {
  let score = 0;
  for (const char of value) {
    const code = char.codePointAt(0) ?? 0;
    if (code === 0xfffd) score += 8;
    if (code === 0xc2 || code === 0xc3 || code === 0xe2) score += 2;
  }
  return score;
}

function repairLatin1Mojibake(value: string): string {
  if (!REVERSIBLE_MOJIBAKE_MARKERS.test(value)) return value;
  const windows1252: Record<number, number> = {
    0x20ac: 0x80, 0x201a: 0x82, 0x0192: 0x83, 0x201e: 0x84,
    0x2026: 0x85, 0x2020: 0x86, 0x2021: 0x87, 0x02c6: 0x88,
    0x2030: 0x89, 0x0160: 0x8a, 0x2039: 0x8b, 0x0152: 0x8c,
    0x017d: 0x8e, 0x2018: 0x91, 0x2019: 0x92, 0x201c: 0x93,
    0x201d: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97,
    0x02dc: 0x98, 0x2122: 0x99, 0x0161: 0x9a, 0x203a: 0x9b,
    0x0153: 0x9c, 0x017e: 0x9e, 0x0178: 0x9f,
  };
  const bytes: number[] = [];
  for (const char of value) {
    const code = char.codePointAt(0) ?? 0;
    const encoded = windows1252[code] ?? code;
    if (encoded > 0xff) return value;
    bytes.push(encoded);
  }
  const candidate = Buffer.from(bytes).toString('utf8');
  return damageScore(candidate) < damageScore(value) ? candidate : value;
}

/** Return normalized display text while leaving already-correct Unicode intact. */
export function repairTextEncoding(value: string): string {
  let repaired = value;
  for (let pass = 0; pass < 2; pass += 1) {
    const next = repairLatin1Mojibake(repaired);
    if (next === repaired) break;
    repaired = next;
  }
  for (const [pattern, replacement] of SPANISH_REPAIRS) {
    repaired = repaired.replace(pattern, replacement);
  }
  return repaired.normalize('NFC');
}

/** Recursively repair strings in JSON-shaped API payloads without mutating them. */
export function repairTextEncodingDeep<T>(value: T): T {
  if (typeof value === 'string') return repairTextEncoding(value) as T;
  if (Array.isArray(value)) return value.map(repairTextEncodingDeep) as T;
  if (value && typeof value === 'object') {
    const prototype = Object.getPrototypeOf(value);
    if (prototype !== Object.prototype && prototype !== null) return value;
    return Object.fromEntries(
      Object.entries(value).map(([key, child]) => [key, repairTextEncodingDeep(child)]),
    ) as T;
  }
  return value;
}

/** True when text still contains corruption that cannot be inferred safely. */
export function hasEncodingDamage(value: string): boolean {
  return DAMAGE_MARKERS.test(value) || damageScore(value) > 0;
}
