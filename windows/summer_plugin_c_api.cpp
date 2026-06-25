#include "include/summer_plugin/summer_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "summer_plugin.h"

void SummerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  summer_plugin::SummerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
