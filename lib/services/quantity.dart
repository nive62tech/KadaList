/// Quantities support three decimal places. Costs round half up to a paise.
int? parseQuantity(String text) {
  final value = text.trim();
  if (!RegExp(r'^\d{1,4}(\.\d{1,3})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final scaled =
      int.parse(parts[0]) * 1000 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(3, '0')));
  return scaled > 0 && scaled <= 9999000 ? scaled : null;
}

int quantityMillis(num value) {
  final result = parseQuantity(value.toString());
  if (result == null) {
    throw ArgumentError('Quantity must be 0.001–9999 with at most 3 decimals');
  }
  return result;
}

int extendedPrice(int unitPaise, int millis) =>
    (unitPaise * millis + 500) ~/ 1000;

String quantityLabel(int millis) =>
    '${millis ~/ 1000}.${(millis % 1000).toString().padLeft(3, '0')}'
        .replaceFirst(RegExp(r'\.?0+$'), '');
