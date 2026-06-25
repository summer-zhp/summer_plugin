import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summer_plugin/summer_plugin.dart';

// A flat source for sort/filter tests: each row is a [col0, col1] pair.
class _RowsSource extends SummerDataTableSource {
  final List<List<String>> rows;
  _RowsSource(this.rows);

  @override
  int get rowCount => rows.length;

  @override
  Widget buildCell(BuildContext context, int row, int col) =>
      Text(rows[row][col]);
}

// ---------------------------------------------------------------------------
// Multi-column sort
// ---------------------------------------------------------------------------

class _MultiSortPage extends StatefulWidget {
  final void Function(List<SummerSortSpec> columns)? onCalled;
  const _MultiSortPage({this.onCalled});

  @override
  State<_MultiSortPage> createState() => _MultiSortPageState();
}

class _MultiSortPageState extends State<_MultiSortPage> {
  List<SummerSortSpec> _sort = const <SummerSortSpec>[];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: SummerDataTable(
            source: _RowsSource(const [
              ['a1', 'b1'],
            ]),
            width: 400,
            height: 300,
            sortColumns: _sort,
            onMultiSortChange: (s) {
              setState(() => _sort = s);
              widget.onCalled?.call(s);
            },
            columns: const [
              SummerDataColumn(key: 'a', label: Text('A'), width: 150, sortable: true),
              SummerDataColumn(key: 'b', label: Text('B'), width: 150, sortable: true),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('plain click starts a single multi-sort', (tester) async {
    List<SummerSortSpec>? result;
    await tester.pumpWidget(_MultiSortPage(onCalled: (s) => result = s));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.length, 1);
    expect(result!.first.key, 'a');
    expect(result!.first.ascending, isTrue);
  });

  testWidgets('shift+click stacks a second sort column', (tester) async {
    List<SummerSortSpec>? result;
    await tester.pumpWidget(_MultiSortPage(onCalled: (s) => result = s));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(result, isNotNull);
    expect(result!.length, 2);
    expect(result!.map((s) => s.key), ['a', 'b']);
  });

  // -------------------------------------------------------------------------
  // Filter dropdown
  // -------------------------------------------------------------------------

  testWidgets('filter dropdown applies the selected value', (tester) async {
    final received = <String, List<Object?>>{};
    late StateSetter setStateOf;
    Map<String, List<Object?>> filtered = const <String, List<Object?>>{};

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setStateOf = setState;
          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 300,
                child: SummerDataTable(
                  source: _RowsSource(const [
                    ['n1', 's1'],
                  ]),
                  width: 400,
                  height: 300,
                  filteredColumnValues: filtered,
                  onFilterChange: (key, values) {
                    setState(() {
                      filtered = Map<String, List<Object?>>.from(filtered)
                        ..[key] = values;
                    });
                    received[key] = values;
                  },
                  columns: const [
                    SummerDataColumn(key: 'name', label: Text('Name'), width: 150),
                    SummerDataColumn(
                      key: 'status',
                      label: Text('Status'),
                      width: 150,
                      filters: [
                        SummerColumnFilter(value: 'a', text: 'Active'),
                        SummerColumnFilter(value: 'i', text: 'Inactive'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    // ignore: unused_local_variable
    setStateOf;
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    await tester.tap(find.text('Active'));
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(received['status'], isNotNull);
    expect(received['status']!.length, 1);
    expect(received['status']!.first, 'a');
  });

  // -------------------------------------------------------------------------
  // Tree data
  // ---------------------------------------------------------------------------

  testWidgets('tree caret expands and collapses children', (tester) async {
    final source = _TreeSource(_TNode('root', [
      _TNode('c1', const []),
      _TNode('c2', const []),
    ]));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: SummerDataTable(
            source: source,
            width: 400,
            height: 300,
            columns: const [
              SummerDataColumn(key: 'name', label: Text('Name'), width: 200),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(source.rowCount, 1); // only root visible

    await tester.tap(find.byIcon(Icons.keyboard_arrow_right).first);
    await tester.pumpAndSettle();

    expect(source.rowCount, 3); // root + two children
    expect(source.rowDepth(1), 1);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_right).first);
    await tester.pumpAndSettle();

    expect(source.rowCount, 1); // collapsed again
  });
}

// Tree test helpers ------------------------------------------------------------

class _TNode {
  final String key;
  final List<_TNode> children;
  const _TNode(this.key, this.children);
}

class _Visible {
  final _TNode node;
  final int depth;
  const _Visible(this.node, this.depth);
}

class _TreeSource extends SummerTreeTableSource {
  final _TNode root;
  final Set<String> expanded = <String>{};
  List<_Visible> _visible = const <_Visible>[];

  _TreeSource(this.root) {
    _rebuild();
  }

  void _rebuild() {
    final out = <_Visible>[];
    void walk(_TNode n, int depth) {
      out.add(_Visible(n, depth));
      if (expanded.contains(n.key)) {
        for (final c in n.children) {
          walk(c, depth + 1);
        }
      }
    }

    walk(root, 0);
    _visible = out;
  }

  @override
  int get rowCount => _visible.length;

  @override
  Object? rowKey(int rowIndex) => _visible[rowIndex].node.key;

  @override
  Widget buildCell(BuildContext context, int row, int col) =>
      Text(_visible[row].node.key);

  @override
  int rowDepth(int rowIndex) => _visible[rowIndex].depth;

  @override
  bool rowHasChildren(int rowIndex) =>
      _visible[rowIndex].node.children.isNotEmpty;

  @override
  bool rowExpanded(int rowIndex) =>
      expanded.contains(_visible[rowIndex].node.key);

  @override
  void toggleExpanded(int rowIndex) {
    final key = _visible[rowIndex].node.key;
    if (expanded.contains(key)) {
      expanded.remove(key);
    } else {
      expanded.add(key);
    }
    _rebuild();
    notifyListeners();
  }
}
