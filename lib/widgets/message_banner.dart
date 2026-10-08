import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

enum MessageTone { error, info }

/// Inline banner from the design: tinted box, round "!" badge, message.
class MessageBanner extends StatelessWidget {
  const MessageBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = MessageTone.error,
  });

  final String message;
  final String? title;
  final MessageTone tone;

  @override
  Widget build(BuildContext context) {
    final isError = tone == MessageTone.error;
    final accent = isError ? AppColors.danger : AppColors.brand;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError ? AppColors.dangerSoft : AppColors.brandSoft,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isError ? AppColors.dangerLine : const Color(0xFFD8D4FF),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isError ? AppColors.dangerIconBg : Colors.white,
              ),
              child: Text(
                isError ? '!' : 'i',
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        title!,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Text(
                    message,
                    style: TextStyle(
                      color: isError ? AppColors.dangerMuted : AppColors.muted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
