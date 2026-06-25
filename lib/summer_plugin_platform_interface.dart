import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'summer_plugin_method_channel.dart';

abstract class SummerPluginPlatform extends PlatformInterface {
  /// Constructs a SummerPluginPlatform.
  SummerPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static SummerPluginPlatform _instance = MethodChannelSummerPlugin();

  /// The default instance of [SummerPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelSummerPlugin].
  static SummerPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SummerPluginPlatform] when
  /// they register themselves.
  static set instance(SummerPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> getBatteryLevel() {
    throw UnimplementedError('getBatteryLevel() has not been implemented.');
  }
}
