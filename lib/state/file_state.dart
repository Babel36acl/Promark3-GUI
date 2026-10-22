/// 文件管理状态
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pm3gui/services/file_collector.dart';
import 'package:pm3gui/l10n/localized_messages.dart';

class FileState extends ChangeNotifier with LocalizedMessages {
  List<CollectedFile> collectedFiles = [];
  List<CardGroup> cardGroups = [];
  bool isScanning = false;
  String? collectBaseDir;
  String? scanError;
  String _lastPm3Path = '';
  String? _lastWorkingDirectory;
  bool _rescanRequested = false;

  /// 扫描 PM3 工作目录，收集 dump / key 文件
  Future<void> scanForFiles(String pm3Path, {String? workingDirectory}) async {
    _lastPm3Path = pm3Path;
    _lastWorkingDirectory = workingDirectory;
    if (isScanning) {
      _rescanRequested = true;
      return;
    }

    isScanning = true;
    scanError = null;
    notifyListeners();

    try {
      // 在 isolate 中执行文件扫描，避免阻塞主线程
      final result = await compute(_scanFilesInIsolate, {
        'pm3Path': pm3Path,
        'collectBaseDir': collectBaseDir,
        'workingDirectory': workingDirectory,
      });

      collectedFiles = result['files'] as List<CollectedFile>;
      cardGroups = result['groups'] as List<CardGroup>;
      final errors = result['errors'] as List<String>;
      scanError = errors.isEmpty ? null : errors.join('\n');
    } catch (e) {
      scanError = l10n.messageFileScanFailed((e).toString());
    }

    isScanning = false;
    notifyListeners();
    if (_rescanRequested) {
      _rescanRequested = false;
      await scanForFiles(_lastPm3Path, workingDirectory: _lastWorkingDirectory);
    }
  }

  /// 在 isolate 中执行文件扫描
  static Future<Map<String, dynamic>> _scanFilesInIsolate(
      Map<String, dynamic> params) async {
    final pm3Path = params['pm3Path'] as String;
    final collectBaseDir = params['collectBaseDir'] as String? ??
        '${Directory.current.path}/pm3_files';

    final errors = <String>[];
    final dirs = FileCollector.defaultScanDirs(pm3Path,
        workingDirectory: params['workingDirectory'] as String?,
        onError: errors.add);
    final files = await FileCollector.scan(dirs, onError: errors.add);

    final organizedFiles = await FileCollector.scan(
      [collectBaseDir],
      recursive: true,
      onError: errors.add,
    );

    final seen = <String>{};
    final allFiles =
        [...files, ...organizedFiles].where((f) => seen.add(f.path)).toList();
    final groups = FileCollector.groupByCard(allFiles);

    return {
      'files': allFiles,
      'groups': groups,
      'errors': errors,
    };
  }

  /// 将已收集的文件整理归类到指定目录
  Future<int> organizeCollectedFiles(String baseDir) async {
    collectBaseDir = baseDir;
    final count = await FileCollector.organizeFiles(collectedFiles, baseDir);
    await scanForFiles(_lastPm3Path, workingDirectory: _lastWorkingDirectory);
    return count;
  }

  void setCollectBaseDir(String? baseDir) {
    collectBaseDir =
        (baseDir != null && baseDir.trim().isNotEmpty) ? baseDir : null;
    notifyListeners();
  }
}
