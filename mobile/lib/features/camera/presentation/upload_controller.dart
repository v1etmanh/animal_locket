import 'package:animal_locket/features/camera/data/image_preparation_service.dart';
import 'package:animal_locket/features/camera/data/media_repository_impl.dart';
import 'package:animal_locket/features/camera/domain/media_repository.dart';
import 'package:animal_locket/features/feed/data/post_repository_impl.dart';
import 'package:animal_locket/features/feed/domain/post_repository.dart';
import 'package:animal_locket/features/feed/presentation/feed_controller.dart';
import 'package:animal_locket/features/feed/presentation/my_posts_grid.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UploadStage {
  idle,
  preparing,
  uploading,
  processing,
  ready,
  rejected,
  failed,
}

class UploadFlowState {
  const UploadFlowState({
    this.stage = UploadStage.idle,
    this.progress = 0,
    this.label = '',
    this.post,
    this.rejectReason,
    this.error,
  });

  final UploadStage stage;
  final double progress;
  final String label;
  final Post? post;
  final String? rejectReason;
  final Object? error;
}

class UploadController extends Notifier<UploadFlowState> {
  @override
  UploadFlowState build() => const UploadFlowState();

  Future<void> publish({required XFile input, String? caption}) async {
    PreparedImage? prepared;
    try {
      state = const UploadFlowState(
        stage: UploadStage.preparing,
        progress: .05,
        label: 'Đang chuẩn bị ảnh',
      );
      prepared = await const ImagePreparationService().prepare(input);
      final media = ref.read(mediaRepositoryProvider);
      final ticket = await media.createUpload(
        context: MediaContext.post,
        contentType: prepared.contentType,
        sizeBytes: prepared.sizeBytes,
      );
      state = const UploadFlowState(
        stage: UploadStage.uploading,
        progress: .12,
        label: 'Đang tải ảnh lên',
      );
      await media.uploadFile(
        ticket: ticket,
        file: prepared.file,
        contentType: prepared.contentType,
        onProgress: (sent, total) {
          if (total <= 0) return;
          state = UploadFlowState(
            stage: UploadStage.uploading,
            progress: .12 + (sent / total * .33),
            label: 'Đang tải ảnh lên',
          );
        },
      );
      await media.complete(ticket.mediaId);
      final post = await ref
          .read(postRepositoryProvider)
          .create(mediaId: ticket.mediaId, caption: caption);
      state = UploadFlowState(
        stage: UploadStage.processing,
        progress: .68,
        label: 'Đang đổi mặt thành con vật',
        post: post,
      );
      ref.invalidate(myPostsProvider);
      final result = await media.waitUntilProcessed(ticket.mediaId);
      // Bài đã đổi trạng thái (PUBLISHED/REJECTED): tải lại feed và lưới ảnh hồ sơ.
      ref
        ..invalidate(myPostsProvider)
        ..invalidate(feedControllerProvider);
      if (result.status == MediaStatus.rejected) {
        state = UploadFlowState(
          stage: UploadStage.rejected,
          progress: 1,
          label: 'Ảnh không được chấp nhận',
          post: post,
          rejectReason: result.rejectReason,
        );
      } else {
        state = UploadFlowState(
          stage: UploadStage.ready,
          progress: 1,
          label: 'Ảnh đã sẵn sàng',
          post: post,
        );
      }
    } catch (error) {
      state = UploadFlowState(
        stage: UploadStage.failed,
        progress: state.progress,
        label: 'Không thể đăng ảnh',
        error: error,
      );
    } finally {
      await prepared?.cleanup();
    }
  }

  void reset() => state = const UploadFlowState();
}

final uploadControllerProvider =
    NotifierProvider<UploadController, UploadFlowState>(UploadController.new);
