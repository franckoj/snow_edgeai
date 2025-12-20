import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GenerateButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isPlaying;

  const GenerateButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: AppTheme.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textPrimary),
                ),
              )
            else
              Icon(
                isPlaying ? Icons.stop_rounded : Icons.auto_awesome_rounded,
                size: 24,
              ),
            const SizedBox(width: AppTheme.spacingMd),
            Text(
              isLoading
                  ? 'Generating...'
                  : isPlaying
                      ? 'Stop Playback'
                      : 'Generate Speech',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
