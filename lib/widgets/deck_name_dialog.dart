import 'package:flutter/material.dart';

import '../utils/breakpoints.dart';

/// Deste oluşturma / yeniden adlandırma penceresi.
///
/// Girilen adı döner; iptal edilirse null.
class DeckNameDialog extends StatefulWidget {
  const DeckNameDialog({super.key, this.initialName});

  /// Dolu ise pencere "yeniden adlandır" kipinde açılır.
  final String? initialName;

  static Future<String?> show(BuildContext context, {String? initialName}) {
    return showDialog<String>(
      context: context,
      builder: (_) => DeckNameDialog(initialName: initialName),
    );
  }

  @override
  State<DeckNameDialog> createState() => _DeckNameDialogState();
}

class _DeckNameDialogState extends State<DeckNameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  bool get _isRenaming => widget.initialName != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isRenaming ? 'Desteyi yeniden adlandır' : 'Yeni deste'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      content: SizedBox(
        width: responsiveDialogWidth(context, preferredWidth: 420),
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'ör. Komite 1 · Kalp',
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Deste adı boş bırakılamaz.'
                : null,
            onFieldSubmitted: (_) => _save(),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isRenaming ? 'Kaydet' : 'Oluştur'),
        ),
      ],
    );
  }
}
