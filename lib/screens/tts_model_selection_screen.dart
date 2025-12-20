import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../models/model_info.dart';
import '../services/model_manager.dart';
import '../services/download_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/model_card.dart';

final _logger = Logger();

class TTSModelSelectionScreen extends StatefulWidget {
  const TTSModelSelectionScreen({super.key});

  @override
  State<TTSModelSelectionScreen> createState() => _TTSModelSelectionScreenState();
}

class _TTSModelSelectionScreenState extends State<TTSModelSelectionScreen> {
  final ModelManager _modelManager = ModelManager();
  final DownloadManager _downloadManager = DownloadManager();

  List<ModelInfo> _models = [];
  final Set<String> _downloadingModels = {};
  final Map<String, double> _downloadProgress = {};
  bool _isLoading = true;
  RuntimeType? _filterRuntime; // This variable is no longer used for filtering in _loadModels, but kept as it's not explicitly removed elsewhere.

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);

    try {
      final allModels = await _modelManager.getAvailableModels();
      
      // Filter for TTS models (ONNX + 'tts' string search for now)
      _models = allModels.where((m) => m.runtime == RuntimeType.onnx && (m.id.toLowerCase().contains('tts') || m.description.toLowerCase().contains('speech'))).toList();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _logger.e('Failed to load models', error: e);
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load models: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadModel(ModelInfo model) async {
    setState(() {
      _downloadingModels.add(model.id);
      _downloadProgress[model.id] = 0;
    });

    try {
      await for (final progress in _downloadManager.downloadModel(model)) {
        if (!mounted) break;
        
        setState(() {
          _downloadProgress[model.id] = progress.percentage;
        });
      }

      if (mounted) {
        setState(() {
          _downloadingModels.remove(model.id);
          _downloadProgress.remove(model.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${model.name} downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _logger.e('Download failed', error: e);
      
      if (mounted) {
        setState(() {
          _downloadingModels.remove(model.id);
          _downloadProgress.remove(model.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _cancelDownload(ModelInfo model) {
    _downloadManager.cancelDownload(model.id);
    setState(() {
      _downloadingModels.remove(model.id);
      _downloadProgress.remove(model.id);
    });
  }

  Future<void> _deleteModel(ModelInfo model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete ${model.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _modelManager.deleteModel(model.id);
      setState(() {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${model.name} deleted')),
        );
      }
    }
  }

  void _selectModel(ModelInfo model) {
    Navigator.pop(context, model);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Voice Models'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadModels,
              child: _models.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                      itemCount: _models.length,
                      itemBuilder: (context, index) {
                        final model = _models[index];
                        final isDownloaded = _modelManager.isModelDownloaded(model.id);
                        final isDownloading = _downloadingModels.contains(model.id);
                        final progress = _downloadProgress[model.id];

                        return ModelCard(
                          model: model,
                          isDownloaded: isDownloaded,
                          isDownloading: isDownloading,
                          downloadProgress: progress,
                          onDownload: isDownloading
                              ? () => _cancelDownload(model)
                              : () => _downloadModel(model),
                          onDelete: () => _deleteModel(model),
                          onSelect: () => _selectModel(model),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.model_training_rounded,
              size: 80,
              color: AppTheme.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'No models available',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'No voice models found in catalog',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
