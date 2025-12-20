import '../models/model_info.dart';

/// Abstract interface for AI inference runtimes
abstract class InferenceRuntime {
  /// Load a model into memory
  Future<void> loadModel(ModelInfo model);

  /// Generate text from a prompt (blocking)
  Future<String> generate(String prompt, GenerationConfig config);

  /// Generate text from a prompt (streaming)
  Stream<String> generateStream(String prompt, GenerationConfig config);

  /// Unload the current model from memory
  Future<void> unload();

  /// Check if a model is currently loaded
  bool get isLoaded;

  /// Get the currently loaded model info
  ModelInfo? get currentModel;

  /// Get runtime type
  RuntimeType get runtime;

  /// Dispose resources
  Future<void> dispose();
}

/// Exception thrown when runtime operations fail
class RuntimeException implements Exception {
  final String message;
  final dynamic originalError;

  RuntimeException(this.message, [this.originalError]);

  @override
  String toString() => 'RuntimeException: $message${originalError != null ? ' ($originalError)' : ''}';
}
