import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'summer_data_cell.dart';
import 'summer_data_column.dart';
import 'summer_data_table_source.dart';
import 'summer_data_table_theme.dart';
import 'summer_expandable.dart';
import 'summer_row_selection.dart';

/// Signature for controlled sort changes.
///
/// [columnKey] is `null` when sorting is cancelled. [ascending] is the
/// requested direction.
typedef SummerSortChange = void Function(String? columnKey, bool ascending);

/// A high-performance, antd/naive-style data table.
///
/// Design highlights
/// * **Vertical virtualization** via `ListView.builder` — only visible rows are
///   built, with momentum physics, scrollbar and mouse-wheel for free.
/// * **Horizontal scroll** via a shared offset notifier + `Transform.translate`;
///   pinned columns are rendered as non-translated siblings so they freeze.
/// * **Fixed header**, **fixed left/right columns**, **controlled sorting**,
///   **row selection**, **expandable rows**, **column resize**, **ellipsis +
///   tooltip**, **hover/selection highlight**, **loading/empty states**,
///   **pagination**.
class SummerDataTable extends StatefulWidget {
  /// Column definitions.
  final List<SummerDataColumn> columns;

  /// Data source (owned by the caller; call `notifyListeners` on change).
  final SummerDataTableSource source;

  /// Theme overrides. Falls back to [SummerDataTableTheme.of] then default.
  final SummerDataTableThemeData? theme;

  /// Fixed height. Enables vertical scrolling when content overflows.
  final double? height;

  /// Fixed width. Enables horizontal scrolling when content overflows.
  final double? width;

  /// Loading state.
  final bool isLoading;

  /// Empty state (also triggers when the source has zero rows).
  final bool isEmpty;

  /// Whether to render the header row.
  final bool showHeader;

  /// Whether to draw outer + inner borders.
  final bool bordered;

  /// Whether hovering a row highlights its background.
  final bool showHover;

  /// Controlled: key of the active sort column, or `null` for "no sort".
  final String? sortColumnKey;

  /// Controlled: direction of the active sort. Ignored when [sortColumnKey]
  /// is `null`.
  final bool sortAscending;

  /// Called when the user cycles the sort on a sortable header.
  final SummerSortChange? onSortChange;

  /// Row selection configuration. `null` disables selection.
  final SummerRowSelection? selection;

  /// Expandable rows configuration. `null` disables expansion.
  final SummerRowExpandable? expandable;

  /// Row interaction callbacks (index is the data row index).
  final ValueChanged<int>? onRowTap;
  final ValueChanged<int>? onRowLongPress;
  final ValueChanged<int>? onRowDoubleTap;

  /// Current page index (0-based). Null disables pagination.
  final int? currentPage;

  /// Total number of pages. Null disables pagination.
  final int? totalPages;

  final VoidCallback? onNextPage;
  final VoidCallback? onPreviousPage;
  final ValueChanged<int>? onPageTap;

  const SummerDataTable({
    super.key,
    required this.columns,
    required this.source,
    this.theme,
    this.height,
    this.width,
    this.isLoading = false,
    this.isEmpty = false,
    this.showHeader = true,
    this.bordered = true,
    this.showHover = true,
    this.sortColumnKey,
    this.sortAscending = true,
    this.onSortChange,
    this.selection,
    this.expandable,
    this.onRowTap,
    this.onRowLongPress,
    this.onRowDoubleTap,
    this.currentPage,
    this.totalPages,
    this.onNextPage,
    this.onPreviousPage,
    this.onPageTap,
  });

  @override
  State<SummerDataTable> createState() => _SummerDataTableState();
}

