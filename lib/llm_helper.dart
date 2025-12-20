import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

final llmLogger = Logger(
  printer: PrettyPrinter(methodCount: 0, errorMethodCount: 5, lineLength: 80),
);

/// Simple tokenizer for basic text processing
/// For production use, consider integrating a proper tokenizer like SentencePiece
class SimpleTokenizer {
  final Map<String, int> vocab;
  final Map<int, String> reverseVocab;
  final int padTokenId;
  final int bosTokenId;
  final int eosTokenId;

  SimpleTokenizer._({
    required this.vocab,
    required this.reverseVocab,
    required this.padTokenId,
    required this.bosTokenId,
    required this.eosTokenId,
  });

  static Future<SimpleTokenizer> load(String vocabPath) async {
    try {
      final jsonString = vocabPath.startsWith('assets/')
          ? await rootBundle.loadString(vocabPath)
          : await File(vocabPath).readAsString();
          
      final json = jsonDecode(jsonString);

      final vocab = Map<String, int>.from(json['vocab'] ?? {});
      final reverseVocab = vocab.map((k, v) => MapEntry(v, k));

      return SimpleTokenizer._(
        vocab: vocab,
        reverseVocab: reverseVocab,
        padTokenId: json['pad_token_id'] ?? 0,
        bosTokenId: json['bos_token_id'] ?? 1,
        eosTokenId: json['eos_token_id'] ?? 2,
      );
    } catch (e) {
      llmLogger.w('Failed to load vocab from $vocabPath, falling back to basic tokenizer: $e');
      return createBasic();
    }
  }

  /// Create a basic character-level tokenizer (fallback if no vocab file)
  static SimpleTokenizer createBasic() {
    final chars = ' abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?;:\'-()[]{}"\n';
    final vocab = <String, int>{};
    
    vocab['<pad>'] = 0;
    vocab['<bos>'] = 1;
    vocab['<eos>'] = 2;
    vocab['<unk>'] = 3;
    
    for (var i = 0; i < chars.length; i++) {
      vocab[chars[i]] = i + 4;
    }

    final reverseVocab = vocab.map((k, v) => MapEntry(v, k));

    return SimpleTokenizer._(
      vocab: vocab,
      reverseVocab: reverseVocab,
      padTokenId: 0,
      bosTokenId: 1,
      eosTokenId: 2,
    );
  }

  List<int> encode(String text, {bool addBos = true, bool addEos = false}) {
    final tokens = <int>[];
    
    if (addBos) tokens.add(bosTokenId);

    // Simple character-level tokenization
    for (var char in text.split('')) {
      tokens.add(vocab[char] ?? vocab['<unk>'] ?? 3);
    }

    if (addEos) tokens.add(eosTokenId);

    return tokens;
  }

  String decode(List<int> tokens, {bool skipSpecialTokens = true}) {
    final chars = <String>[];
    
    for (var token in tokens) {
      if (skipSpecialTokens && 
          (token == padTokenId || token == bosTokenId || token == eosTokenId)) {
        continue;
      }
      chars.add(reverseVocab[token] ?? '<unk>');
    }

    return chars.join('');
  }
}

/// LLM Inference class for running ONNX language models
class LLMInference {
  final OrtSession session;
  final SimpleTokenizer tokenizer;
  final int maxLength;
  final int vocabSize;

  LLMInference._({
    required this.session,
    required this.tokenizer,
    required this.maxLength,
    required this.vocabSize,
  });

  static Future<LLMInference> load(
    String modelPath, {
    String? vocabPath,
    int maxLength = 512,
    int vocabSize = 32000,
  }) async {
    llmLogger.i('Loading LLM model from $modelPath');

    // Load tokenizer
    final tokenizer = vocabPath != null
        ? await SimpleTokenizer.load(vocabPath)
        : SimpleTokenizer.createBasic();

    // Load ONNX model
    final ort = OnnxRuntime();
    final modelFilePath = await _copyModelToFile(modelPath);
    final session = await ort.createSession(modelFilePath);

    llmLogger.i('LLM model loaded successfully');

    return LLMInference._(
      session: session,
      tokenizer: tokenizer,
      maxLength: maxLength,
      vocabSize: vocabSize,
    );
  }

