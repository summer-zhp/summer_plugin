# summer_plugin

![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A53.3.0-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-%E2%89%A53.9.2-0175C2?logo=dart)

> 一款参考 antd / naive-ui 表格能力、为 Flutter 打造的高性能数据表格组件 **SummerDataTable**。

`summer_plugin` 提供一个功能完备、可受控、可定制的 `SummerDataTable`,内置虚拟滚动、固定列/固定表头、单/多列排序、列筛选、行选择、行展开、列宽调整、树形/层级数据、表头分组(合并表头)、省略号 + Tooltip、悬停/选中高亮、加载/空态与分页。

- 🚀 **性能优先**:纵向 `ListView.builder` 虚拟化 + 横向单一 RenderBox 平移(只重绘不重建)。
- 🎛️ **完全受控**:排序、选择、展开、筛选、分页状态均由调用方持有,组件不藏状态。
- 🧩 **API 友好**:ant 风格的列定义 + 数据源(`ChangeNotifier`),与现有项目心智模型一致。

---

## 目录

- [特性一览](#特性一览)
- [安装](#安装)
- [快速开始](#快速开始)
- [数据源](#数据源)
- [功能示例](#功能示例)
  - [固定列](#固定列)
  - [排序(单列 / 多列)](#排序单列--多列)
  - [列筛选](#列筛选)
  - [行选择](#行选择)
  - [行展开](#行展开)
  - [列宽调整](#列宽调整)
  - [省略号 + Tooltip](#省略号--tooltip)
  - [分页](#分页)
  - [树形 / 层级数据](#树形--层级数据)
  - [表头分组(合并表头)](#表头分组合并表头)
- [主题定制](#主题定制)
- [架构与性能](#架构与性能)
- [许可证](#许可证)

---

## 特性一览

| 能力 | 说明 |
| --- | --- |
| 纵向虚拟滚动 | `ListView.builder`,自带惯性物理、滚动条、鼠标滚轮 |
| 横向滚动 | 拖拽 / 惯性 fling / Shift+滚轮;固定列不随滚动 |
| 固定列 | 左 / 右固定(`SummerColumnPin.left` / `.right`),表头同步固定 |
| 排序 | 单列(`onSortChange`)或多列(`onMultiSortChange`,Shift+点击叠加,表头显示优先级序号) |
| 列筛选 | 表头漏斗下拉,支持单选/多选 + 重置/确定 |
| 行选择 | 复选框 / 单选 / 全选,自定义指示器(规避已废弃的 `Radio` API) |
| 行展开 | 行下方的详情面板 |
| 列宽调整 | 拖拽列右边框 |
| 树形数据 | `SummerTreeTableSource` 自动启用,首列缩进 + 展开 caret |
| 表头分组 | `SummerDataColumn.children` 递归合并表头 |
| 省略号 + Tooltip | 超长文本自动省略并悬浮提示 |
| 悬停 / 选中高亮 | 可开关 |
| 加载 / 空态 | 内置默认样式,可替换 |
| 分页 | 内置分页条(带省略号) |

---

## 安装

发布到 pub.dev 后:

```yaml
dependencies:
  summer_plugin: ^0.0.1
```

或直接通过 Git 依赖:

```yaml
dependencies:
  summer_plugin:
    git:
      url: https://github.com/summer-zhp/summer_plugin.git
```

```dart
import 'package:summer_plugin/summer_plugin.dart';
```

> 环境要求: Dart `>=3.9.2`,Flutter `>=3.3.0`。

---

## 快速开始

```dart
import 'package:flutter/material.dart';
import 'package:summer_plugin/summer_plugin.dart';

class Employee {
  final int id;
  final String name;
  final String dept;
  const Employee({required this.id, required this.name, required this.dept});
}

class EmployeeSource extends SummerDataTableSource {
  final List<Employee> rows;
  EmployeeSource(this.rows);

  @override
  int get rowCount => rows.length;

  @override
  Object? rowKey(int rowIndex) => rows[rowIndex].id;

  @override
  Widget buildCell(BuildContext context, int row, int col) {
    final e = rows[row];
    switch (col) {
      case 0:
        return Text('${e.id}');
      case 1:
        return Text(e.name);
      default:
        return Text(e.dept);
    }
  }
}

class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SummerDataTable(
      source: EmployeeSource(const [
        Employee(id: 1, name: '张三', dept: '技术部'),
        Employee(id: 2, name: '李四', dept: '产品部'),
      ]),
      columns: const [
        SummerDataColumn(key: 'id', label: Text('ID'), width: 60),
        SummerDataColumn(key: 'name', label: Text('姓名'), width: 160),
        SummerDataColumn(key: 'dept', label: Text('部门'), width: 120),
      ],
    );
  }
}
```

---

## 数据源

表格数据由 `SummerDataTableSource`(继承自 `ChangeNotifier`)提供。数据变化时调用 `notifyListeners()` 即可刷新:

```dart
abstract class SummerDataTableSource extends ChangeNotifier {
  int get rowCount;
  Widget buildCell(BuildContext context, int rowIndex, int columnIndex);
  Object? rowKey(int rowIndex) => rowIndex; // 可选,用于选择/展开的稳定标识
}
```

> `columnIndex` 是**叶子列**的索引(扁平列即为列顺序;含分组的表头时,索引按 DFS 深度优先的叶子顺序计数)。

树形数据请使用 [`SummerTreeTableSource`](#树形--层级数据)。

---

## 功能示例

### 固定列

```dart
SummerDataColumn(
  key: 'id',
  label: Text('ID'),
  width: 60,
  pin: SummerColumnPin.left,  // 或 .right
),
```

> 仅**顶层列**可固定;嵌套在分组内的列始终属于可横向滚动的中段。

### 排序(单列 / 多列)

**单列排序**(受控,三态循环:升序 → 降序 → 取消):

```dart
String? _sortKey;
bool _asc = true;

SummerDataTable(
  source: source,
  sortColumnKey: _sortKey,
  sortAscending: _asc,
  onSortChange: (key, asc) => setState(() {
    _sortKey = key;       // null 表示取消排序
    _asc = asc;
  }),
  columns: const [
    SummerDataColumn(key: 'name', label: Text('姓名'), sortable: true),
  ],
);
```

**多列排序**(普通点击替换为单列;**Shift+点击**叠加列并循环方向,表头显示优先级序号):

```dart
List<SummerSortSpec> _sort = const [];

SummerDataTable(
  source: source,
  sortColumns: _sort,
  onMultiSortChange: (specs) => setState(() => _sort = specs),
  columns: const [
    SummerDataColumn(
      key: 'name',
      label: Text('姓名'),
      sortable: true,
      sortDirections: [true, false], // 点击循环方向,true=升序
    ),
  ],
);
```

> 同时提供 `onSortChange` 与 `onMultiSortChange` 时,以多列为准。

### 列筛选

```dart
SummerDataColumn(
  key: 'status',
  label: Text('状态'),
  width: 110,
  filters: const [
    SummerColumnFilter(value: '在职', text: '在职'),
    SummerColumnFilter(value: '试用', text: '试用'),
  ],
  filterMultiple: true, // false 为单选
);

// 受控:
Map<String, List<Object?>> _filters = const {};
SummerDataTable(
  filteredColumnValues: _filters,
  onFilterChange: (key, values) =>
      setState(() => _filters = {..._filters, key: values}),
);
```

表头出现漏斗图标(有选中值时高亮),点击弹出锚定下拉,内含重置/确定。注意:筛选**只负责回传选中值**,具体数据过滤逻辑由你的数据源自行实现。

### 行选择

```dart
final Set<Object?> _selected = {};

SummerDataTable(
  source: source,
  selection: SummerRowSelection(
    type: SummerSelectionType.checkbox, // 或 .radio / .none
    selectedKeys: _selected,
    onChanged: (next) => setState(() {
      _selected
        ..clear()
        ..addAll(next);
    }),
    disabled: false, // 禁用所有行
  ),
);
```

单选模式下每行显示自定义圆形指示器(规避 Flutter 3.32+ 已废弃的 `Radio.groupValue/onChanged`)。

### 行展开

```dart
final Set<Object?> _expanded = {};

SummerDataTable(
  source: source,
  expandable: SummerRowExpandable(
    expandedKeys: _expanded,
    onChanged: (next) => setState(() {
      _expanded
        ..clear()
        ..addAll(next);
    }),
    builder: (context, rowIndex) => Padding(
      padding: const EdgeInsets.all(16),
      child: Text('第 $rowIndex 行的详情内容'),
    ),
  ),
);
```

### 列宽调整

```dart
SummerDataColumn(
  key: 'name',
  label: Text('姓名'),
  width: 160,
  minWidth: 80,
  maxWidth: 400,
  resizable: true,
),
```

拖拽该列右边缘即可调整,范围被 `minWidth` / `maxWidth` 约束。

### 省略号 + Tooltip

```dart
SummerDataColumn(
  key: 'name',
  label: Text('姓名'),
  width: 160,
  ellipsis: true,
),
```

超长文本单行省略,悬浮 400ms 后弹出 Tooltip。也可在数据源里直接使用 `SummerDataCell(child: ..., ellipsis: true)`。

### 分页

```dart
SummerDataTable(
  source: source,
  currentPage: 0,
  totalPages: 5,
  onNextPage: () => setState(() => _page++),
  onPreviousPage: () => setState(() => _page--),
  onPageTap: (p) => setState(() => _page = p),
);
```

> 表格只负责展示分页条并回传翻页事件;实际数据切片由你的数据源完成(通常每页提供一个 `page` 子集)。

### 树形 / 层级数据

将数据源改为 `SummerTreeTableSource`,表格会**自动**进入树模式:首列按深度缩进并显示展开 caret。

```dart
class DeptTreeSource extends SummerTreeTableSource {
  final List<Node> roots;
  final Set<String> expanded = {};
  List<Node> _visible = const [];

  DeptTreeSource(this.roots) { _rebuild(); }

  void _rebuild() {
    final out = <Node>[];
    void walk(Node n, int depth) {
      out.add(n..depth = depth);
      if (expanded.contains(n.key)) {
        for (final c in n.children) {
          walk(c, depth + 1);
        }
      }
    }
    for (final r in roots) {
      walk(r, 0);
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
  bool rowHasChildren(int rowIndex) =>
      _visible[rowIndex].children.isNotEmpty;

  @override
  bool rowExpanded(int rowIndex) =>
      expanded.contains(_visible[rowIndex].key);

  @override
  void toggleExpanded(int rowIndex) {
    final key = _visible[rowIndex].key;
    expanded.contains(key) ? expanded.remove(key) : expanded.add(key);
    _rebuild();
    notifyListeners(); // 必须通知,否则 UI 不刷新
  }

  @override
  Widget buildCell(BuildContext context, int row, int col) =>
      Text(_visible[row].name);
}
```

> `SummerTreeTableSource` 自行持有展平列表与展开态;调用 `toggleExpanded` 后务必 `notifyListeners()`。

### 表头分组(合并表头)

为列指定 `children` 即可生成多级合并表头(antd / naive 风格)。分组列只渲染表头(合并显示),不渲染单元格;单元格只为其**叶子列**生成。

```dart
SummerDataColumn(
  key: 'compensation',
  label: Text('薪资信息'),
  children: [
    SummerDataColumn(
      key: 'base',
      label: Text('基本工资'),
      width: 120,
      sortable: true,
    ),
    SummerDataColumn(
      key: 'bonus',
      label: Text('奖金'),
      width: 120,
    ),
  ],
),
```

- 叶子列占据底部行,纵向合并到底(`rowspan = 总深度 - 当前层级`);分组列占单行、横向合并其所有叶子宽度。
- **约束**:分组列不可固定/排序/调整大小/筛选(这些能力作用于叶子列);嵌套列始终归属中段。无 `children` 的扁平表与旧行为完全一致。

---

## 主题定制

`SummerDataTableThemeData` 含较多必填字段,推荐用 `defaultTheme()`(antd 风格)再通过 `copyWith` 局部覆盖:

```dart
SummerDataTable(
  source: source,
  columns: columns,
  theme: SummerDataTableThemeData.defaultTheme().copyWith(
    headerHeight: 48,
    rowHeight: 44,
    borderColor: const Color(0xFFE8E8E8),
    headerBackgroundColor: const Color(0xFFFAFAFA),
    sortActiveColor: const Color(0xFF1890FF), // antd 蓝
    hoverColor: const Color(0xFFF5F5F5),
    selectedColor: const Color(0xFFE6F7FF),
    altRowBackgroundColor: const Color(0xFFFAFAFA),
    resizeHandleColor: const Color(0xFFD9D9D9),
  ),
);
```

不传 `theme` 时,组件按 `SummerDataTableTheme.of(context)` 取值,无上层主题则回退到 `defaultTheme()`。若要让多个表格共享主题,可用 `SummerDataTableTheme`(`InheritedWidget`)包裹:

```dart
SummerDataTableTheme(
  data: SummerDataTableThemeData.defaultTheme().copyWith(sortActiveColor: Colors.red),
  child: SummerDataTable(source: source, columns: columns),
);
```

可覆盖项包括:`headerBackgroundColor`、`headerTextStyle`、`cellBackgroundColor`、`altRowBackgroundColor`、`hoverColor`、`selectedColor`、`sortActiveColor`、`cellTextStyle`、`rowHeight`、`headerHeight`、`borderColor`、`borderWidth`、`resizeHandleColor`、`resizeHandleWidth`、`sortAscendingIcon`、`sortDescendingIcon`、`expandIcon`、`loadingWidget`、`emptyWidget`。

---

## 架构与性能

`SummerDataTable` 采用**标准 Widget 组合**而非自定义 paint-loop `RenderBox`:

- **纵向**:`ListView.builder` 原生虚拟化、物理与滚动条。
- **横向**:共享 `ValueNotifier<double>` 驱动一个 `_XTranslatedBox`(`RenderProxyBox`)。横向滚动时**只 `markNeedsPaint` 重绘**,不重建任何 cell 子树;固定列作为不参与平移的兄弟节点。
- **列分区**(`left/right/middle`)在每次 build 中**预计算一次**,供表头与每个可见行复用,避免逐行重复过滤。
- **表头分组**:中段表头用 `Stack` 绝对定位实现 rowspan/colspan 语义;叶子列与分组列各自定位。

> 取舍:含展开行的 `_flatten()`、以及「全选」态计算在有展开/选择时为 O(n)/build(典型数据量无感);筛选弹层定位为尽力而为的边缘收敛。分页通常将单屏行数控制在页大小,进一步降低开销。

---

## 许可证

[MIT License](./LICENSE) © 2026 summer-zhp
