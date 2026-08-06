import 'package:flutter/material.dart';

import '../state/study_settings.dart';
import '../utils/breakpoints.dart';

/// Günlük yeni kart limitini değiştirme penceresi.
///
/// Girilen değeri döner; iptal edilirse null.
class DailyLimitDialog extends StatefulWidget {
  const DailyLimitDialog({super.key, required this.currentLimit});

  final int currentLimit;

  static Future<int?> show(BuildContext context, {required int currentLimit}) {
    return showDialog<int>(
      context: context,
      builder: (_) => DailyLimitDialog(currentLimit: currentLimit),
    );
  }

  @override
  State<DailyLimitDialog> createState() => _DailyLimitDialogState();
}

class _DailyLimitDialogState extends State<DailyLimitDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.currentLimit}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null) return 'Bir sayı gir.';
    if (parsed < StudySettings.minDailyNewCardLimit ||
        parsed > StudySettings.maxDailyNewCardLimit) {
      return '${StudySettings.minDailyNewCardLimit}-'
          '${StudySettings.maxDailyNewCardLimit} arası bir değer gir.';
    }
    return null;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(int.parse(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Günlük yeni kart limiti'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      content: SizedBox(
        width: responsiveDialogWidth(context, preferredWidth: 360),
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Günde en fazla yeni kart',
              helperText: '"Bugün Çalış" kuyruğuna eklenecek yeni kart sayısı.',
            ),
            validator: _validate,
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
        FilledButton(onPressed: _save, child: const Text('Kaydet')),
      ],
    );
  }
}
