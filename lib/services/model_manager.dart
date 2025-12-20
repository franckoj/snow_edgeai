import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../models/model_info.dart';

final _logger = Logger();

/// Model catalog and registry
class ModelManager {
  static final ModelManager _instance = ModelManager._internal();
  factory ModelManager() => _instance;
  ModelManager._internal();

  List<ModelInfo>? _models;
  final Map<String, File> _downloadedModels = {};

  /// Load model catalog from assets
  Future<List<ModelInfo>> getAvailableModels() async {
    if (_models != null) return _models!;

    try {
      final jsonString = await rootBundle.loadString('assets/models/catalog.json');
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final modelsList = json['models'] as List;

      _models = modelsList.map((m) => ModelInfo.fromJson(m as Map<String, dynamic>)).toList();
      
      // Fallback: Inject bundled TTS model if missing (handles stale asset cache)
      if (!_models!.any((m) => m.id == 'bundled-tts-en')) {
        _logger.w('Bundled model missing from catalog, injecting fallback');
        _models!.add(
          ModelInfo(
            id: 'bundled-tts-en',
            name: 'Default TTS (English)',
            description: 'Standard built-in English voice model.',
            runtime: RuntimeType.onnx,
            sizeBytes: 0,
            downloadUrl: '',
            filename: 'assets/onnx',
            config: {'isBundled': true},
          ),
        );
      }

      // Check which models are already downloaded
      await _checkDownloadedModels();

      return _models!;
    } catch (e) {
      _logger.e('Failed to load model catalog', error: e);
      return [];
    }
  }


  /// Check which models are downloaded
  Future<void> _checkDownloadedModels() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${dir.path}/models');

    if (!modelsDir.existsSync()) {
      return;
    }

    for (final model in _models ?? <ModelInfo>[]) {
      final runtimeDir = model.runtime == RuntimeType.onnx ? 'onnx' : 'llamacpp';
      final modelFile = File('${modelsDir.path}/$runtimeDir/${model.filename}');

      if (modelFile.existsSync()) {
        _downloadedModels[model.id] = modelFile;
      }
    }
  }

  /// Check if a model is downloaded
  bool isModelDownloaded(String modelId) {
    if (_downloadedModels.containsKey(modelId)) return true;
    
    // Check for bundled models
    final model = getModelById(modelId);
    if (model != null && model.config['isBundled'] == true) {
      return true;
    }
    
    return false;
  }

  /// Get model by ID
  ModelInfo? getModelById(String modelId) {
    return _models?.firstWhere(
      (m) => m.id == modelId,
      orElse: () => throw Exception('Model not found: $modelId'),
    );
  }

  /// Get downloaded models
  List<ModelInfo> getDownloadedModels() {
    if (_models == null) return [];
    return _models!.where((m) => isModelDownloaded(m.id)).toList();
  }

  /// Get models by runtime
  List<ModelInfo> getModelsByRuntime(RuntimeType runtime) {
    if (_models == null) return [];
    return _models!.where((m) => m.runtime == runtime).toList();
  }

  /// Mark model as downloaded
  void markAsDownloaded(String modelId, File modelFile) {
    _downloadedModels[modelId] = modelFile;
  }

  /// Delete a downloaded model
  Future<void> deleteModel(String modelId) async {
    final modelFile = _downloadedModels[modelId];
    if (modelFile != null && modelFile.existsSync()) {
      await modelFile.delete();
      _downloadedModels.remove(modelId);
      _logger.i('Deleted model: $modelId');
    }
  }

  /// Get total storage used by models
  Future<int> getTotalStorageUsed() async {
    int totalBytes = 0;

    for (final file in _downloadedModels.values) {
      if (file.existsSync()) {
        totalBytes += await file.length();
      }
    }

    return totalBytes;
  }

  /// Clear cache
  void clearCache() {
    _models = null;
    _downloadedModels.clear();
  }
}
