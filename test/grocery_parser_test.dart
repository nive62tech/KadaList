import 'package:flutter_test/flutter_test.dart';
import 'package:kadalist/models/grocery_candidate.dart';
import 'package:kadalist/models/shopping_item.dart';
import 'package:kadalist/services/grocery_parser.dart';

void main() {
  final parser = GroceryParser();
  test('conflicting Manglish quantities require confirmation', () {
    for (final text in [
      'rand kilo thakkali moonnu kilo',
      'noor pachamulak arakkilo',
      '2 kg rice 3 kg',
    ]) {
      final item = parser.parse(text).single;
      expect(item.quantity, isNull, reason: text);
      expect(item.issues.join(' '), contains('Conflicting'));
      expect(item.name, anyOf('Tomato', 'Green chilli', 'Rice'));
    }
  });
  test('beans spelling and missing unit remain explicit', () {
    final item = parser.parse('beens oru').single;
    expect(item.name, 'Beans');
    expect(item.quantity, 1);
    expect(item.unit, isNull);
    expect(item.ambiguous, isTrue);
  });
  test('bunch attachment must be clear', () {
    final clear = parser.parse('rand kett cheera').single;
    expect(
      (clear.name, clear.quantity, clear.unit),
      ('Spinach', 2, ItemUnit.bunch),
    );
    final unclear = parser.parse('payar rand kett cheera');
    expect(unclear.map((i) => i.name), ['Cowpeas', 'Spinach']);
    expect(unclear.every((i) => i.quantity == null && i.ambiguous), isTrue);
    final separated = parser.parse('payar, rand kettu cheera');
    expect(separated.last.quantity, 2);
  });
  test('mixed scripts and expanded units stay deterministic', () {
    final items = parser.parse(
      'രണ്ട് കെട്ട് ചീര, nooru g pachamulaku, ara litre milk, kaal kg vendakka, 250 ml പാൽ',
    );
    expect(items.map((i) => i.quantity), [2, 100, 0.5, 0.25, 250]);
    expect(items.every((i) => !i.ambiguous), isTrue);
  });
  final examples = <(String, List<(String, num, ItemUnit)>)>[
    (
      '2 kg rice, 500 g sugar',
      [('Rice', 2, ItemUnit.kg), ('Sugar', 500, ItemUnit.g)],
    ),
    (
      'രണ്ട് കിലോ അരി, അര കിലോ പരിപ്പ്',
      [('Rice', 2, ItemUnit.kg), ('Dal', 0.5, ItemUnit.kg)],
    ),
    (
      'oru kg ari, ara kg parippu, kaal kg uzhunnu',
      [
        ('Rice', 1, ItemUnit.kg),
        ('Dal', 0.5, ItemUnit.kg),
        ('Urad dal', 0.25, ItemUnit.kg),
      ],
    ),
    (
      'രണ്ട് kg ari and half litre പാൽ',
      [('Rice', 2, ItemUnit.kg), ('Milk', 0.5, ItemUnit.litre)],
    ),
    (
      'two packets tea powder and one piece coconut',
      [('Tea powder', 2, ItemUnit.packet), ('Coconut', 1, ItemUnit.piece)],
    ),
    (
      'rice 2kg sugar 0.25kg',
      [('Rice', 2, ItemUnit.kg), ('Sugar', 0.25, ItemUnit.kg)],
    ),
    (
      '1kg ari 500g parippu 250g uzhunnu',
      [
        ('Rice', 1, ItemUnit.kg),
        ('Dal', 500, ItemUnit.g),
        ('Urad dal', 250, ItemUnit.g),
      ],
    ),
    (
      'one and a half kg rice, a quarter kg sugar',
      [('Rice', 1.5, ItemUnit.kg), ('Sugar', 0.25, ItemUnit.kg)],
    ),
    (
      '1/2 kg rice; ¼ kg sugar; 1 1/2 litre milk',
      [
        ('Rice', 0.5, ItemUnit.kg),
        ('Sugar', 0.25, ItemUnit.kg),
        ('Milk', 1.5, ItemUnit.litre),
      ],
    ),
    (
      'അരക്കിലോ അരിയും കാൽക്കിലോ പരിപ്പും',
      [('Rice', 0.5, ItemUnit.kg), ('Dal', 0.25, ItemUnit.kg)],
    ),
    (
      'രണ്ടര കിലോ അരി, ഒന്നര ലിറ്റർ പാൽ',
      [('Rice', 2.5, ItemUnit.kg), ('Milk', 1.5, ItemUnit.litre)],
    ),
    (
      'half a kg rice, quarter of a litre milk',
      [('Rice', 0.5, ItemUnit.kg), ('Milk', 0.25, ItemUnit.litre)],
    ),
    (
      'twenty five g tea powder, one hundred and fifty ml milk',
      [('Tea powder', 25, ItemUnit.g), ('Milk', 150, ItemUnit.ml)],
    ),
    (
      '൨ കിലോ അരി, അഞ്ഞൂറ് ഗ്രാം പഞ്ചസാര',
      [('Rice', 2, ItemUnit.kg), ('Sugar', 500, ItemUnit.g)],
    ),
    (
      'Please buy 2kg rice and 1 litre milk venam',
      [('Rice', 2, ItemUnit.kg), ('Milk', 1, ItemUnit.litre)],
    ),
    (
      '2kg rice. 1kg sugar!',
      [('Rice', 2, ItemUnit.kg), ('Sugar', 1, ItemUnit.kg)],
    ),
  ];
  for (final example in examples) {
    test('parse ${example.$1}', () {
      final items = parser.parse(example.$1);
      expect(items.length, example.$2.length);
      for (var i = 0; i < items.length; i++) {
        expect((
          items[i].name,
          items[i].quantity,
          items[i].unit,
        ), example.$2[i]);
        expect(
          items[i].confidence,
          CandidateConfidence.high,
          reason: items[i].issues.join('; '),
        );
        expect(example.$1, contains(items[i].originalText));
      }
    });
  }
  test('all required Kerala groceries are recognized', () {
    final items = parser.parse(
      '1 kg ari, 1 kg parippu, 1 kg uzhunnu, 1 kg kadala, 1 kg muthira, 1 kg mulakupodi, 1 kg mallipodi, 1 kg sugar, 1 kg tea powder, 1 kg puttu podi, 1 kg atta',
    );
    expect(items.map((i) => i.name), [
      'Rice',
      'Dal',
      'Urad dal',
      'Chickpeas',
      'Horse gram',
      'Chilli powder',
      'Coriander powder',
      'Sugar',
      'Tea powder',
      'Puttu flour',
      'Atta',
    ]);
    expect(items.every((i) => !i.ambiguous), isTrue);
  });
  test('Malayalam grocery aliases and units', () {
    final items = parser.parse(
      'ഒരു കിലോ കടല, ഒരു കിലോ മുതിര, ഒരു പാക്കറ്റ് മുളകുപൊടി, ഒരു പാക്കറ്റ് മല്ലിപ്പൊടി, ഒരു പാക്കറ്റ് പുട്ടുപൊടി, ഒരു കിലോ ആട്ട, പന്ത്രണ്ട് എണ്ണം മുട്ട',
    );
    expect(items.map((i) => i.name), [
      'Chickpeas',
      'Horse gram',
      'Chilli powder',
      'Coriander powder',
      'Puttu flour',
      'Atta',
      'Eggs',
    ]);
    expect(items.last.quantity, 12);
  });
  test('unknown names retain spelling, explicit amounts and source text', () {
    final items = parser.parse(
      '0.5 kg Dragon Fruit, രണ്ട് പാക്കറ്റ് പുതിയ സാധനം',
    );
    expect(items.first.name, 'Dragon Fruit');
    expect(items.first.quantity, 0.5);
    expect(items.first.originalText, '0.5 kg Dragon Fruit');
    expect(items.first.ambiguous, isTrue);
    expect(items.last.name, 'പുതിയ സാധനം');
    expect(items.last.quantity, 2);
  });
  test('missing and vague quantities are never defaulted', () {
    for (final input in [
      'rice',
      'some rice',
      'കുറച്ച് അരി',
      'about 2 kg rice',
      'rice roughly 2 kg',
      'kurachu ari',
    ]) {
      final item = parser.parse(input).single;
      expect(item.quantity, isNull, reason: input);
      expect(item.ambiguous, isTrue);
    }
    final two = parser.parse('rice and sugar');
    expect(two.length, 2);
    expect(two.every((i) => i.quantity == null && i.unit == null), isTrue);
  });
  test('missing units and unsupported units require a choice', () {
    expect(parser.parse('two rice').single.unit, isNull);
    expect(parser.parse('2 cups rice').single.unit, isNull);
    expect(parser.parse('2 cups rice').single.ambiguous, isTrue);
  });
  test('ranged and alternative quantities remain unresolved', () {
    for (final input in [
      '2 or 3 kg rice',
      '2-3 kg rice',
      'rice 2 kg or 3 kg',
      'two to three kg rice',
    ]) {
      final items = parser.parse(input);
      expect(items.length, 1, reason: input);
      expect(items.single.quantity, isNull, reason: input);
      expect(items.single.ambiguous, isTrue);
    }
    expect(parser.parse('2kg rice or sugar').every((i) => i.ambiguous), isTrue);
  });
  test('invalid or unsupported precision is not silently rounded', () {
    for (final input in [
      '-2kg rice',
      '0kg rice',
      '0.0001kg rice',
      '10000kg rice',
      '1/3kg rice',
    ]) {
      final item = parser.parse(input).single;
      expect(item.quantity, isNull, reason: input);
      expect(item.ambiguous, isTrue);
    }
  });
  test('blank and punctuation-only input produce no candidates', () {
    expect(parser.parse(' \n,;.!?'), isEmpty);
  });
  test('approximation before, inside or after an amount stays unresolved', () {
    for (final input in [
      'approximately 2 kg rice',
      '2 kg approx rice',
      'rice 2kg approximately',
      '2kg rice about',
    ]) {
      final item = parser.parse(input).single;
      expect(item.quantity, isNull, reason: input);
      expect(item.ambiguous, isTrue);
    }
  });
  test(
    'prices, pack multiplication and people counts are not exact grocery amounts',
    () {
      for (final input in ['rice ₹100', '2 x 500g rice', 'rice for 2 people']) {
        final items = parser.parse(input);
        expect(
          items.every((i) => i.quantity == null && i.ambiguous),
          isTrue,
          reason: input,
        );
      }
    },
  );
  test('unfamiliar qualifiers stay intact', () {
    expect(parser.parse('2kg red rice').single.name, 'red rice');
    expect(
      parser.parse('1 packet sugar free biscuits').single.name,
      'sugar free biscuits',
    );
  });
}
