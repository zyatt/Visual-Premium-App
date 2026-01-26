import 'package:network_info_plus/network_info_plus.dart';

class NetworkUtils {
  static Future<String?> getLocalIp() async {
    final info = NetworkInfo();
    return await info.getWifiIP(); 
  }
}
