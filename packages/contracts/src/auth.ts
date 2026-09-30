import { z } from 'zod';
import commonPasswordList from './data/common-passwords.json' with { type: 'json' };

// ----------------------------------------------------------------- email

/**
 * The one spelling of an address. Case and stray spaces are how the same
 * person ends up with two accounts, so both are gone before the address
 * is stored, looked up or compared.
 */
export function normalizeEmail(raw: string): string {
  return raw.trim().toLowerCase();
}

export const emailSchema = z
  .string()
  .transform(normalizeEmail)
  .pipe(z.email({ message: 'Not an email address' }).max(254));

// -------------------------------------------------------------- password

export const passwordMinLength = 10;

/**
 * An upper bound, too: argon2 would hash a megabyte happily, and a
 * sign-in endpoint that does so on request is a denial of service.
 */
export const passwordMaxLength = 256;

const commonPasswords: ReadonlySet<string> = new Set(commonPasswordList);

/** The leetspeak a list-maker tries first, undone: `p@ssw0rd` is `password`. */
const leet: Record<string, string> = { '0': 'o', '3': 'e', '4': 'a', '5': 's', '@': 'a', $: 's' };

function unleet(value: string, one: 'i' | 'l'): string {
  return value.replace(/[01345@$]/g, (c) => (c === '1' ? one : (leet[c] ?? c)));
}

