import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:summer_plugin/summer_plugin.dart';

/// Source keyed by leaf index — exactly what `buildCell` receives for grouped
/// columns (the index walks the flattened leaves in DFS order).
class _LeafSource extends SummerDataTableSource {
  final List<List<String>> rows;
  _LeafSource(this.rows);

  @override
  int get rowCount => rows.length;

  @override
  Widget buildCell(BuildContext context, int row, int leaf) =>
      Text(rows[row][leaf]);
}

const _groupedColumns = <SummerDataColumn>[
  SummerDataColumn(
    key: 'id',
    label: Text('ID'),
    width: 60,
    pin: SummerColumnPin.left,
  ),
  SummerDataColumn(
    key: 'contact',
    label: Text('联系方式'),
    children: [
      SummerDataColumn(key: 'phone', label: Text('电话'), width: 150),
      SummerDataColumn(key: 'email', label: Text('邮箱'), width: 170),
    ],
  ),
  SummerDataColumn(
    key: 'action',
    label: Text('操作'),
    width: 80,
    pin: SummerColumnPin.right,
  ),
];

Widget _harness({required SummerDataTableSource source}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 300,
          child: SummerDataTable(
            source: source,
            width: 600,
            height: 300,
            columns: _groupedColumns,
          ),
        ),
      ),
    );

void main() {
  testWidgets('renders group header plus its leaf headers', (tester) async {
    await tester.pumpWidget(_harness(
      source: _LeafSource(const [
        ['1', '13800000000', 'a@x.com', '编辑'],
      ]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('联系方式'), findsOneWidget); // group
    expect(find.text('电话'), findsOneWidget); // leaf under group
    expect(find.text('邮箱'), findsOneWidget); // leaf under group
    expect(find.text('ID'), findsOneWidget); // pinned-left leaf
    expect(find.text('操作'), findsOneWidget); // pinned-right leaf
  });

  testWidgets('body cells are built per leaf in DFS order', (tester) async {
    await tester.pumpWidget(_harness(
      source: _LeafSource(const [
        ['7', '13900000000', 'b@y.com', '删除'],
      ]),
    ));
    await tester.pumpAndSettle();

    // leaf order: id, phone, email, action
    expect(find.text('7'), findsOneWidget);
    expect(find.text('13900000000'), findsOneWidget);
    expect(find.text('b@y.com'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('group header sits in the row above its leaves', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 300,
          child: SummerDataTable(
            source: _LeafSource(const [
              ['1', 'p', 'e'],
            ]),
            width: 600,
            height: 300,
            columns: const [
              SummerDataColumn(key: 'id', label: Text('ID'), width: 60),
              SummerDataColumn(key: 'g', label: Text('G'), children: [
                SummerDataColumn(key: 'a', label: Text('A'), width: 120),
                SummerDataColumn(key: 'b', label: Text('B'), width: 120),
              ]),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // depth = 2: the group 'G' is on row 0, its leaves 'A'/'B' on row 1.
    final groupDy = tester.getCenter(find.text('G')).dy;
    final leafDy = tester.getCenter(find.text('A')).dy;
    expect(groupDy, lessThan(leafDy));
  });

  testWidgets('sorting still works on a leaf under a group', (tester) async {
    String? sortedKey;
    bool? ascending;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 300,
          child: SummerDataTable(
            source: _LeafSource(const [
              ['1', 'p', 'e'],
            ]),
            width: 600,
            height: 300,
            onSortChange: (key, asc) {
              sortedKey = key;
              ascending = asc;
            },
            columns: const [
              SummerDataColumn(key: 'id', label: Text('ID'), width: 60),
              SummerDataColumn(key: 'g', label: Text('G'), children: [
                SummerDataColumn(
                    key: 'a', label: Text('A'), width: 120, sortable: true),
                SummerDataColumn(key: 'b', label: Text('B'), width: 120),
              ]),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();

    expect(sortedKey, 'a');
    expect(ascending, isTrue);
  });
}
