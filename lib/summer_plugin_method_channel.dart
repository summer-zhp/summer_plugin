import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'summer_plugin_platform_interface.dart';

/// An implementation of [SummerPluginPlatform] that uses method channels.
class MethodChannelSummerPlugin extends SummerPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('summer_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  // 获取电量
  @override
  Future<String?> getBatteryLevel() async {
    final batteryLevel = await methodChannel.invokeMethod<String>(
      'getBatteryLevel',
    );
    return batteryLevel;
  }
}
