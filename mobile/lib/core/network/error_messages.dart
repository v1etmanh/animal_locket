const _messages = <String, String>{
  'PROFILE_REQUIRED': 'Bạn cần hoàn tất hồ sơ trước khi tiếp tục.',
  'INVALID_ALIAS': 'Biệt danh cần từ 3 đến 20 ký tự hợp lệ.',
  'INVALID_BIRTHDATE': 'Ngày sinh không hợp lệ.',
  'ALIAS_COOLDOWN': 'Bạn chỉ có thể đổi biệt danh một lần mỗi 24 giờ.',
  'PRO_REQUIRED': 'Tính năng này dành cho thành viên Pro.',
  'ANIMAL_NOT_OWNED': 'Bạn chưa sở hữu con vật này.',
  'SPIN_COOLDOWN': 'Chưa đến lượt quay tiếp theo.',
  'NO_AVATAR_SPIN': 'Bạn không còn lượt quay avatar nào.',
  'AVATAR_NOT_OWNED': 'Avatar này không có trong bộ sưu tập của bạn.',
  'AVATAR_POOL_EXHAUSTED':
      'Tạm thời hết avatar mới để cấp. Lượt quay của bạn vẫn còn, hãy thử lại sau.',
  'AVATAR_BUSY': 'Hệ thống đang bận cấp avatar. Hãy thử lại.',
  'COLLECTION_COMPLETE': 'Bạn đã hoàn thành bộ sưu tập.',
  'FILE_TOO_LARGE': 'Ảnh vượt quá giới hạn 10 MB.',
  'UNSUPPORTED_MEDIA_TYPE': 'Định dạng ảnh chưa được hỗ trợ.',
  'UPLOAD_LIMIT': 'Bạn đã đạt giới hạn tải ảnh trong giờ này.',
  'PHOTO_LIMIT': 'Bạn đã đạt giới hạn đăng ảnh hôm nay.',
  'SWIPE_LIMIT': 'Bạn đã hết lượt quẹt phải hôm nay.',
  'TOO_MANY_SEARCHES': 'Bạn đang tìm quá nhanh. Hãy chờ một chút.',
  'NO_BOOST': 'Bạn không còn Boost.',
  'INVITE_LIMIT': 'Bạn đã đạt giới hạn lời mời hôm nay.',
  'REPORT_LIMIT': 'Bạn đã đạt giới hạn báo cáo hôm nay.',
  'CHAT_RATE_LIMIT': 'Bạn đang gửi tin quá nhanh.',
  'MEDIA_NOT_READY': 'Ảnh vẫn đang được xử lý.',
  'INVALID_MESSAGE': 'Tin nhắn không hợp lệ.',
  'GLYPH_INVALID_POINTS': 'Nét vẽ ký hiệu không hợp lệ.',
  'GLYPH_INVALID_COLOR': 'Màu ký hiệu không được hỗ trợ.',
  'GLYPH_DUPLICATE': 'Ký hiệu này đã có trong hội thoại.',
  'GLYPH_LIMIT': 'Hội thoại đã đạt giới hạn ký hiệu.',
  'GLYPH_NOT_FOUND': 'Không tìm thấy ký hiệu này.',
  'GLYPH_NOT_ACTIVE': 'Ký hiệu này không còn được sử dụng.',
  'GLYPH_NOT_OWNER': 'Bạn không thể xóa ký hiệu của người khác.',
  'GLYPH_SEQUENCE_TOO_LONG': 'Câu có quá nhiều ký hiệu.',
  'INVALID_GLYPH_MESSAGE': 'Tin nhắn ký hiệu không hợp lệ.',
  'GLYPH_CREATE_RATE_LIMIT': 'Bạn đang tạo ký hiệu quá nhanh.',
  'RECEIPT_ALREADY_USED': 'Giao dịch này đã được sử dụng.',
  'STORE_UNAVAILABLE': 'Cửa hàng đang tạm gián đoạn. Vui lòng thử lại.',
  'INVALID_RECEIPT': 'Không thể xác minh giao dịch.',
  'SERVICE_UNAVAILABLE': 'Dịch vụ đang tạm gián đoạn.',
  'IDENTITY_UNAVAILABLE': 'Không thể xác minh tài khoản lúc này.',
};

String messageForApiCode(String? code, {int? status}) {
  if (code != null && _messages.containsKey(code)) return _messages[code]!;
  if (status == 429) return 'Thao tác quá nhanh. Vui lòng chờ rồi thử lại.';
  if (status == 503) return 'Dịch vụ đang tạm gián đoạn. Vui lòng thử lại.';
  return 'Có lỗi xảy ra. Vui lòng thử lại.';
}
