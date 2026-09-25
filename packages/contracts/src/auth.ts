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

/**
 * Whether [password] is one of the 10,000 most common passwords. The
 * list is lowercase, and so is the comparison: "Password12" is not a
 * better password than "password12".
 */
export function isCommonPassword(password: string): boolean {
  return commonPasswords.has(password.toLowerCase());
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

export const registerBodySchema = z.object({
  email: emailSchema,
  password: passwordSchema,
  displayName: displayNameSchema.optional(),
  client: clientKindSchema.default('web'),
  deviceName: deviceNameSchema.optional(),
});
export type RegisterBody = z.input<typeof registerBodySchema>;

export const loginBodySchema = z.object({
  email: emailSchema,
  password: loginPasswordSchema,
  client: clientKindSchema.default('web'),
  deviceName: deviceNameSchema.optional(),
});
export type LoginBody = z.input<typeof loginBodySchema>;

/** The web sends nothing (the cookie carries the token); the phone sends it here. */
export const refreshBodySchema = z.object({
  refreshToken: z.string().min(1).max(300).optional(),
});
export type RefreshBody = z.input<typeof refreshBodySchema>;

export const logoutBodySchema = refreshBodySchema;
export type LogoutBody = RefreshBody;

export const verifyEmailBodySchema = z.object({ token: linkTokenSchema });
export type VerifyEmailBody = z.input<typeof verifyEmailBodySchema>;

export const resendVerificationBodySchema = z.object({ email: emailSchema });
export type ResendVerificationBody = z.input<typeof resendVerificationBodySchema>;

export const forgotPasswordBodySchema = z.object({ email: emailSchema });
export type ForgotPasswordBody = z.input<typeof forgotPasswordBodySchema>;

export const resetPasswordBodySchema = z.object({
  token: linkTokenSchema,
  password: passwordSchema,
});
export type ResetPasswordBody = z.input<typeof resetPasswordBodySchema>;

export const patchMeBodySchema = z.strictObject({
  displayName: displayNameSchema.nullable().optional(),
});
export type PatchMeBody = z.input<typeof patchMeBodySchema>;

/** Deleting everything asks for the password again, whatever the token says. */
export const deleteMeBodySchema = z.object({ password: loginPasswordSchema });
export type DeleteMeBody = z.input<typeof deleteMeBodySchema>;

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
