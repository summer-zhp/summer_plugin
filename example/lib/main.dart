import 'package:flutter/material.dart';
import 'package:summer_plugin/summer_plugin.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: TableDemoPage());
  }
}

class TableDemoPage extends StatefulWidget {
  const TableDemoPage({super.key});

  @override
  State<TableDemoPage> createState() => _TableDemoPageState();
}

class _TableDemoPageState extends State<TableDemoPage> {
  late final _EmployeeSource _source;

  final int _pageSize = 10;
  int _currentPage = 0;

  // Controlled sort.
  String? _sortKey;
  bool _sortAscending = true;

  // Controlled selection + expansion.
  final Set<Object?> _selected = {};
  final Set<Object?> _expanded = {};

  @override
  void initState() {
    super.initState();
    final all = List<_Employee>.generate(
      55,
      (i) => _Employee(
        id: i + 1,
        name: '员工 ${i + 1} · 高级前端工程师（React / Flutter）',
        department: const ['技术部', '产品部', '设计部', '市场部'][i % 4],
        role: const ['工程师', '经理', '总监', '实习生'][i % 4],
        salary: (5000 + i * 317).toDouble(),
        joinDate: '2024-${(i % 12 + 1).toString().padLeft(2, '0')}-01',
      ),
    );
    _source = _EmployeeSource(all);
  }

  List<_Employee> get _sorted {
    final list = List<_Employee>.of(_source.all);
    switch (_sortKey) {
      case 'id':
        list.sort((a, b) =>
            _sortAscending ? a.id.compareTo(b.id) : b.id.compareTo(a.id));
        break;
      case 'name':
        list.sort((a, b) => _sortAscending
            ? a.name.compareTo(b.name)
            : b.name.compareTo(a.name));
        break;
      case 'dept':
        list.sort((a, b) => _sortAscending
            ? a.department.compareTo(b.department)
            : b.department.compareTo(a.department));
        break;
      case 'salary':
        list.sort((a, b) => _sortAscending
            ? a.salary.compareTo(b.salary)
            : b.salary.compareTo(a.salary));
        break;
    }
    return list;
  }

  List<_Employee> get _page {
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _source.all.length);
    return _sorted.sublist(start, end);
  }

  int get _totalPages => (_source.all.length / _pageSize).ceil();

  void _onSort(String? key, bool ascending) {
    setState(() {
      _sortKey = key;
      _sortAscending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Push the current page into the source and notify.
    _source.page = _page;
    final selectedCount = _selected.length;

    return Scaffold(
      appBar: AppBar(title: const Text('SummerDataTable Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('已选择 $selectedCount 项', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Expanded(
              child: SummerDataTable(
                height: 520,
                source: _source,
                bordered: true,
                showHover: true,
                sortColumnKey: _sortKey,
                sortAscending: _sortAscending,
                onSortChange: _onSort,
                onRowTap: (row) => debugPrint('tap row $row'),
                selection: SummerRowSelection(
                  type: SummerSelectionType.checkbox,
                  selectedKeys: _selected,
                  onChanged: (next) => setState(() => _selected
                    ..clear()
                    ..addAll(next)),
                ),
                expandable: SummerRowExpandable(
                  expandedKeys: _expanded,
                  onChanged: (next) => setState(() => _expanded
                    ..clear()
                    ..addAll(next)),
                  builder: (context, row) {
                    final e = _page[row];
                    return Container(
                      color: const Color(0xFFFAFAFA),
                      padding: const EdgeInsets.all(16),
                      child: Text('展开详情：${e.name} · ${e.department} · '
                          '入职 ${e.joinDate} · 薪资 ¥${e.salary.toStringAsFixed(0)}'),
                    );
                  },
                ),
                columns: const [
                  SummerDataColumn(
                    key: 'id',
                    label: Text('ID'),
                    width: 60,
                    sortable: true,
                    pin: SummerColumnPin.left,
                    alignment: Alignment.center,
                  ),
                  SummerDataColumn(
                    key: 'name',
                    label: Text('姓名'),
                    width: 200,
                    sortable: true,
                    resizable: true,
                    ellipsis: true,
                  ),
                  SummerDataColumn(
                    key: 'dept',
                    label: Text('部门'),
                    width: 100,
                    sortable: true,
                    resizable: true,
                  ),
                  SummerDataColumn(
                    key: 'role',
                    label: Text('职位'),
                    flex: 1,
                    ellipsis: true,
                  ),
                  SummerDataColumn(
                    key: 'salary',
                    label: Text('薪资'),
                    width: 110,
                    sortable: true,
                    resizable: true,
                    alignment: Alignment.centerRight,
                  ),
                  SummerDataColumn(
                    key: 'join',
                    label: Text('入职日期'),
                    width: 120,
                  ),
                  SummerDataColumn(
                    key: 'action',
                    label: Text('操作'),
                    width: 90,
                    pin: SummerColumnPin.right,
                    alignment: Alignment.center,
                  ),
                ],
                currentPage: _currentPage,
                totalPages: _totalPages,
                onNextPage: () => setState(() => _currentPage++),
                onPreviousPage: () => setState(() => _currentPage--),
                onPageTap: (p) => setState(() => _currentPage = p),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Source
// -----------------------------------------------------------------------------

class _EmployeeSource extends SummerDataTableSource {
  final List<_Employee> all;
  List<_Employee> page = const [];

  _EmployeeSource(this.all);

  @override
  int get rowCount => page.length;

  @override
  Object? rowKey(int rowIndex) => page[rowIndex].id;

  @override
  Widget buildCell(BuildContext context, int row, int col) {
    final e = page[row];
    switch (col) {
      case 0:
        return Text('${e.id}');
      case 1:
        return Text(e.name);
      case 2:
        return Text(e.department);
      case 3:
        return Text(e.role);
      case 4:
        return Text('¥${e.salary.toStringAsFixed(0)}');
      case 5:
        return Text(e.joinDate);
      case 6:
        return TextButton(
          onPressed: () {},
          child: const Text('编辑', style: TextStyle(fontSize: 13)),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// -----------------------------------------------------------------------------
// Model
// -----------------------------------------------------------------------------

class _Employee {
  final int id;
  final String name;
  final String department;
  final String role;
  final double salary;
  final String joinDate;

  const _Employee({
    required this.id,
    required this.name,
    required this.department,
    required this.role,
    required this.salary,
    required this.joinDate,
  });
}
