import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'summer_data_cell.dart';
import 'summer_data_column.dart';
import 'summer_data_table_source.dart';
import 'summer_data_table_theme.dart';
import 'summer_expandable.dart';
import 'summer_row_selection.dart';
import 'summer_tree_table_source.dart';

/// Signature for controlled single-column sort changes.
///
/// [columnKey] is `null` when sorting is cancelled.
typedef SummerSortChange = void Function(String? columnKey, bool ascending);

/// Signature for controlled multi-column sort changes.
typedef SummerMultiSortChange = void Function(List<SummerSortSpec> columns);

/// Signature for controlled per-column filter changes.
typedef SummerFilterChange = void Function(
    String columnKey, List<Object?> values);

/// A high-performance, antd/naive-style data table.
///
/// Design highlights
/// * **Vertical virtualization** via `ListView.builder` — only visible rows are
///   built, with momentum physics, scrollbar and mouse-wheel for free.
/// * **Horizontal scroll** via a shared offset notifier driving a single
///   render-object translate ([_XTranslatedBox]) — X scrolling repaints without
///   rebuilding any cell widget. Pinned columns are non-translated siblings.
/// * **Fixed header**, **fixed left/right columns**, **single + multi-column
///   sorting** (Shift+click), **row selection**, **expandable rows**,
///   **column resize**, **column filtering dropdown**, **tree/hierarchical
///   data**, **ellipsis + tooltip**, **hover/selection highlight**,
///   **loading/empty states**, **pagination**.
class SummerDataTable extends StatefulWidget {
  /// Column definitions.
  final List<SummerDataColumn> columns;

  /// Data source (owned by the caller; call `notifyListeners` on change).
  /// Use a [SummerTreeTableSource] to enable tree mode.
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

  // -- Single-column sort (controlled) -------------------------------------

  /// Active sort column key, or `null`. Ignored when [onMultiSortChange] is set.
  final String? sortColumnKey;

  /// Direction of the single active sort. Ignored when [sortColumnKey] is null.
  final bool sortAscending;

  /// Called when the user cycles a sortable header (single-sort mode).
  final SummerSortChange? onSortChange;

  // -- Multi-column sort (controlled) --------------------------------------

  /// Active multi-sort specs in priority order. Used when [onMultiSortChange]
  /// is set (which also switches the header to multi-sort mode).
  final List<SummerSortSpec>? sortColumns;

  /// Called when the user changes the sort set. Enabling this activates
  /// multi-sort (Shift+click to stack columns).
  final SummerMultiSortChange? onMultiSortChange;

  // -- Filtering (controlled) ----------------------------------------------

  /// Selected filter values per column key.
  final Map<String, List<Object?>>? filteredColumnValues;

  /// Called when a column's filter selection is applied/reset.
  final SummerFilterChange? onFilterChange;

  // -- Selection / expansion ----------------------------------------------

  /// Row selection configuration. `null` disables selection.
  final SummerRowSelection? selection;

  /// Expandable rows configuration (detail panel under a row). `null` disables.
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
    this.sortColumns,
    this.onMultiSortChange,
    this.filteredColumnValues,
    this.onFilterChange,
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

  // Filter dropdown overlay.
  OverlayEntry? _filterEntry;

  bool get _isMultiSort => widget.onMultiSortChange != null;
  bool get _isTree => widget.source is SummerTreeTableSource;

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
    _closeFilter();
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

  /// Unified sort spec list derived from single- or multi-sort mode.
  List<SummerSortSpec> get _effectiveSort {
    if (_isMultiSort) return widget.sortColumns ?? const <SummerSortSpec>[];
    final k = widget.sortColumnKey;
    return k == null
        ? const <SummerSortSpec>[]
        : <SummerSortSpec>[SummerSortSpec(key: k, ascending: widget.sortAscending)];
  }

