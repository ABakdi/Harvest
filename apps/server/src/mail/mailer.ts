import type { Logger } from 'pino';

/**
 * The server sends two emails, ever: verify, and reset ([[Accounts]]).
 * Every sender is one of these.
 */
export interface MailMessage {
  to: string;
  subject: string;
  text: string;
  /** What the message is for, for logs and tests; never shown to anyone. */
  purpose: 'verify' | 'reset';
  /** The link the message carries. */
  link: string;
}

export interface Mailer {
  send(message: MailMessage): Promise<void>;
}

/**
 * Development mail: the link goes to the log, where I can click it. The
 * address does not; logs never carry one.
 */
export class LogMailer implements Mailer {
  constructor(private readonly logger: Logger) {}

  send(message: MailMessage): Promise<void> {
    this.logger.info({ purpose: message.purpose, link: message.link }, 'mail (not sent: no SMTP configured)');
    return Promise.resolve();
  }
}

/** Keeps every message, for tests to read the links back out of. */
export class MemoryMailer implements Mailer {
  readonly sent: MailMessage[] = [];

  send(message: MailMessage): Promise<void> {
    this.sent.push(message);
    return Promise.resolve();
  }

  /** The newest message of [purpose] to [to]. */
  last(to: string, purpose: MailMessage['purpose']): MailMessage | undefined {
    return this.sent.filter((m) => m.to === to && m.purpose === purpose).at(-1);
  }
}
