import 'package:flutter/material.dart';

import '../models/card_filter.dart';

/// Sayfa aralığı seçimi: çipe basınca RangeSlider'lı bir pencere açılır.
///
/// Kart listesi filtre çubuğu ve Deneme Sınavı kapsam seçimi ortak kullanır.
/// Tam aralık seçilirse filtre kaldırılır (sayfasız kartları dışlamamak için).
class PageRangeFilterChip extends StatelessWidget {
  const PageRangeFilterChip({
    super.key,
    required this.filter,
    required this.bounds,
    required this.onChanged,
  });

  final CardFilter filter;

  /// PDF'ten gelen kartların (min, max) sayfa sınırı.
  final (int, int) bounds;
  final ValueChanged<CardFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = filter.hasPageRange;
    final lo = filter.minPage ?? bounds.$1;
    final hi = filter.maxPage ?? bounds.$2;

    return FilterChip(
      label: Text(selected ? 'Sayfa $lo-$hi' : 'Sayfa aralığı'),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: (_) async {
        final result = await showDialog<RangeValues?>(
          context: context,
          builder: (_) => _PageRangeDialog(
            bounds: bounds,
            initial: RangeValues(lo.toDouble(), hi.toDouble()),
          ),
        );
        if (result == null) return;
        // Tam aralık seçildiyse filtreyi kaldır (sayfasız kartları dışlama).
        if (result.start.round() == bounds.$1 &&
            result.end.round() == bounds.$2) {
          onChanged(filter.withPageRange(null, null));
        } else {
          onChanged(
            filter.withPageRange(result.start.round(), result.end.round()),
          );
        }
      },
    );
  }
}

class _PageRangeDialog extends StatefulWidget {
  const _PageRangeDialog({required this.bounds, required this.initial});

  final (int, int) bounds;
  final RangeValues initial;

  @override
  State<_PageRangeDialog> createState() => _PageRangeDialogState();
}

class _PageRangeDialogState extends State<_PageRangeDialog> {
  late RangeValues _values = widget.initial;

  @override
  Widget build(BuildContext context) {
    final min = widget.bounds.$1.toDouble();
    final max = widget.bounds.$2.toDouble();
    final divisions = (widget.bounds.$2 - widget.bounds.$1).clamp(1, 1000);

    return AlertDialog(
      title: const Text('Sayfa aralığı'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_values.start.round()} – ${_values.end.round()}. sayfalar',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          RangeSlider(
            values: _values,
            min: min,
            max: max,
            divisions: divisions,
            labels: RangeLabels(
              '${_values.start.round()}',
              '${_values.end.round()}',
            ),
            onChanged: (v) => setState(() => _values = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            RangeValues(min, max), // tüm aralık = temizle
          ),
          child: const Text('Tümü'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_values),
          child: const Text('Uygula'),
        ),
      ],
    );
  }
}