  SummerSortSpec? _specFor(String key) {
    for (final s in _effectiveSort) {
      if (s.key == key) return s;
    }
    return null;
  }

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
        child: theme.emptyWidget ?? const Center(child: Text('暂无数据')),
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

    // Build the header tree and collect user *leaf* columns in DFS order.
    // `userColumnIndex` is the leaf index reported to `source.buildCell`.
    final userLeaves = <_RCol>[];
    final headerRoots = <_HNode>[];
    for (final c in widget.columns) {
      headerRoots.add(_buildHeaderNode(c, 0, userLeaves));
    }
    cols.addAll(userLeaves);

    // Pinned columns must be fixed; give flex-pinned a default.
    for (final col in cols) {
      if (col.pin != SummerColumnPin.none && col.width.isNaN) {
        col.width = 120;
      }
    }

    // Partition once (consumed by both header and every body row).
    final left = cols
        .where((c) => c.pin == SummerColumnPin.left)
        .toList(growable: false);
    final right = cols
        .where((c) => c.pin == SummerColumnPin.right)
        .toList(growable: false);
    final middle = cols
        .where((c) => c.pin == SummerColumnPin.none)
        .toList(growable: false);

    final leftW = left.fold<double>(0, (a, c) => a + c.width);
    final rightW = right.fold<double>(0, (a, c) => a + c.width);
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

    // Resolve header-node widths: leaves read the (now-resolved) leaf width;
    // groups sum their descendants. Also compute header depth.
    var depth = 1;
    for (final r in headerRoots) {
      _resolveNodeWidth(r);
      depth = math.max(depth, _nodeDepth(r));
    }

    final middleContent = middle.fold<double>(0, (a, c) => a + c.width);

