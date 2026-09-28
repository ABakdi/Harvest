import { isIPv4, isIPv6 } from 'node:net';

/**
 * The network a client address belongs to, as far as a limit is
 * concerned: the /24 of an IPv4 address and the /48 of an IPv6 one. One
 * machine is given many addresses of the same network, so a limit per
 * address alone counts it many times over (S6-03).
 */
export function networkOf(ip: string | undefined): string {
  if (!ip) return 'unknown';
  const mapped = /^::ffff:(\d+\.\d+\.\d+\.\d+)$/i.exec(ip);
  const v4 = mapped?.[1] ?? ip;
  if (isIPv4(v4)) return `${v4.split('.').slice(0, 3).join('.')}.0/24`;
  if (!isIPv6(ip)) return 'unknown';
  // Expand `::` so the first three groups are the first three groups.
  const [head = '', tail = ''] = ip.toLowerCase().split('::');
  const left = head ? head.split(':') : [];
  const right = tail ? tail.split(':') : [];
  const groups = ip.includes('::') ? [...left, ...Array<string>(8 - left.length - right.length).fill('0'), ...right] : left;
  return `${groups
    .slice(0, 3)
    .map((group) => group.replace(/^0+(?=.)/, ''))
    .join(':')}::/48`;
}
