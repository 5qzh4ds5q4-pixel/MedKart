import 'package:flutter/material.dart';

import 'content_shell.dart';

/// Çalışma sırasında geçici (oturuma özel) konu filtresi seçimi.
///
/// Çoklu seçim checkbox listesi olarak gösterilir; seçilen konu kümesini
/// döner, iptal edilirse null. Kalıcı bir ayar DEĞİLDİR — çağıran taraf bu
/// seçimi yalnızca o oturumun [CardFilter]'ına uygular.
class TopicFilterSheet extends StatefulWidget {
  const TopicFilterSheet({
    super.key,
    required this.topics,
    required this.initialSelection,
  });

  final List<String> topics;
  final Set<String> initialSelection;

  static Future<Set<String>?> show(
    BuildContext context, {
    required List<String> topics,
    required Set<String> initialSelection,
  }) {
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          TopicFilterSheet(topics: topics, initialSelection: initialSelection),
    );
  }

  @override
  State<TopicFilterSheet> createState() => _TopicFilterSheetState();
}

class _TopicFilterSheetState extends State<TopicFilterSheet> {
  late Set<String> _selected = {...widget.initialSelection};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ContentShell(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Konu Filtrele', style: theme.textTheme.titleMedium),
                ),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selected = {}),
                    child: const Text('Temizle'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Yalnızca seçili konu(lar)daki kartlar çalışılır. Bu oturuma özeldir.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final topic in widget.topics)
                      CheckboxListTile(
                        title: Text(topic),
                        value: _selected.contains(topic),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (checked) => setState(() {
                          if (checked ?? false) {
                            _selected.add(topic);
                          } else {
                            _selected.remove(topic);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                child: Text(
                  _selected.isEmpty
                      ? 'Tüm konular'
                      : 'Uygula (${_selected.length})',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