    return _Layout(cols, left, right, middle, headerRoots, depth, leftW,
        rightW, middleViewport, middleContent);
  }

  /// Recursively builds the header tree, appending each user leaf column to
  /// [outLeaves] in display (DFS) order.
  _HNode _buildHeaderNode(
      SummerDataColumn c, int level, List<_RCol> outLeaves) {
    if (c.children.isEmpty) {
      final forceMiddle = level > 0; // nested leaves can't be pinned
      final leafIndex = outLeaves.length;
      final key = c.key ?? 'col_$leafIndex';
      final alreadyResized = _resizedWidths.containsKey(key);
      final leaf = _RCol(
        key: key,
        pin: forceMiddle ? SummerColumnPin.none : c.pin,
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
        sortDirections: c.sortDirections,
        resizable: c.resizable,
        ellipsis: c.ellipsis,
        alignment: c.alignment,
        padding: c.padding,
        label: c.label,
        filters: c.filters,
        filterMultiple: c.filterMultiple,
        userColumnIndex: leafIndex,
        baseWidth: c.width ?? c.minWidth,
      );
      outLeaves.add(leaf);
      return _HNode.leaf(leaf, c.label, level, key);
    }
    final childNodes = <_HNode>[
      for (final child in c.children) _buildHeaderNode(child, level + 1, outLeaves),
    ];
    return _HNode.group(
        childNodes, c.label, level, c.key ?? 'group:$level:${childNodes.length}');
  }

  double _resolveNodeWidth(_HNode n) {
    if (n.isLeaf) {
      n.width = n.leaf!.width;
      return n.width;
    }
    var sum = 0.0;
    for (final c in n.children) {
      sum += _resolveNodeWidth(c);
    }
    n.width = sum;
    return sum;
  }

  int _nodeDepth(_HNode n) {
    if (n.isLeaf) return 1;
    var d = 0;
    for (final c in n.children) {
      d = math.max(d, _nodeDepth(c));
    }
    return d + 1;
  }

  bool _nodeIsMiddle(_HNode n) =>
      !n.isLeaf || n.leaf!.pin == SummerColumnPin.none;

  // --------------------------------------------------------------------------
  // Header
  // --------------------------------------------------------------------------

  Widget _buildHeader(SummerDataTableThemeData theme) {
    final layout = _layout!;
    final totalH = theme.headerHeight * layout.depth;
    final sort = _effectiveSort; // resolved once per header build
    return SizedBox(
      height: totalH,
      child: Row(
        children: <Widget>[
          for (final c in layout.left) _buildLeafHeaderCell(c, theme, sort, totalH),
          Expanded(child: _buildHeaderMiddle(theme, sort, totalH)),
          for (final c in layout.right) _buildLeafHeaderCell(c, theme, sort, totalH),
        ],
      ),
    );
  }

  Widget _buildHeaderMiddle(SummerDataTableThemeData theme,
      List<SummerSortSpec> sort, double totalH) {
    final layout = _layout!;
    return SizedBox(
      height: totalH,
      child: ClipRect(
        child: OverflowBox(
          minWidth: layout.middleContent,
          maxWidth: layout.middleContent,
          alignment: Alignment.centerLeft,
          child: _XTranslatedBox(
            offset: _xOffset,
            maxX: layout.maxX,
            child: SizedBox(
              width: layout.middleContent,
              height: totalH,
              child: Stack(
                clipBehavior: Clip.none,
                children:
                    _buildMiddleHeaderCells(layout.headerRoots, theme, sort),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Lays out the merged middle header as absolutely-positioned cells. A leaf
  /// spans from its level down to the bottom row (rowspan = depth - level); a
  /// group occupies a single row (rowspan = 1) and the width of its leaves.
  List<Widget> _buildMiddleHeaderCells(List<_HNode> roots,
      SummerDataTableThemeData theme, List<SummerSortSpec> sort) {
    final cells = <Widget>[];
    final hh = theme.headerHeight;
    final depth = _layout!.depth;
    var x = 0.0;
    void walk(_HNode n) {
      if (!_nodeIsMiddle(n)) return; // pinned leaf handled by the side row
      if (n.isLeaf) {
        final h = (depth - n.level) * hh;
        cells.add(Positioned(
          left: x,
          top: n.level * hh,
          width: n.width,
          height: h,
          child: _buildLeafHeaderCell(n.leaf!, theme, sort, h),
        ));
        x += n.width;
      } else {
        final startX = x;
        // Group painted first so its descendants render on top of it.
        cells.add(Positioned(
          left: startX,
          top: n.level * hh,
          width: n.width,
          height: hh,
          child: _buildGroupHeaderCell(n, theme),
        ));
        for (final child in n.children) {
          walk(child);
        }
        x = startX + n.width;
      }
    }

    for (final r in roots) {
      walk(r);
    }
    return cells;
  }

  Widget _buildGroupHeaderCell(_HNode n, SummerDataTableThemeData theme) {
    return Container(
      width: n.width,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      alignment: Alignment.center,
      child: DefaultTextStyle(
        style: theme.headerTextStyle,
        child: n.label,
      ),
    );
  }

  Widget _buildLeafHeaderCell(_RCol col, SummerDataTableThemeData theme,
      List<SummerSortSpec> sort, double height) {
    final spec = _specIn(sort, col.key);
    final isActive = col.sortable && spec != null;
    final priority = sort.indexWhere((s) => s.key == col.key);
    final showPriority =
        isActive && _isMultiSort && sort.length > 1 && priority >= 0;

    Widget content;
    if (col.isSelection) {
      content = _buildSelectionHeader(theme);
    } else if (col.isExpand) {
      content = const SizedBox.shrink();
    } else {
      Widget labelArea = Flexible(
        child: DefaultTextStyle(
          style: theme.headerTextStyle.copyWith(
            color: isActive ? theme.sortActiveColor : null,
          ),
          child: col.label,
        ),
      );
      Widget sortBits = const SizedBox.shrink();
      if (col.sortable) {
        sortBits = Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(width: 2),
            _sortIndicator(theme, isActive, spec),
            if (showPriority)
              Padding(
                padding: const EdgeInsets.only(left: 1),
                child: Text(
                  '${priority + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.sortActiveColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        );
      }

      content = Padding(
        padding: col.padding,
        child: Align(
          alignment: col.alignment,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (col.sortable)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onHeaderTap(col),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[labelArea, sortBits],
                  ),
                )
              else
                labelArea,
              if (_hasFilter(col)) ...<Widget>[
                const SizedBox(width: 4),
                _filterFunnel(col, theme),
              ],
            ],
          ),
        ),
      );
    }

    Widget cell = Container(
      width: col.width,
      height: height,
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

  SummerSortSpec? _specIn(List<SummerSortSpec> sort, String key) {
    for (final s in sort) {
      if (s.key == key) return s;
    }
    return null;
  }

  Widget _sortIndicator(
      SummerDataTableThemeData theme, bool isActive, SummerSortSpec? spec) {
    final ascending = isActive ? spec!.ascending : null;
    final data = ascending == null
        ? Icons.unfold_more
        : (ascending ? Icons.arrow_drop_up : Icons.arrow_drop_down);
    return Icon(
      data,
      size: 16,
      color: isActive ? theme.sortActiveColor : const Color(0xFFBFBFBF),
    );
  }

  bool _hasFilter(_RCol col) =>
      col.filters != null &&
      col.filters!.isNotEmpty &&
      widget.onFilterChange != null;

  Widget _filterFunnel(_RCol col, SummerDataTableThemeData theme) {
    final active =
        (widget.filteredColumnValues?[col.key]?.isNotEmpty ?? false);
    return Builder(
      builder: (iconCtx) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openFilter(col, iconCtx),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              Icons.filter_alt_outlined,
              size: 15,
              color: active ? theme.sortActiveColor : const Color(0xFFBFBFBF),
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Sorting
  // --------------------------------------------------------------------------

  void _onHeaderTap(_RCol col) {
    if (_isMultiSort) {
      _onMultiSort(col, HardwareKeyboard.instance.isShiftPressed);
    } else {
      _onSingleSort(col);
    }
  }

  void _onSingleSort(_RCol col) {
    if (widget.onSortChange == null) return;
    final spec = _specFor(col.key);
    final dirs = col.sortDirections;
    if (spec == null) {
      if (dirs.isNotEmpty) widget.onSortChange!(col.key, dirs.first);
    } else {
      final idx = dirs.indexOf(spec.ascending);
      if (idx >= 0 && idx + 1 < dirs.length) {
        widget.onSortChange!(col.key, dirs[idx + 1]);
      } else {
        widget.onSortChange!(null, true); // cancel
      }
    }
  }

  void _onMultiSort(_RCol col, bool shift) {
    if (widget.onMultiSortChange == null) return;
    final list = List<SummerSortSpec>.from(_effectiveSort);
    final dirs = col.sortDirections;
    final idx = list.indexWhere((s) => s.key == col.key);

    if (!shift) {
      if (idx == 0 && list.length == 1) {
        // cycle the single active column
        final di = dirs.indexOf(list[0].ascending);
        if (di >= 0 && di + 1 < dirs.length) {
          list[0] = SummerSortSpec(key: col.key, ascending: dirs[di + 1]);
        } else {
          list.clear();
        }
      } else {
        list
          ..clear()
          ..addAll(dirs.isEmpty
              ? const <SummerSortSpec>[]
              : <SummerSortSpec>[SummerSortSpec(key: col.key, ascending: dirs.first)]);
      }
    } else {
      if (idx < 0) {
        if (dirs.isNotEmpty) {
          list.add(SummerSortSpec(key: col.key, ascending: dirs.first));
        }
      } else {
        final di = dirs.indexOf(list[idx].ascending);
        if (di >= 0 && di + 1 < dirs.length) {
          list[idx] = SummerSortSpec(key: col.key, ascending: dirs[di + 1]);
        } else {
          list.removeAt(idx);
        }
      }
    }
    widget.onMultiSortChange!(list);
  }

  // --------------------------------------------------------------------------
  // Filtering
  // --------------------------------------------------------------------------

  void _openFilter(_RCol col, BuildContext iconCtx) {
    _closeFilter();
    final rb = iconCtx.findRenderObject();
    if (rb is! RenderBox) return;
    final origin = rb.localToGlobal(Offset.zero);
    final overlay = Overlay.of(context, rootOverlay: true);
    _filterEntry = OverlayEntry(
      builder: (_) => _FilterOverlay(
        origin: origin,
        iconSize: rb.size,
        column: col,
        initialSelected:
            widget.filteredColumnValues?[col.key] ?? const <Object?>[],
        onApply: (values) {
          widget.onFilterChange!(col.key, values);
          _closeFilter();
        },
        onClose: _closeFilter,
      ),
    );
    overlay.insert(_filterEntry!);
  }

  void _closeFilter() {
    _filterEntry?.remove();
    _filterEntry = null;
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
    // Most tables have no expandable rows: avoid the O(n) _flatten allocation
    // and map the list index straight to the row index.
    final exp = widget.expandable;
    final useFlat = exp != null;
    final List<_Flat> flat = useFlat ? _flatten() : const <_Flat>[];
    final int itemCount = useFlat ? flat.length : widget.source.rowCount;
    return GestureDetector(
      onHorizontalDragUpdate: _onHDrag,
      onHorizontalDragEnd: _onHDragEnd,
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: ListView.builder(
          controller: _yController,
          padding: EdgeInsets.zero,
          itemCount: itemCount,
          itemBuilder: (context, i) {
            final bool isExpand;
            final int rowIndex;
            if (useFlat) {
              final item = flat[i];
              isExpand = item.isExpand;
              rowIndex = item.rowIndex;
            } else {
              isExpand = false;
              rowIndex = i;
            }
            if (isExpand) {
              return exp!.builder(context, rowIndex);
            }
            return _SummerBodyRow(
              layout: _layout!,
              rowIndex: rowIndex,
              theme: theme,
              source: widget.source,
              selection: widget.selection,
              expandable: widget.expandable,
              isTree: _isTree,
              xOffset: _xOffset,
              hovered: widget.showHover ? _hoveredRow : null,
              bordered: widget.bordered,
              onTap: widget.onRowTap,
              onLongPress: widget.onRowLongPress,
              onDoubleTap: widget.onRowDoubleTap,
              onSelectionToggle: _toggleSelection,
              onExpandToggle: _toggleExpand,
              onTreeToggle: _onTreeToggle,
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

  void _onTreeToggle(int rowIndex) {
    final s = widget.source;
    if (s is SummerTreeTableSource) s.toggleExpanded(rowIndex);
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
    final controller = _fling = AnimationController.unbounded(vsync: this);
    controller.value = _xOffset.value;
    final sim = FrictionSimulation(0.02, _xOffset.value, velocity);
    controller.addListener(() {
      final v = controller.value.clamp(0.0, maxX);
      if (v != _xOffset.value) _xOffset.value = v;
      if (v <= 0 || v >= maxX) controller.stop();
    });
    controller.animateWith(sim);
  }

  void _stopFling() => _fling?.stop();

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
              color: active ? Colors.white : theme.cellTextStyle.color,
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
  final List<_RCol> left;
  final List<_RCol> right;
  final List<_RCol> middle;
  final List<_HNode> headerRoots;
  final int depth;
  final double leftWidth;
  final double rightWidth;
  final double middleViewport;
  final double middleContent;

  const _Layout(this.columns, this.left, this.right, this.middle,
      this.headerRoots, this.depth, this.leftWidth, this.rightWidth,
      this.middleViewport, this.middleContent);

  double get maxX =>
      middleContent > middleViewport ? middleContent - middleViewport : 0.0;
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
  final List<bool> sortDirections;
  final bool resizable;
  final bool ellipsis;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;
  final Widget label;
  final List<SummerColumnFilter>? filters;
  final bool filterMultiple;
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
    this.sortDirections = const [true, false],
    this.resizable = false,
    this.ellipsis = false,
    this.alignment = Alignment.centerLeft,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    required this.label,
    this.filters,
    this.filterMultiple = true,
    this.userColumnIndex,
    this.isSelection = false,
    this.isExpand = false,
    this.baseWidth = 0,
  });
}

/// A node in the header tree. Leaves reference their resolved [_RCol]; groups
/// aggregate children. `width` is filled by `_resolveNodeWidth` after the leaf
/// widths are known.
class _HNode {
  final String key;
  final Widget label;
  final int level;
  final bool isLeaf;
  final _RCol? leaf;
  final List<_HNode> children;
  double width;

  _HNode.leaf(this.leaf, this.label, this.level, this.key)
      : isLeaf = true,
        children = const <_HNode>[],
        width = 0;

  _HNode.group(this.children, this.label, this.level, this.key)
      : isLeaf = false,
        leaf = null,
        width = 0;
}

class _Flat {
  final bool isExpand;
  final int rowIndex;
  const _Flat(this.isExpand, this.rowIndex);
}

// =============================================================================
// Single translate render box (X-scroll optimization)
// =============================================================================

/// Translates its child horizontally by `-offset.value` (clamped to `maxX`)
/// without rebuilding the child subtree — only a repaint is scheduled when the
/// offset changes. This is what makes horizontal scrolling cheap.
class _XTranslatedBox extends SingleChildRenderObjectWidget {
  final ValueListenable<double> offset;
  final double maxX;

  const _XTranslatedBox({
    required this.offset,
    required this.maxX,
    required super.child,
  });

  @override
  _RenderXTranslatedBox createRenderObject(BuildContext context) =>
      _RenderXTranslatedBox(offset: offset, maxX: maxX);

  @override
  void updateRenderObject(
      BuildContext context, _RenderXTranslatedBox renderObject) {
    renderObject
      ..offset = offset
      ..maxX = maxX;
  }
}

class _RenderXTranslatedBox extends RenderProxyBox {
  _RenderXTranslatedBox({
    required ValueListenable<double> offset,
    required double maxX,
  })  : _offset = offset,
        _maxX = maxX;

  ValueListenable<double> _offset;
  double _maxX;

  set offset(ValueListenable<double> value) {
    if (_offset == value) return;
    _offset.removeListener(_changed);
    _offset = value;
    _offset.addListener(_changed);
    _changed();
  }

  set maxX(double value) {
    if (_maxX == value) return;
    _maxX = value;
    _changed();
  }

  double get _dx =>
      -(_offset.value.clamp(0.0, math.max(0.0, _maxX))).toDouble();

  void _changed() {
    if (attached) markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset.addListener(_changed);
  }

  @override
  void detach() {
    _offset.removeListener(_changed);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      context.paintChild(child!, offset + Offset(_dx, 0));
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: Offset(_dx, 0),
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) =>
          child!.hitTest(result, position: transformed),
    );
  }
}

// =============================================================================
// Filter dropdown overlay
// =============================================================================

class _FilterOverlay extends StatefulWidget {
  final Offset origin;
  final Size iconSize;
  final _RCol column;
  final List<Object?> initialSelected;
  final ValueChanged<List<Object?>> onApply;
  final VoidCallback onClose;

  const _FilterOverlay({
    required this.origin,
    required this.iconSize,
    required this.column,
    required this.initialSelected,
    required this.onApply,
    required this.onClose,
  });

  @override
  State<_FilterOverlay> createState() => _FilterOverlayState();
}

class _FilterOverlayState extends State<_FilterOverlay> {
  late final Set<Object?> _selected = Set<Object?>.from(widget.initialSelected);

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final left =
        widget.origin.dx.clamp(0.0, math.max(0.0, screenW - 208)).toDouble();
    final filters = widget.column.filters ?? const <SummerColumnFilter>[];

    return Stack(
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onClose,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: left,
          top: widget.origin.dy + widget.iconSize.height + 4,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 200,
              constraints: const BoxConstraints(maxHeight: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: <Widget>[
                        for (final f in filters) _item(f),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Row(
                      children: <Widget>[
                        TextButton(
                          onPressed: () => widget.onApply(const <Object?>[]),
                          child: const Text('重置'),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () =>
                              widget.onApply(_selected.toList()),
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(SummerColumnFilter f) {
    final checked = _selected.contains(f.value);
    return InkWell(
      onTap: () => _toggle(f.value),
      child: Row(
        children: <Widget>[
          Checkbox(
            value: checked,
            onChanged: (_) => _toggle(f.value),
          ),
          Expanded(child: Text(f.text)),
        ],
      ),
    );
  }

  void _toggle(Object? value) {
    setState(() {
      if (widget.column.filterMultiple) {
        if (_selected.contains(value)) {
          _selected.remove(value);
        } else {
          _selected.add(value);
        }
      } else {
        _selected
          ..clear()
          ..add(value);
      }
    });
  }
}

// =============================================================================
// Body row
// =============================================================================

class _SummerBodyRow extends StatelessWidget {
  static const double _treeIndent = 24.0;

  final _Layout layout;
  final int rowIndex;
  final SummerDataTableThemeData theme;
  final SummerDataTableSource source;
  final SummerRowSelection? selection;
  final SummerRowExpandable? expandable;
  final bool isTree;
  final ValueListenable<double> xOffset;
  final ValueNotifier<int?>? hovered;
  final bool bordered;
  final ValueChanged<int>? onTap;
  final ValueChanged<int>? onLongPress;
  final ValueChanged<int>? onDoubleTap;
  final void Function(Object? key, bool willSelect)? onSelectionToggle;
  final ValueChanged<int>? onExpandToggle;
  final ValueChanged<int>? onTreeToggle;

  const _SummerBodyRow({
    required this.layout,
    required this.rowIndex,
    required this.theme,
    required this.source,
    required this.selection,
    required this.expandable,
    required this.isTree,
    required this.xOffset,
    required this.hovered,
    required this.bordered,
    required this.onTap,
    required this.onLongPress,
    required this.onDoubleTap,
    required this.onSelectionToggle,
    required this.onExpandToggle,
    required this.onTreeToggle,
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
    final layout = this.layout;
    return SizedBox(
      height: theme.rowHeight,
      child: ClipRect(
        child: OverflowBox(
          minWidth: layout.middleContent,
          maxWidth: layout.middleContent,
          alignment: Alignment.centerLeft,
          child: _XTranslatedBox(
            offset: xOffset,
            maxX: layout.maxX,
            child: SizedBox(
              width: layout.middleContent,
              child: Row(
                children: <Widget>[
                  for (final c in layout.middle) _cell(context, c),
                ],
              ),
            ),
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

      // Tree mode: indent + expand caret on the first user column.
      if (isTree && col.userColumnIndex == 0) {
        final tree = source as SummerTreeTableSource;
        content = Row(
          children: <Widget>[
            SizedBox(width: tree.rowDepth(rowIndex) * _treeIndent),
            _treeCaret(tree),
            Expanded(child: content),
          ],
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

  Widget _treeCaret(SummerTreeTableSource tree) {
    final hasChildren = tree.rowHasChildren(rowIndex);
    if (!hasChildren) return const SizedBox(width: _treeIndent);
    final expanded = tree.rowExpanded(rowIndex);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTreeToggle == null ? null : () => onTreeToggle!(rowIndex),
      child: SizedBox(
        width: _treeIndent,
        child: Center(
          child: Transform.rotate(
            angle: expanded ? math.pi / 2 : 0,
            child: theme.expandIcon,
          ),
        ),
      ),
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
