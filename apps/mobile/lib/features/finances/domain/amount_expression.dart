import 'package:harvest/features/finances/presentation/money.dart';

/// The characters an amount may be typed with: digits, a decimal point
/// or comma, the four operations, brackets and spaces.
final RegExp amountCharacters = RegExp(r'[\d.,+\-*/×÷() ]');

/// Whether [input] is a sum rather than a number — anything with an
/// operator or a bracket in it.
bool isAmountExpression(String input) => RegExp(r'[+\-*/×÷()]').hasMatch(input);

/// `12+3.5*2` → 1900, in minor units.
///
/// A receipt is three things and a coffee; typing the total means
/// adding it up first, on a phone, in a queue ([[Checkpoint-6]]). So
/// the amount box takes a sum and shows what it comes to, and Log logs
/// the result. Plain numbers still go through [parseToMinor], which
/// knows about grouping commas; inside a sum a comma is a decimal
/// point, because `1,5+2` is not a thousand and a half.
///
/// The four operations and brackets, evaluated left to right with the
/// usual precedence. Anything that does not parse, divides by zero, or
/// comes to zero or less is null — the same answer a bad number gives.
int? evaluateAmountToMinor(String input) {
  if (!isAmountExpression(input)) return parseToMinor(input);
  final result = _Parser(input).parse();
  if (result == null || !result.isFinite || result <= 0) return null;
  final minor = (result * 100).round();
  if (minor > maxMajorUnits * 100) return null;
  return minor;
}

/// Recursive descent over `expr := term (('+'|'-') term)*`,
/// `term := factor (('*'|'/') factor)*`, `factor := number | '(' expr ')'
/// | '-' factor`.
class _Parser {
  _Parser(String input)
    : _text = input
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll(',', '.')
          .replaceAll(' ', '');

  final String _text;
  int _at = 0;

  double? parse() {
    final value = _expression();
    if (value == null || _at != _text.length) return null;
    return value;
  }

  String? get _peek => _at < _text.length ? _text[_at] : null;

  double? _expression() {
    var left = _term();
    if (left == null) return null;
    while (_peek == '+' || _peek == '-') {
      final op = _text[_at++];
      final right = _term();
      if (right == null) return null;
      left = op == '+' ? left! + right : left! - right;
    }
    return left;
  }

  double? _term() {
    var left = _factor();
    if (left == null) return null;
    while (_peek == '*' || _peek == '/') {
      final op = _text[_at++];
      final right = _factor();
      if (right == null) return null;
      if (op == '/' && right == 0) return null;
      left = op == '*' ? left! * right : left! / right;
    }
    return left;
  }

  double? _factor() {
    if (_peek == '-') {
      _at++;
      final value = _factor();
      return value == null ? null : -value;
    }
    if (_peek == '(') {
      _at++;
      final value = _expression();
      if (value == null || _peek != ')') return null;
      _at++;
      return value;
    }
    final start = _at;
    while (_peek != null && RegExp(r'[\d.]').hasMatch(_peek!)) {
      _at++;
    }
    if (start == _at) return null;
    return double.tryParse(_text.substring(start, _at));
  }
}
