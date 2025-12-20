import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VoiceSelector extends StatelessWidget {
  final String selectedVoice;
  final Function(String) onVoiceSelected;

  const VoiceSelector({
    super.key,
    required this.selectedVoice,
    required this.onVoiceSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Voice',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Row(
          children: [
            Expanded(
              child: _VoiceOption(
                label: 'Female',
                isSelected: selectedVoice.startsWith('F'),
                onTap: () => onVoiceSelected('F1'),
                icon: Icons.female_rounded,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: _VoiceOption(
                label: 'Male',
                isSelected: selectedVoice.startsWith('M'),
                onTap: () => onVoiceSelected('M1'),
                icon: Icons.male_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VoiceOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;

  const _VoiceOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: AppTheme.textPrimary,
              size: 32,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
