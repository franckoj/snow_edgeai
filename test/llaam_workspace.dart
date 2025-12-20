import 'package:flutter_llama/flutter_llama.dart';




void main() {
  final llama = FlutterLlama.instance;
  // Using braindler Q4_K_M quantization (88MB - optimal balance)
final config = LlamaConfig(
  modelPath: 'assets/models/qwen/Qwen3-0.6B-Q8_0.gguf',  // braindler from ollama.com/nativemind/braindler
  nThreads: 4,
  nGpuLayers: 0,  // 0 = CPU only, -1 = all layers on GPU
  contextSize: 2048,
  batchSize: 512,
  useGpu: true,
  verbose: false,
);

final success = await llama.loadModel(config);
if (success) {
  print('Braindler model loaded successfully!');
}

  print('Hello, World!');
}