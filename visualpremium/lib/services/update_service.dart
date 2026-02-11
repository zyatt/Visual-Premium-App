import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool mandatory;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.mandatory,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json, String currentVersion) {
    return UpdateInfo(
      currentVersion: currentVersion,
      latestVersion: json['latestVersion'] ?? '',
      downloadUrl: json['downloadUrl'] ?? '',
      releaseNotes: json['releaseNotes'] ?? '',
      mandatory: json['mandatory'] ?? false,
    );
  }
}

class UpdateService {
  static const String _updateCheckUrl = 'UPDATE_CHECK_URL';

  static Future<UpdateInfo?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final apiUrl = dotenv.env[_updateCheckUrl];
      if (apiUrl == null || apiUrl.isEmpty) {
        return null;
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      
      Map<String, dynamic> updateData;
      
      if (data.containsKey('tag_name')) {
        final latestVersion = (data['tag_name'] as String).replaceFirst('v', '');
        
        final assets = data['assets'] as List?;
        if (assets == null || assets.isEmpty) {
          return null;
        }
        
        final exeAsset = assets.firstWhere(
          (a) => (a['name'] as String).toLowerCase().endsWith('.exe'),
          orElse: () => null,
        );
        
        if (exeAsset == null) {
          return null;
        }
        
        updateData = {
          'latestVersion': latestVersion,
          'downloadUrl': exeAsset['browser_download_url'],
          'releaseNotes': data['body'] ?? 'Nova versão disponível',
          'mandatory': false,
          'minSupportedVersion': '1.0.0'
        };
      } else if (data.containsKey('latestVersion')) {
        updateData = data;
      } else {
        return null;
      }
      
      final latestVersion = updateData['latestVersion'] as String;

      if (_shouldUpdate(currentVersion, latestVersion)) {
        return UpdateInfo.fromJson(updateData, currentVersion);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static bool _shouldUpdate(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final currentNum = i < currentParts.length ? currentParts[i] : 0;
      final latestNum = i < latestParts.length ? latestParts[i] : 0;

      if (latestNum > currentNum) return true;
      if (latestNum < currentNum) return false;
    }

    return false;
  }

  static Future<bool> downloadAndInstallUpdate(
    String downloadUrl,
    Function(double) onProgress,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final installerPath = '${tempDir.path}\\VisualPremiumSetup.exe';

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await request.send();

      if (response.statusCode != 200) {
        return false;
      }

      final totalBytes = response.contentLength ?? 0;
      int downloadedBytes = 0;

      final file = File(installerPath);
      final sink = file.openWrite();

      await response.stream.listen(
        (List<int> chunk) {
          sink.add(chunk);
          downloadedBytes += chunk.length;

          if (totalBytes > 0) {
            final progress = downloadedBytes / totalBytes;
            onProgress(progress);
          }
        },
        onDone: () async {
          await sink.close();
          onProgress(1.0);
        },
        onError: (e) {
          sink.close();
        },
      ).asFuture();

      await Future.delayed(const Duration(milliseconds: 500));

      await Process.start(
        installerPath,
        ['/SILENT', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
        mode: ProcessStartMode.detached,
      );

      await Future.delayed(const Duration(milliseconds: 500));
      exit(0);
    } catch (e) {
      return false;
    }
  }
}