import 'summer_plugin_platform_interface.dart';

export 'table/summer_data_cell.dart';
export 'table/summer_data_column.dart';
export 'table/summer_data_table.dart';
export 'table/summer_data_table_source.dart';
export 'table/summer_data_table_theme.dart';
export 'table/summer_expandable.dart';
export 'table/summer_row_selection.dart';
export 'table/summer_tree_table_source.dart';

class SummerPlugin {
  Future<String?> getPlatformVersion() {
    return SummerPluginPlatform.instance.getPlatformVersion();
  }

  Future<String?> getBatteryLevel() {
    return SummerPluginPlatform.instance.getBatteryLevel();
  }
}
