import '../models/grocery_candidate.dart';
import '../models/shopping_item.dart';
import 'grocery_lexicon.dart';
import 'quantity.dart';

class GroceryParser {
  static final _units = {
    for (final entry in unitAliases.entries)
      for (final alias in entry.value) alias: entry.key,
  };
  static final _names = {
    for (final entry in groceryAliases.entries)
      for (final alias in entry.value) alias: entry.key,
  };
  static const _joiners = {
    'and',
    '&',
    'plus',
    'ഉം',
    'കൂടാതെ',
    'pinne',
    'ennittu',
    'or',
    'അല്ലെങ്കിൽ',
    'allenkil',
  };
  static const _fillers = {
    'please',
    'buy',
    'get',
    'need',
    'i',
    'want',
    'of',
    'വേണം',
    'വാങ്ങണം',
    'എനിക്ക്',
    'venam',
    'vaanganam',
    'vangണം',
  };
  static const _uncertain = {
    'some',
    'few',
    'little',
    'about',
    'around',
    'roughly',
    'approximately',
    'approx',
    'kurachu',
    'kurach',
    'കുറച്ച്',
    'കുറച്ചു',
    'ഏകദേശം',
  };

  List<GroceryCandidate> parse(String input) {
    final result = <GroceryCandidate>[];
    // Keep source offsets: normalization changes case/digits, never source text.
    for (final source in input.split(RegExp(r'[,;\n!?。]|(?<!\d)\.|\.(?!\d)'))) {
      final normalized = _normalize(source);
      final tokens = RegExp(r'-?\d+(?:\.\d+)?(?:/\d+)?|[½¼¾]|[^\s\d.,;!?½¼¾]+')
          .allMatches(normalized)
          .map((m) => _Token(m.group(0)!.toLowerCase(), m.start, m.end))
          .toList();
      final unsupportedContext = tokens.any(
        (t) => {
          'x',
          '×',
          '₹',
          'rs',
          'rupees',
          'people',
          'persons',
          'servings',
        }.contains(t.text),
      );
      var p = 0;
      while (p < tokens.length) {
        while (p < tokens.length &&
            (_joiners.contains(tokens[p].text) ||
                _fillers.contains(tokens[p].text))) {
          p++;
        }
        if (p == tokens.length) break;
        final start = p;
        final issues = <String>[];
        if (tokens.any(
          (t) => {'or', 'അല്ലെങ്കിൽ', 'allenkil'}.contains(t.text),
        )) {
          issues.add('Alternative choices need confirmation');
        }
        var uncertain = false;
        while (p < tokens.length && _uncertain.contains(tokens[p].text)) {
          uncertain = true;
          p++;
        }
        final prefix = _amount(tokens, p);
        int? millis;
        ItemUnit? unit;
        if (prefix != null) {
          millis = prefix.millis;
          unit = prefix.unit;
          p = prefix.end;
          if (prefix.issue != null) issues.add(prefix.issue!);
          if (p < tokens.length && _units.containsKey(tokens[p].text)) {
            unit = _units[tokens[p++].text];
          }
          while (p < tokens.length && _fillers.contains(tokens[p].text)) {
            p++;
          }
          while (p < tokens.length && _uncertain.contains(tokens[p].text)) {
            uncertain = true;
            p++;
          }
        }
        final nameStart = p;
        final known = _knownName(tokens, p);
        String name;
        if (known != null) {
          name = known.$1;
          p = known.$2;
          // Preserve qualifiers rather than silently discarding unfamiliar text.
          while (p < tokens.length &&
              !_boundary(tokens, p) &&
              _knownName(tokens, p) == null &&
              !_fillers.contains(tokens[p].text)) {
            p++;
          }
          if (p > known.$2) {
            name = source.substring(tokens[nameStart].start, tokens[p - 1].end);
            issues.add('Unrecognized name or qualifier');
          }
        } else {
          while (p < tokens.length &&
              !_boundary(tokens, p) &&
              !_fillers.contains(tokens[p].text)) {
            p++;
          }
          name = p > nameStart
              ? source.substring(tokens[nameStart].start, tokens[p - 1].end)
              : '';
          issues.add('Unknown grocery name; preserved as typed');
        }
        final trailing = _amount(tokens, p);
        if (prefix != null &&
            trailing != null &&
            (trailing.end == tokens.length ||
                _joiners.contains(tokens[trailing.end].text) ||
                _fillers.contains(tokens[trailing.end].text))) {
          p = trailing.end;
          millis = null;
          issues.add('Conflicting quantities; confirm the intended amount');
        }
        if (prefix == null) {
          // A vague amount must not become an exact quantity.
          while (p < tokens.length && _uncertain.contains(tokens[p].text)) {
            uncertain = true;
            p++;
          }
          final suffix = _amount(tokens, p);
          if (suffix != null) {
            millis = suffix.millis;
            if (suffix.unit == ItemUnit.bunch &&
                _knownName(tokens, suffix.end) != null) {
              millis = null;
              issues.add(
                'Bunch quantity may belong to the next grocery; confirm attachment',
              );
            }
            unit = suffix.unit;
            p = suffix.end;
            if (suffix.issue != null) issues.add(suffix.issue!);
            if (p < tokens.length && _units.containsKey(tokens[p].text)) {
              unit = _units[tokens[p++].text];
            }
          }
        }
        while (p < tokens.length && _uncertain.contains(tokens[p].text)) {
          uncertain = true;
          p++;
        }
        if (unsupportedContext) {
          millis = null;
          issues.add(
            'Prices, pack sizes or non-grocery counts need manual confirmation',
          );
        }
        if (p == start) {
          p++;
        }
        if (name.isEmpty) {
          issues.add('Grocery name could not be identified');
        }
        if (uncertain) {
          millis = null;
          issues.add('Approximate or unspecified quantity');
        }
        if (millis == null) issues.add('Enter a confirmed quantity');
        if (unit == null) issues.add('Select a unit; none inferred');
        final original = source.substring(
          tokens[start].start,
          tokens[p - 1].end,
        );
        result.add(
          GroceryCandidate(
            name: name.isEmpty ? original : name,
            quantity: millis == null ? null : millis / 1000,
            unit: unit,
            originalText: original,
            issues: List.unmodifiable(issues),
          ),
        );
      }
    }
    return result;
  }

