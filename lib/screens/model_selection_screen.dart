import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../models/model_info.dart';
import '../services/model_manager.dart';
import '../services/download_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/model_card.dart';

final _logger = Logger();

class ModelSelectionScreen extends StatefulWidget {
  const ModelSelectionScreen({super.key});

  @override
  State<ModelSelectionScreen> createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends State<ModelSelectionScreen> {
  final ModelManager _modelManager = ModelManager();
  final DownloadManager _downloadManager = DownloadManager();

  List<ModelInfo> _models = [];
  Set<String> _downloadingModels = {};
  Map<String, double> _downloadProgress = {};
  bool _isLoading = true;
  RuntimeType? _filterRuntime;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);

    try {
      final models = await _modelManager.getAvailableModels();
      setState(() {
        _models = models;
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

  List<ModelInfo> _getFilteredModels() {
    if (_filterRuntime == null) return _models;
    return _models.where((m) => m.runtime == _filterRuntime).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredModels = _getFilteredModels();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Model'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<RuntimeType?>(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filter by runtime',
            onSelected: (runtime) {
              setState(() => _filterRuntime = runtime);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Runtimes'),
              ),
              const PopupMenuItem(
                value: RuntimeType.llamaCpp,
                child: Text('llama.cpp only'),
              ),
              const PopupMenuItem(
                value: RuntimeType.onnx,
                child: Text('ONNX only'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadModels,
              child: filteredModels.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                      itemCount: filteredModels.length,
                      itemBuilder: (context, index) {
                        final model = filteredModels[index];
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
              _filterRuntime == null
                  ? 'No models found in catalog'
                  : 'No ${_filterRuntime == RuntimeType.onnx ? "ONNX" : "llama.cpp"} models available',
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
