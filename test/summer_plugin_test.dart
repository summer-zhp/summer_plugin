import 'package:flutter_test/flutter_test.dart';
import 'package:summer_plugin/summer_plugin.dart';
import 'package:summer_plugin/summer_plugin_platform_interface.dart';
import 'package:summer_plugin/summer_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSummerPluginPlatform
    with MockPlatformInterfaceMixin
    implements SummerPluginPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<String?> getBatteryLevel() => Future.value('100');
}

void main() {
  final SummerPluginPlatform initialPlatform = SummerPluginPlatform.instance;

  test('$MethodChannelSummerPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSummerPlugin>());
  });

  test('getPlatformVersion', () async {
    SummerPlugin summerPlugin = SummerPlugin();
    MockSummerPluginPlatform fakePlatform = MockSummerPluginPlatform();
    SummerPluginPlatform.instance = fakePlatform;

    expect(await summerPlugin.getPlatformVersion(), '42');
  });
}
