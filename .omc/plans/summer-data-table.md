# Summer DataTable Plugin - Implementation Plan

## Context

Build a custom DataTable widget as a Flutter plugin (`summer_plugin`). The existing plugin scaffold is a vanilla Flutter plugin template with no widget logic. The goal is to create a high-performance, customizable data table with:

- Custom `RenderObject` layout (not relying on Flutter's built-in `DataTable` widget)
- Each cell is a full Flutter `Widget` (not just text)
- Both vertical and horizontal scrolling with auto-adjusting column widths
- Fixed header row and optional fixed (pinned) left/right columns
- Sorting, pagination, loading/empty states

## Architecture Overview

```
User Code
    |
    v
SummerDataTable (StatefulWidget)
    |-- SummerDataTableTheme (InheritedWidget)
    |-- Scrollable (single, 2D via combined offset)
    |       |
    |       v
    |   _SummerDataTableRenderObjectWidget (SingleChildRenderObjectWidget)
    |       |
    |       v
    |   SummerDataTableRenderBox (Custom RenderBox)
    |       |-- Measures all cells (2-pass layout)
    |       |-- Positions children in paint()
    |       |-- Handles hit testing for taps on cells/headers
    |       |-- Clipping for scroll, fixed header, pinned columns
    |
    v
SummerDataTableDelegate (user-provided)
    |-- buildColumnHeader(int index) -> Widget
    |-- buildCell(int rowIndex, int colIndex) -> Widget
    |-- onSort(columnIndex, ascending)
    |-- onTapRow(rowIndex)
```

**Scrolling Strategy**: A single `Scrollable` with combined offset `(scrollX, scrollY)`. The `RenderBox` interprets this offset to determine content position. The header row and pinned columns are painted at fixed positions (not translated by scroll offset), while body cells are translated by `(-scrollX, -scrollY)`.

## File Structure

```
lib/
  summer_plugin.dart              (barrel export)
  summer_plugin_method_channel.dart
  summer_plugin_platform_interface.dart
  table/
    summer_data_table.dart        (main widget)
    summer_data_column.dart       (column definition model)
    summer_data_cell.dart         (cell definition model)
    summer_data_table_delegate.dart  (abstract delegate)
    summer_data_table_theme.dart  (theme data + InheritedWidget)
    summer_data_table_render_object.dart  (custom RenderBox)
```

## Detailed Class Designs

### 1. `SummerDataColumn` (`table/summer_data_column.dart`)

```dart
class SummerDataColumn {
  final Widget label;             // Header widget (typically Text)
  final double? fixedWidth;       // If set, column uses this width (no auto)
  final double? minWidth;         // Min width for auto-width columns
  final double? maxWidth;         // Max width for auto-width columns
  final bool sortable;            // Show sort indicator, enable tap-to-sort
  final AlignmentGeometry cellAlignment;  // Default alignment for cells
  final bool pinned;              // Pin to left (do not scroll horizontally)
  final bool pinnedRight;         // Pin to right (do not scroll horizontally)
  final double spacing;           // Horizontal spacing/padding in this column

  const SummerDataColumn({
    required this.label,
    this.fixedWidth,
    this.minWidth = 50.0,
    this.maxWidth = 300.0,
    this.sortable = false,
    this.cellAlignment = Alignment.centerLeft,
    this.pinned = false,
    this.pinnedRight = false,
    this.spacing = 0.0,
  });

  bool get hasFixedWidth => fixedWidth != null;
}
```

### 2. `SummerDataCell` (`table/summer_data_cell.dart`)

```dart
class SummerDataCell {
  final Widget child;             // Cell content widget
  final TextStyle? textStyle;     // Default text style (applied if child is Text)
  final AlignmentGeometry? alignment;
  final double? height;           // Override row height for this cell
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const SummerDataCell({
    required this.child,
    this.textStyle,
    this.alignment,
    this.height,
    this.padding,
    this.backgroundColor,
  });

  /// Factory for simple text cells
  factory SummerDataCell.text(
    String text, {
    TextStyle? style,
    AlignmentGeometry? alignment,
  }) {
    return SummerDataCell(
      child: Text(text, style: style, overflow: TextOverflow.ellipsis),
      alignment: alignment,
    );
  }
}
```

### 3. `SummerDataTableDelegate` (`table/summer_data_table_delegate.dart`)

```dart
abstract class SummerDataTableDelegate {
  /// Total number of data rows
  int get rowCount;

  /// Total number of columns
  int get columnCount;

  /// Build the header widget for column [index]
  Widget buildColumnHeader(BuildContext context, int index);

  /// Build the cell widget for row [rowIndex], column [colIndex]
  Widget buildCell(BuildContext context, int rowIndex, int colIndex);

  /// Called when user taps a column header (for sorting)
  void onSort(int columnIndex, bool ascending) {}

  /// Called when user taps a row
  void onTapRow(int rowIndex) {}

  /// Whether to show a selection checkbox column
  bool get showSelectionCheckbox => false;

  /// Build the selection checkbox widget for row [rowIndex]
  Widget? buildSelectionCheckbox(BuildContext context, int rowIndex) => null;
}
```

### 4. `SummerDataTableTheme` (`table/summer_data_table_theme.dart`)

```dart
class SummerDataTableThemeData {
  final Color headerBackgroundColor;
  final TextStyle headerTextStyle;
  final Color cellBackgroundColor;
  final Color altRowBackgroundColor;  // Zebra striping
  final TextStyle cellTextStyle;
  final double rowHeight;
  final double headerHeight;
  final Color borderColor;
  final double borderWidth;
  final BorderRadiusGeometry? headerBorderRadius;
  final Widget? sortAscendingIcon;
  final Widget? sortDescendingIcon;
  final Widget? loadingWidget;
  final Widget? emptyWidget;

  const SummerDataTableThemeData({...});

  static SummerDataTableThemeData defaultTheme();
}

class SummerDataTableTheme extends InheritedWidget {
  final SummerDataTableThemeData data;

  const SummerDataTableTheme({
    Key? key,
    required this.data,
    required Widget child,
  }) : super(key: key, child: child);

  static SummerDataTableThemeData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SummerDataTableTheme>()?.data
        ?? SummerDataTableThemeData.defaultTheme();
  }
}
```

### 5. `SummerDataTable` (`table/summer_data_table.dart`)

```dart
class SummerDataTable extends StatefulWidget {
  final List<SummerDataColumn> columns;
  final SummerDataTableDelegate delegate;
  final SummerDataTableThemeData? theme;
  final ScrollController? scrollController;
  final double? height;           // Fixed height (enables vertical scroll)
  final double? width;            // Fixed width (enables horizontal scroll)
  final bool isLoading;
  final bool isEmpty;
  final VoidCallback? onLoadMore; // Trigger pagination
  final int? currentPage;
  final int? totalPages;

  const SummerDataTable({
    Key? key,
    required this.columns,
    required this.delegate,
    this.theme,
    this.scrollController,
    this.height,
    this.width,
    this.isLoading = false,
    this.isEmpty = false,
    this.onLoadMore,
    this.currentPage,
    this.totalPages,
  }) : super(key: key);

  @override
  State<SummerDataTable> createState() => _SummerDataTableState();
}
```

**State responsibilities:**
- Create/manage `ScrollController` (internal or user-provided)
- Handle sort state (`_sortColumnIndex`, `_sortAscending`)
- Trigger `setState` on sort changes, delegation to delegate
- Pass scroll controller and children to `RenderObjectWidget`

### 6. `SummerDataTableRenderBox` (`table/summer_data_table_render_object.dart`)

This is the core of the implementation. Extends `RenderBox` and implements `ContainerRenderObjectMixin` and `RenderBoxContainerDefaultsMixin` for managing multiple child render objects.

**Key Properties:**
```dart
class SummerDataTableRenderBox extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, ParentData>,
         RenderBoxContainerDefaultsMixin<RenderBox, ParentData> {

  // Configuration
  List<SummerDataColumn> _columns;
  double _rowHeight;
  double _headerHeight;
  bool _showHeader;
  Offset _scrollOffset;   // Combined (scrollX, scrollY)

  // Computed layout data (set during performLayout)
  late List<double> _columnOffsets;   // X position of each column
  late List<double> _columnWidths;    // Width of each column
  late double _totalTableWidth;       // Total content width
  late double _totalTableHeight;      // Total content height
  late int _headerChildCount;         // Number of header children
  late int _bodyChildCount;           // Number of body children

  // ParentData structure
  // Each child's ParentData stores:
  //   - int rowIndex
  //   - int colIndex
  //   - bool isHeader
  //   - Rect? rect (computed position during layout)
}
```

**Layout Algorithm (`performLayout`):**

```
PHASE 1: Measure intrinsic widths
  For each column j:
    if columns[j].fixedWidth != null:
      widths[j] = columns[j].fixedWidth
    else:
      widths[j] = columns[j].minWidth
      For each row i:
        Ask child (row i, col j) for intrinsic width
        widths[j] = max(widths[j], intrinsicWidth)
      widths[j] = min(widths[j], columns[j].maxWidth)

PHASE 2: Calculate total width
  totalWidth = sum(widths[j] for all j)

PHASE 3: Handle overflow (if totalWidth > availableWidth)
  If totalWidth > maxWidth constraint:
    Scale down non-fixed columns proportionally
    Ensure no column goes below minWidth

PHASE 4: Calculate column X positions
  x = 0
  For each column j:
    columnOffsets[j] = x
    x += widths[j]
  totalTableWidth = x

PHASE 5: Position children
  // Header children: at y = 0, each column j at x = columnOffsets[j]
  // Body children: at y = headerHeight + rowIndex * rowHeight
  // Each child gets its position stored in ParentData.rect

PHASE 6: Size the RenderBox
  size = Size(
    min(totalTableWidth, constraints.maxWidth),
    headerHeight + rowCount * rowHeight
  )
```

**Paint Algorithm (`paint`):**

```
1. Save canvas state
2. Clip to size (prevent overflow)

3. PAINT BODY CELLS (scrollable region):
   canvas.save()
   canvas.clipRect(Rect.fromLTWH(0, headerHeight, width, height - headerHeight))
   canvas.translate(-scrollOffset.dx, -scrollOffset.dy)
   For each body child:
     paint child at its ParentData.rect position
   canvas.restore()

4. PAINT HEADER (fixed, not translated):
   canvas.save()
   canvas.clipRect(Rect.fromLTWH(0, 0, width, headerHeight))
   For each header child:
     paint child at its ParentData.rect position (x = columnOffsets[j], y = 0)
   canvas.restore()

5. PAINT PINNED LEFT COLUMNS (fixed, not translated horizontally):
   canvas.save()
   canvas.clipRect(Rect.fromLTWH(0, 0, pinnedLeftWidth, height))
   For each pinned-left body child:
     paint child at its rect position (x unchanged, y translated by -scrollOffset.dy)
   canvas.restore()

6. PAINT PINNED RIGHT COLUMNS (fixed, not translated horizontally):
   canvas.save()
   canvas.clipRect(Rect.fromLTWH(width - pinnedRightWidth, 0, pinnedRightWidth, height))
   For each pinned-right body child:
     paint child at its rect position (x unchanged, y translated by -scrollOffset.dy)
   canvas.restore()

7. Restore canvas state
```

**Hit Testing (`hitTestChildren`):**
- Iterate children in reverse paint order (topmost first)
- Check if hit point falls within child's `ParentData.rect`
- Adjust hit point by scroll offset for body cells
- Return first matching child

**Scroll Offset Handling:**
- `scrollOffset` setter triggers `markPaint()` and optionally `markLayout()` (only if scroll affects column widths, which it does not in this design)
- The `Scrollable` widget drives the offset via its `ScrollPosition`

## Scrolling Integration

The `SummerDataTable` widget wraps the render object widget in a `Scrollable`:

```dart
Widget build(BuildContext context) {
  return SizedBox(
    height: widget.height,
    width: widget.width,
    child: Scrollable(
      controller: _scrollController,
      axisDirection: AxisDirection.down,
      physics: const ClampingScrollPhysics(),
      viewportBuilder: (context, offset) {
        return _SummerDataTableViewport(
          offset: offset,
          columns: widget.columns,
          delegate: widget.delegate,
          // ...
        );
      },
    );
  );
}
```

The `_SummerDataTableViewport` is a `RenderObjectElement` that:
1. Creates `SummerDataTableRenderBox`
2. Passes scroll offset from the `ViewportOffset`
3. Updates render object when offset changes

**Combined X+Y scroll**: The `ScrollPosition` tracks a single scalar value. The render object interprets it as combined offset. We use a custom `ScrollPhysics` or simply multiply: `scrollX = position.pixels % totalWidth`, `scrollY = position.pixels ~/ totalWidth * rowHeight`. Alternatively, use **two nested Scrollables** (outer horizontal, inner vertical) which is simpler but has nested scroll caveats.

**Recommended approach**: Two separate `ScrollController` instances:
- Outer: horizontal `SingleChildScrollView` wrapping the entire table
- Inner: vertical `ListView`-like scroll for the body

This avoids complex combined-offset math and leverages Flutter's built-in scroll physics. The render object receives both offsets separately.

## Implementation Order

### Phase 1: Data Models + Delegate (files: 3)
1. Create `table/summer_data_column.dart`
2. Create `table/summer_data_cell.dart`
3. Create `table/summer_data_table_delegate.dart`

**Acceptance criteria:**
- All three files compile without errors
- `SummerDataColumn` has all specified fields
- `SummerDataCell` has `text` factory constructor
- `SummerDataTableDelegate` defines `rowCount`, `columnCount`, `buildColumnHeader`, `buildCell`

### Phase 2: Theme (file: 1)
4. Create `table/summer_data_table_theme.dart`

**Acceptance criteria:**
- `SummerDataTableThemeData` has all styling fields with sensible defaults
- `SummerDataTableTheme` is an `InheritedWidget` with `of(context)` method
- `defaultTheme()` returns a complete, visually reasonable theme

### Phase 3: Custom RenderObject (file: 1, most complex)
5. Create `table/summer_data_table_render_object.dart`

**Acceptance criteria:**
- `SummerDataTableRenderBox` extends `RenderBox` with child management mixins
- `performLayout()` implements the 6-phase column width algorithm
- `paint()` correctly clips and positions header, body, and pinned columns
- `hitTestChildren()` returns correct child for tap coordinates
- Scroll offset correctly shifts body content while header remains fixed
- Auto-width columns respect `minWidth` and `maxWidth` constraints
- Fixed-width columns are not adjusted during auto-width calculation

### Phase 4: Main Widget + Integration (files: 2)
6. Create `table/summer_data_table.dart`
7. Update `lib/summer_plugin.dart` barrel export

**Acceptance criteria:**
- `SummerDataTable` is a `StatefulWidget` that builds the full widget tree
- Horizontal scroll works (columns overflow the available width)
- Vertical scroll works (rows overflow the available height)
- Header row remains fixed at top during vertical scroll
- Pinned columns remain fixed during horizontal scroll
- Sorting triggers delegate callback and updates visual indicator
- Loading state shows `loadingWidget`
- Empty state shows `emptyWidget`
- Barrel export includes all table classes

### Phase 5: Example App + Testing
8. Update `example/lib/main.dart` with a demo using `SummerDataTable`
9. Write widget tests in `test/`

**Acceptance criteria:**
- Example app displays a table with 10+ columns and 50+ rows
- Horizontal scrolling is visible when columns overflow
- Vertical scrolling is visible when rows overflow
- Tapping a sortable column header toggles sort indicator
- Auto-width columns adjust to content
- Widget tests verify layout, scroll, and sort behavior

## Success Criteria

1. The plugin compiles with `flutter analyze` (no errors)
2. Example app renders a scrollable table with auto-width columns
3. Header stays fixed during vertical scroll
4. Pinned columns stay fixed during horizontal scroll
5. Sorting works end-to-end (tap header -> delegate callback -> visual update)
6. Loading and empty states display correctly
7. Each cell is a full Flutter Widget (can contain buttons, images, etc.)
8. No performance issues with 100+ rows and 10+ columns (custom RenderObject avoids widget rebuild overhead)
