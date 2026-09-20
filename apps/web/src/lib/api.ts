import type {
  AssistRequest,
  AssistStatus,
  AuthResult,
  ErrorBody,
  ForgotPasswordBody,
  Issue,
  LoginBody,
  Me,
  PatchMeBody,
  PullResult,
  PushBody,
  PushResult,
  RegisterBody,
  Release,
  ResetPasswordBody,
  SessionsResult,
} from '@harvest/contracts';
import { fileIvHeader } from '@harvest/contracts';

/**
 * The web's only door to the server. Everything else it knows, it knows
 * from IndexedDB (W1); this is for signing in, the account, and sync.
 *
 * The session follows [[Accounts]]: the access token lives in this
 * module's memory and nowhere else, and the refresh token is an
 * HttpOnly cookie on `/v1/auth` that no script can read. A reload
 * therefore starts with no access token, and gets one by refreshing.
 *
 * Refresh tokens rotate, and presenting one twice revokes the whole
 * family (AC4). Two tabs refreshing at once would do exactly that with
 * the one cookie they share, so every refresh runs inside a Web Lock
 * that all tabs of this origin queue on, and a tab that waited behind
 * another one uses the token that tab broadcast instead of spending
 * the cookie again.
 */

const base: string = (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/+$/, '') ?? '';

export class ApiError extends Error {
  override readonly name = 'ApiError';

  constructor(
    readonly status: number,
    /** The contract's error code, or `network` when no answer came at all. */
    readonly code: string,
    message: string,
    readonly details: Issue[] = [],
    readonly retryAfter: number | null = null,
  ) {
    super(message);
  }

  /** No answer: offline, DNS, a server that is down. */
  get isNetwork(): boolean {
    return this.code === 'network';
  }
}

interface Access {
  token: string;
  /** Epoch ms after which the token is not worth sending. */
  expiresAt: number;
  /** When this tab learned of it, to tell a fresh token from an old one. */
  receivedAt: number;
}

let access: Access | null = null;
let currentUser: Me | null = null;
let inflight: Promise<AuthResult | null> | null = null;

type SessionListener = (user: Me | null) => void;
const sessionListeners = new Set<SessionListener>();

/** Hears every change of who is signed in, this tab's or another's. */
export function onSessionChange(listener: SessionListener): () => void {
  sessionListeners.add(listener);
  return () => sessionListeners.delete(listener);
}

function announce(user: Me | null): void {
  currentUser = user;
  for (const listener of sessionListeners) listener(user);
}

export function sessionUser(): Me | null {
  return currentUser;
}

// ----------------------------------------------------------- other tabs

type AuthMessage =
  | { kind: 'signed-in'; result: AuthResult; at: number }
  | { kind: 'signed-out' };

const channel: BroadcastChannel | null =
  typeof BroadcastChannel === 'function' ? new BroadcastChannel('harvest-auth') : null;

channel?.addEventListener('message', (event: MessageEvent<AuthMessage>) => {
  const message = event.data;
  if (message.kind === 'signed-in') {
    remember(message.result, false);
  } else {
    forget(false);
  }
});

function remember(result: AuthResult, broadcast = true): void {
  const now = Date.now();
  access = { token: result.accessToken, expiresAt: now + result.expiresIn * 1000, receivedAt: now };
  if (broadcast) channel?.postMessage({ kind: 'signed-in', result, at: now } satisfies AuthMessage);
  announce(result.user);
}

function forget(broadcast = true): void {
  access = null;
  if (broadcast) channel?.postMessage({ kind: 'signed-out' } satisfies AuthMessage);
  announce(null);
}

// -------------------------------------------------------------- fetching

async function toError(response: Response): Promise<ApiError> {
  const retryAfter = Number(response.headers.get('retry-after')) || null;
  try {
    const body = (await response.json()) as Partial<ErrorBody>;
    if (body.error) {
      return new ApiError(response.status, body.error.code, body.error.message, body.error.details ?? [], retryAfter);
    }
  } catch {
    // Not the contract's shape: a proxy's error page, most likely.
  }
  return new ApiError(response.status, 'internal', response.statusText || 'Request failed', [], retryAfter);
}

