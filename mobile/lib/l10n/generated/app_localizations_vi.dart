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
  String get feedTab => 'Bảng tin';

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

  @override
  String get languageSection => 'Ngôn ngữ';

  @override
  String get cancel => 'Huỷ';

  @override
  String get save => 'Lưu';

  @override
  String get delete => 'Xoá';

  @override
  String get close => 'Đóng';

  @override
  String get continueLabel => 'Tiếp tục';

  @override
  String get loadFailedRetry => 'Không tải được · Thử lại';

  @override
  String get unknownAnimal => 'Con vật';

  @override
  String get anonymousFriend => 'Người bạn ẩn danh';

  @override
  String get rarityCommon => 'Phổ thông';

  @override
  String get rarityRare => 'Hiếm';

  @override
  String get rarityEpic => 'Sử thi';

  @override
  String get rarityUnknown => 'Chưa rõ';

  @override
  String get avatarSemantic => 'Ảnh đại diện con vật';

  @override
  String avatarSemanticNamed(String name) {
    return 'Ảnh đại diện: $name';
  }

  @override
  String get animalLocked => 'Con vật chưa mở khóa';

  @override
  String get errTooFast => 'Thao tác quá nhanh. Vui lòng chờ rồi thử lại.';

  @override
  String get errServiceRetry => 'Dịch vụ đang tạm gián đoạn. Vui lòng thử lại.';

  @override
  String get errProfileRequired => 'Bạn cần hoàn tất hồ sơ trước khi tiếp tục.';

  @override
  String get errInvalidAlias => 'Biệt danh cần từ 3 đến 20 ký tự hợp lệ.';

  @override
  String get errInvalidBirthdate => 'Ngày sinh không hợp lệ.';

  @override
  String get errAliasCooldown =>
      'Bạn chỉ có thể đổi biệt danh một lần mỗi 24 giờ.';

  @override
  String get errProRequired => 'Tính năng này dành cho thành viên Pro.';

  @override
  String get errAnimalNotOwned => 'Bạn chưa sở hữu con vật này.';

  @override
  String get errSpinCooldown => 'Chưa đến lượt quay tiếp theo.';

  @override
  String get errNoAvatarSpin => 'Bạn không còn lượt quay avatar nào.';

  @override
  String get errAvatarNotOwned =>
      'Avatar này không có trong bộ sưu tập của bạn.';

  @override
  String get errAvatarPoolExhausted =>
      'Tạm thời hết avatar mới để cấp. Lượt quay của bạn vẫn còn, hãy thử lại sau.';

  @override
  String get errAvatarBusy => 'Hệ thống đang bận cấp avatar. Hãy thử lại.';

  @override
  String get errCollectionComplete => 'Bạn đã hoàn thành bộ sưu tập.';

  @override
  String get errFileTooLarge => 'Ảnh vượt quá giới hạn 10 MB.';

  @override
  String get errUnsupportedMediaType => 'Định dạng ảnh chưa được hỗ trợ.';

  @override
  String get errUploadLimit => 'Bạn đã đạt giới hạn tải ảnh trong giờ này.';

  @override
  String get errPhotoLimit => 'Bạn đã đạt giới hạn đăng ảnh hôm nay.';

  @override
  String get errSwipeLimit => 'Bạn đã hết lượt quẹt phải hôm nay.';

  @override
  String get errTooManySearches => 'Bạn đang tìm quá nhanh. Hãy chờ một chút.';

  @override
  String get errNoBoost => 'Bạn không còn Boost.';

  @override
  String get errInviteLimit => 'Bạn đã đạt giới hạn lời mời hôm nay.';

  @override
  String get errReportLimit => 'Bạn đã đạt giới hạn báo cáo hôm nay.';

  @override
  String get errChatRateLimit => 'Bạn đang gửi tin quá nhanh.';

  @override
  String get errMediaNotReady => 'Ảnh vẫn đang được xử lý.';

  @override
  String get errInvalidMessage => 'Tin nhắn không hợp lệ.';

  @override
  String get errGlyphInvalidPoints => 'Nét vẽ ký hiệu không hợp lệ.';

  @override
  String get errGlyphInvalidColor => 'Màu ký hiệu không được hỗ trợ.';

  @override
  String get errGlyphDuplicate => 'Ký hiệu này đã có trong hội thoại.';

  @override
  String get errGlyphLimit => 'Hội thoại đã đạt giới hạn ký hiệu.';

  @override
  String get errGlyphNotFound => 'Không tìm thấy ký hiệu này.';

  @override
  String get errGlyphNotActive => 'Ký hiệu này không còn được sử dụng.';

  @override
  String get errGlyphNotOwner => 'Bạn không thể xóa ký hiệu của người khác.';

  @override
  String get errGlyphSequenceTooLong => 'Câu có quá nhiều ký hiệu.';

  @override
  String get errInvalidGlyphMessage => 'Tin nhắn ký hiệu không hợp lệ.';

  @override
  String get errGlyphCreateRateLimit => 'Bạn đang tạo ký hiệu quá nhanh.';

  @override
  String get errReceiptAlreadyUsed => 'Giao dịch này đã được sử dụng.';

  @override
  String get errStoreUnavailable =>
      'Cửa hàng đang tạm gián đoạn. Vui lòng thử lại.';

  @override
  String get errInvalidReceipt => 'Không thể xác minh giao dịch.';

  @override
  String get errServiceUnavailable => 'Dịch vụ đang tạm gián đoạn.';

  @override
  String get errIdentityUnavailable => 'Không thể xác minh tài khoản lúc này.';

  @override
  String get signInHeadline => 'Gần nhau hơn,\nvẫn là chính mình.';

  @override
  String get signInSubtitle =>
      'Chia sẻ khoảnh khắc với bạn bè. Mỗi người là một con vật duy nhất, không lộ tên thật.';

  @override
  String get signInOpening => 'Đang mở đăng nhập…';

  @override
  String get signInEmail => 'Đăng nhập bằng email';

  @override
  String signInFailed(String error) {
    return 'Đăng nhập thất bại: $error';
  }

  @override
  String get openDemoAccount => 'Mở tài khoản demo';

  @override
  String get signInPrivacy =>
      'Chúng tôi không hiển thị tên thật, email hay vị trí chính xác của bạn.';

  @override
  String get termsAgree =>
      'Tôi đồng ý Điều khoản sử dụng và Chính sách riêng tư.';

  @override
  String get pickBirthdate => 'Chọn ngày sinh';

  @override
  String get safetySetupTitle => 'Thiết lập an toàn';

  @override
  String get birthdateSection => 'Ngày sinh';

  @override
  String get birthAgeSpace => 'Mỗi độ tuổi có một không gian phù hợp.';

  @override
  String get birthPrivacy =>
      'Ngày sinh chỉ dùng để xác định nhóm tuổi. Thông tin này không xuất hiện trên hồ sơ.';

  @override
  String get dayLabel => 'Ngày';

  @override
  String get monthLabel => 'Tháng';

  @override
  String get yearLabel => 'Năm';

  @override
  String get tapToPickBirthdate => 'Chạm để chọn ngày sinh';

  @override
  String get aliasSuggestion1 => 'Mây Tinh Nghịch';

  @override
  String get aliasSuggestion2 => 'Cáo Mơ Màng';

  @override
  String get aliasSuggestion3 => 'Nắng Lấp Lánh';

  @override
  String get aliasSuggestion4 => 'Gấu Bồng Bềnh';

  @override
  String get revealSection => 'Avatar của riêng bạn';

  @override
  String get photoDeveloping => 'ảnh chưa rửa…';

  @override
  String get revealReady => 'Sẵn sàng nhận con vật?';

  @override
  String revealGreeting(String alias) {
    return 'Chào $alias';
  }

  @override
  String get aliasNotRealName => 'Biệt danh của bạn không cần là tên thật.';

  @override
  String get spinning => 'Đang quay…';

  @override
  String animalUniqueAvatar(String animal) {
    return '$animal · không ai khác có avatar này';
  }

  @override
  String get nicknameLabel => 'Biệt danh';

  @override
  String get randomNickname => 'Tạo biệt danh ngẫu nhiên';

  @override
  String get registering => 'Đang đăng ký…';

  @override
  String get spinAvatar => 'Quay avatar';

  @override
  String get enterApp => 'Vào app';

  @override
  String get billingProPlan => 'Gói Pro';

  @override
  String billingProPlanDays(int days) {
    return 'Gói Pro $days ngày';
  }

  @override
  String billingBoost(int quantity) {
    return 'Boost khám phá × $quantity';
  }

  @override
  String billingPriorityInvite(int quantity) {
    return 'Lời mời ưu tiên × $quantity';
  }

  @override
  String billingAnimalPack(String item) {
    return 'Gói con vật $item';
  }

  @override
  String get billingDemoDisabled => 'Chế độ demo không mua hàng được.';

  @override
  String get billingTransactionError => 'Giao dịch gặp lỗi.';

  @override
  String get billingCheckoutOpened =>
      'Đã mở trang thanh toán. Thanh toán xong quay lại app để cập nhật.';

  @override
  String get billingBrowserFailed => 'Không mở được trình duyệt.';

  @override
  String get billingWebPaymentOff =>
      'Thanh toán web chưa được bật trên máy chủ.';

  @override
  String get billingNotOnWeb => 'Sản phẩm này chưa bán qua web.';

  @override
  String get billingSessionFailed => 'Không tạo được phiên thanh toán.';

  @override
  String get billingUpdated => 'Đã cập nhật giao dịch của bạn.';

  @override
  String get billingVerified => 'Giao dịch đã được xác minh.';

  @override
  String get billingNotVerified =>
      'Backend chưa xác minh giao dịch. Giao dịch chưa được hoàn tất.';

  @override
  String get billingCanceled => 'Đã huỷ giao dịch.';

  @override
  String get proLoadFailed => 'Không thể tải cửa hàng · Thử lại';

  @override
  String get proHeadline => 'Nhiều cách kết nối hơn';

  @override
  String get proPerkBoost => 'Boost khám phá';

  @override
  String get proPerkInvite => 'Lời mời kết bạn ưu tiên';

  @override
  String get proMinorNotice => 'Tài khoản dưới 18 tuổi không hiển thị ưu đãi.';

  @override
  String get proNoWebProducts => 'Chưa có sản phẩm bán qua web.';

  @override
  String get proWebPaymentNote =>
      'Thanh toán trên trang web của Animal Locket (VietQR/PayPal). Xong bấm \"Quay lại app\".';

  @override
  String proViaStore(String product, String price) {
    return 'Qua cửa hàng: $product · $price';
  }

  @override
  String get proRestore => 'Khôi phục giao dịch cửa hàng';

  @override
  String get proCurrentPro => 'Bạn đang dùng Pro';

  @override
  String proCurrentProUntil(String date) {
    return 'Bạn đang dùng Pro đến $date';
  }

  @override
  String get proCurrentFree => 'Bạn đang dùng gói Free';

  @override
  String proWallet(int boosts, int invites) {
    return 'Boost: $boosts · Lời mời ưu tiên: $invites';
  }

  @override
  String get newMoment => 'Khoảnh khắc mới';

  @override
  String get flashMode => 'Đổi chế độ đèn flash';

  @override
  String get pickFromGallery => 'Chọn từ thư viện';

  @override
  String get flipCamera => 'Lật camera';

  @override
  String get takePhoto => 'Chụp ảnh';

  @override
  String get cameraPermission => 'Cho phép camera để chụp khoảnh khắc.';

  @override
  String get allowCamera => 'Cho phép camera';

  @override
  String get previewSendingFirst => 'Đang gửi ảnh trước, đợi chút nhé.';

  @override
  String get previewTitle => 'Xem trước';

  @override
  String get messageLabel => 'Lời nhắn';

  @override
  String get messageHintFriends => 'Viết gì đó cho bạn bè…';

  @override
  String get sendingPhoto => 'Đang gửi ảnh trước…';

  @override
  String get sendToFriends => 'Gửi cho bạn bè';

  @override
  String get retake => 'Chụp lại';

  @override
  String get previewNote =>
      'Ảnh được gửi cho toàn bộ bạn bè. Bản đầu chưa hỗ trợ chọn từng người nhận.';

  @override
  String get sendSending => 'Đang gửi…';

  @override
  String get sendSent => 'Đã gửi';

  @override
  String get sendRejected => 'Ảnh không được chấp nhận';

  @override
  String get sendFailed => 'Gửi lỗi, kiểm tra mạng';

  @override
  String get chatListTitle => 'Trò chuyện';

  @override
  String get chatOnlyFriends => 'Tin nhắn chỉ mở giữa bạn bè.';

  @override
  String get chatEmpty => 'Chưa có cuộc trò chuyện nào.';

  @override
  String get chatStart => 'Bắt đầu trò chuyện';

  @override
  String get chatRecent => 'Tin nhắn gần đây';

  @override
  String unreadCount(int count) {
    return '$count tin chưa đọc';
  }

  @override
  String get friendsLabel => 'Bạn bè';

  @override
  String swipesLeft(int count) {
    return 'Còn $count lượt quẹt phải hôm nay';
  }

  @override
  String get enableLocationHint =>
      'Bật vị trí để tìm người ở gần. Hiện chỉ thấy người đang online.';

  @override
  String get enableLocation => 'Bật vị trí';

  @override
  String get discoverSlow => 'Dịch vụ đang chậm, bộ thẻ có thể chưa đầy đủ.';

  @override
  String get skip => 'Bỏ qua';

  @override
  String get useBoost => 'Dùng Boost';

  @override
  String get addFriend => 'Kết bạn';

  @override
  String get friendsMade => 'Đã thành bạn! Bạn có thể bắt đầu trò chuyện.';

  @override
  String get boostUsed => 'Đã dùng 1 Boost.';

  @override
  String get online => 'Đang online';

  @override
  String get anonymousAnimal => 'Con vật ẩn danh';

  @override
  String get deckEmpty => 'Hết thẻ mới rồi';

  @override
  String get reload => 'Tải lại';

  @override
  String get findNewFriends => 'Tìm người bạn mới';

  @override
  String get locationConsent =>
      'Vị trí chỉ được xin khi bạn bật khám phá. Nếu từ chối, bạn vẫn có thể dùng chế độ online.';

  @override
  String get enableDiscovery => 'Bật khám phá';

  @override
  String discoverLoadFailedCode(String code) {
    return 'Không thể tải khám phá ($code).';
  }

  @override
  String get discoverLoadFailed => 'Không thể tải khám phá.';

  @override
  String get distUnder1km => 'dưới 1 km';

  @override
  String get dist1to3km => '1–3 km';

  @override
  String get distUnder3km => 'dưới 3 km';

  @override
  String get dist3to10km => '3–10 km';

  @override
  String get distOver10km => 'trên 10 km';

  @override
  String get feedTitle => 'Khoảnh khắc';

  @override
  String get feedLoadFailed => 'Không thể tải feed. Vui lòng kiểm tra mạng.';

  @override
  String get feedEmpty =>
      'Chưa có khoảnh khắc nào\nHãy chụp ảnh hoặc kết bạn để bắt đầu.';

  @override
  String get feedDegraded =>
      'Một phần dịch vụ đang chậm. Feed có thể chưa đầy đủ.';

  @override
  String get unlike => 'Bỏ thích';

  @override
  String get like => 'Thích';

  @override
  String get timeJustNow => 'Vừa xong';

  @override
  String timeMinutesAgo(int count) {
    return '$count phút trước';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count giờ trước';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count ngày trước';
  }

  @override
  String get dayToday => 'Hôm nay';

  @override
  String get dayYesterday => 'Hôm qua';

  @override
  String get noPhotosYet => 'Chưa có ảnh nào.';

  @override
  String get befriendToSee => 'Kết bạn để xem ảnh của người này.';

  @override
  String get photosLoadFailed => 'Không tải được ảnh · Thử lại';

  @override
  String get morePhotos => 'Xem thêm ảnh';

  @override
  String get postProcessing => 'Đang xử lý';

  @override
  String get postRejected => 'Bị từ chối';

  @override
  String get postRejectedPhoto => 'Ảnh bị từ chối';

  @override
  String get postProcessingPhoto => 'Ảnh đang được xử lý';

  @override
  String get deletePhoto => 'Xoá ảnh';

  @override
  String get deletePhotoQ => 'Xoá ảnh này?';

  @override
  String get deletePhotoBody => 'Bạn bè sẽ không còn thấy ảnh này nữa.';

  @override
  String get deletePhotoFailed => 'Không xoá được ảnh. Thử lại sau.';

  @override
  String get friendsAndRequests => 'Bạn bè và lời mời';

  @override
  String tabFriends(int count) {
    return 'Bạn bè $count';
  }

  @override
  String tabRequests(int count) {
    return 'Lời mời $count';
  }

  @override
  String tabSent(int count) {
    return 'Đã gửi $count';
  }

  @override
  String get noFriends => 'Chưa có bạn bè.';

  @override
  String get offline => 'Ngoại tuyến';

  @override
  String get viewProfile => 'Xem hồ sơ';

  @override
  String get noIncoming => 'Không có lời mời mới.';

  @override
  String get noOutgoing => 'Bạn chưa gửi lời mời nào.';

  @override
  String get distanceHidden => 'Không hiển thị khoảng cách để bảo vệ riêng tư';

  @override
  String get accept => 'Chấp nhận';

  @override
  String get decline => 'Từ chối';

  @override
  String get settings => 'Cài đặt';

  @override
  String get changeNickname => 'Đổi biệt danh';

  @override
  String get memberPro => 'Thành viên Pro';

  @override
  String get memberFree => 'Thành viên Free';

  @override
  String get ownedAvatars => 'Avatar sở hữu';

  @override
  String get myPhotos => 'Ảnh của tôi';

  @override
  String get noMyPhotos => 'Bạn chưa đăng ảnh nào.';

  @override
  String get collection => 'Bộ sưu tập';

  @override
  String get collectionNote =>
      'Mỗi avatar chỉ thuộc về bạn, không ai khác có được.';

  @override
  String get collectionNoteMulti =>
      'Chạm một avatar để dùng nó. Mỗi avatar chỉ thuộc về bạn.';

  @override
  String spinAvatarButton(int count) {
    return 'Quay avatar ($count)';
  }

  @override
  String get upgradePro => 'Nâng cấp Pro';

  @override
  String friendsCount(int count) {
    return 'Bạn bè ($count)';
  }

  @override
  String get seeAll => 'Xem tất cả';

  @override
  String get friendsLoadFailed => 'Không tải được bạn bè · Thử lại';

  @override
  String get noFriendsYet => 'Chưa có bạn bè nào.';

  @override
  String get findFriends => 'Tìm bạn';

  @override
  String openProfileOf(String name) {
    return 'Mở trang của $name';
  }

  @override
  String get profileLoadFailed => 'Không thể tải hồ sơ.';

  @override
  String photosOf(String name) {
    return 'Ảnh của $name';
  }

  @override
  String noPhotosOf(String name) {
    return '$name chưa đăng ảnh nào.';
  }

  @override
  String get anonymousProfile => 'Hồ sơ ẩn danh';

  @override
  String get message => 'Nhắn tin';

  @override
  String get unfriend => 'Huỷ kết bạn';

  @override
  String get report => 'Báo cáo';

  @override
  String get block => 'Chặn';

  @override
  String get blockQ => 'Chặn người này?';

  @override
  String get blockBody =>
      'Hai người sẽ không thể tìm thấy hoặc nhắn tin cho nhau.';

  @override
  String get reportDetails => 'Chi tiết';

  @override
  String get sendReport => 'Gửi báo cáo';

  @override
  String get reportSent => 'Đã gửi báo cáo.';

  @override
  String get settingsTitle => 'Cài đặt và riêng tư';

  @override
  String get allowDiscovery => 'Cho phép khám phá';

  @override
  String get discoveryOffNote =>
      'Tắt để xoá vị trí và dừng xuất hiện trong bộ thẻ.';

  @override
  String get blockedSection => 'Đã chặn';

  @override
  String get nobodyBlocked => 'Chưa chặn ai.';

  @override
  String get unblock => 'Bỏ chặn';

  @override
  String get signOut => 'Đăng xuất';

  @override
  String get deleteAccount => 'Xoá tài khoản';

  @override
  String get deleteAccountQ => 'Xoá tài khoản?';

  @override
  String get deleteAccountBody =>
      'Ảnh, tin nhắn và hồ sơ sẽ bị xoá. Thao tác này không thể hoàn tác.';

  @override
  String get keepAccount => 'Giữ tài khoản';

  @override
  String get finalConfirm => 'Xác nhận lần cuối';

  @override
  String get typeDeleteWord => 'Nhập XOÁ để xác nhận';

  @override
  String get deleteWord => 'XOÁ';

  @override
  String get deleteForever => 'Xoá vĩnh viễn';

  @override
  String get themeSection => 'Màu giao diện';

  @override
  String get themeShu => 'Shu · Son đỏ';

  @override
  String get themeYuzu => 'Yuzu · Vàng thanh yên';

  @override
  String get themeSakura => 'Sakura · Hồng anh đào';

  @override
  String get themeSora => 'Sora · Trời xanh';

  @override
  String get glyphSysAgree => 'Đồng ý';

  @override
  String get glyphSysHurry => 'Gấp nhé';

  @override
  String get glyphSysBusy => 'Đang bận';

  @override
  String get glyphSysCoffee => 'Đi cà phê không?';

  @override
  String get glyphSysHungry => 'Đói bụng';

  @override
  String get glyphSysComing => 'Đang tới';

  @override
  String get view => 'Xem';

  @override
  String unfriendQ(String name) {
    return 'Huỷ kết bạn với $name?';
  }

  @override
  String get pushTitle => 'Thông báo';

  @override
  String get pushDisabled => 'Thông báo chưa được bật trong bản ứng dụng này.';

  @override
  String get pushLoading => 'Đang đăng ký nhận thông báo…';

  @override
  String get pushDenied =>
      'Quyền thông báo đã bị từ chối. Hãy bật lại trong cài đặt điện thoại.';

  @override
  String get pushError => 'Chưa đăng ký được thông báo. Vui lòng thử lại.';

  @override
  String get pushRegistered => 'Thiết bị đã đăng ký nhận thông báo.';

  @override
  String get pushRetry => 'Thử lại';

  @override
  String get pushIncoming => 'Bạn có thông báo mới.';
}
