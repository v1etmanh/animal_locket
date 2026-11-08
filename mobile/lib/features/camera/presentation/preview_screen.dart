import 'dart:typed_data';

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

  /// Gửi chạy nền rồi quay về camera ngay; trạng thái "Đang gửi / Đã gửi" hiện ở màn hình camera.
  void _publish() {
    final path = widget.imagePath;
    if (path == null) return;
    final started = ref
        .read(uploadControllerProvider.notifier)
        .publish(input: XFile(path), caption: _caption.text);
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang gửi ảnh trước, đợi chút nhé.')),
      );
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final sending = ref.watch(uploadControllerProvider).sending;
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
          const SizedBox(height: 18),
          TextField(
            controller: _caption,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Lời nhắn',
              hintText: 'Viết gì đó cho bạn bè…',
            ),
          ),
          const SizedBox(height: 10),
          GradientButton(
            label: sending ? 'Đang gửi ảnh trước…' : 'Gửi cho bạn bè',
            green: true,
            icon: Icons.send_rounded,
            onPressed: sending ? null : _publish,
          ),
          TextButton(
            onPressed: () => context.pop(),
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
