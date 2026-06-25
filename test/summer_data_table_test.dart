import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summer_plugin/summer_plugin.dart';

class _Row {
  final int id;
  final String name;
  final int salary;
  const _Row(this.id, this.name, this.salary);
}

class _TestSource extends SummerDataTableSource {
  final List<_Row> rows;
  _TestSource(this.rows);

  @override
  int get rowCount => rows.length;

  @override
  Object? rowKey(int rowIndex) => rows[rowIndex].id;

  @override
  Widget buildCell(BuildContext context, int row, int col) {
    final r = rows[row];
    switch (col) {
      case 0:
        return Text('${r.id}');
      case 1:
        return Text(r.name);
      case 2:
        return Text('¥${r.salary}');
      default:
        return const SizedBox.shrink();
    }
  }
}

Widget _harness({
  required SummerDataTableSource source,
  required VoidCallback onSortId,
  required ValueChanged<int> onRowTap,
  required ValueChanged<Set<Object?>> onSelectionChanged,
  required ValueChanged<Set<Object?>> onExpandChanged,
  required Set<Object?> selected,
  required Set<Object?> expanded,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 300,
        child: SummerDataTable(
          source: source,
          width: 400,
          height: 300,
          sortColumnKey: 'id',
          sortAscending: true,
          onSortChange: (key, asc) => onSortId(),
          onRowTap: onRowTap,
          selection: SummerRowSelection(
            selectedKeys: selected,
            onChanged: onSelectionChanged,
          ),
          expandable: SummerRowExpandable(
            expandedKeys: expanded,
            onChanged: onExpandChanged,
            builder: (context, row) => const Text('expanded panel'),
          ),
          columns: const [
            SummerDataColumn(
              key: 'id',
              label: Text('ID'),
              width: 80,
              sortable: true,
              pin: SummerColumnPin.left,
            ),
            SummerDataColumn(
              key: 'name',
              label: Text('Name'),
              width: 200,
              ellipsis: true,
            ),
            SummerDataColumn(
              key: 'salary',
              label: Text('Salary'),
              width: 200,
            ),
            SummerDataColumn(
              key: 'action',
              label: Text('Action'),
              width: 80,
              pin: SummerColumnPin.right,
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders header and body cells without throwing',
      (tester) async {
    final source =
        _TestSource(const [_Row(1, 'Alice', 1000), _Row(2, 'Bob', 2000)]);

    await tester.pumpWidget(_harness(
      source: source,
      onSortId: () {},
      onRowTap: (_) {},
      onSelectionChanged: (_) {},
      onExpandChanged: (_) {},
      selected: const {},
      expanded: const {},
    ));
    await tester.pumpAndSettle();

    expect(find.text('ID'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('tapping a sortable header reports a sort change',
      (tester) async {
    final source = _TestSource(const [_Row(1, 'Alice', 1000)]);
    var sorted = false;

    await tester.pumpWidget(_harness(
      source: source,
      onSortId: () => sorted = true,
      onRowTap: (_) {},
      onSelectionChanged: (_) {},
      onExpandChanged: (_) {},
      selected: const {},
      expanded: const {},
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ID'));
    await tester.pumpAndSettle();
    expect(sorted, isTrue);
  });

  testWidgets('tapping a row fires onRowTap', (tester) async {
    final source = _TestSource(const [_Row(1, 'Alice', 1000)]);
    int? tapped;

    await tester.pumpWidget(_harness(
      source: source,
      onSortId: () {},
      onRowTap: (i) => tapped = i,
      onSelectionChanged: (_) {},
      onExpandChanged: (_) {},
      selected: const {},
      expanded: const {},
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    expect(tapped, 0);
  });

  testWidgets('expand toggle adds the row key', (tester) async {
    final source = _TestSource(const [_Row(1, 'Alice', 1000)]);
    Set<Object?>? expanded;

    await tester.pumpWidget(_harness(
      source: source,
      onSortId: () {},
      onRowTap: (_) {},
      onSelectionChanged: (_) {},
      onExpandChanged: (next) => expanded = next,
      selected: const {},
      expanded: const {},
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.keyboard_arrow_right).first);
    await tester.pumpAndSettle();
    expect(expanded, isNotNull);
    expect(expanded!.length, 1);
  });

  testWidgets('checkbox selection toggles a row key', (tester) async {
    final source = _TestSource(const [_Row(1, 'Alice', 1000)]);
    Set<Object?>? selected;

    await tester.pumpWidget(_harness(
      source: source,
      onSortId: () {},
      onRowTap: (_) {},
      onSelectionChanged: (next) => selected = next,
      onExpandChanged: (_) {},
      selected: const {},
      expanded: const {},
    ));
    await tester.pumpAndSettle();

    // First Checkbox is the select-all header; the second is row 0.
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(selected, isNotNull);
    expect(selected!.length, 1);
  });

  testWidgets('horizontal drag scrolls the body without throwing',
      (tester) async {
    final source = _TestSource(const [_Row(1, 'Alice', 1000)]);

    await tester.pumpWidget(_harness(
      source: source,
      onSortId: () {},
      onRowTap: (_) {},
      onSelectionChanged: (_) {},
      onExpandChanged: (_) {},
      selected: const {},
      expanded: const {},
    ));
    await tester.pumpAndSettle();

    // middle content (400) > viewport (240) so maxX = 160; drag must not throw.
    await tester.timedDrag(
      find.byType(ListView),
      const Offset(-80, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
  });
}
