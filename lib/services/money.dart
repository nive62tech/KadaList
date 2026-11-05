String money(int paise) =>
    '${paise < 0 ? '-' : ''}₹${paise.abs() ~/ 100}.${(paise.abs() % 100).toString().padLeft(2, '0')}';
String moneyInput(int paise) =>
    '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';
int? parseMoney(String text) {
  final value = text.trim();
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(value)) {
    return null;
  }
  final parts = value.split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
}
