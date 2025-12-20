import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sdk/helper.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/voice_selector.dart';
import '../widgets/quality_slider.dart';
import '../widgets/generate_button.dart';
import '../widgets/audio_player_widget.dart';
import '../models/model_info.dart';
import '../services/model_manager.dart';
import '../screens/tts_model_selection_screen.dart';

final logger = Logger(level: Level.all);

class TTSScreen extends StatefulWidget {
  const TTSScreen({super.key});

  @override
  State<TTSScreen> createState() => _TTSScreenState();
}

class _TTSScreenState extends State<TTSScreen> {
  final TextEditingController _textController = TextEditingController(
    text: 'Hello, welcome to Snow Edge AI. This is a truly offline text to speech demo running on your device.',
  );
  final AudioPlayer _audioPlayer = AudioPlayer();

  TextToSpeech? _textToSpeech;
  Style? _style;
  bool _isLoading = false;
  bool _isGenerating = false;
  String _status = 'Initializing...';
  int _totalSteps = 10;
  double _speed = 1.0;
  bool _isPlaying = false;
  String? _lastGeneratedFilePath;
  String _selectedVoice = 'F1';
  
  ModelInfo? _loadedModelInfo;

  @override
  void initState() {
    super.initState();
    _loadLastModel();
    _setupAudioPlayerListeners();
  }

  Future<void> _loadLastModel() async {
     // Try to load last selected model
    final prefs = await SharedPreferences.getInstance();
    String? lastId = prefs.getString('last_tts_model_id');
    
    // Default to bundled model if no preference
    lastId ??= 'bundled-tts-en';

    if (lastId != null) {
      try {
        // Ensure catalog is loaded
        await ModelManager().getAvailableModels();
        final model = ModelManager().getModelById(lastId);
        if (model != null && ModelManager().isModelDownloaded(lastId)) {
          await _loadSpecificModel(model);
          return;
        }
      } catch (e) {
        // Model might not exist in catalog or not downloaded
        logger.w('Failed to load last model: $lastId', error: e);
      }
    }
    
    // If we still haven't loaded anything, try loading the bundled model explicitly
    try {
       await ModelManager().getAvailableModels();
       final bundled = ModelManager().getModelById('bundled-tts-en');
       if (bundled != null) {
         await _loadSpecificModel(bundled);
         return;
       }
    } catch (e) {
       logger.e('Failed to load bundled fallback', error: e);
    }
    
    // If no model loaded, update status
    setState(() {
      _status = 'Please select a voice model';
      _isLoading = false;
    });
  }

