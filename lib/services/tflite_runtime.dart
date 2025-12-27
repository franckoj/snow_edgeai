import 'dart:io';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/model_info.dart';
import 'inference_runtime.dart';

final _logger = Logger();

/// LiteRT (TensorFlow Lite) runtime implementation
class LiteRTInferenceRuntime implements InferenceRuntime {
  static final LiteRTInferenceRuntime _instance = LiteRTInferenceRuntime._internal();
  
  LiteRTInferenceRuntime._internal();
  
  factory LiteRTInferenceRuntime() => _instance;

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
      _logger.i('Loading LiteRT model: ${model.name} (ID: ${model.id})');
      
      // Step 1: Ensure the model file is in a temporary location for the interpreter
      final file = await _ensureTempFile(model);
      
      // Verification: Check signature
      final bytes = await file.readAsBytes();
      if (bytes.length < 8) {
        throw RuntimeException('Model file is too small');
      }
      final signature = String.fromCharCodes(bytes.sublist(4, 8));
      _logger.i('Model file size: ${bytes.length} bytes, Signature: "$signature"');

      if (signature == 'RTLM') {
        _logger.i('✅ Detected LiteRT (RTLM) model signature.');
      } else if (signature == 'TFL3') {
        _logger.i('✅ Detected legacy TFLite (TFL3) model signature.');
      } else {
         _logger.w('⚠️ WARNING: Unexpected model signature: "$signature". Expected "RTLM" or "TFL3".');
      }

      final options = InterpreterOptions();
      if (model.config['threads'] != null) {
        options.threads = model.config['threads'] as int;
      }

      // Step 2: Initialize the Interpreter
      _logger.i('Creating LiteRT interpreter from temp file: ${file.path}');
      
      try {
        // Attempt 1: Load from file (standard, efficient)
        _interpreter = await Interpreter.fromFile(file, options: options);
      } catch (e) {
        _logger.w('Interpreter.fromFile failed: $e. Falling back to fromBuffer...');
        // Attempt 2: Load from memory (fallback for certain file system issues)
        _interpreter = await Interpreter.fromBuffer(bytes, options: options);
      }
      
      // Asynchronous Inference Pattern:
      // 1. Create your Interpreter (Done above)
      // 2. Wrap it with IsolateInterpreter
      _logger.i('Wrapping interpreter with IsolateInterpreter for asynchronous inference...');
      
      if (_interpreter == null) {
        throw RuntimeException('LiteRT interpreter not initialized');
      }

      // Create isolate interpreter from the address of the main interpreter
      _isolateInterpreter = await IsolateInterpreter.create(address: _interpreter!.address);
      
      _isModelLoaded = true;
      _currentModel = model;
      _logger.i('LiteRT model loaded successfully via temp file copy');
    } catch (e, stackTrace) {
      _logger.e('Failed to load LiteRT model', error: e, stackTrace: stackTrace);
      await unload();
      throw RuntimeException('Failed to load LiteRT model: $e', e);
    }
  }

  @override
  Future<String> generate(String prompt, GenerationConfig config) async {
    if (!isLoaded || _isolateInterpreter == null) {
      throw RuntimeException('No LiteRT model loaded');
    }

    try {
      _logger.w('LiteRT generate called - generic text generation not fully implemented');
      return 'LiteRT inference for "${_currentModel?.name}" triggered via Isolate.';
    } catch (e) {
      _logger.e('LiteRT generation failed', error: e);
      throw RuntimeException('LiteRT generation failed: $e', e);
    }
  }

  @override
  Stream<String> generateStream(String prompt, GenerationConfig config) async* {
    if (!isLoaded || _isolateInterpreter == null) {
      throw RuntimeException('No LiteRT model loaded');
    }

    _logger.w('LiteRT generateStream called - generic streaming not implemented');
    yield 'LiteRT streaming triggered via Isolate...';
  }

  @override
  Future<void> unload() async {
    _logger.i('Unloading LiteRT model and Isolate');
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
    return '${dir.path}/models/litert/${model.filename}';
  }

  Future<File> _ensureTempFile(ModelInfo model) async {
    final appDir = await getTemporaryDirectory();
    final fileName = model.filename;
    final tempFile = File('${appDir.path}/$fileName');
    
    final isBundled = model.config['isBundled'] == true;
    
    if (isBundled) {
      final assetPath = 'assets/models/litert/${model.filename}';
      _logger.i('Copying asset $assetPath to ${tempFile.path}');
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      await tempFile.writeAsBytes(bytes, flush: true);
    } else {
      final modelPath = await _getModelPath(model);
      final storageFile = File(modelPath);
      if (!await storageFile.exists()) {
        throw RuntimeException('Model file not found at: $modelPath');
      }
      
      // Only copy if not already in temp or if we want to be strictly sure (as "same" logic implies)
      // For performance on large models, one might skip if exists(), but let's follow the user's "use the same" logic.
      _logger.i('Copying downloaded model from $modelPath to ${tempFile.path}');
      final bytes = await storageFile.readAsBytes();
      await tempFile.writeAsBytes(bytes, flush: true);
    }
    
    return tempFile;
  }
}
