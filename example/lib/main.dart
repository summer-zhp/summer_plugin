import 'package:flutter/material.dart';
import 'package:summer_plugin/summer_plugin.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: _DemoHome());
  }
}

class _DemoHome extends StatelessWidget {
  const _DemoHome();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SummerDataTable Demo'),
          bottom: const TabBar(tabs: [
            Tab(text: '高级表格'),
            Tab(text: '树形表格'),
            Tab(text: '分组表头'),
          ]),
        ),
        body: const TabBarView(
          children: [_AdvancedTab(), _TreeTab(), _GroupTab()],
        ),
      ),
    );
  }
}

// =============================================================================
// Tab 1 — flat table: multi-sort + filter + selection + expand + resize + ellipsis
// =============================================================================

class _AdvancedTab extends StatefulWidget {
  const _AdvancedTab();

  @override
  State<_AdvancedTab> createState() => _AdvancedTabState();
}

class _AdvancedTabState extends State<_AdvancedTab> {
  late final List<_Employee> _all;
  late final _EmployeeSource _source;

  final Set<Object?> _selected = {};
  final Set<Object?> _expanded = {};

  // Multi-sort.
  List<SummerSortSpec> _sort = const [];

  // Per-column filter values.
  Map<String, List<Object?>> _filters = const {};

  int _currentPage = 0;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    const statuses = ['在职', '试用', '离职'];
    _all = List.generate(
      46,
      (i) => _Employee(
        id: i + 1,
        name: '员工 ${i + 1} · 高级前端工程师（React / Flutter）',
        department: const ['技术部', '产品部', '设计部', '市场部'][i % 4],
        salary: (6000 + i * 317).toDouble(),
        status: statuses[i % 3],
      ),
    );
    _source = _EmployeeSource(const []);
  }

  List<_Employee> get _view {
    var list = List<_Employee>.of(_all);
    final statusSel = _filters['status'];
    if (statusSel != null && statusSel.isNotEmpty) {
      list = list.where((e) => statusSel.contains(e.status)).toList();
    }
    for (final spec in _sort) {
      list.sort((a, b) {
        int r;
        switch (spec.key) {
          case 'name':
            r = a.name.compareTo(b.name);
            break;
          case 'salary':
            r = a.salary.compareTo(b.salary);
            break;
          default:
            r = a.id.compareTo(b.id);
        }
        return spec.ascending ? r : -r;
      });
    }
    return list;
  }

  List<_Employee> get _page {
    final view = _view;
    final start = (_currentPage * _pageSize).clamp(0, view.length);
    final end = (start + _pageSize).clamp(0, view.length);
    return view.sublist(start, end);
  }

  int get _totalPages {
    final t = (_view.length / _pageSize).ceil();
    return t < 1 ? 1 : t;
  }

  @override
  Widget build(BuildContext context) {
    _source.page = _page;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SummerDataTable(
        height: 520,
        source: _source,
        sortColumns: _sort,
        onMultiSortChange: (s) => setState(() => _sort = s),
        filteredColumnValues: _filters,
        onFilterChange: (key, values) =>
            setState(() => _filters = Map<String, List<Object?>>.from(_filters)
              ..[key] = values),
        selection: SummerRowSelection(
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
          builder: (context, row) => Container(
            color: const Color(0xFFFAFAFA),
            padding: const EdgeInsets.all(16),
            child: Text('展开详情：${_page[row].name} · ${_page[row].status}'),
          ),
        ),
        columns: const [
          SummerDataColumn(
            key: 'id',
            label: Text('ID'),
            width: 60,
            pin: SummerColumnPin.left,
            alignment: Alignment.center,
          ),
          SummerDataColumn(
            key: 'name',
            label: Text('姓名'),
            width: 220,
            sortable: true,
            resizable: true,
            ellipsis: true,
          ),
          SummerDataColumn(
            key: 'department',
            label: Text('部门'),
            width: 100,
            flex: 1,
          ),
          SummerDataColumn(
            key: 'status',
            label: Text('状态'),
            width: 110,
            filters: [
              SummerColumnFilter(value: '在职', text: '在职'),
              SummerColumnFilter(value: '试用', text: '试用'),
              SummerColumnFilter(value: '离职', text: '离职'),
            ],
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
    );
  }
}

class _EmployeeSource extends SummerDataTableSource {
  List<_Employee> page;
  _EmployeeSource(this.page);

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
        return Text(e.status);
      case 4:
        return Text('¥${e.salary.toStringAsFixed(0)}');
      default:
        return TextButton(
          onPressed: () {},
          child: const Text('编辑', style: TextStyle(fontSize: 13)),
        );
    }
  }
}