/** Digits and the usual symbols tacked on the end: `password12`, `Password123!`. */
const trailing = /[\d!@#$%^&*?.,;:_+=~-]+$/;

/**
 * Whether [password] is one of the 10,000 most common passwords, or one
 * of them dressed up (W6-40): the list is lowercase, and so is the
 * comparison ("Password12" is no better than "password12"); digits and
 * symbols added at the end are taken off when at least four characters
 * are left ("password12", "Password123!"); and the common leetspeak is
 * undone ("p@ssw0rd"). The clients' own check is this one, so what they
 * say while I type is what the server decides.
 */
export function isCommonPassword(password: string): boolean {
  const lower = password.toLowerCase();
  const candidates = new Set<string>([lower]);
  const stripped = lower.replace(trailing, '');
  if (stripped.length >= 4) candidates.add(stripped);
  for (const base of [lower, stripped]) {
    for (const one of ['i', 'l'] as const) {
      const plain = unleet(base, one);
      if (plain.length >= 4) candidates.add(plain);
      const bare = plain.replace(trailing, '');
      if (bare.length >= 4) candidates.add(bare);
    }
  }
  return [...candidates].some((candidate) => commonPasswords.has(candidate));
}

/**
 * The whole policy ([[Accounts]]): at least ten characters, and not one
 * everybody else chose first. No composition rules; they make passwords
 * harder to remember, not harder to guess.
 */
export const passwordSchema = z
  .string()
  .min(passwordMinLength, { message: `At least ${passwordMinLength} characters` })
  .max(passwordMaxLength, { message: `At most ${passwordMaxLength} characters` })
  .refine((value) => !isCommonPassword(value), {
    message: 'Too common; pick something less guessable',
  });

/**
 * What sign-in accepts. It deliberately does not apply the policy: an
 * account made before a rule changed must still be able to sign in, and
 * "too short" must not hint that nobody with that password exists.
 */
const loginPasswordSchema = z.string().min(1).max(passwordMaxLength);

// --------------------------------------------------------------- clients

/**
 * Where the refresh token goes. The web keeps it in an HttpOnly cookie
 * no script can read; the phone keeps it in secure storage, so it needs
 * the token in the body.
 */
export const clientKindSchema = z.enum(['web', 'mobile']);
export type ClientKind = z.infer<typeof clientKindSchema>;

const deviceNameSchema = z.string().trim().min(1).max(100);
const displayNameSchema = z.string().trim().min(1).max(60);

/** An opaque single-use token from an emailed link. */
const linkTokenSchema = z.string().min(20).max(200);

// ----------------------------------------------------------------- bodies

// Strict: a key the contract does not name is refused, not carried along
// (audit S5-07).

/** The sign-up fields, for a form that asks for some of them. */
export const registerFieldsSchema = z.strictObject({
  email: emailSchema,
  password: passwordSchema,
  displayName: displayNameSchema.optional(),
  client: clientKindSchema.default('web'),
  deviceName: deviceNameSchema.optional(),
});

/**
 * Whether a display name gives the password away. A name that is the
 * password is a password manager filling the field after the password
 * as its confirmation; shown on every screen, it would be read by anyone
 * looking.
 */
export function nameIsPassword(displayName: string | undefined, password: string): boolean {
  return displayName !== undefined && displayName.trim() !== '' && displayName.trim() === password.trim();
}

export const registerBodySchema = registerFieldsSchema.refine(
  (body) => !nameIsPassword(body.displayName, body.password),
  { path: ['displayName'], message: 'not_the_password' },
);
export type RegisterBody = z.input<typeof registerBodySchema>;

export const loginBodySchema = z.strictObject({
  email: emailSchema,
  password: loginPasswordSchema,
  client: clientKindSchema.default('web'),
  deviceName: deviceNameSchema.optional(),
});
export type LoginBody = z.input<typeof loginBodySchema>;

/** The web sends nothing (the cookie carries the token); the phone sends it here. */
export const refreshBodySchema = z.strictObject({
  refreshToken: z.string().min(1).max(300).optional(),
});
export type RefreshBody = z.input<typeof refreshBodySchema>;

export const logoutBodySchema = refreshBodySchema;
export type LogoutBody = RefreshBody;

export const verifyEmailBodySchema = z.strictObject({ token: linkTokenSchema });
export type VerifyEmailBody = z.input<typeof verifyEmailBodySchema>;

export const resendVerificationBodySchema = z.strictObject({ email: emailSchema });
export type ResendVerificationBody = z.input<typeof resendVerificationBodySchema>;

export const forgotPasswordBodySchema = z.strictObject({ email: emailSchema });
export type ForgotPasswordBody = z.input<typeof forgotPasswordBodySchema>;

export const resetPasswordBodySchema = z.strictObject({
  token: linkTokenSchema,
  password: passwordSchema,
});
export type ResetPasswordBody = z.input<typeof resetPasswordBodySchema>;

export const patchMeBodySchema = z.strictObject({
  displayName: displayNameSchema.nullable().optional(),
});
export type PatchMeBody = z.input<typeof patchMeBodySchema>;

/** Deleting everything asks for the password again, whatever the token says. */
export const deleteMeBodySchema = z.strictObject({ password: loginPasswordSchema });
export type DeleteMeBody = z.input<typeof deleteMeBodySchema>;

/**
 * `POST /v1/me/reauth`: the password again, before this device writes
 * my data out (the archive, the spreadsheet; Phase 7, M7.6), so a
 * session left open is not enough to take everything. 204 for the right
 * one, 403 `forbidden` for a wrong one, counted with *Delete account*.
 */
export const reauthBodySchema = z.strictObject({ password: loginPasswordSchema });
export type ReauthBody = z.input<typeof reauthBodySchema>;

export const sessionParamsSchema = z.object({
  id: z.string().regex(/^[0-9a-f]{24}$/, { message: 'Not a session id' }),
});

// ------------------------------------------------------------- responses

const isoInstant = z.iso.datetime();

export const meSchema = z.object({
  id: z.string(),
  email: z.string(),
  displayName: z.string().nullable(),
  verifiedAt: isoInstant.nullable(),
  /** Base64; the public half of the private tier's key derivation. */
  syncSalt: z.string(),
  createdAt: isoInstant,
  /**
   * The account is one the server's `ADMIN_EMAILS` names ([[Admin]]).
   * Absent from a server before it, which reads as not an admin.
   */
  admin: z.boolean().optional(),
});
export type Me = z.infer<typeof meSchema>;

/**
 * What register, login and refresh answer. [refreshToken] is present
 * only for `client: 'mobile'`; the web gets it as a cookie instead.
 */
export const authResultSchema = z.object({
  accessToken: z.string(),
  /** Seconds until [accessToken] expires. */
  expiresIn: z.number().int().positive(),
  refreshToken: z.string().optional(),
  user: meSchema,
});
export type AuthResult = z.infer<typeof authResultSchema>;

export const sessionSchema = z.object({
  id: z.string(),
  deviceName: z.string().nullable(),
  client: clientKindSchema,
  createdAt: isoInstant,
  lastSeenAt: isoInstant,
  current: z.boolean(),
});
export type Session = z.infer<typeof sessionSchema>;

export const sessionsResultSchema = z.object({ sessions: z.array(sessionSchema) });
export type SessionsResult = z.infer<typeof sessionsResultSchema>;

const publishedReleaseSchema = z.object({
  tag: z.string(),
  name: z.string().nullable(),
  publishedAt: isoInstant.nullable(),
  htmlUrl: z.string(),
  /** The release notes as written on GitHub (markdown), for the download page. */
  notes: z.string().nullable(),
  apk: z
    .object({
      name: z.string(),
      url: z.string(),
      size: z.number().int().nonnegative(),
      /** Hex SHA-256 of the file, as GitHub computed it; null when GitHub has none. */
      sha256: z.string().nullable(),
    })
    .nullable(),
});

/**
 * The newest release that is not a pre-release, and beside it the newest
 * pre-release when one is newer (a beta of the next version), so the
 * download page can mention it. Absent from servers older than it.
 */
export const releaseSchema = publishedReleaseSchema.extend({
  prerelease: publishedReleaseSchema.nullable().optional(),
});
export type Release = z.infer<typeof releaseSchema>;
export type PublishedRelease = z.infer<typeof publishedReleaseSchema>;

export const healthSchema = z.object({ status: z.literal('ok') });
export type Health = z.infer<typeof healthSchema>;
