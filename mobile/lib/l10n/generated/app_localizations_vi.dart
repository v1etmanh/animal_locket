// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appName => 'Animal Locket';

  @override
  String get photosTab => 'Ảnh';

  @override
  String get discoverTab => 'Khám phá';

  @override
  String get chatTab => 'Chat';

  @override
  String get profileTab => 'Hồ sơ';

  @override
  String get retry => 'Thử lại';

  @override
  String get genericError => 'Có lỗi xảy ra. Vui lòng thử lại.';

  @override
  String get conversationTitle => 'Trò chuyện';

  @override
  String get messagesLoadError => 'Không thể tải tin nhắn.';

  @override
  String get messageSendFailed =>
      'Tin chưa gửi được. Nội dung vẫn được giữ trên màn hình.';

  @override
  String get messageHint => 'Nhắn tin…';

  @override
  String get sendMessage => 'Gửi tin nhắn';

  @override
  String get sendPhoto => 'Gửi ảnh';

  @override
  String get glyphModeOpen => 'Mở chế độ nhắn bằng ký hiệu';

  @override
  String get glyphModeClose => 'Đóng chế độ nhắn bằng ký hiệu';

  @override
  String get glyphDrawLabel => 'Khung vẽ ký hiệu một nét';

  @override
  String get glyphDrawHint => 'Vẽ một nét vào đây';

  @override
  String get glyphClearStroke => 'Xóa nét vẽ';

  @override
  String get glyphRecognizing => 'Đang nhận diện…';

  @override
  String get glyphNoMatch =>
      'Chưa nhận ra ký hiệu. Bạn có thể vẽ lại hoặc tạo ký hiệu mới.';

  @override
  String get glyphAmbiguous =>
      'Nét vẽ giống nhiều ký hiệu. Hãy chọn kết quả đúng.';

  @override
  String glyphMatched(String meaning) {
    return 'Đã nhận diện $meaning';
  }

  @override
  String get glyphAddToComposer => 'Thêm vào câu';

  @override
  String get glyphQuickPick => 'Chọn nhanh';

  @override
  String get glyphComposerEmpty => 'Chưa có ký hiệu trong câu';

  @override
  String glyphRemoveToken(String meaning) {
    return 'Xóa ký hiệu $meaning';
  }

  @override
  String get glyphClearComposer => 'Xóa toàn bộ câu ký hiệu';

  @override
  String get glyphSend => 'Gửi ký hiệu';

  @override
  String get glyphDictionary => 'Từ điển ký hiệu';

  @override
  String get glyphCreate => 'Tạo ký hiệu';

  @override
  String get glyphSystemTab => 'Hệ thống';

  @override
  String get glyphPersonalTab => 'Cá nhân';

  @override
  String get glyphConversationTab => 'Hội thoại';

  @override
  String get glyphDictionaryEmpty => 'Chưa có ký hiệu trong mục này.';

  @override
  String get glyphDictionaryError => 'Không thể tải từ điển ký hiệu.';

  @override
  String get glyphMeaningLabel => 'Ý nghĩa ký hiệu';

  @override
  String get glyphMeaningHint => 'Ví dụ Đi cà phê không';

  @override
  String get glyphColorLabel => 'Màu ký hiệu';

  @override
  String get glyphSave => 'Lưu ký hiệu';

  @override
  String get glyphDelete => 'Xóa ký hiệu';

  @override
  String get glyphCollisionWarning => 'Nét vẽ quá giống một ký hiệu đã có.';

  @override
  String get glyphTooShort => 'Hãy vẽ một nét rõ hơn.';

  @override
  String get glyphFeatureWaitingBackend =>
      'Gửi ký hiệu đang chờ backend tương thích.';

  @override
  String get glyphShowMeaning => 'Hiện nghĩa ký hiệu';

  @override
  String get glyphHideMeaning => 'Ẩn nghĩa ký hiệu';

  @override
  String get glyphUnknownFallback =>
      'Không tải được hình ký hiệu. Đang hiển thị nội dung thay thế.';

  @override
  String get retryMessage => 'Gửi lại tin nhắn';

  @override
  String get conversationClosed => 'Hội thoại đã đóng';
}
