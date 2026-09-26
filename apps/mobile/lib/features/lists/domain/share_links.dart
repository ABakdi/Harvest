/// Where a shared or pasted link lands ([[Lists]]: Saving from
/// anywhere). The phone's share sheet and the web's add field read the
/// same rules, both held to `packages/core/fixtures/share-links.json`.
///
/// Only the host decides, and nothing is fetched (L9): a video site goes
/// to *To watch* as a video, anything else to *To read* as an article.
library;

import 'package:harvest/features/lists/domain/lists.dart';
import 'package:meta/meta.dart';

/// The sites a link to which is a video. A subdomain counts; a host that
/// merely ends in the name does not.
const videoHosts = [
  'youtube.com',
  'youtu.be',
  'vimeo.com',
  'dailymotion.com',
  'dai.ly',
  'twitch.tv',
  'tiktok.com',
];

/// The built-in list a link lands in, and the type it is saved as.
typedef SharedLink = ({BuiltInList list, MediaType mediaType});

final _bareLink = RegExp(r'^https?://\S+$', caseSensitive: false);
final _anyLink = RegExp(r'https?://\S+', caseSensitive: false);
final _authority = RegExp('^https?://([^/?#]*)', caseSensitive: false);

/// The link, when [text] is one bare http(s) URL and nothing else;
/// otherwise null.
String? linkOf(String text) {
  final trimmed = text.trim();
  if (!_bareLink.hasMatch(trimmed)) return null;
  return _hostOf(trimmed).isEmpty ? null : trimmed;
}

/// The host of an http(s) URL, lower-cased, without a user or a port;
/// empty when there is none.
String _hostOf(String url) {
  final match = _authority.firstMatch(url.trim());
  if (match == null) return '';
  final authority = match.group(1)!;
  return authority
      .substring(authority.lastIndexOf('@') + 1)
      .replaceFirst(RegExp(r':\d*$'), '')
      .toLowerCase();
}

/// The list and type a link gets from its host alone.
SharedLink classifyLink(String url) {
  final host = _hostOf(url);
  final video = videoHosts.any(
    (site) => host == site || host.endsWith('.$site'),
  );
  return video
      ? (list: BuiltInList.watch, mediaType: MediaType.video)
      : (list: BuiltInList.read, mediaType: MediaType.article);
}

/// What another app handed over with *Share*, read into an item: the
/// title to start from, the link if there is one, and where it goes.
@immutable
class SharedDraft {
  const SharedDraft({required this.title, this.link, this.target});

  /// Reads a share: [subject] is `EXTRA_SUBJECT` (a page's title, a
  /// video's name), [text] is `EXTRA_TEXT`.
  ///
  /// A browser shares the bare link; YouTube and many others share a
  /// line of text with the link at its end. Either way the link is the
  /// first http(s) URL, and whatever else was said makes the title when
  /// there is no subject. Nothing is looked up (L9).
  factory SharedDraft.of({String? subject, String? text}) {
    final body = (text ?? '').trim();
    final named = (subject ?? '').trim();
    final found = linkOf(body) == null
        ? _anyLink.firstMatch(body)?.group(0)
        : body;
    final link = found == null ? null : linkOf(_trimTrailing(found));
    if (link == null) {
      return SharedDraft(title: named.isNotEmpty ? named : body);
    }
    final rest = body
        .replaceFirst(found!, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceFirst(RegExp(r'[\s:\-–—|]+$'), '');
    final title = named.isNotEmpty
        ? named
        : rest.isNotEmpty
        ? rest
        : link;
    return SharedDraft(title: title, link: link, target: classifyLink(link));
  }

  /// The shared subject, or the text; a bare link stands in as its own
  /// title until I type one.
  final String title;
  final String? link;

  /// Where a link lands (To read, To watch); null for text without a
  /// link, which goes to a plain list.
  final SharedLink? target;

  /// A link at the end of a sentence carries its full stop or bracket.
  static String _trimTrailing(String url) =>
      url.replaceFirst(RegExp(r'''[.,;:!?)\]}'"»]+$'''), '');
}
