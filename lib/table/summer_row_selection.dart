import 'package:flutter/widgets.dart';

/// Row selection mode.
enum SummerSelectionType {
  /// No selection column.
  none,

  /// Multiple rows selectable via checkboxes.
  checkbox,

  /// Single row selectable via radio buttons.
  radio,
}

/// Row-selection configuration (controlled).
///
/// The caller owns [selectedKeys] and updates them in [onChanged].
class SummerRowSelection {
  /// Selection mode.
  final SummerSelectionType type;

  /// Currently selected row keys.
  final Set<Object?> selectedKeys;

  /// Invoked with the new key set when the selection changes.
  final ValueChanged<Set<Object?>>? onChanged;

  /// Width of the selection column.
  final double width;

  /// When true, all row checkboxes render disabled and ignore taps.
  final bool disabled;

  const SummerRowSelection({
    this.type = SummerSelectionType.checkbox,
    this.selectedKeys = const <Object?>{},
    this.onChanged,
    this.width = 48.0,
    this.disabled = false,
  });
}