class _Employee {
  final int id;
  final String name;
  final String department;
  final double salary;
  final String status;
  const _Employee({
    required this.id,
    required this.name,
    required this.department,
    required this.salary,
    required this.status,
  });
}

// =============================================================================
// Tab 2 — tree table
// =============================================================================

class _TreeTab extends StatefulWidget {
  const _TreeTab();

  @override
  State<_TreeTab> createState() => _TreeTabState();
}

class _TreeTabState extends State<_TreeTab> {
  late final _DeptTreeSource _source;
  final Set<Object?> _selected = {};

  @override
  void initState() {
    super.initState();
    _source = _DeptTreeSource([
      _Dept(
        name: '技术部',
        employees: const [
          _Emp(name: '张三', role: '前端', salary: 18000),
          _Emp(name: '李四', role: '后端', salary: 22000),
          _Emp(name: '王五', role: '测试', salary: 15000),
        ],
      ),
      _Dept(
        name: '产品部',
        employees: const [
          _Emp(name: '赵六', role: '产品经理', salary: 25000),
          _Emp(name: '孙七', role: '交互', salary: 17000),
        ],
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SummerDataTable(
        height: 420,
        source: _source,
        sortColumnKey: 'name',
        sortAscending: true,
        onSortChange: (key, asc) => debugPrint('sort $key $asc'),
        selection: SummerRowSelection(
          selectedKeys: _selected,
          onChanged: (next) => setState(() => _selected
            ..clear()
            ..addAll(next)),
        ),
        columns: const [
          SummerDataColumn(
            key: 'name',
            label: Text('名称'),
            width: 220,
            sortable: true,
            ellipsis: true,
          ),
          SummerDataColumn(key: 'role', label: Text('职位'), width: 140),
          SummerDataColumn(
            key: 'salary',
            label: Text('薪资'),
            width: 120,
            alignment: Alignment.centerRight,
          ),
        ],
      ),
    );
  }
}

class _Dept {
  final String name;
  final List<_Emp> employees;
  const _Dept({required this.name, required this.employees});
}

class _Emp {
  final String name;
  final String role;
  final double salary;
  const _Emp({required this.name, required this.role, required this.salary});
}

// A flattened visible node: either a department (depth 0) or an employee.
class _VNode {
  final String key;
  final int depth;
  final bool hasChildren;
  final String name;
  final String? role;
  final double? salary;
  const _VNode(this.key, this.depth, this.hasChildren,
      {required this.name, this.role, this.salary});
}

class _DeptTreeSource extends SummerTreeTableSource {
  final List<_Dept> _roots;
  final Set<String> _expanded = {'技术部'}; // expand the first dept by default
  List<_VNode> _visible = const [];

  _DeptTreeSource(this._roots) {
    _rebuild();
  }

  void _rebuild() {
    final out = <_VNode>[];
    for (final d in _roots) {
      out.add(_VNode('dept:${d.name}', 0, d.employees.isNotEmpty,
          name: d.name));
      if (_expanded.contains(d.name)) {
        for (final e in d.employees) {
          out.add(_VNode('emp:${d.name}:${e.name}', 1, false,
              name: e.name, role: e.role, salary: e.salary));
        }
      }
    }
    _visible = out;
  }

  @override
  int get rowCount => _visible.length;

  @override
  Object? rowKey(int rowIndex) => _visible[rowIndex].key;

  @override
  int rowDepth(int rowIndex) => _visible[rowIndex].depth;

  @override
  bool rowHasChildren(int rowIndex) => _visible[rowIndex].hasChildren;

  @override
  bool rowExpanded(int rowIndex) {
    final node = _visible[rowIndex];
    // Only dept nodes (depth 0) can expand; their key encodes the dept name.
    if (node.depth != 0) return false;
    return _expanded.contains(node.name);
  }

  @override
  void toggleExpanded(int rowIndex) {
    final node = _visible[rowIndex];
    if (node.depth != 0) return;
    if (_expanded.contains(node.name)) {
      _expanded.remove(node.name);
    } else {
      _expanded.add(node.name);
    }
    _rebuild();
    notifyListeners();
  }

  @override
  Widget buildCell(BuildContext context, int row, int col) {
    final n = _visible[row];
    switch (col) {
      case 0:
        return Text(n.name);
      case 1:
        return Text(n.role ?? '');
      case 2:
        return Text(n.salary == null ? '' : '¥${n.salary!.toStringAsFixed(0)}');
      default:
        return const SizedBox.shrink();
    }
  }
}

// =============================================================================
// Tab 3 — grouped header (column grouping / merged header)
// =============================================================================

class _GroupTab extends StatelessWidget {
  const _GroupTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SummerDataTable(
        height: 420,
        source: _GroupSource(),
        // depth = 2: the "薪资信息" group spans its two leaves.
        columns: const [
          SummerDataColumn(
            key: 'id',
            label: Text('ID'),
            width: 60,
            pin: SummerColumnPin.left,
            alignment: Alignment.center,
          ),
          SummerDataColumn(key: 'name', label: Text('姓名'), width: 160),
          SummerDataColumn(
            key: 'compensation',
            label: Text('薪资信息'),
            children: [
              SummerDataColumn(
                key: 'base',
                label: Text('基本工资'),
                width: 120,
                sortable: true,
                alignment: Alignment.centerRight,
              ),
              SummerDataColumn(
                key: 'bonus',
                label: Text('奖金'),
                width: 120,
                alignment: Alignment.centerRight,
              ),
            ],
          ),
          SummerDataColumn(key: 'dept', label: Text('部门'), width: 120),
          SummerDataColumn(
            key: 'action',
            label: Text('操作'),
            width: 80,
            pin: SummerColumnPin.right,
            alignment: Alignment.center,
          ),
        ],
      ),
    );
  }
}

