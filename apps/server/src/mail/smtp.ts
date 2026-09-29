import { createTransport, type SMTPTransportOptions } from 'nodemailer';
import type { SmtpConfig } from '../config.js';
import type { MailMessage, Mailer } from './mailer.js';

/**
 * The transport's options. On a port that starts in plain text (587)
 * the connection must turn to TLS before anything is sent: a reset link
 * read on the way is an account taken, so STARTTLS is required, not
 * merely tried (audit S5-13). Only `SMTP_ALLOW_PLAINTEXT` — a relay on
 * the same machine — lets it go without.
 */
export function transportOptions(config: SmtpConfig): SMTPTransportOptions {
  return {
    host: config.host,
    port: config.port,
    secure: config.secure,
    requireTLS: !config.secure && !config.allowPlaintext,
    tls: { minVersion: 'TLSv1.2' },
    ...(config.user ? { auth: { user: config.user, pass: config.pass ?? '' } } : {}),
  };
}

export class SmtpMailer implements Mailer {
  private readonly transport: ReturnType<typeof createTransport>;

  constructor(
    config: SmtpConfig,
    private readonly from: string,
  ) {
    this.transport = createTransport(transportOptions(config));
  }

  async send(message: MailMessage): Promise<void> {
    await this.transport.sendMail({
      from: this.from,
      to: message.to,
      subject: message.subject,
      text: message.text,
    });
  }
}
