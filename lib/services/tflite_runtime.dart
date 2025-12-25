import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/model_info.dart';
import 'inference_runtime.dart';

final _logger = Logger();

/// TensorFlow Lite runtime implementation
class TfliteInferenceRuntime implements InferenceRuntime {
  static final TfliteInferenceRuntime _instance = TfliteInferenceRuntime._internal();
  
  TfliteInferenceRuntime._internal();
  
  factory TfliteInferenceRuntime() => _instance;

  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  ModelInfo? _currentModel;
  bool _isModelLoaded = false;

  @override
  RuntimeType get runtime => RuntimeType.tflite;

  @override
  bool get isLoaded => _isModelLoaded;

  @override
  ModelInfo? get currentModel => _currentModel;

  @override
  Future<void> loadModel(ModelInfo model) async {
    try {
      final isBundled = model.config['isBundled'] == true;
      
      if (isBundled) {
        final assetPath = 'assets/models/${model.filename}';
        _logger.i('Loading TFLite model from ASSET: $assetPath');
        
        final options = InterpreterOptions();
        if (model.config['threads'] != null) {
          options.threads = model.config['threads'] as int;
        }
        
        _interpreter = await Interpreter.fromAsset(assetPath, options: options);
      } else {
        final modelPath = await _getModelPath(model);
        _logger.i('Attempting to load TFLite model from FILE: $modelPath');
        final file = File(modelPath);
        
        if (!await file.exists()) {
          _logger.e('Model file NOT FOUND at: $modelPath');
          throw RuntimeException('Model file not found: $modelPath');
        }

        final bytes = await file.readAsBytes();
        _logger.i('Model file size: ${bytes.length} bytes');
        
        if (bytes.length < 8) {
          throw RuntimeException('Model file is too small to be a valid TFLite model');
        }
        
        final signature = String.fromCharCodes(bytes.sublist(4, 8));
        _logger.i('Model file signature at offset 4: "$signature"');
        
        final options = InterpreterOptions();
        if (model.config['threads'] != null) {
          options.threads = model.config['threads'] as int;
        }

        _logger.i('Creating TFLite interpreter from buffer (more robust than fromFile)...');
        _interpreter = Interpreter.fromBuffer(bytes, options: options);
      }
      
      _logger.i('Wrapping interpreter with IsolateInterpreter for non-blocking inference...');
      _isolateInterpreter = await IsolateInterpreter.create(address: _interpreter!.address);
      
      _isModelLoaded = true;
      _currentModel = model;
      _logger.i('TFLite model loaded successfully (${isBundled ? "Asset" : "Buffer"})');
    } catch (e, stackTrace) {
      _logger.e('Failed to load TFLite model', error: e, stackTrace: stackTrace);
      await unload();
      throw RuntimeException('Failed to load TFLite model: $e', e);
    }
  }

  @override
  Future<String> generate(String prompt, GenerationConfig config) async {
    if (!isLoaded || _isolateInterpreter == null) {
      throw RuntimeException('No TFLite model loaded');
    }

    try {
      _logger.w('TFLite generate called - generic text generation not fully implemented for TFLite');
      // For a real implementation, we would use _isolateInterpreter.run(...)
      return 'TFLite inference for "${_currentModel?.name}" triggered via Isolate. Generic text generation is restricted by model architecture.';
    } catch (e) {
      _logger.e('TFLite generation failed', error: e);
      throw RuntimeException('TFLite generation failed: $e', e);
    }
  }

  @override
  Stream<String> generateStream(String prompt, GenerationConfig config) async* {
    if (!isLoaded || _isolateInterpreter == null) {
      throw RuntimeException('No TFLite model loaded');
    }

    _logger.w('TFLite generateStream called - generic streaming not implemented for TFLite');
    yield 'TFLite streaming triggered via Isolate... [Not implemented for general TFLite models]';
  }

  @override
  Future<void> unload() async {
    _logger.i('Unloading TFLite model and Isolate');
    _isolateInterpreter?.close();
    _isolateInterpreter = null;
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    _currentModel = null;
  }

  @override
  Future<void> dispose() async {
    // Persistent.
  }

  Future<String> _getModelPath(ModelInfo model) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/models/tflite/${model.filename}';
  }
}