class _Staff {
  final int id;
  final String name;
  final double base;
  final double bonus;
  final String dept;
  const _Staff({
    required this.id,
    required this.name,
    required this.base,
    required this.bonus,
    required this.dept,
  });
}

class _GroupSource extends SummerDataTableSource {
  // Leaf order matches the DFS flatten: id(0), name(1), base(2), bonus(3),
  // dept(4), action(5).
  final List<_Staff> _rows = List.generate(
    18,
    (i) => _Staff(
      id: i + 1,
      name: '员工 ${i + 1}',
      base: (8000 + i * 250).toDouble(),
      bonus: (1000 + (i % 5) * 400).toDouble(),
      dept: const ['技术部', '产品部', '设计部'][i % 3],
    ),
  );

  @override
  int get rowCount => _rows.length;

  @override
  Object? rowKey(int rowIndex) => _rows[rowIndex].id;

  @override
  Widget buildCell(BuildContext context, int row, int leaf) {
    final s = _rows[row];
    switch (leaf) {
      case 0:
        return Text('${s.id}');
      case 1:
        return Text(s.name);
      case 2:
        return Text('¥${s.base.toStringAsFixed(0)}');
      case 3:
        return Text('¥${s.bonus.toStringAsFixed(0)}');
      case 4:
        return Text(s.dept);
      default:
        return TextButton(
          onPressed: () {},
          child: const Text('编辑', style: TextStyle(fontSize: 13)),
        );
    }
  }
}
