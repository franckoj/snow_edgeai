import 'dart:async';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../llm_helper.dart' as llm;
import '../models/model_info.dart';
import 'inference_runtime.dart';

final _logger = Logger();

/// ONNX Runtime implementation (wraps existing llm_helper.dart code)
class OnnxInferenceRuntime implements InferenceRuntime {
  llm.LLMInference? _model;
  ModelInfo? _currentModel;

  @override
  RuntimeType get runtime => RuntimeType.onnx;

  @override
  bool get isLoaded => _model != null;

  @override
  ModelInfo? get currentModel => _currentModel;

  @override
  Future<void> loadModel(ModelInfo model) async {
    try {
      _logger.i('Loading ONNX model: ${model.name}');

      final bool isBundled = model.config['isBundled'] == true;
      final modelPath = isBundled ? model.filename : await _getModelPath(model);
      final vocabPath = model.config['vocabPath'] as String?;
      final maxLength = model.config['contextLength'] as int? ?? 512;
      final vocabSize = model.config['vocabSize'] as int? ?? 32000;

      if (!isBundled && !File(modelPath).existsSync()) {
        throw RuntimeException('Model file not found: $modelPath');
      }

      _model = await llm.LLMInference.load(
        modelPath,
        vocabPath: vocabPath,
        maxLength: maxLength,
        vocabSize: vocabSize,
      );

      _currentModel = model;
      _logger.i('ONNX model loaded successfully');
    } catch (e) {
      _logger.e('Failed to load ONNX model', error: e);
      await unload();
      throw RuntimeException('Failed to load ONNX model', e);
    }
  }

  @override
  Future<String> generate(String prompt, GenerationConfig config) async {
    if (!isLoaded || _model == null) {
      throw RuntimeException('No model loaded');
    }

    try {
      return await _model!.generate(
        prompt,
        maxNewTokens: config.maxTokens,
        temperature: config.temperature,
        topK: config.topK,
        topP: config.topP,
      );
    } catch (e) {
      _logger.e('Generation failed', error: e);
      throw RuntimeException('Generation failed', e);
    }
  }

  @override
  Stream<String> generateStream(String prompt, GenerationConfig config) async* {
    if (!isLoaded || _model == null) {
      throw RuntimeException('No model loaded');
    }

    final controller = StreamController<String>();

    // Start generation in the background
    _model!.generate(
      prompt,
      maxNewTokens: config.maxTokens,
      temperature: config.temperature,
      topK: config.topK,
      topP: config.topP,
      onToken: (token) {
        if (!controller.isClosed) {
          controller.add(token);
        }
      },
    ).then((_) {
      if (!controller.isClosed) {
        controller.close();
      }
    }).catchError((e) {
      if (!controller.isClosed) {
        controller.addError(e);
        controller.close();
      }
    });

    yield* controller.stream;
  }

  @override
  Future<void> unload() async {
    _logger.i('Unloading ONNX model');
    _model = null;
    _currentModel = null;
  }

  @override
  Future<void> dispose() async {
    await unload();
  }

  Future<String> _getModelPath(ModelInfo model) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/models/onnx/${model.filename}';
  }
}
