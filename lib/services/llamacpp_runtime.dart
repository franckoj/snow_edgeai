import 'dart:io';
import 'package:flutter_llama/flutter_llama.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../models/model_info.dart';
import 'inference_runtime.dart';

final _logger = Logger();

/// llama.cpp runtime implementation using flutter_llama
class LlamaCppInferenceRuntime implements InferenceRuntime {
  final FlutterLlama _llama = FlutterLlama.instance;
  ModelInfo? _currentModel;
  bool _isLoaded = false;

  @override
  RuntimeType get runtime => RuntimeType.llamaCpp;

  @override
  bool get isLoaded => _isLoaded;

  @override
  ModelInfo? get currentModel => _currentModel;

  @override
  Future<void> loadModel(ModelInfo model) async {
    try {
      _logger.i('Loading llama.cpp model: ${model.name}');

      // Get model path
      final modelPath = await _getModelPath(model);
      final file = File(modelPath);
      
      if (!await file.exists()) {
        throw RuntimeException('Model file not found: $modelPath');
      }

      // Configure LlamaConfig
      final config = LlamaConfig(
        modelPath: modelPath,
        nThreads: 4,
        nGpuLayers: model.config['gpuLayers'] as int? ?? 0,
        contextSize: model.config['contextLength'] as int? ?? 2048,
        batchSize: 512,
        useGpu: (model.config['gpuLayers'] as int? ?? 0) > 0,
        verbose: false,
      );

      final success = await _llama.loadModel(config);
      if (!success) {
        throw RuntimeException('Failed to load model with flutter_llama');
      }

      _isLoaded = true;
      _currentModel = model;
      _logger.i('Model loaded successfully');
    } catch (e, stackTrace) {
      _logger.e('Failed to load model', error: e, stackTrace: stackTrace);
      await unload();
      throw RuntimeException('Failed to load llama.cpp model: $e', e);
    }
  }

  @override
  Future<String> generate(String prompt, GenerationConfig config) async {
    if (!isLoaded) {
      throw RuntimeException('No model loaded');
    }

    try {
      final params = GenerationParams(
        prompt: prompt,
        temperature: config.temperature,
        topP: config.topP,
        topK: config.topK,
        maxTokens: config.maxTokens,
        repeatPenalty: config.repeatPenalty,
      );

      final response = await _llama.generate(params);
      return response.text;
    } catch (e) {
      _logger.e('Generation failed', error: e);
      throw RuntimeException('Generation failed: $e', e);
    }
  }

  @override
  Stream<String> generateStream(String prompt, GenerationConfig config) async* {
    if (!isLoaded) {
      throw RuntimeException('No model loaded');
    }

    try {
      final params = GenerationParams(
        prompt: prompt,
        temperature: config.temperature,
        topP: config.topP,
        topK: config.topK,
        maxTokens: config.maxTokens,
        repeatPenalty: config.repeatPenalty,
      );

      yield* _llama.generateStream(params);
    } catch (e) {
      _logger.e('Streaming generation failed', error: e);
      throw RuntimeException('Streaming generation failed: $e', e);
    }
  }

  @override
  Future<void> unload() async {
    _logger.i('Unloading llama.cpp model');
    await _llama.unloadModel();
    _isLoaded = false;
    _currentModel = null;
  }

  @override
  Future<void> dispose() async {
    await unload();
  }

  Future<String> _getModelPath(ModelInfo model) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/models/llamacpp/${model.filename}';
  }
}