  bool _boundary(List<_Token> t, int p) =>
      _joiners.contains(t[p].text) ||
      _uncertain.contains(t[p].text) ||
      _amount(t, p) != null;

  (String, int)? _knownName(List<_Token> t, int p) {
    for (var length = 3; length > 0; length--) {
      if (p + length > t.length) continue;
      final key = t.sublist(p, p + length).map((v) => v.text).join(' ');
      final name = _names[key];
      if (name != null) return (name, p + length);
    }
    return null;
  }

  _Amount? _amount(List<_Token> t, int p) {
    if (p >= t.length) return null;
    final word = t[p].text;
    // Common joined Malayalam/Manglish half/quarter-kilo forms.
    const compound = {
      'അരക്കിലോ': 500,
      'കാൽക്കിലോ': 250,
      'കാൽകിലോ': 250,
      'കാല്‍ക്കിലോ': 250,
      'arakkilo': 500,
      'arakilo': 500,
      'kaalkilo': 250,
    };
    if (compound.containsKey(word)) {
      return _Amount(compound[word], p + 1, unit: ItemUnit.kg);
    }
    var n = _atom(word);
    if (n == null && !RegExp(r'^-?\d').hasMatch(word)) return null;
    var end = p + 1;
    String? issue;
    if (n == null) issue = 'Invalid or unsupported quantity';
    if (n != null &&
        n >= 20000 &&
        n <= 90000 &&
        n % 10000 == 0 &&
        end < t.length) {
      final next = numberWords[t[end].text];
      if (next != null && next >= 1000 && next <= 9000) {
        n += next;
        end++;
      }
    }
    if (n != null &&
        n >= 1000 &&
        n <= 9000 &&
        end < t.length &&
        t[end].text == 'hundred') {
      n *= 100;
      end++;
    }
    if (n != null && n >= 100000 && end < t.length) {
      var nextAt = end;
      if (t[nextAt].text == 'and') nextAt++;
      if (nextAt < t.length) {
        final extra = numberWords[t[nextAt].text];
        if (extra != null && extra >= 1000 && extra < 100000) {
          n += extra;
          end = nextAt + 1;
          if (extra >= 20000 && end < t.length) {
            final ones = numberWords[t[end].text];
            if (ones != null && ones >= 1000 && ones <= 9000) {
              n += ones;
              end++;
            }
          }
        }
      }
    }
    if (end < t.length && t[end].text == 'and') {
      var fractionAt = end + 1;
      if (fractionAt < t.length &&
          (t[fractionAt].text == 'a' || t[fractionAt].text == 'an')) {
        fractionAt++;
      }
      if (fractionAt < t.length) {
        final fraction = _atom(t[fractionAt].text);
        if (fraction != null && fraction < 1000) {
          n = n == null ? null : n + fraction;
          end = fractionAt + 1;
        }
      }
    } else if (n != null &&
        n == 1000 &&
        end < t.length &&
        {'half', 'quarter'}.contains(t[end].text) &&
        {'a', 'an'}.contains(word)) {
      n = _atom(t[end++].text);
    } else if (end < t.length &&
        {'1/2', '1/4', '½', '¼'}.contains(t[end].text)) {
      n = n == null ? null : n + _atom(t[end].text)!;
      end++;
    }
    if (n != null && n < 1000) {
      if (end < t.length && t[end].text == 'of') end++;
      if (end < t.length && {'a', 'an'}.contains(t[end].text)) end++;
    }
    ItemUnit? unit;
    if (end < t.length && _units.containsKey(t[end].text)) {
      unit = _units[t[end++].text];
    }
    if (end + 1 < t.length &&
        {'or', '-', 'to', 'അല്ലെങ്കിൽ', 'allenkil'}.contains(t[end].text) &&
        _atom(t[end + 1].text) != null) {
      n = null;
      end += 2;
      issue = 'Alternative or ranged quantities need confirmation';
    }
    // The lexer retains a leading minus, including the second half of 2-3.
    if (end < t.length &&
        t[end].text.startsWith('-') &&
        _atom(t[end].text.substring(1)) != null) {
      n = null;
      end++;
      issue = 'Ranged quantities need confirmation';
    }
    if (end < t.length && _units.containsKey(t[end].text)) {
      unit = _units[t[end++].text];
    }
    if (n != null && (n <= 0 || n > 9999000)) {
      n = null;
      issue = 'Quantity outside supported range';
    }
    return _Amount(n, end, unit: unit, issue: issue);
  }

  int? _atom(String word) {
    if (numberWords.containsKey(word)) return numberWords[word];
    const fractions = {
      '1/2': 500,
      '1/4': 250,
      '3/4': 750,
      '½': 500,
      '¼': 250,
      '¾': 750,
    };
    return fractions[word] ?? parseQuantity(word);
  }

  String _normalize(String input) {
    var value = input;
    const digits = '൦൧൨൩൪൫൬൭൮൯';
    for (var i = 0; i < digits.length; i++) {
      value = value.replaceAll(digits[i], '$i');
    }
    return value;
  }
}

class _Token {
  const _Token(this.text, this.start, this.end);
  final String text;
  final int start, end;
}

class _Amount {
  const _Amount(this.millis, this.end, {this.unit, this.issue});
  final int? millis;
  final int end;
  final ItemUnit? unit;
  final String? issue;
}
