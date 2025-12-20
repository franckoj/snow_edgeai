/// Model runtime types supported by the application
enum RuntimeType {
  onnx,
  llamaCpp,
}

/// Model download and load status
enum ModelStatus {
  notDownloaded,
  downloading,
  downloaded,
  loading,
  loaded,
  error,
}

/// Model information and metadata
class ModelInfo {
  final String id;
  final String name;
  final String description;
  final RuntimeType runtime;
  final int sizeBytes;
  final String downloadUrl;
  final String filename;
  final Map<String, dynamic> config;
  final String? sha256;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.runtime,
    required this.sizeBytes,
    required this.downloadUrl,
    required this.filename,
    required this.config,
    this.sha256,
  });

  /// Get human-readable size
  String get sizeFormatted {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    } else if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Get runtime display name
  String get runtimeName {
    switch (runtime) {
      case RuntimeType.onnx:
        return 'ONNX Runtime';
      case RuntimeType.llamaCpp:
        return 'llama.cpp';
    }
  }

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      runtime: json['runtime'] == 'onnx' 
          ? RuntimeType.onnx 
          : RuntimeType.llamaCpp,
      sizeBytes: json['sizeBytes'] as int,
      downloadUrl: json['downloadUrl'] as String,
      filename: json['filename'] as String,
      config: Map<String, dynamic>.from(json['config'] as Map),
      sha256: json['sha256'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'runtime': runtime == RuntimeType.onnx ? 'onnx' : 'llamacpp',
      'sizeBytes': sizeBytes,
      'downloadUrl': downloadUrl,
      'filename': filename,
      'config': config,
      'sha256': sha256,
    };
  }
}

/// Generation configuration parameters
class GenerationConfig {
  final int maxTokens;
  final double temperature;
  final int topK;
  final double topP;
  final double repeatPenalty;

  const GenerationConfig({
    this.maxTokens = 512,
    this.temperature = 0.7,
    this.topK = 50,
    this.topP = 0.9,
    this.repeatPenalty = 1.1,
  });

  GenerationConfig copyWith({
    int? maxTokens,
    double? temperature,
    int? topK,
    double? topP,
    double? repeatPenalty,
  }) {
    return GenerationConfig(
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      topK: topK ?? this.topK,
      topP: topP ?? this.topP,
      repeatPenalty: repeatPenalty ?? this.repeatPenalty,
    );
  }
}
