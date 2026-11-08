import 'package:flutter/material.dart';
import '../services/grocery_parser.dart';
import '../widgets/offline_speech_input.dart';
import 'grocery_review_screen.dart';

class GroceryTextScreen extends StatefulWidget {
  const GroceryTextScreen({
    super.key,
    required this.listId,
    this.voiceFirst = false,
  });
  final int listId;
  final bool voiceFirst;
  @override
  State<GroceryTextScreen> createState() => _GroceryTextScreenState();
}

class _GroceryTextScreenState extends State<GroceryTextScreen> {
  final _text = TextEditingController();
  String? _error;
  bool _speechActive = false;

  Widget _voiceInput() => OfflineSpeechInput(
    onActiveChanged: (active) => setState(() => _speechActive = active),
    onTranscript: (transcript) {
      final prefix = _text.text.trimRight();
      _text.text = prefix.isEmpty ? transcript : '$prefix\n$transcript';
      setState(() => _error = null);
    },
  );
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final candidates = GroceryParser().parse(_text.text);
    if (candidates.isEmpty) {
      setState(() => _error = 'Type at least one grocery item.');
      return;
    }
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GroceryReviewScreen(listId: widget.listId, candidates: candidates),
      ),
    );
    if (saved == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.voiceFirst
            ? 'Add groceries by voice'
            : 'Paste or type grocery list',
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.voiceFirst) _voiceInput(),
            const Text(
              'Malayalam, English or Manglish — processed entirely on this device. Review every item before saving. Use commas or new lines for unfamiliar names.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
              minLines: 6,
              maxLines: 12,
              maxLength: 10000,
              decoration: InputDecoration(
                labelText: 'Grocery text',
                hintText: '2 kg ari, അര കിലോ പരിപ്പ്, one litre milk',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _speechActive ? null : _parse,
              child: const Text('Review extracted items'),
            ),
            if (!widget.voiceFirst) _voiceInput(),
          ],
        ),
      ),
    ),
  );
}
