import 'package:animal_locket/core/network/api_problem.dart';
import 'package:animal_locket/core/network/error_messages.dart';
import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/features/camera/presentation/upload_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Viên trạng thái nhỏ nổi trên camera: "Đang gửi…" → "Đã gửi ✓" (tự ẩn) hoặc lỗi + "Thử lại".
class SendStatusPill extends ConsumerWidget {
  const SendStatusPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upload = ref.watch(uploadControllerProvider);
    final notifier = ref.read(uploadControllerProvider.notifier);
    final Widget content = switch (upload.stage) {
      UploadStage.idle => const SizedBox.shrink(key: ValueKey('idle')),
      UploadStage.sending => const _Pill(
        key: ValueKey('sending'),
        leading: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        text: 'Đang gửi…',
      ),
      UploadStage.sent => _Pill(
        key: const ValueKey('sent'),
        leading: const Icon(Icons.check_circle, color: Colors.white, size: 18),
        text: 'Đã gửi',
        color: AppColors.green,
        actionLabel: 'Xem',
        onAction: () {
          notifier.dismiss();
          context.go('/feed');
        },
      ),
      UploadStage.rejected => _Pill(
        key: const ValueKey('rejected'),
        leading: const Icon(Icons.block, color: Colors.white, size: 18),
        text: 'Ảnh không được chấp nhận',
        color: AppColors.danger,
        onClose: notifier.dismiss,
      ),
      UploadStage.failed => _Pill(
        key: const ValueKey('failed'),
        leading: const Icon(Icons.error_outline, color: Colors.white, size: 18),
        text: _failureText(upload.error),
        color: AppColors.danger,
        actionLabel: 'Thử lại',
        onAction: notifier.retry,
        onClose: notifier.dismiss,
      ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: content,
    );
  }

  static String _failureText(Object? error) => error is ApiProblem
      ? messageForApiCode(error.code, status: error.status)
      : 'Gửi lỗi, kiểm tra mạng';
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.leading,
    required this.text,
    this.color,
    this.actionLabel,
    this.onAction,
    this.onClose,
  });

  final Widget leading;
  final String text;
  final Color? color;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(
        color: (color ?? Colors.black).withValues(alpha: .72),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
              ),
            )
          else
            const SizedBox(width: 8),
          if (onClose != null)
            IconButton(
              tooltip: 'Đóng',
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
        ],
      ),
    ),
  );
}
