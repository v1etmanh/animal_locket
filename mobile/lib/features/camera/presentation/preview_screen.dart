import 'dart:typed_data';

import 'package:animal_locket/core/network/api_problem.dart';
import 'package:animal_locket/core/network/error_messages.dart';
import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/core/widgets/gradient_button.dart';
import 'package:animal_locket/features/camera/presentation/upload_controller.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key, this.imagePath});
  final String? imagePath;

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final path = widget.imagePath;
    if (path == null) return;
    await ref
        .read(uploadControllerProvider.notifier)
        .publish(input: XFile(path), caption: _caption.text);
  }

  @override
  Widget build(BuildContext context) {
    final upload = ref.watch(uploadControllerProvider);
    final busy =
        upload.stage == UploadStage.preparing ||
        upload.stage == UploadStage.uploading ||
        upload.stage == UploadStage.processing;
    return AppPage(
      title: 'Xem trước',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: widget.imagePath == null
                  ? const ColoredBox(
                      color: AppColors.border,
                      child: Center(
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    )
                  : FutureBuilder<List<int>>(
                      future: XFile(widget.imagePath!).readAsBytes(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return Image.memory(
                          Uint8List.fromList(snapshot.data!),
                          fit: BoxFit.cover,
                        );
                      },
                    ),
            ),
          ),
          if (upload.stage != UploadStage.idle) ...[
            const SizedBox(height: 18),
            Text(
              upload.label,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: upload.stage == UploadStage.processing
                  ? upload.progress.clamp(0, .9)
                  : upload.progress,
              minHeight: 9,
              borderRadius: BorderRadius.circular(10),
              color: upload.stage == UploadStage.rejected
                  ? AppColors.danger
                  : AppColors.purple,
              backgroundColor: AppColors.border,
            ),
            const SizedBox(height: 7),
            Text(
              'Tiến trình ước lượng ${(upload.progress.clamp(0, .9) * 100).round()}%',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          if (upload.stage == UploadStage.failed) ...[
            const SizedBox(height: 10),
            Text(
              upload.error is ApiProblem
                  ? messageForApiCode(
                      (upload.error! as ApiProblem).code,
                      status: (upload.error! as ApiProblem).status,
                    )
                  : 'Không thể đăng ảnh. Vui lòng kiểm tra mạng và thử lại.',
              style: const TextStyle(color: AppColors.danger),
            ),
          ],
          if (upload.stage == UploadStage.rejected) ...[
            const SizedBox(height: 10),
            Text(
              upload.rejectReason ?? 'Ảnh không được chấp nhận.',
              style: const TextStyle(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: _caption,
            enabled: !busy,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Lời nhắn',
              hintText: 'Viết gì đó cho bạn bè…',
            ),
          ),
          const SizedBox(height: 10),
          GradientButton(
            label: upload.stage == UploadStage.ready
                ? 'Xem trong feed'
                : busy
                ? 'Đang xử lý…'
                : 'Gửi cho bạn bè',
            green: true,
            icon: Icons.send_rounded,
            onPressed: busy
                ? null
                : upload.stage == UploadStage.ready
                ? () {
                    ref.read(uploadControllerProvider.notifier).reset();
                    context.go('/feed');
                  }
                : _publish,
          ),
          TextButton(
            onPressed: busy
                ? null
                : () {
                    ref.read(uploadControllerProvider.notifier).reset();
                    context.pop();
                  },
            child: const Text('Chụp lại'),
          ),
          const Text(
            'Ảnh được gửi cho toàn bộ bạn bè. Bản đầu chưa hỗ trợ chọn từng người nhận.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
