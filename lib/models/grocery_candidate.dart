import 'shopping_item.dart';

enum CandidateConfidence { high, needsReview }

/// A parser suggestion, never a saved shopping item. Nulls require user input.
class GroceryCandidate {
  const GroceryCandidate({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.originalText,
    required this.issues,
  });
  final String name, originalText;
  final num? quantity;
  final ItemUnit? unit;
  final List<String> issues;
  CandidateConfidence get confidence => issues.isEmpty
      ? CandidateConfidence.high
      : CandidateConfidence.needsReview;
  bool get ambiguous => issues.isNotEmpty;
}