  /// Generate text from a prompt
  Future<String> generate(
    String prompt, {
    int maxNewTokens = 100,
    double temperature = 0.7,
    int topK = 50,
    double topP = 0.9,
    Function(String)? onToken,
  }) async {
    try {
      // Encode prompt
      final inputIds = tokenizer.encode(prompt, addBos: true, addEos: false);
      
      llmLogger.d('Input tokens: ${inputIds.length}');

      // Generate tokens
      final generatedTokens = await _generateTokens(
        inputIds,
        maxNewTokens: maxNewTokens,
        temperature: temperature,
        topK: topK,
        topP: topP,
        onToken: onToken,
      );

      // Decode response
      final response = tokenizer.decode(generatedTokens, skipSpecialTokens: true);
      
      return response;
    } catch (e, stackTrace) {
      llmLogger.e('Error during generation', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<int>> _generateTokens(
    List<int> inputIds, {
    required int maxNewTokens,
    required double temperature,
    required int topK,
    required double topP,
    Function(String)? onToken,
  }) async {
    final currentIds = List<int>.from(inputIds);
    final generated = <int>[];

    for (var i = 0; i < maxNewTokens; i++) {
      // Prepare input tensor
      final inputLength = currentIds.length;
      final inputTensor = await OrtValue.fromList(
        Int64List.fromList(currentIds),
        [1, inputLength],
      );

      // Run inference
      final result = await session.run({
        'input_ids': inputTensor,
      });

      // Get logits (assuming output name is 'logits')
      final logitsValue = result.values.first;
      final logits = await logitsValue.asList();

      // Get last token logits
      final lastLogits = _getLastTokenLogits(logits as List<double>, vocabSize);

      // Apply temperature and sampling
      final nextToken = _sampleToken(
        lastLogits,
        temperature: temperature,
        topK: topK,
        topP: topP,
      );

      // Check for EOS token
      if (nextToken == tokenizer.eosTokenId) {
        break;
      }

      generated.add(nextToken);
      currentIds.add(nextToken);

      // Callback for streaming
      if (onToken != null) {
        final tokenStr = tokenizer.decode([nextToken], skipSpecialTokens: true);
        onToken(tokenStr);
      }

      // Prevent context overflow
      if (currentIds.length >= maxLength) {
        llmLogger.w('Reached max context length');
        break;
      }
    }

    return generated;
  }

  List<double> _getLastTokenLogits(List<double> logits, int vocabSize) {
    // Assuming logits shape is [batch_size, sequence_length, vocab_size]
    // We want the last sequence position
    final lastPosition = logits.length - vocabSize;
    return logits.sublist(lastPosition, logits.length);
  }

  int _sampleToken(
    List<double> logits, {
    required double temperature,
    required int topK,
    required double topP,
  }) {
    // Apply temperature
    final scaledLogits = logits.map((l) => l / temperature).toList();

    // Convert to probabilities (softmax)
    final expLogits = scaledLogits.map((l) => _exp(l)).toList();
    final sumExp = expLogits.reduce((a, b) => a + b);
    final probs = expLogits.map((e) => e / sumExp).toList();

    // Top-k sampling
    final indexed = List.generate(probs.length, (i) => MapEntry(i, probs[i]));
    indexed.sort((a, b) => b.value.compareTo(a.value));
    final topKIndices = indexed.take(topK).toList();

    // Top-p (nucleus) sampling
    var cumProb = 0.0;
    final nucleusIndices = <MapEntry<int, double>>[];
    for (var entry in topKIndices) {
      cumProb += entry.value;
      nucleusIndices.add(entry);
      if (cumProb >= topP) break;
    }

    // Normalize probabilities
    final nucleusSum = nucleusIndices.fold<double>(0.0, (sum, e) => sum + e.value);
    final normalizedProbs = nucleusIndices.map((e) => e.value / nucleusSum).toList();

    // Sample from distribution
    final random = _random.nextDouble();
    var cumulativeProb = 0.0;
    for (var i = 0; i < normalizedProbs.length; i++) {
      cumulativeProb += normalizedProbs[i];
      if (random <= cumulativeProb) {
        return nucleusIndices[i].key;
      }
    }

    return nucleusIndices.last.key;
  }

  double _exp(double x) {
    // Simple exp approximation to avoid overflow
    if (x > 20) return double.maxFinite;
    if (x < -20) return 0.0;
    return _e.pow(x);
  }

  static const _e = 2.718281828459045;
  static final _random = Random();
}

// Random number generator
class Random {
  int _seed = DateTime.now().millisecondsSinceEpoch;

  double nextDouble() {
    _seed = (1103515245 * _seed + 12345) % 2147483648;
    return _seed / 2147483648;
  }
}

// Helper to copy model to file system
Future<String> _copyModelToFile(String path) async {
  // If it's already an absolute path to a file that exists, just return it
  if (File(path).existsSync()) {
    return path;
  }

  try {
    final byteData = await rootBundle.load(path);
    final tempDir = await getApplicationCacheDirectory();
    final modelPath = '${tempDir.path}/${path.split("/").last}';

    final file = File(modelPath);
    if (!file.existsSync()) {
      await file.writeAsBytes(byteData.buffer.asUint8List());
    }
    
    return modelPath;
  } catch (e) {
    if (path.startsWith('/')) {
      // It was intended to be a file but doesn't exist
      throw FileSystemException('Model file not found', path);
    }
    rethrow;
  }
}

// Extension for power operation
extension NumExtension on num {
  double pow(num exponent) {
    return _pow(toDouble(), exponent.toDouble());
  }
}

double _pow(double base, double exponent) {
  if (exponent == 0) return 1.0;
  if (exponent == 1) return base;
  
  var result = 1.0;
  var absExp = exponent.abs().toInt();
  
  for (var i = 0; i < absExp; i++) {
    result *= base;
  }
  
  return exponent < 0 ? 1 / result : result;
}
