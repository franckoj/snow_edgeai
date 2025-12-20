import 'dart:io';
import 'package:logger/logger.dart';

class MemoryHelper {
  static final Logger _logger = Logger();

  /// Logs the current Resident Set Size (RSS) memory usage of the process.
  /// Currently only supported on macOS and Linux (POSIX-compliant ps command).
  static Future<void> logMemoryUsage(String tag) async {
    if (!Platform.isMacOS && !Platform.isLinux) {
      // _logger.d('Memory logging not supported on ${Platform.operatingSystem}');
      return; 
    }

    try {
      // 'ps -o rss= -p PID' returns the RSS in KB
      final result = await Process.run('ps', ['-o', 'rss=', '-p', '$pid']);
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          final rssKb = int.tryParse(output) ?? 0;
          final rssMb = rssKb / 1024;
          _logger.i('🧠 Memory [$tag]: ${rssMb.toStringAsFixed(2)} MB');
        }
      } else {
        _logger.w('Failed to check memory: ${result.stderr}');
      }
    } catch (e) {
      _logger.w('Failed to get memory usage', error: e);
    }
  }
}
