import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatMessageWidget extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageWidget({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            _buildAvatar(context, isUser: false),
            const SizedBox(width: AppTheme.spacingSm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _buildMessageBubble(context),
                const SizedBox(height: 4),
                _buildTimestamp(context),
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: AppTheme.spacingSm),
            _buildAvatar(context, isUser: true),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, {required bool isUser}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser ? AppTheme.primary : AppTheme.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: isUser ? AppTheme.primary : AppTheme.textSecondary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.psychology_rounded,
        size: 18,
        color: isUser ? Colors.white : AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _copyToClipboard(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? AppTheme.primary
              : AppTheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppTheme.radiusMd),
            topRight: const Radius.circular(AppTheme.radiusMd),
            bottomLeft: Radius.circular(
              message.isUser ? AppTheme.radiusMd : AppTheme.radiusSm,
            ),
            bottomRight: Radius.circular(
              message.isUser ? AppTheme.radiusSm : AppTheme.radiusMd,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: message.isUser ? Colors.white : AppTheme.textPrimary,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.content_copy_rounded,
                size: 12,
                color: (message.isUser ? Colors.white : AppTheme.textSecondary)
                    .withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context) {
    final timeStr = _formatTime(message.timestamp);
    return Text(
      timeStr,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary.withOpacity(0.7),
            fontSize: 11,
          ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
      ),
    );
  }
}
