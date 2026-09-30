/**
 * Whether [bytes] begin the way a file of [type] does: a report's
 * attachment is taken only as what it is, never a page or a script
 * named a picture ([[Admin]] F12-5).
 */
export function looksLike(type: string, bytes: Buffer): boolean {
  const at = (offset: number, text: string) => bytes.subarray(offset, offset + text.length).toString('latin1') === text;
  switch (type) {
    case 'image/jpeg':
      return bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
    case 'image/png':
      return bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
    case 'image/webp':
      return at(0, 'RIFF') && at(8, 'WEBP');
    case 'audio/mp4':
      return at(4, 'ftyp');
    case 'audio/aac':
      // Raw ADTS frames, or AAC in an MP4 box.
      return (bytes[0] === 0xff && (bytes[1]! & 0xf6) === 0xf0) || at(4, 'ftyp');
    case 'audio/webm':
      return bytes.subarray(0, 4).equals(Buffer.from([0x1a, 0x45, 0xdf, 0xa3]));
    case 'audio/ogg':
      return at(0, 'OggS');
    case 'audio/mpeg':
      return at(0, 'ID3') || (bytes[0] === 0xff && (bytes[1]! & 0xe0) === 0xe0);
    case 'audio/wav':
      return at(0, 'RIFF') && at(8, 'WAVE');
    default:
      return false;
  }
}