async function send(path: string, init: RequestInit): Promise<Response> {
  try {
    return await fetch(`${base}${path}`, { credentials: 'include', ...init });
  } catch (error) {
    throw new ApiError(0, 'network', error instanceof Error ? error.message : 'Network error');
  }
}

function jsonInit(method: string, body: unknown, token: string | null, signal?: AbortSignal): RequestInit {
  const headers: Record<string, string> = { accept: 'application/json' };
  if (body !== undefined) headers['content-type'] = 'application/json';
  if (token) headers.authorization = `Bearer ${token}`;
  return {
    method,
    headers,
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
    ...(signal ? { signal } : {}),
  };
}

async function parse<T>(response: Response): Promise<T> {
  if (response.status === 204 || response.status === 202) return undefined as T;
  return (await response.json()) as T;
}

// --------------------------------------------------------------- refresh

async function refreshOnce(requestedAt: number): Promise<AuthResult | null> {
  // Another tab refreshed while this one queued for the lock: its token
  // arrived over the channel, and the cookie it left is already the
  // next one. Spending it again would only rotate for nothing.
  if (access && currentUser && access.receivedAt > requestedAt && access.expiresAt > Date.now() + 30_000) {
    return {
      accessToken: access.token,
      expiresIn: Math.floor((access.expiresAt - Date.now()) / 1000),
      user: currentUser,
    };
  }
  const response = await send('/v1/auth/refresh', jsonInit('POST', {}, null));
  if (response.status === 401) {
    forget();
    return null;
  }
  if (!response.ok) throw await toError(response);
  const result = await parse<AuthResult>(response);
  remember(result);
  return result;
}

/**
 * A new access token from the refresh cookie, or null when there is no
 * session any more. One at a time in this tab, and one at a time across
 * every tab of the origin.
 */
export function refreshSession(): Promise<AuthResult | null> {
  if (inflight) return inflight;
  const requestedAt = Date.now();
  const run = () => refreshOnce(requestedAt);
  const locks = typeof navigator !== 'undefined' ? navigator.locks : undefined;
  // The DOM typings nest the callback's promise inside the lock's; the
  // lock resolves with the callback's value, as a promise does.
  const locked = locks ? (locks.request('harvest-refresh', run) as unknown as Promise<AuthResult | null>) : run();
  const started = locked.finally(() => {
    inflight = null;
  });
  inflight = started;
  return started;
}

async function accessToken(): Promise<string> {
  if (access && access.expiresAt > Date.now() + 30_000) return access.token;
  const result = await refreshSession();
  if (!result) throw new ApiError(401, 'unauthorized', 'Signed out');
  return result.accessToken;
}

interface RequestOptions {
  method?: string;
  body?: unknown;
  /** Whether the call needs the access token. */
  auth?: boolean;
  signal?: AbortSignal;
}

async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = 'GET', body, auth = true, signal } = options;
  let response = await send(path, jsonInit(method, body, auth ? await accessToken() : null, signal));
  if (response.status === 401 && auth) {
    // Expired early, or signed out elsewhere: one refresh, one retry.
    const result = await refreshSession();
    if (!result) throw new ApiError(401, 'unauthorized', 'Signed out');
    response = await send(path, jsonInit(method, body, result.accessToken, signal));
  }
  if (!response.ok) throw await toError(response);
  return parse<T>(response);
}

// ---------------------------------------------------------------- routes

/** A name for the sessions list, from what the browser says it is. */
export function deviceName(): string {
  const agent = typeof navigator !== 'undefined' ? navigator.userAgent : '';
  const browser = /Edg\//.test(agent)
    ? 'Edge'
    : /Firefox\//.test(agent)
      ? 'Firefox'
      : /Chrome\//.test(agent)
        ? 'Chrome'
        : /Safari\//.test(agent)
          ? 'Safari'
          : 'Browser';
  const system = /Android/.test(agent)
    ? 'Android'
    : /iPhone|iPad/.test(agent)
      ? 'iOS'
      : /Mac OS X/.test(agent)
        ? 'macOS'
        : /Windows/.test(agent)
          ? 'Windows'
          : /Linux/.test(agent)
            ? 'Linux'
            : null;
  return system ? `${browser} on ${system}` : browser;
}

