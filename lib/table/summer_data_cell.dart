import 'package:flutter/material.dart';

/// A styled cell-content wrapper for [SummerDataTable].
///
/// Unlike the previous data-class version, this is a real widget. The table
/// uses it internally for [SummerDataColumn.ellipsis] columns; callers may also
/// use it directly inside [SummerDataTableSource.buildCell].
class SummerDataCell extends StatelessWidget {
  /// The cell content.
  final Widget child;

  /// Alignment of [child] within the cell.
  final AlignmentGeometry alignment;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// When true, [child] is constrained to one line, ellipsized, and wrapped in
  /// a [Tooltip] showing [tooltip] (or the child's textual value).
  final bool ellipsis;

  /// Optional tooltip text. Falls back to the child text when omitted.
  final String? tooltip;

  const SummerDataCell({
    super.key,
    required this.child,
    this.alignment = Alignment.centerLeft,
    this.padding = EdgeInsets.zero,
    this.ellipsis = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (ellipsis) {
      final tip = tooltip ?? _extractText(child);
      content = Tooltip(
        message: tip,
        waitDuration: const Duration(milliseconds: 400),
        child: DefaultTextStyle.merge(
          style: const TextStyle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: child,
        ),
      );
    }
    return Padding(padding: padding, child: Align(alignment: alignment, child: content));
  }

  String _extractText(Widget w) {
    if (w is Text) return w.data ?? '';
    return '';
  }
}