  Future<void> _showModelSelector() async {
    final ModelInfo? selectedModel = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TTSModelSelectionScreen()),
    );

    if (selectedModel != null) {
      await _loadSpecificModel(selectedModel);
    }
  }

  Future<void> _loadSpecificModel(ModelInfo model) async {
    setState(() {
      _isLoading = true;
      _status = 'Loading ${model.name}...';
    });
    
    try {
      String modelPath;
      
      if (model.config['isBundled'] == true) {
        // Bundled model in assets
        modelPath = model.filename; // Should be 'assets/onnx'
      } else {
        // Downloaded model
        final dir = await getApplicationDocumentsDirectory();
        final modelDirName = model.filename.replaceAll('.zip', '');
        modelPath = '${dir.path}/models/onnx/$modelDirName';
      }

      // Load ONNX models from that path
      _textToSpeech = await loadTextToSpeech(modelPath, useGpu: false);
      
      // Load default voice style
      await _loadVoiceStyle(_selectedVoice);

      // Save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_tts_model_id', model.id);

      setState(() {
        _loadedModelInfo = model;
        _isLoading = false;
        _status = 'Ready: ${model.name}';
      });
    } catch (e, stackTrace) {
      logger.e('Error loading model', error: e, stackTrace: stackTrace);
      setState(() {
        _isLoading = false;
        _status = 'Error: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load model: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _setupAudioPlayerListeners() {
    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;

      setState(() {
        _isPlaying = state.playing;

        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.pause();
        }
      });
    });
  }

  Future<void> _unloadModels() async {
    if (_textToSpeech != null) {
      await _textToSpeech!.release();
      _textToSpeech = null;
      _style = null;
      
      // Force garbage collection of large buffers if possible
      setState(() {
        _status = 'Models unloaded';
        _isLoading = false;
        _loadedModelInfo = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TTS models unloaded')),
        );
      }
    }
  }

  Future<void> _loadVoiceStyle(String voiceName) async {
    try {
      _style = await loadVoiceStyle(['assets/voice_styles/$voiceName.json']);
      setState(() => _selectedVoice = voiceName);
    } catch (e) {
      logger.e('Error loading voice style', error: e);
    }
  }

  Future<void> _generateSpeech() async {
    if (_textToSpeech == null || _style == null) return;

    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _status = 'Synthesizing speech...';
    });

    List<double>? wav;

    try {
      final result = await _textToSpeech!.call(
        _textController.text,
        _style!,
        _totalSteps,
        speed: _speed,
      );

      wav = result['wav'] is List<double>
          ? result['wav']
          : (result['wav'] as List).cast<double>();
          
      // Save to file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/speech_$timestamp.wav';

      writeWavFile(outputPath, wav!, _textToSpeech!.sampleRate);

      final file = File(outputPath);
      if (!file.existsSync()) {
        throw Exception('Failed to create WAV file');
      }

      final absolutePath = file.absolute.path;

      setState(() {
        _isGenerating = false;
        _status = 'Ready';
        _lastGeneratedFilePath = absolutePath;
      });

      // Auto play
      final uri = Uri.file(absolutePath);
      await _audioPlayer.setAudioSource(AudioSource.uri(uri));
      await _audioPlayer.play();
      
    } catch (e) {
      logger.e('Error generating speech', error: e);
      setState(() {
        _isGenerating = false;
        _status = 'Error';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generation failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_audioPlayer.processingState == ProcessingState.completed) {
        await _audioPlayer.seek(Duration.zero);
      }
      await _audioPlayer.play();
    }
  }

  @override
  void dispose() {
    _textToSpeech?.release();
    _textController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text to Speech'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_textToSpeech == null)
            IconButton(
              icon: const Icon(Icons.manage_search_rounded),
              tooltip: 'Manage Models',
              onPressed: _showModelSelector,
            )
          else
            IconButton(
              icon: const Icon(Icons.eject_rounded),
              tooltip: 'Unload Model',
              onPressed: _unloadModels,
            ),
        ],
      ),
      // ... body

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text Input
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Enter text to synthesize...',
                alignLabelWithHint: true,
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTheme.spacingXl),

            // Voice Selector
            VoiceSelector(
              selectedVoice: _selectedVoice,
              onVoiceSelected: (voice) async {
                await _loadVoiceStyle(voice);
              },
            ),
            const SizedBox(height: AppTheme.spacingXl),

            // Quality Sliders
            QualitySlider(
              label: 'Quality (Steps)',
              value: _totalSteps.toDouble(),
              min: 5,
              max: 20,
              divisions: 15,
              onChanged: (value) => setState(() => _totalSteps = value.toInt()),
              labelFormatter: (val) => val.toInt().toString(),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            QualitySlider(
              label: 'Speed',
              value: _speed,
              min: 0.5,
              max: 1.5,
              divisions: 10,
              onChanged: (value) => setState(() => _speed = value),
              labelFormatter: (val) => '${val.toStringAsFixed(1)}x',
            ),
            const SizedBox(height: AppTheme.spacingXl),

            // Generate Button
            GenerateButton(
              onPressed: _generateSpeech,
              isLoading: _isLoading || _isGenerating,
              isPlaying: _isPlaying && _isGenerating, // Only show stop if generating
            ),
            
            // Audio Player
            if (_lastGeneratedFilePath != null && !_isGenerating) ...[
              const SizedBox(height: AppTheme.spacingXl),
              AudioPlayerWidget(
                isPlaying: _isPlaying,
                progress: 0.0, // TODO: Implement progress stream
                onPlayPause: _togglePlayback,
              ),
            ],
            
            // Status Text (Debug)
            if (_isLoading || _isGenerating) ...[
              const SizedBox(height: AppTheme.spacingMd),
              Center(
                child: Text(
                  _status,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
