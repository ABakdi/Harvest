import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'editing_focus.g.dart';

/// Whether a note's body currently has the caret.
///
/// Three widgets in three different parts of the tree need to know:
/// the editor puts its toolbar up, the Records switch gets out of the
/// way, and neither can ask the other. The keyboard's own inset would
/// be the obvious signal, except a Scaffold eats it before the screens
/// underneath can see it — so the fact is stated once, here.
@riverpod
class WritingNote extends _$WritingNote {
  @override
  bool build() => false;

  // ignore: avoid_positional_boolean_parameters — it is the whole state.
  void set(bool writing) {
    if (state != writing) state = writing;
  }
}