export const api = {
  async login(body: Omit<LoginBody, 'client' | 'deviceName'>): Promise<AuthResult> {
    const result = await request<AuthResult>('/v1/auth/login', {
      method: 'POST',
      auth: false,
      body: { ...body, client: 'web', deviceName: deviceName() } satisfies LoginBody,
    });
    remember(result);
    return result;
  },

  async register(body: Omit<RegisterBody, 'client' | 'deviceName'>): Promise<AuthResult> {
    const result = await request<AuthResult>('/v1/auth/register', {
      method: 'POST',
      auth: false,
      body: { ...body, client: 'web', deviceName: deviceName() } satisfies RegisterBody,
    });
    remember(result);
    return result;
  },

  async logout(): Promise<void> {
    try {
      await request<void>('/v1/auth/logout', { method: 'POST', auth: false, body: {} });
    } finally {
      forget();
    }
  },

  verifyEmail: (token: string) =>
    request<void>('/v1/auth/verify-email', { method: 'POST', auth: false, body: { token } }),
  resendVerification: (email: string) =>
    request<void>('/v1/auth/resend-verification', { method: 'POST', auth: false, body: { email } }),
  forgotPassword: (body: ForgotPasswordBody) =>
    request<void>('/v1/auth/forgot-password', { method: 'POST', auth: false, body }),
  resetPassword: (body: ResetPasswordBody) =>
    request<void>('/v1/auth/reset-password', { method: 'POST', auth: false, body }),

  async me(): Promise<Me> {
    const me = await request<Me>('/v1/me');
    announce(me);
    return me;
  },
  patchMe: (body: PatchMeBody) => request<Me>('/v1/me', { method: 'PATCH', body }),
  async deleteMe(password: string): Promise<void> {
    await request<void>('/v1/me', { method: 'DELETE', body: { password } });
    forget();
  },
  sessions: () => request<SessionsResult>('/v1/me/sessions'),
  revokeSession: (id: string) => request<void>(`/v1/me/sessions/${encodeURIComponent(id)}`, { method: 'DELETE' }),

  latestRelease: (signal?: AbortSignal) =>
    request<Release>('/v1/releases/latest', { auth: false, ...(signal ? { signal } : {}) }),

  /**
   * One file's sealed bytes, with the nonce they were sealed with
   * ([[Sync-API]], files). Binary rather than JSON, so it goes around
   * `request` — the one thing it borrows is the retry after a refresh.
   */
  async file(sha256: string): Promise<{ sealed: ArrayBuffer; iv: string }> {
    const init = (token: string | null): RequestInit => ({
      method: 'GET',
      headers: {
        accept: 'application/octet-stream',
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
    });
    let response = await send(`/v1/files/${sha256}`, init(await accessToken()));
    if (response.status === 401) {
      const result = await refreshSession();
      if (!result) throw new ApiError(401, 'unauthorized', 'Signed out');
      response = await send(`/v1/files/${sha256}`, init(result.accessToken));
    }
    if (!response.ok) throw await toError(response);
    return { sealed: await response.arrayBuffer(), iv: response.headers.get(fileIvHeader) ?? '' };
  },

  assistStatus: () => request<AssistStatus>('/v1/assist/status'),

  /**
   * The assist, as server-sent events. The response itself is handed
   * back, because what matters is reading it as it arrives.
   */
  async assist(body: AssistRequest, signal?: AbortSignal): Promise<Response> {
    const init = (token: string | null): RequestInit => ({
      method: 'POST',
      headers: {
        accept: 'text/event-stream',
        'content-type': 'application/json',
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify(body),
      ...(signal ? { signal } : {}),
    });
    let response = await send('/v1/assist', init(await accessToken()));
    if (response.status === 401) {
      const result = await refreshSession();
      if (!result) throw new ApiError(401, 'unauthorized', 'Signed out');
      response = await send('/v1/assist', init(result.accessToken));
    }
    if (!response.ok) throw await toError(response);
    return response;
  },

  push: (body: PushBody) => request<PushResult>('/v1/sync/push', { method: 'POST', body }),
  pull: (after: number, limit: number) => request<PullResult>(`/v1/sync/pull?after=${after}&limit=${limit}`),
};

/** For tests: start from a clean, signed-out module. */
export function resetApiForTests(): void {
  access = null;
  currentUser = null;
  inflight = null;
}