class _SummerDataTableState extends State<SummerDataTable>
    with SingleTickerProviderStateMixin {
  late final ScrollController _yController;
  final ValueNotifier<double> _xOffset = ValueNotifier<double>(0);
  final ValueNotifier<int?> _hoveredRow = ValueNotifier<int?>(null);

  /// User-driven column width overrides keyed by column key.
  final Map<String, double> _resizedWidths = {};

  /// Most recently computed layout (set during build, read by gestures).
  _Layout? _layout;

  // Horizontal fling state.
  AnimationController? _fling;

  // Resize drag state.
  String? _resizeKey;
  double _resizeStartW = 0;
  double _resizeStartX = 0;

  @override
  void initState() {
    super.initState();
    _yController = ScrollController();
    widget.source.addListener(_onSourceChanged);
  }

  @override
  void didUpdateWidget(covariant SummerDataTable old) {
    super.didUpdateWidget(old);
    if (!identical(widget.source, old.source)) {
      old.source.removeListener(_onSourceChanged);
      widget.source.addListener(_onSourceChanged);
      _xOffset.value = 0;
    }
  }

  @override
  void dispose() {
    widget.source.removeListener(_onSourceChanged);
    _fling?.dispose();
    _yController.dispose();
    _xOffset.dispose();
    _hoveredRow.dispose();
    super.dispose();
  }

  void _onSourceChanged() {
    if (!mounted) return;
    final maxX = _layout?.maxX ?? 0;
    if (_xOffset.value > maxX) _xOffset.value = maxX;
    setState(() {});
  }

  SummerDataTableThemeData get _theme =>
      widget.theme ?? SummerDataTableTheme.of(context);

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = _theme;

    if (widget.isLoading) {
      return SizedBox(
        height: widget.height,
        width: widget.width,
        child:
            theme.loadingWidget ?? const Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.isEmpty || widget.source.rowCount == 0) {
      return SizedBox(
        height: widget.height,
        width: widget.width,
        child: theme.emptyWidget ??
            const Center(child: Text('暂无数据')),
      );
    }

    final hasPagination = widget.currentPage != null && widget.totalPages != null;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _layout = _computeLayout(constraints.maxWidth);
          return DecoratedBox(
            decoration: widget.bordered
                ? BoxDecoration(
                    border: Border.all(
                      color: theme.borderColor,
                      width: theme.borderWidth,
                    ),
                  )
                : const BoxDecoration(),
            child: Column(
              children: <Widget>[
                if (widget.showHeader) _buildHeader(theme),
                Expanded(child: _buildBody(context, theme)),
                if (hasPagination) _buildPagination(theme),
              ],
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Layout resolution
  // --------------------------------------------------------------------------

  _Layout _computeLayout(double avail) {
    final cols = <_RCol>[];

    if (widget.expandable != null) {
      cols.add(_RCol(
        key: '__expand',
        pin: SummerColumnPin.left,
        width: widget.expandable!.columnWidth,
        fixed: true,
        alignment: Alignment.center,
        label: const SizedBox.shrink(),
        isExpand: true,
      ));
    }

    final sel = widget.selection;
    if (sel != null && sel.type != SummerSelectionType.none) {
      cols.add(_RCol(
        key: '__select',
        pin: SummerColumnPin.left,
        width: sel.width,
        fixed: true,
        alignment: Alignment.center,
        label: const SizedBox.shrink(),
        isSelection: true,
      ));
    }

    for (var i = 0; i < widget.columns.length; i++) {
      final c = widget.columns[i];
      final key = c.key ?? 'col_$i';
      final alreadyResized = _resizedWidths.containsKey(key);
      cols.add(_RCol(
        key: key,
        pin: c.pin,
        // NaN marks flex columns resolved later.
        width: alreadyResized
            ? _resizedWidths[key]!
            : (c.isFixed
                ? c.width!.clamp(c.minWidth, c.maxWidth)
                : double.nan),
        fixed: c.isFixed || alreadyResized,
        flex: c.flex,
        minWidth: c.minWidth,
        maxWidth: c.maxWidth,
        sortable: c.sortable,
        resizable: c.resizable,
        ellipsis: c.ellipsis,
        alignment: c.alignment,
        padding: c.padding,
        label: c.label,
        userColumnIndex: i,
        baseWidth: c.width ?? c.minWidth,
      ));
    }

    // Pinned columns must be fixed; give flex-pinned a default.
    for (final col in cols) {
      if (col.pin != SummerColumnPin.none && col.width.isNaN) {
        col.width = 120;
      }
    }

    final leftW = cols
        .where((c) => c.pin == SummerColumnPin.left)
        .fold<double>(0, (a, c) => a + c.width);
    final rightW = cols
        .where((c) => c.pin == SummerColumnPin.right)
        .fold<double>(0, (a, c) => a + c.width);

    final middle = cols.where((c) => c.pin == SummerColumnPin.none).toList();
    final finiteAvail = avail.isFinite ? avail : leftW + rightW;
    final middleViewport = math.max(0.0, finiteAvail - leftW - rightW);

    final sumFixed = middle
        .where((c) => c.fixed)
        .fold<double>(0, (a, c) => a + c.width);
    final totalFlex = middle
        .where((c) => !c.fixed)
        .fold<int>(0, (a, c) => a + c.flex);
    final flexUnit = (totalFlex > 0 && sumFixed < middleViewport)
        ? (middleViewport - sumFixed) / totalFlex
        : 0.0;

    for (final col in middle) {
      if (!col.fixed) {
        col.width = math.max(col.minWidth, col.flex * flexUnit);
      }
    }

    final middleContent =
        middle.fold<double>(0, (a, c) => a + c.width);

    return _Layout(cols, leftW, rightW, middleViewport, middleContent);
  }

  // --------------------------------------------------------------------------
  // Header
  // --------------------------------------------------------------------------

  Widget _buildHeader(SummerDataTableThemeData theme) {
    final layout = _layout!;
    return SizedBox(
      height: theme.headerHeight,
      child: Row(
        children: <Widget>[
          for (final c in layout.left) _buildHeaderCell(c, theme),
          Expanded(child: _buildHeaderMiddle(theme)),
          for (final c in layout.right) _buildHeaderCell(c, theme),
        ],
      ),
    );
  }

  Widget _buildHeaderMiddle(SummerDataTableThemeData theme) {
    final layout = _layout!;
    return SizedBox(
      height: theme.headerHeight,
      child: ClipRect(
        child: OverflowBox(
          minWidth: layout.middleContent,
          maxWidth: layout.middleContent,
          alignment: Alignment.centerLeft,
          child: ListenableBuilder(
            listenable: _xOffset,
            builder: (context, _) {
              final x = _xOffset.value.clamp(0.0, layout.maxX);
              return Transform.translate(
                offset: Offset(-x, 0),
                child: SizedBox(
                  width: layout.middleContent,
                  child: Row(
                    children: <Widget>[
                      for (final c in layout.middle) _buildHeaderCell(c, theme),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(_RCol col, SummerDataTableThemeData theme) {
    final isActive = col.sortable && widget.sortColumnKey == col.key;

    Widget content;
    if (col.isSelection) {
      content = _buildSelectionHeader(theme);
    } else if (col.isExpand) {
      content = const SizedBox.shrink();
    } else {
      content = Padding(
        padding: col.padding,
        child: Align(
          alignment: col.alignment,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: DefaultTextStyle(
                  style: theme.headerTextStyle.copyWith(
                    color: isActive ? theme.sortActiveColor : null,
                  ),
                  child: col.label,
                ),
              ),
              if (col.sortable) ...<Widget>[
                const SizedBox(width: 2),
                _sortIndicator(col, theme, isActive),
              ],
            ],
          ),
        ),
      );
      if (col.sortable) {
        content = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onHeaderSort(col),
          child: content,
        );
      }
    }

    Widget cell = Container(
      width: col.width,
      height: theme.headerHeight,
      decoration: BoxDecoration(
        color: theme.headerBackgroundColor,
        border: Border(
          bottom: BorderSide(color: theme.borderColor, width: theme.borderWidth),
          right: widget.bordered
              ? BorderSide(color: theme.borderColor, width: theme.borderWidth)
              : BorderSide.none,
        ),
      ),
      child: content,
    );

    if (col.resizable && !col.isSelection && !col.isExpand) {
      cell = Stack(
        children: <Widget>[
          cell,
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: theme.resizeHandleWidth + 4,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) => _onResizeStart(col, d),
              onHorizontalDragUpdate: _onResizeUpdate,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: Center(
                  child: Container(
                    width: 1,
                    color: theme.resizeHandleColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return cell;
  }

  Widget _sortIndicator(_RCol col, SummerDataTableThemeData theme, bool isActive) {
    final ascending = isActive ? widget.sortAscending : null;
    final data = ascending == null
        ? Icons.unfold_more
        : (ascending ? Icons.arrow_drop_up : Icons.arrow_drop_down);
    return Icon(
      data,
      size: 16,
      color: isActive
          ? theme.sortActiveColor
          : const Color(0xFFBFBFBF),
    );
  }

  void _onHeaderSort(_RCol col) {
    if (widget.onSortChange == null) return;
    final key = col.key;
    if (widget.sortColumnKey == key) {
      if (widget.sortAscending) {
        widget.onSortChange!(key, false); // asc -> desc
      } else {
        widget.onSortChange!(null, true); // desc -> cancel
      }
    } else {
      widget.onSortChange!(key, true); // new column -> asc
    }
  }

  Widget _buildSelectionHeader(SummerDataTableThemeData theme) {
    final sel = widget.selection!;
    if (sel.type == SummerSelectionType.radio || sel.disabled) {
      return const SizedBox.shrink();
    }
    final keys = <Object?>{
      for (var r = 0; r < widget.source.rowCount; r++)
        widget.source.rowKey(r),
    };
    final all = keys.isNotEmpty && keys.every(sel.selectedKeys.contains);
    final none = keys.intersection(sel.selectedKeys).isEmpty;
    final value = all ? true : (none ? false : null);
    return Checkbox(
      tristate: true,
      value: value,
      onChanged: (v) {
        final next = (v ?? false) ? keys : <Object?>{};
        sel.onChanged?.call(next);
      },
    );
  }

  // --------------------------------------------------------------------------
  // Body (virtualized)
  // --------------------------------------------------------------------------

  Widget _buildBody(BuildContext context, SummerDataTableThemeData theme) {
    final flat = _flatten();
    return GestureDetector(
      onHorizontalDragUpdate: _onHDrag,
      onHorizontalDragEnd: _onHDragEnd,
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: ListView.builder(
          controller: _yController,
          padding: EdgeInsets.zero,
          itemCount: flat.length,
          itemBuilder: (context, i) {
            final item = flat[i];
            if (item.isExpand) {
              return widget.expandable!.builder(context, item.rowIndex);
            }
            return _SummerBodyRow(
              layout: _layout!,
              rowIndex: item.rowIndex,
              theme: theme,
              source: widget.source,
              selection: widget.selection,
              expandable: widget.expandable,
              xOffset: _xOffset,
              hovered: widget.showHover ? _hoveredRow : null,
              bordered: widget.bordered,
              onTap: widget.onRowTap,
              onLongPress: widget.onRowLongPress,
              onDoubleTap: widget.onRowDoubleTap,
              onSelectionToggle: _toggleSelection,
              onExpandToggle: _toggleExpand,
            );
          },
        ),
      ),
    );
  }

  List<_Flat> _flatten() {
    final out = <_Flat>[];
    final exp = widget.expandable;
    final count = widget.source.rowCount;
    for (var r = 0; r < count; r++) {
      out.add(_Flat(false, r));
      if (exp != null && exp.expandedKeys.contains(widget.source.rowKey(r))) {
        out.add(_Flat(true, r));
      }
    }
    return out;
  }

  // --------------------------------------------------------------------------
  // Selection / expansion handlers
  // --------------------------------------------------------------------------

  void _toggleSelection(Object? key, bool willSelect) {
    final sel = widget.selection;
    if (sel == null || sel.onChanged == null) return;
    Set<Object?> next;
    if (sel.type == SummerSelectionType.radio) {
      next = <Object?>{key};
    } else {
      next = Set<Object?>.from(sel.selectedKeys);
      willSelect ? next.add(key) : next.remove(key);
    }
    sel.onChanged!(next);
  }

  void _toggleExpand(int rowIndex) {
    final exp = widget.expandable;
    if (exp == null || exp.onChanged == null) return;
    final key = widget.source.rowKey(rowIndex);
    final next = Set<Object?>.from(exp.expandedKeys);
    next.contains(key) ? next.remove(key) : next.add(key);
    exp.onChanged!(next);
  }

  // --------------------------------------------------------------------------
  // Horizontal scroll (drag / fling / wheel)
  // --------------------------------------------------------------------------

  void _onHDrag(DragUpdateDetails d) {
    final maxX = _layout?.maxX ?? 0;
    if (maxX <= 0) return;
    _stopFling();
    final nx = (_xOffset.value - d.delta.dx).clamp(0.0, maxX);
    if (nx != _xOffset.value) _xOffset.value = nx;
  }

  void _onHDragEnd(DragEndDetails d) {
    final maxX = _layout?.maxX ?? 0;
    if (maxX <= 0) return;
    final px = d.velocity.pixelsPerSecond.dx;
    if (px.abs() < 60) return;
    _runFling(-px, maxX);
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final maxX = _layout?.maxX ?? 0;
    if (maxX <= 0) return;
    double dx = e.scrollDelta.dx;
    if (HardwareKeyboard.instance.isShiftPressed) dx += e.scrollDelta.dy;
    if (dx == 0) return;
    _stopFling();
    _xOffset.value = (_xOffset.value + dx).clamp(0.0, maxX);
  }

  void _runFling(double velocity, double maxX) {
    _stopFling();
    final controller =
        _fling = AnimationController.unbounded(vsync: this);
    controller.value = _xOffset.value;
    final sim = FrictionSimulation(0.02, _xOffset.value, velocity);
    controller.addListener(() {
      final v = controller.value.clamp(0.0, maxX);
      if (v != _xOffset.value) _xOffset.value = v;
      if (v <= 0 || v >= maxX) controller.stop();
    });
    controller.animateWith(sim);
  }

  void _stopFling() {
    _fling?.stop();
  }

  // --------------------------------------------------------------------------
  // Column resize
  // --------------------------------------------------------------------------

  void _onResizeStart(_RCol col, DragStartDetails d) {
    _resizeKey = col.key;
    _resizeStartW = _resizedWidths[col.key] ?? col.baseWidth;
    _resizeStartX = d.globalPosition.dx;
  }

  void _onResizeUpdate(DragUpdateDetails d) {
    if (_resizeKey == null) return;
    final col = _layout?.columns.firstWhere((c) => c.key == _resizeKey);
    if (col == null) return;
    final delta = d.globalPosition.dx - _resizeStartX;
    final nw = (_resizeStartW + delta).clamp(col.minWidth, col.maxWidth);
    if (_resizedWidths[_resizeKey!] != nw) {
      setState(() => _resizedWidths[_resizeKey!] = nw);
    }
  }

  // --------------------------------------------------------------------------
  // Pagination
  // --------------------------------------------------------------------------

  Widget _buildPagination(SummerDataTableThemeData theme) {
    final current = widget.currentPage ?? 0;
    final total = widget.totalPages ?? 1;

    final pages = _pageWindow(current, total);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.borderColor, width: theme.borderWidth),
        ),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: current > 0 ? widget.onPreviousPage : null,
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (final p in pages)
                    if (p == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('…'),
                      )
                    else
                      _pageButton(p, p == current, theme),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: current < total - 1 ? widget.onNextPage : null,
          ),
        ],
      ),
    );
  }

  /// Returns the page numbers to render, with `null` meaning an ellipsis.
  List<int?> _pageWindow(int current, int total) {
    if (total <= 7) return [for (var i = 0; i < total; i++) i];
    final out = <int?>[0];
    final start = math.max(1, current - 1);
    final end = math.min(total - 2, current + 1);
    if (start > 1) out.add(null);
    for (var i = start; i <= end; i++) {
      out.add(i);
    }
    if (end < total - 2) out.add(null);
    out.add(total - 1);
    return out;
  }

  Widget _pageButton(int page, bool active, SummerDataTableThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: widget.onPageTap == null ? null : () => widget.onPageTap!(page),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? theme.sortActiveColor : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${page + 1}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active
                  ? Colors.white
                  : theme.cellTextStyle.color,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Layout model
// =============================================================================

class _Layout {
  final List<_RCol> columns;
  final double leftWidth;
  final double rightWidth;
  final double middleViewport;
  final double middleContent;

  const _Layout(this.columns, this.leftWidth, this.rightWidth,
      this.middleViewport, this.middleContent);

  double get maxX =>
      middleContent > middleViewport ? middleContent - middleViewport : 0.0;

  List<_RCol> get left =>
      columns.where((c) => c.pin == SummerColumnPin.left).toList(growable: false);
  List<_RCol> get right => columns
      .where((c) => c.pin == SummerColumnPin.right)
      .toList(growable: false);
  List<_RCol> get middle => columns
      .where((c) => c.pin == SummerColumnPin.none)
      .toList(growable: false);
}

class _RCol {
  final String key;
  SummerColumnPin pin;
  double width;
  final bool fixed;
  final int flex;
  final double minWidth;
  final double maxWidth;
  final bool sortable;
  final bool resizable;
  final bool ellipsis;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;
  final Widget label;
  final int? userColumnIndex;
  final bool isSelection;
  final bool isExpand;
  final double baseWidth;

  _RCol({
    required this.key,
    required this.pin,
    required this.width,
    this.fixed = true,
    this.flex = 0,
    this.minWidth = 40,
    this.maxWidth = double.infinity,
    this.sortable = false,
    this.resizable = false,
    this.ellipsis = false,
    this.alignment = Alignment.centerLeft,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    required this.label,
    this.userColumnIndex,
    this.isSelection = false,
    this.isExpand = false,
    this.baseWidth = 0,
  });
}

class _Flat {
  final bool isExpand;
  final int rowIndex;
  const _Flat(this.isExpand, this.rowIndex);
}

// =============================================================================
// Body row
// =============================================================================

class _SummerBodyRow extends StatelessWidget {
  final _Layout layout;
  final int rowIndex;
  final SummerDataTableThemeData theme;
  final SummerDataTableSource source;
  final SummerRowSelection? selection;
  final SummerRowExpandable? expandable;
  final ValueListenable<double> xOffset;
  final ValueNotifier<int?>? hovered;
  final bool bordered;
  final ValueChanged<int>? onTap;
  final ValueChanged<int>? onLongPress;
  final ValueChanged<int>? onDoubleTap;
  final void Function(Object? key, bool willSelect)? onSelectionToggle;
  final ValueChanged<int>? onExpandToggle;

  const _SummerBodyRow({
    required this.layout,
    required this.rowIndex,
    required this.theme,
    required this.source,
    required this.selection,
    required this.expandable,
    required this.xOffset,
    required this.hovered,
    required this.bordered,
    required this.onTap,
    required this.onLongPress,
    required this.onDoubleTap,
    required this.onSelectionToggle,
    required this.onExpandToggle,
  });

  @override
  Widget build(BuildContext context) {
    final rowHeight = theme.rowHeight;
    final inner = SizedBox(
      height: rowHeight,
      child: Row(
        children: <Widget>[
          for (final c in layout.left) _cell(context, c),
          Expanded(child: _middle(context)),
          for (final c in layout.right) _cell(context, c),
        ],
      ),
    );

    if (hovered == null) {
      return ColoredBox(color: _background(false), child: inner);
    }

    return MouseRegion(
      onEnter: (_) => hovered!.value = rowIndex,
      onExit: (_) {
        if (hovered!.value == rowIndex) hovered!.value = null;
      },
      child: ValueListenableBuilder<int?>(
        valueListenable: hovered!,
        builder: (context, h, _) {
          final isHovered = h == rowIndex;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onTap == null ? null : () => onTap!(rowIndex),
            onLongPress:
                onLongPress == null ? null : () => onLongPress!(rowIndex),
            onDoubleTap:
                onDoubleTap == null ? null : () => onDoubleTap!(rowIndex),
            child: ColoredBox(color: _background(isHovered), child: inner),
          );
        },
      ),
    );
  }

  Widget _middle(BuildContext context) {
    return SizedBox(
      height: theme.rowHeight,
      child: ClipRect(
        child: OverflowBox(
          minWidth: layout.middleContent,
          maxWidth: layout.middleContent,
          alignment: Alignment.centerLeft,
          child: ListenableBuilder(
            listenable: xOffset,
            builder: (context, _) {
              final x = xOffset.value.clamp(0.0, layout.maxX);
              return Transform.translate(
                offset: Offset(-x, 0),
                child: SizedBox(
                  width: layout.middleContent,
                  child: Row(
                    children: <Widget>[
                      for (final c in layout.middle) _cell(context, c),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, _RCol col) {
    Widget content;
    if (col.isExpand) {
      content = _expandControl();
    } else if (col.isSelection) {
      content = _selectionControl();
    } else {
      final cell = source.buildCell(context, rowIndex, col.userColumnIndex!);
      if (col.ellipsis) {
        content = SummerDataCell(
          ellipsis: true,
          alignment: col.alignment,
          padding: col.padding,
          child: cell,
        );
      } else {
        content = Padding(
          padding: col.padding,
          child: Align(alignment: col.alignment, child: cell),
        );
      }
    }

    return Container(
      width: col.width,
      height: theme.rowHeight,
      decoration: BoxDecoration(
        border: bordered
            ? Border(
                right: BorderSide(
                    color: theme.borderColor, width: theme.borderWidth),
              )
            : null,
      ),
      child: content,
    );
  }

  Widget _expandControl() {
    final exp = expandable!;
    final isOpen = exp.expandedKeys.contains(source.rowKey(rowIndex));
    final icon = isOpen
        ? (exp.collapseIcon ?? exp.expandIcon ?? theme.expandIcon)
        : (exp.expandIcon ?? theme.expandIcon);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onExpandToggle == null ? null : () => onExpandToggle!(rowIndex),
      child: SizedBox(
        width: expandable!.columnWidth,
        child: Center(
          child: Transform.rotate(
            angle: isOpen ? math.pi / 2 : 0,
            child: icon,
          ),
        ),
      ),
    );
  }

  Widget _selectionControl() {
    final sel = selection!;
    final key = source.rowKey(rowIndex);
    final checked = sel.selectedKeys.contains(key);
    if (sel.type == SummerSelectionType.radio) {
      // Custom indicator avoids the deprecated Radio.groupValue/onChanged API.
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: sel.disabled ? null : () => onSelectionToggle!(key, true),
        child: Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: checked
                  ? theme.sortActiveColor
                  : const Color(0xFFBFBFBF),
              width: 2,
            ),
          ),
          child: checked
              ? Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.sortActiveColor,
                  ),
                )
              : null,
        ),
      );
    }
    return Checkbox(
      value: checked,
      onChanged: sel.disabled
          ? null
          : (v) => onSelectionToggle!(key, v ?? false),
    );
  }

  Color _background(bool isHovered) {
    final sel = selection;
    if (sel != null && sel.selectedKeys.contains(source.rowKey(rowIndex))) {
      if (theme.selectedColor != null) return theme.selectedColor!;
    }
    if (isHovered && theme.hoverColor != null) return theme.hoverColor!;
    if (rowIndex.isOdd && theme.altRowBackgroundColor != null) {
      return theme.altRowBackgroundColor!;
    }
    return theme.cellBackgroundColor;
  }
}
