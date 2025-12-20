import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AudioPlayerWidget extends StatelessWidget {
  final bool isPlaying;
  final double progress;
  final VoidCallback onPlayPause;
  final VoidCallback? onDownload;

  const AudioPlayerWidget({
    super.key,
    required this.isPlaying,
    required this.progress,
    required this.onPlayPause,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPlayPause,
                icon: Icon(
                  isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 48,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generated Audio',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppTheme.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ),
              ),
              if (onDownload != null)
                IconButton(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_rounded),
                  color: AppTheme.textSecondary,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
