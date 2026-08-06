import 'package:flutter/material.dart';

import '../state/study_settings.dart';
import '../utils/breakpoints.dart';

/// Opsiyonel günlük çalışma hedefini değiştirme penceresi.
///
/// [DailyLimitDialog]'dan farkı hedefin ZORUNLU OLMAMASI: alan boş bırakılıp
/// kaydedilebilir, bu hedefi temizler. Bu yüzden "kaydedilen değer" ile
/// "iptal" birbirinden ayrılamayan tek bir `int?` ile temsil edilemez —
/// pencere [DailyGoalResult] döner, iptalde `null`.
class DailyGoalDialog extends StatefulWidget {
  const DailyGoalDialog({super.key, required this.currentGoal});

  /// Mevcut hedef; `null` = hedef belirlenmemiş.
  final int? currentGoal;

  /// Pencereyi açar. İptal edilirse `null`, kaydedilirse [DailyGoalResult]
  /// döner (`result.goal == null` ise kullanıcı hedefi kaldırmıştır).
  static Future<DailyGoalResult?> show(
    BuildContext context, {
    required int? currentGoal,
  }) {
    return showDialog<DailyGoalResult>(
      context: context,
      builder: (_) => DailyGoalDialog(currentGoal: currentGoal),
    );
  }

  @override
  State<DailyGoalDialog> createState() => _DailyGoalDialogState();
}

/// Kaydedilen hedef. `goal == null` = kullanıcı hedefi kaldırdı (alanı boş
/// bıraktı). Pencerenin `null` dönmesiyle karıştırılmasın diye ayrı bir tip.
class DailyGoalResult {
  const DailyGoalResult(this.goal);

  final int? goal;
}

class _DailyGoalDialogState extends State<DailyGoalDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentGoal?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final text = (value ?? '').trim();
    // Boş = hedef yok. Geçerli bir giriş, hata değil.
    if (text.isEmpty) return null;

    final parsed = int.tryParse(text);
    if (parsed == null) return 'Bir sayı gir ya da alanı boş bırak.';
    if (parsed < StudySettings.minDailyGoal ||
        parsed > StudySettings.maxDailyGoal) {
      return '${StudySettings.minDailyGoal}-${StudySettings.maxDailyGoal} '
          'arası bir değer gir.';
    }
    return null;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final text = _controller.text.trim();
    Navigator.of(
      context,
    ).pop(DailyGoalResult(text.isEmpty ? null : int.parse(text)));
  }

  void _clear() {
    Navigator.of(context).pop(const DailyGoalResult(null));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Günlük hedef'),
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
              labelText: 'Günde kaç kart (opsiyonel)',
              helperText: 'Boş bırakırsan hedef gösterilmez. '
                  'Çalışma kuyruğunu etkilemez.',
              helperMaxLines: 3,
            ),
            validator: _validate,
            onFieldSubmitted: (_) => _save(),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        // Hedef zaten yoksa "Kaldır" anlamsız olurdu.
        if (widget.currentGoal != null)
          TextButton(onPressed: _clear, child: const Text('Kaldır')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(onPressed: _save, child: const Text('Kaydet')),
      ],
    );
  }
}
