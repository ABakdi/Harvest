/**
 * Notes read aloud, dictated and recorded in a browser ([[Notes]] N7,
 * N10), with the phone's rules for what is spoken ported from
 * `voice.dart`.
 *
 * N10 says read aloud and dictation use the device's own engines, and
 * Business rule 13 says nothing new goes out over the network. So both
 * are offered only where the browser can do them on this computer: a
 * voice the browser marks as local, and speech recognition that runs
 * on the device. Where it cannot, the control is not there.
 */

const embed = /!\[\[([^[\]\n]+?)\]\]/g;

/**
 * A note as it should be heard: the words, without the markdown, in
 * paragraphs so the player can skip one at a time (`speechParagraphs`).
 * An embed is dropped whole, and a table row reads as its cells.
 */
export function speechParagraphs(markdown: string): string[] {
  const lines: string[] = [];
  let inFence = false;
  for (const raw of markdown.split('\n')) {
    const line = raw.trimEnd();
    if (line.trimStart().startsWith('```')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    let text = line
      .replace(embed, '')
      .replace(/^\s{0,3}#{1,6}\s+/, '')
      .replace(/^\s*>\s?/, '')
      .replace(/^\s*([-*+]|\d+[.)])\s+(\[[ xX]\]\s+)?/, '')
      .replace(/\[\[([^\]|]+)(\|([^\]]+))?\]\]/g, (_, title: string, _pipe: string | undefined, label: string | undefined) => label ?? title)
      .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
      .replace(/(\*\*|__|\*|_|~~|`|==)/g, '')
      .replace(/^\s*([-*_]\s*){3,}$/, '')
      .trim();
    if (text.startsWith('|')) {
      text = text
        .split('|')
        .map((cell) => cell.trim())
        .filter((cell) => cell.length > 0 && !/^:?-+:?$/.test(cell))
        .join(', ');
    }
    lines.push(text);
  }
  const paragraphs: string[] = [];
  let buffer = '';
  for (const line of lines) {
    if (!line) {
      if (buffer) paragraphs.push(buffer);
      buffer = '';
      continue;
    }
    buffer = buffer ? `${buffer} ${line}` : line;
  }
  if (buffer) paragraphs.push(buffer);
  return paragraphs;
}

const arabicLetter = /[؀-ۿݐ-ݿࢠ-ࣿ]/g;

/** Arabic when most of the letters are, otherwise [fallback] (`speechLanguageOf`). */
export function speechLanguageOf(text: string, fallback: string): string {
  const letters = text.match(/\p{L}/gu)?.length ?? 0;
  if (letters === 0) return fallback;
  const arabic = text.match(arabicLetter)?.length ?? 0;
  return arabic * 2 >= letters ? 'ar' : fallback;
}

// ------------------------------------------------------------ speaking

/** A voice on this computer for [language], or null: a remote voice would send the note away. */
export function localVoice(language: string): SpeechSynthesisVoice | null {
  if (typeof speechSynthesis === 'undefined') return null;
  const voices = speechSynthesis.getVoices().filter((voice) => voice.localService);
  const base = language.toLowerCase().split('-')[0]!;
  return (
    voices.find((voice) => voice.lang.toLowerCase() === language.toLowerCase()) ??
    voices.find((voice) => voice.lang.toLowerCase().split(/[-_]/)[0] === base) ??
    null
  );
}

/** Whether this browser can speak at all; the voices may still be loading. */
export function canSpeak(): boolean {
  return typeof speechSynthesis !== 'undefined' && typeof SpeechSynthesisUtterance !== 'undefined';
}

// ----------------------------------------------------------- recording

/**
 * The container a recording is made in, and the extension it is named
 * with. The phone records AAC in `.m4a`, and only names with an audio
 * extension it knows count as a recording (N7), so MP4 audio comes
 * first, then Ogg. WebM holds the same Opus audio Ogg would; it takes
 * `.ogg` so the phone keeps it, and players read the bytes, not the name.
 */
export function recordingFormat(): { mimeType: string; extension: string } | null {
  if (typeof MediaRecorder === 'undefined' || typeof navigator === 'undefined' || !navigator.mediaDevices?.getUserMedia) {
    return null;
  }
  const candidates: [string, string][] = [
    ['audio/mp4;codecs=mp4a.40.2', 'm4a'],
    ['audio/mp4', 'm4a'],
    ['audio/ogg;codecs=opus', 'ogg'],
    ['audio/webm;codecs=opus', 'ogg'],
    ['audio/webm', 'ogg'],
  ];
  for (const [mimeType, extension] of candidates) {
    if (MediaRecorder.isTypeSupported(mimeType)) return { mimeType, extension };
  }
  return null;
}

// ----------------------------------------------------------- dictation

interface RecognitionResultList {
  length: number;
  [index: number]: { isFinal: boolean; 0: { transcript: string } };
}

/** The slice of the Web Speech recognition API dictation uses. */
export interface Recognition {
  lang: string;
  continuous: boolean;
  interimResults: boolean;
  processLocally?: boolean;
  onresult: ((event: { resultIndex: number; results: RecognitionResultList }) => void) | null;
  onend: (() => void) | null;
  onerror: ((event: { error: string }) => void) | null;
  start(): void;
  stop(): void;
}

interface RecognitionConstructor {
  new (): Recognition;
  /** Chrome's on-device check; absent where recognition can only use a server. */
  available?: (options: { langs: string[]; processLocally: boolean }) => Promise<string>;
}

function recognitionClass(): RecognitionConstructor | null {
  if (typeof window === 'undefined') return null;
  const scope = window as unknown as { SpeechRecognition?: RecognitionConstructor; webkitSpeechRecognition?: RecognitionConstructor };
  return scope.SpeechRecognition ?? scope.webkitSpeechRecognition ?? null;
}

/**
 * A recogniser that listens on this computer, or null. Recognition that
 * can only work by sending the microphone to the browser's vendor is
 * not offered: that would be a new outbound request (Business rule 13),
 * and N10 promises dictation never leaves the device.
 */
export async function localDictation(language: string): Promise<Recognition | null> {
  const Class = recognitionClass();
  if (!Class || typeof Class.available !== 'function') return null;
  try {
    if ((await Class.available({ langs: [language], processLocally: true })) !== 'available') return null;
  } catch {
    return null;
  }
  const recognition = new Class();
  recognition.lang = language;
  recognition.processLocally = true;
  recognition.continuous = true;
  recognition.interimResults = false;
  return recognition;
}
