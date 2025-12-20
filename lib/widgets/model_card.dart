import 'package:flutter/material.dart';
import '../models/model_info.dart';
import '../theme/app_theme.dart';

class ModelCard extends StatelessWidget {
  final ModelInfo model;
  final bool isDownloaded;
  final bool isDownloading;
  final double? downloadProgress;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onSelect;

  const ModelCard({
    super.key,
    required this.model,
    required this.isDownloaded,
    this.isDownloading = false,
    this.downloadProgress,
    this.onDownload,
    this.onDelete,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      child: InkWell(
        onTap: isDownloaded ? onSelect : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          model.sizeFormatted,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  _buildRuntimeBadge(context),
                ],
              ),
              const SizedBox(height: AppTheme.spacingSm),

              // Description
              Text(
                model.description,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTheme.spacingMd),

              // Progress bar (if downloading)
              if (isDownloading && downloadProgress != null) ...[
                LinearProgressIndicator(
                  value: downloadProgress! / 100,
                  backgroundColor: AppTheme.surface,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  '${downloadProgress!.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppTheme.spacingSm),
              ],

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isDownloaded && !isDownloading)
                    OutlinedButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download'),
                    ),
                  if (isDownloading)
                    OutlinedButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Cancel'),
                    ),
                  if (isDownloaded) ...[
                    if (model.config['isBundled'] != true)
                      OutlinedButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                        ),
                      ),
                    const SizedBox(width: AppTheme.spacingSm),
                    FilledButton.icon(
                      onPressed: onSelect,
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text('Use Model'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuntimeBadge(BuildContext context) {
    final color = model.runtime == RuntimeType.onnx 
        ? Colors.blue 
        : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        model.runtimeName,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
      ),
    );
  }
}
