import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appName.
  ///
  /// In vi, this message translates to:
  /// **'Animal Locket'**
  String get appName;

  /// No description provided for @photosTab.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh'**
  String get photosTab;

  /// No description provided for @feedTab.
  ///
  /// In vi, this message translates to:
  /// **'Bảng tin'**
  String get feedTab;

  /// No description provided for @discoverTab.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá'**
  String get discoverTab;

  /// No description provided for @chatTab.
  ///
  /// In vi, this message translates to:
  /// **'Chat'**
  String get chatTab;

  /// No description provided for @profileTab.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ'**
  String get profileTab;

  /// No description provided for @retry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get retry;

  /// No description provided for @genericError.
  ///
  /// In vi, this message translates to:
  /// **'Có lỗi xảy ra. Vui lòng thử lại.'**
  String get genericError;

  /// No description provided for @conversationTitle.
  ///
  /// In vi, this message translates to:
  /// **'Trò chuyện'**
  String get conversationTitle;

  /// No description provided for @messagesLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải tin nhắn.'**
  String get messagesLoadError;

  /// No description provided for @messageSendFailed.
  ///
  /// In vi, this message translates to:
  /// **'Tin chưa gửi được. Nội dung vẫn được giữ trên màn hình.'**
  String get messageSendFailed;

  /// No description provided for @messageHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin…'**
  String get messageHint;

  /// No description provided for @sendMessage.
  ///
  /// In vi, this message translates to:
  /// **'Gửi tin nhắn'**
  String get sendMessage;

  /// No description provided for @sendPhoto.
  ///
  /// In vi, this message translates to:
  /// **'Gửi ảnh'**
  String get sendPhoto;

  /// No description provided for @glyphModeOpen.
  ///
  /// In vi, this message translates to:
  /// **'Mở chế độ nhắn bằng ký hiệu'**
  String get glyphModeOpen;

  /// No description provided for @glyphModeClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng chế độ nhắn bằng ký hiệu'**
  String get glyphModeClose;

  /// No description provided for @glyphDrawLabel.
  ///
  /// In vi, this message translates to:
  /// **'Khung vẽ ký hiệu một nét'**
  String get glyphDrawLabel;

  /// No description provided for @glyphDrawHint.
  ///
  /// In vi, this message translates to:
  /// **'Vẽ một nét vào đây'**
  String get glyphDrawHint;

  /// No description provided for @glyphClearStroke.
  ///
  /// In vi, this message translates to:
  /// **'Xóa nét vẽ'**
  String get glyphClearStroke;

  /// No description provided for @glyphRecognizing.
  ///
  /// In vi, this message translates to:
  /// **'Đang nhận diện…'**
  String get glyphRecognizing;

  /// No description provided for @glyphNoMatch.
  ///
  /// In vi, this message translates to:
  /// **'Chưa nhận ra ký hiệu. Bạn có thể vẽ lại hoặc tạo ký hiệu mới.'**
  String get glyphNoMatch;

  /// No description provided for @glyphAmbiguous.
  ///
  /// In vi, this message translates to:
  /// **'Nét vẽ giống nhiều ký hiệu. Hãy chọn kết quả đúng.'**
  String get glyphAmbiguous;

  /// No description provided for @glyphMatched.
  ///
  /// In vi, this message translates to:
  /// **'Đã nhận diện {meaning}'**
  String glyphMatched(String meaning);

  /// No description provided for @glyphAddToComposer.
  ///
  /// In vi, this message translates to:
  /// **'Thêm vào câu'**
  String get glyphAddToComposer;

  /// No description provided for @glyphQuickPick.
  ///
  /// In vi, this message translates to:
  /// **'Chọn nhanh'**
  String get glyphQuickPick;

  /// No description provided for @glyphComposerEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ký hiệu trong câu'**
  String get glyphComposerEmpty;

  /// No description provided for @glyphRemoveToken.
  ///
  /// In vi, this message translates to:
  /// **'Xóa ký hiệu {meaning}'**
  String glyphRemoveToken(String meaning);

  /// No description provided for @glyphClearComposer.
  ///
  /// In vi, this message translates to:
  /// **'Xóa toàn bộ câu ký hiệu'**
  String get glyphClearComposer;

  /// No description provided for @glyphSend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi ký hiệu'**
  String get glyphSend;

  /// No description provided for @glyphDictionary.
  ///
  /// In vi, this message translates to:
  /// **'Từ điển ký hiệu'**
  String get glyphDictionary;

  /// No description provided for @glyphCreate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo ký hiệu'**
  String get glyphCreate;

  /// No description provided for @glyphSystemTab.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống'**
  String get glyphSystemTab;

  /// No description provided for @glyphPersonalTab.
  ///
  /// In vi, this message translates to:
  /// **'Cá nhân'**
  String get glyphPersonalTab;

  /// No description provided for @glyphConversationTab.
  ///
  /// In vi, this message translates to:
  /// **'Hội thoại'**
  String get glyphConversationTab;

  /// No description provided for @glyphDictionaryEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ký hiệu trong mục này.'**
  String get glyphDictionaryEmpty;

  /// No description provided for @glyphDictionaryError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải từ điển ký hiệu.'**
  String get glyphDictionaryError;

  /// No description provided for @glyphMeaningLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ý nghĩa ký hiệu'**
  String get glyphMeaningLabel;

  /// No description provided for @glyphMeaningHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ Đi cà phê không'**
  String get glyphMeaningHint;

  /// No description provided for @glyphColorLabel.
  ///
  /// In vi, this message translates to:
  /// **'Màu ký hiệu'**
  String get glyphColorLabel;

  /// No description provided for @glyphSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu ký hiệu'**
  String get glyphSave;

  /// No description provided for @glyphDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xóa ký hiệu'**
  String get glyphDelete;

  /// No description provided for @glyphCollisionWarning.
  ///
  /// In vi, this message translates to:
  /// **'Nét vẽ quá giống một ký hiệu đã có.'**
  String get glyphCollisionWarning;

  /// No description provided for @glyphTooShort.
  ///
  /// In vi, this message translates to:
  /// **'Hãy vẽ một nét rõ hơn.'**
  String get glyphTooShort;

  /// No description provided for @glyphFeatureWaitingBackend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi ký hiệu đang chờ backend tương thích.'**
  String get glyphFeatureWaitingBackend;

  /// No description provided for @glyphShowMeaning.
  ///
  /// In vi, this message translates to:
  /// **'Hiện nghĩa ký hiệu'**
  String get glyphShowMeaning;

  /// No description provided for @glyphHideMeaning.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn nghĩa ký hiệu'**
  String get glyphHideMeaning;

  /// No description provided for @glyphUnknownFallback.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được hình ký hiệu. Đang hiển thị nội dung thay thế.'**
  String get glyphUnknownFallback;

  /// No description provided for @retryMessage.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lại tin nhắn'**
  String get retryMessage;

  /// No description provided for @conversationClosed.
  ///
  /// In vi, this message translates to:
  /// **'Hội thoại đã đóng'**
  String get conversationClosed;

  /// No description provided for @languageSection.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get languageSection;

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get delete;

  /// No description provided for @close.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get close;

  /// No description provided for @continueLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get continueLabel;

  /// No description provided for @loadFailedRetry.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được · Thử lại'**
  String get loadFailedRetry;

  /// No description provided for @unknownAnimal.
  ///
  /// In vi, this message translates to:
  /// **'Con vật'**
  String get unknownAnimal;

  /// No description provided for @anonymousFriend.
  ///
  /// In vi, this message translates to:
  /// **'Người bạn ẩn danh'**
  String get anonymousFriend;

  /// No description provided for @rarityCommon.
  ///
  /// In vi, this message translates to:
  /// **'Phổ thông'**
  String get rarityCommon;

  /// No description provided for @rarityRare.
  ///
  /// In vi, this message translates to:
  /// **'Hiếm'**
  String get rarityRare;

  /// No description provided for @rarityEpic.
  ///
  /// In vi, this message translates to:
  /// **'Sử thi'**
  String get rarityEpic;

  /// No description provided for @rarityUnknown.
  ///
  /// In vi, this message translates to:
  /// **'Chưa rõ'**
  String get rarityUnknown;

  /// No description provided for @avatarSemantic.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh đại diện con vật'**
  String get avatarSemantic;

  /// No description provided for @avatarSemanticNamed.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh đại diện: {name}'**
  String avatarSemanticNamed(String name);

  /// No description provided for @animalLocked.
  ///
  /// In vi, this message translates to:
  /// **'Con vật chưa mở khóa'**
  String get animalLocked;

  /// No description provided for @errTooFast.
  ///
  /// In vi, this message translates to:
  /// **'Thao tác quá nhanh. Vui lòng chờ rồi thử lại.'**
  String get errTooFast;

  /// No description provided for @errServiceRetry.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ đang tạm gián đoạn. Vui lòng thử lại.'**
  String get errServiceRetry;

  /// No description provided for @errProfileRequired.
  ///
  /// In vi, this message translates to:
  /// **'Bạn cần hoàn tất hồ sơ trước khi tiếp tục.'**
  String get errProfileRequired;

  /// No description provided for @errInvalidAlias.
  ///
  /// In vi, this message translates to:
  /// **'Biệt danh cần từ 3 đến 20 ký tự hợp lệ.'**
  String get errInvalidAlias;

  /// No description provided for @errInvalidBirthdate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày sinh không hợp lệ.'**
  String get errInvalidBirthdate;

  /// No description provided for @errAliasCooldown.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chỉ có thể đổi biệt danh một lần mỗi 24 giờ.'**
  String get errAliasCooldown;

  /// No description provided for @errProRequired.
  ///
  /// In vi, this message translates to:
  /// **'Tính năng này dành cho thành viên Pro.'**
  String get errProRequired;

  /// No description provided for @errAnimalNotOwned.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa sở hữu con vật này.'**
  String get errAnimalNotOwned;

  /// No description provided for @errSpinCooldown.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đến lượt quay tiếp theo.'**
  String get errSpinCooldown;

  /// No description provided for @errNoAvatarSpin.
  ///
  /// In vi, this message translates to:
  /// **'Bạn không còn lượt quay avatar nào.'**
  String get errNoAvatarSpin;

  /// No description provided for @errAvatarNotOwned.
  ///
  /// In vi, this message translates to:
  /// **'Avatar này không có trong bộ sưu tập của bạn.'**
  String get errAvatarNotOwned;

  /// No description provided for @errAvatarPoolExhausted.
  ///
  /// In vi, this message translates to:
  /// **'Tạm thời hết avatar mới để cấp. Lượt quay của bạn vẫn còn, hãy thử lại sau.'**
  String get errAvatarPoolExhausted;

  /// No description provided for @errAvatarBusy.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống đang bận cấp avatar. Hãy thử lại.'**
  String get errAvatarBusy;

  /// No description provided for @errCollectionComplete.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã hoàn thành bộ sưu tập.'**
  String get errCollectionComplete;

  /// No description provided for @errFileTooLarge.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh vượt quá giới hạn 10 MB.'**
  String get errFileTooLarge;

  /// No description provided for @errUnsupportedMediaType.
  ///
  /// In vi, this message translates to:
  /// **'Định dạng ảnh chưa được hỗ trợ.'**
  String get errUnsupportedMediaType;

  /// No description provided for @errUploadLimit.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã đạt giới hạn tải ảnh trong giờ này.'**
  String get errUploadLimit;

  /// No description provided for @errPhotoLimit.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã đạt giới hạn đăng ảnh hôm nay.'**
  String get errPhotoLimit;

  /// No description provided for @errSwipeLimit.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã hết lượt quẹt phải hôm nay.'**
  String get errSwipeLimit;

  /// No description provided for @errTooManySearches.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang tìm quá nhanh. Hãy chờ một chút.'**
  String get errTooManySearches;

  /// No description provided for @errNoBoost.
  ///
  /// In vi, this message translates to:
  /// **'Bạn không còn Boost.'**
  String get errNoBoost;

  /// No description provided for @errInviteLimit.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã đạt giới hạn lời mời hôm nay.'**
  String get errInviteLimit;

  /// No description provided for @errReportLimit.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã đạt giới hạn báo cáo hôm nay.'**
  String get errReportLimit;

  /// No description provided for @errChatRateLimit.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang gửi tin quá nhanh.'**
  String get errChatRateLimit;

  /// No description provided for @errMediaNotReady.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh vẫn đang được xử lý.'**
  String get errMediaNotReady;

  /// No description provided for @errInvalidMessage.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn không hợp lệ.'**
  String get errInvalidMessage;

  /// No description provided for @errGlyphInvalidPoints.
  ///
  /// In vi, this message translates to:
  /// **'Nét vẽ ký hiệu không hợp lệ.'**
  String get errGlyphInvalidPoints;

  /// No description provided for @errGlyphInvalidColor.
  ///
  /// In vi, this message translates to:
  /// **'Màu ký hiệu không được hỗ trợ.'**
  String get errGlyphInvalidColor;

  /// No description provided for @errGlyphDuplicate.
  ///
  /// In vi, this message translates to:
  /// **'Ký hiệu này đã có trong hội thoại.'**
  String get errGlyphDuplicate;

  /// No description provided for @errGlyphLimit.
  ///
  /// In vi, this message translates to:
  /// **'Hội thoại đã đạt giới hạn ký hiệu.'**
  String get errGlyphLimit;

  /// No description provided for @errGlyphNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy ký hiệu này.'**
  String get errGlyphNotFound;

  /// No description provided for @errGlyphNotActive.
  ///
  /// In vi, this message translates to:
  /// **'Ký hiệu này không còn được sử dụng.'**
  String get errGlyphNotActive;

  /// No description provided for @errGlyphNotOwner.
  ///
  /// In vi, this message translates to:
  /// **'Bạn không thể xóa ký hiệu của người khác.'**
  String get errGlyphNotOwner;

  /// No description provided for @errGlyphSequenceTooLong.
  ///
  /// In vi, this message translates to:
  /// **'Câu có quá nhiều ký hiệu.'**
  String get errGlyphSequenceTooLong;

  /// No description provided for @errInvalidGlyphMessage.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn ký hiệu không hợp lệ.'**
  String get errInvalidGlyphMessage;

  /// No description provided for @errGlyphCreateRateLimit.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang tạo ký hiệu quá nhanh.'**
  String get errGlyphCreateRateLimit;

  /// No description provided for @errReceiptAlreadyUsed.
  ///
  /// In vi, this message translates to:
  /// **'Giao dịch này đã được sử dụng.'**
  String get errReceiptAlreadyUsed;

  /// No description provided for @errStoreUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Cửa hàng đang tạm gián đoạn. Vui lòng thử lại.'**
  String get errStoreUnavailable;

  /// No description provided for @errInvalidReceipt.
  ///
  /// In vi, this message translates to:
  /// **'Không thể xác minh giao dịch.'**
  String get errInvalidReceipt;

  /// No description provided for @errServiceUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ đang tạm gián đoạn.'**
  String get errServiceUnavailable;

  /// No description provided for @errIdentityUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Không thể xác minh tài khoản lúc này.'**
  String get errIdentityUnavailable;

  /// No description provided for @signInHeadline.
  ///
  /// In vi, this message translates to:
  /// **'Gần nhau hơn,\nvẫn là chính mình.'**
  String get signInHeadline;

  /// No description provided for @signInSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ khoảnh khắc với bạn bè. Mỗi người là một con vật duy nhất, không lộ tên thật.'**
  String get signInSubtitle;

  /// No description provided for @signInOpening.
  ///
  /// In vi, this message translates to:
  /// **'Đang mở đăng nhập…'**
  String get signInOpening;

  /// No description provided for @signInEmail.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập bằng email'**
  String get signInEmail;

  /// No description provided for @signInFailed.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập thất bại: {error}'**
  String signInFailed(String error);

  /// No description provided for @openDemoAccount.
  ///
  /// In vi, this message translates to:
  /// **'Mở tài khoản demo'**
  String get openDemoAccount;

  /// No description provided for @signInPrivacy.
  ///
  /// In vi, this message translates to:
  /// **'Chúng tôi không hiển thị tên thật, email hay vị trí chính xác của bạn.'**
  String get signInPrivacy;

  /// No description provided for @termsAgree.
  ///
  /// In vi, this message translates to:
  /// **'Tôi đồng ý Điều khoản sử dụng và Chính sách riêng tư.'**
  String get termsAgree;

  /// No description provided for @pickBirthdate.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngày sinh'**
  String get pickBirthdate;

  /// No description provided for @safetySetupTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thiết lập an toàn'**
  String get safetySetupTitle;

  /// No description provided for @birthdateSection.
  ///
  /// In vi, this message translates to:
  /// **'Ngày sinh'**
  String get birthdateSection;

  /// No description provided for @birthAgeSpace.
  ///
  /// In vi, this message translates to:
  /// **'Mỗi độ tuổi có một không gian phù hợp.'**
  String get birthAgeSpace;

  /// No description provided for @birthPrivacy.
  ///
  /// In vi, this message translates to:
  /// **'Ngày sinh chỉ dùng để xác định nhóm tuổi. Thông tin này không xuất hiện trên hồ sơ.'**
  String get birthPrivacy;

  /// No description provided for @dayLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngày'**
  String get dayLabel;

  /// No description provided for @monthLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tháng'**
  String get monthLabel;

  /// No description provided for @yearLabel.
  ///
  /// In vi, this message translates to:
  /// **'Năm'**
  String get yearLabel;

  /// No description provided for @tapToPickBirthdate.
  ///
  /// In vi, this message translates to:
  /// **'Chạm để chọn ngày sinh'**
  String get tapToPickBirthdate;

  /// No description provided for @aliasSuggestion1.
  ///
  /// In vi, this message translates to:
  /// **'Mây Tinh Nghịch'**
  String get aliasSuggestion1;

  /// No description provided for @aliasSuggestion2.
  ///
  /// In vi, this message translates to:
  /// **'Cáo Mơ Màng'**
  String get aliasSuggestion2;

  /// No description provided for @aliasSuggestion3.
  ///
  /// In vi, this message translates to:
  /// **'Nắng Lấp Lánh'**
  String get aliasSuggestion3;

  /// No description provided for @aliasSuggestion4.
  ///
  /// In vi, this message translates to:
  /// **'Gấu Bồng Bềnh'**
  String get aliasSuggestion4;

  /// No description provided for @revealSection.
  ///
  /// In vi, this message translates to:
  /// **'Avatar của riêng bạn'**
  String get revealSection;

  /// No description provided for @photoDeveloping.
  ///
  /// In vi, this message translates to:
  /// **'ảnh chưa rửa…'**
  String get photoDeveloping;

  /// No description provided for @revealReady.
  ///
  /// In vi, this message translates to:
  /// **'Sẵn sàng nhận con vật?'**
  String get revealReady;

  /// No description provided for @revealGreeting.
  ///
  /// In vi, this message translates to:
  /// **'Chào {alias}'**
  String revealGreeting(String alias);

  /// No description provided for @aliasNotRealName.
  ///
  /// In vi, this message translates to:
  /// **'Biệt danh của bạn không cần là tên thật.'**
  String get aliasNotRealName;

  /// No description provided for @spinning.
  ///
  /// In vi, this message translates to:
  /// **'Đang quay…'**
  String get spinning;

  /// No description provided for @animalUniqueAvatar.
  ///
  /// In vi, this message translates to:
  /// **'{animal} · không ai khác có avatar này'**
  String animalUniqueAvatar(String animal);

  /// No description provided for @nicknameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Biệt danh'**
  String get nicknameLabel;

  /// No description provided for @randomNickname.
  ///
  /// In vi, this message translates to:
  /// **'Tạo biệt danh ngẫu nhiên'**
  String get randomNickname;

  /// No description provided for @registering.
  ///
  /// In vi, this message translates to:
  /// **'Đang đăng ký…'**
  String get registering;

  /// No description provided for @spinAvatar.
  ///
  /// In vi, this message translates to:
  /// **'Quay avatar'**
  String get spinAvatar;

  /// No description provided for @enterApp.
  ///
  /// In vi, this message translates to:
  /// **'Vào app'**
  String get enterApp;

  /// No description provided for @billingProPlan.
  ///
  /// In vi, this message translates to:
  /// **'Gói Pro'**
  String get billingProPlan;

  /// No description provided for @billingProPlanDays.
  ///
  /// In vi, this message translates to:
  /// **'Gói Pro {days} ngày'**
  String billingProPlanDays(int days);

  /// No description provided for @billingBoost.
  ///
  /// In vi, this message translates to:
  /// **'Boost khám phá × {quantity}'**
  String billingBoost(int quantity);

  /// No description provided for @billingPriorityInvite.
  ///
  /// In vi, this message translates to:
  /// **'Lời mời ưu tiên × {quantity}'**
  String billingPriorityInvite(int quantity);

  /// No description provided for @billingAnimalPack.
  ///
  /// In vi, this message translates to:
  /// **'Gói con vật {item}'**
  String billingAnimalPack(String item);

  /// No description provided for @billingDemoDisabled.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ demo không mua hàng được.'**
  String get billingDemoDisabled;

  /// No description provided for @billingTransactionError.
  ///
  /// In vi, this message translates to:
  /// **'Giao dịch gặp lỗi.'**
  String get billingTransactionError;

  /// No description provided for @billingCheckoutOpened.
  ///
  /// In vi, this message translates to:
  /// **'Đã mở trang thanh toán. Thanh toán xong quay lại app để cập nhật.'**
  String get billingCheckoutOpened;

  /// No description provided for @billingBrowserFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không mở được trình duyệt.'**
  String get billingBrowserFailed;

  /// No description provided for @billingWebPaymentOff.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán web chưa được bật trên máy chủ.'**
  String get billingWebPaymentOff;

  /// No description provided for @billingNotOnWeb.
  ///
  /// In vi, this message translates to:
  /// **'Sản phẩm này chưa bán qua web.'**
  String get billingNotOnWeb;

  /// No description provided for @billingSessionFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tạo được phiên thanh toán.'**
  String get billingSessionFailed;

  /// No description provided for @billingUpdated.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật giao dịch của bạn.'**
  String get billingUpdated;

  /// No description provided for @billingVerified.
  ///
  /// In vi, this message translates to:
  /// **'Giao dịch đã được xác minh.'**
  String get billingVerified;

  /// No description provided for @billingNotVerified.
  ///
  /// In vi, this message translates to:
  /// **'Backend chưa xác minh giao dịch. Giao dịch chưa được hoàn tất.'**
  String get billingNotVerified;

  /// No description provided for @billingCanceled.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ giao dịch.'**
  String get billingCanceled;

  /// No description provided for @proLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải cửa hàng · Thử lại'**
  String get proLoadFailed;

  /// No description provided for @proHeadline.
  ///
  /// In vi, this message translates to:
  /// **'Nhiều cách kết nối hơn'**
  String get proHeadline;

  /// No description provided for @proPerkBoost.
  ///
  /// In vi, this message translates to:
  /// **'Boost khám phá'**
  String get proPerkBoost;

  /// No description provided for @proPerkInvite.
  ///
  /// In vi, this message translates to:
  /// **'Lời mời kết bạn ưu tiên'**
  String get proPerkInvite;

  /// No description provided for @proMinorNotice.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản dưới 18 tuổi không hiển thị ưu đãi.'**
  String get proMinorNotice;

  /// No description provided for @proNoWebProducts.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có sản phẩm bán qua web.'**
  String get proNoWebProducts;

  /// No description provided for @proWebPaymentNote.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán trên trang web của Animal Locket (VietQR/PayPal). Xong bấm \"Quay lại app\".'**
  String get proWebPaymentNote;

  /// No description provided for @proViaStore.
  ///
  /// In vi, this message translates to:
  /// **'Qua cửa hàng: {product} · {price}'**
  String proViaStore(String product, String price);

  /// No description provided for @proRestore.
  ///
  /// In vi, this message translates to:
  /// **'Khôi phục giao dịch cửa hàng'**
  String get proRestore;

  /// No description provided for @proCurrentPro.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang dùng Pro'**
  String get proCurrentPro;

  /// No description provided for @proCurrentProUntil.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang dùng Pro đến {date}'**
  String proCurrentProUntil(String date);

  /// No description provided for @proCurrentFree.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang dùng gói Free'**
  String get proCurrentFree;

  /// No description provided for @proWallet.
  ///
  /// In vi, this message translates to:
  /// **'Boost: {boosts} · Lời mời ưu tiên: {invites}'**
  String proWallet(int boosts, int invites);

  /// No description provided for @newMoment.
  ///
  /// In vi, this message translates to:
  /// **'Khoảnh khắc mới'**
  String get newMoment;

  /// No description provided for @flashMode.
  ///
  /// In vi, this message translates to:
  /// **'Đổi chế độ đèn flash'**
  String get flashMode;

  /// No description provided for @pickFromGallery.
  ///
  /// In vi, this message translates to:
  /// **'Chọn từ thư viện'**
  String get pickFromGallery;

  /// No description provided for @flipCamera.
  ///
  /// In vi, this message translates to:
  /// **'Lật camera'**
  String get flipCamera;

  /// No description provided for @takePhoto.
  ///
  /// In vi, this message translates to:
  /// **'Chụp ảnh'**
  String get takePhoto;

  /// No description provided for @cameraPermission.
  ///
  /// In vi, this message translates to:
  /// **'Cho phép camera để chụp khoảnh khắc.'**
  String get cameraPermission;

  /// No description provided for @allowCamera.
  ///
  /// In vi, this message translates to:
  /// **'Cho phép camera'**
  String get allowCamera;

  /// No description provided for @previewSendingFirst.
  ///
  /// In vi, this message translates to:
  /// **'Đang gửi ảnh trước, đợi chút nhé.'**
  String get previewSendingFirst;

  /// No description provided for @previewTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xem trước'**
  String get previewTitle;

  /// No description provided for @messageLabel.
  ///
  /// In vi, this message translates to:
  /// **'Lời nhắn'**
  String get messageLabel;

  /// No description provided for @messageHintFriends.
  ///
  /// In vi, this message translates to:
  /// **'Viết gì đó cho bạn bè…'**
  String get messageHintFriends;

  /// No description provided for @sendingPhoto.
  ///
  /// In vi, this message translates to:
  /// **'Đang gửi ảnh trước…'**
  String get sendingPhoto;

  /// No description provided for @sendToFriends.
  ///
  /// In vi, this message translates to:
  /// **'Gửi cho bạn bè'**
  String get sendToFriends;

  /// No description provided for @retake.
  ///
  /// In vi, this message translates to:
  /// **'Chụp lại'**
  String get retake;

  /// No description provided for @previewNote.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh được gửi cho toàn bộ bạn bè. Bản đầu chưa hỗ trợ chọn từng người nhận.'**
  String get previewNote;

  /// No description provided for @sendSending.
  ///
  /// In vi, this message translates to:
  /// **'Đang gửi…'**
  String get sendSending;

  /// No description provided for @sendSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi'**
  String get sendSent;

  /// No description provided for @sendRejected.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh không được chấp nhận'**
  String get sendRejected;

  /// No description provided for @sendFailed.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lỗi, kiểm tra mạng'**
  String get sendFailed;

  /// No description provided for @chatListTitle.
  ///
  /// In vi, this message translates to:
  /// **'Trò chuyện'**
  String get chatListTitle;

  /// No description provided for @chatOnlyFriends.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn chỉ mở giữa bạn bè.'**
  String get chatOnlyFriends;

  /// No description provided for @chatEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có cuộc trò chuyện nào.'**
  String get chatEmpty;

  /// No description provided for @chatStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu trò chuyện'**
  String get chatStart;

  /// No description provided for @chatRecent.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn gần đây'**
  String get chatRecent;

  /// No description provided for @unreadCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} tin chưa đọc'**
  String unreadCount(int count);

  /// No description provided for @friendsLabel.
  ///
  /// In vi, this message translates to:
  /// **'Bạn bè'**
  String get friendsLabel;

  /// No description provided for @swipesLeft.
  ///
  /// In vi, this message translates to:
  /// **'Còn {count} lượt quẹt phải hôm nay'**
  String swipesLeft(int count);

  /// No description provided for @enableLocationHint.
  ///
  /// In vi, this message translates to:
  /// **'Bật vị trí để tìm người ở gần. Hiện chỉ thấy người đang online.'**
  String get enableLocationHint;

  /// No description provided for @enableLocation.
  ///
  /// In vi, this message translates to:
  /// **'Bật vị trí'**
  String get enableLocation;

  /// No description provided for @discoverSlow.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ đang chậm, bộ thẻ có thể chưa đầy đủ.'**
  String get discoverSlow;

  /// No description provided for @skip.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ qua'**
  String get skip;

  /// No description provided for @useBoost.
  ///
  /// In vi, this message translates to:
  /// **'Dùng Boost'**
  String get useBoost;

  /// No description provided for @addFriend.
  ///
  /// In vi, this message translates to:
  /// **'Kết bạn'**
  String get addFriend;

  /// No description provided for @friendsMade.
  ///
  /// In vi, this message translates to:
  /// **'Đã thành bạn! Bạn có thể bắt đầu trò chuyện.'**
  String get friendsMade;

  /// No description provided for @boostUsed.
  ///
  /// In vi, this message translates to:
  /// **'Đã dùng 1 Boost.'**
  String get boostUsed;

  /// No description provided for @online.
  ///
  /// In vi, this message translates to:
  /// **'Đang online'**
  String get online;

  /// No description provided for @anonymousAnimal.
  ///
  /// In vi, this message translates to:
  /// **'Con vật ẩn danh'**
  String get anonymousAnimal;

  /// No description provided for @deckEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Hết thẻ mới rồi'**
  String get deckEmpty;

  /// No description provided for @reload.
  ///
  /// In vi, this message translates to:
  /// **'Tải lại'**
  String get reload;

  /// No description provided for @findNewFriends.
  ///
  /// In vi, this message translates to:
  /// **'Tìm người bạn mới'**
  String get findNewFriends;

  /// No description provided for @locationConsent.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí chỉ được xin khi bạn bật khám phá. Nếu từ chối, bạn vẫn có thể dùng chế độ online.'**
  String get locationConsent;

  /// No description provided for @enableDiscovery.
  ///
  /// In vi, this message translates to:
  /// **'Bật khám phá'**
  String get enableDiscovery;

  /// No description provided for @discoverLoadFailedCode.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải khám phá ({code}).'**
  String discoverLoadFailedCode(String code);

  /// No description provided for @discoverLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải khám phá.'**
  String get discoverLoadFailed;

  /// No description provided for @distUnder1km.
  ///
  /// In vi, this message translates to:
  /// **'dưới 1 km'**
  String get distUnder1km;

  /// No description provided for @dist1to3km.
  ///
  /// In vi, this message translates to:
  /// **'1–3 km'**
  String get dist1to3km;

  /// No description provided for @distUnder3km.
  ///
  /// In vi, this message translates to:
  /// **'dưới 3 km'**
  String get distUnder3km;

  /// No description provided for @dist3to10km.
  ///
  /// In vi, this message translates to:
  /// **'3–10 km'**
  String get dist3to10km;

  /// No description provided for @distOver10km.
  ///
  /// In vi, this message translates to:
  /// **'trên 10 km'**
  String get distOver10km;

  /// No description provided for @feedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khoảnh khắc'**
  String get feedTitle;

  /// No description provided for @feedLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải feed. Vui lòng kiểm tra mạng.'**
  String get feedLoadFailed;

  /// No description provided for @feedEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có khoảnh khắc nào\nHãy chụp ảnh hoặc kết bạn để bắt đầu.'**
  String get feedEmpty;

  /// No description provided for @feedDegraded.
  ///
  /// In vi, this message translates to:
  /// **'Một phần dịch vụ đang chậm. Feed có thể chưa đầy đủ.'**
  String get feedDegraded;

  /// No description provided for @unlike.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ thích'**
  String get unlike;

  /// No description provided for @like.
  ///
  /// In vi, this message translates to:
  /// **'Thích'**
  String get like;

  /// No description provided for @timeJustNow.
  ///
  /// In vi, this message translates to:
  /// **'Vừa xong'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In vi, this message translates to:
  /// **'{count} phút trước'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In vi, this message translates to:
  /// **'{count} giờ trước'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In vi, this message translates to:
  /// **'{count} ngày trước'**
  String timeDaysAgo(int count);

  /// No description provided for @dayToday.
  ///
  /// In vi, this message translates to:
  /// **'Hôm nay'**
  String get dayToday;

  /// No description provided for @dayYesterday.
  ///
  /// In vi, this message translates to:
  /// **'Hôm qua'**
  String get dayYesterday;

  /// No description provided for @noPhotosYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ảnh nào.'**
  String get noPhotosYet;

  /// No description provided for @befriendToSee.
  ///
  /// In vi, this message translates to:
  /// **'Kết bạn để xem ảnh của người này.'**
  String get befriendToSee;

  /// No description provided for @photosLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được ảnh · Thử lại'**
  String get photosLoadFailed;

  /// No description provided for @morePhotos.
  ///
  /// In vi, this message translates to:
  /// **'Xem thêm ảnh'**
  String get morePhotos;

  /// No description provided for @postProcessing.
  ///
  /// In vi, this message translates to:
  /// **'Đang xử lý'**
  String get postProcessing;

  /// No description provided for @postRejected.
  ///
  /// In vi, this message translates to:
  /// **'Bị từ chối'**
  String get postRejected;

  /// No description provided for @postRejectedPhoto.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh bị từ chối'**
  String get postRejectedPhoto;

  /// No description provided for @postProcessingPhoto.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh đang được xử lý'**
  String get postProcessingPhoto;

  /// No description provided for @deletePhoto.
  ///
  /// In vi, this message translates to:
  /// **'Xoá ảnh'**
  String get deletePhoto;

  /// No description provided for @deletePhotoQ.
  ///
  /// In vi, this message translates to:
  /// **'Xoá ảnh này?'**
  String get deletePhotoQ;

  /// No description provided for @deletePhotoBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn bè sẽ không còn thấy ảnh này nữa.'**
  String get deletePhotoBody;

  /// No description provided for @deletePhotoFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không xoá được ảnh. Thử lại sau.'**
  String get deletePhotoFailed;

  /// No description provided for @friendsAndRequests.
  ///
  /// In vi, this message translates to:
  /// **'Bạn bè và lời mời'**
  String get friendsAndRequests;

  /// No description provided for @tabFriends.
  ///
  /// In vi, this message translates to:
  /// **'Bạn bè {count}'**
  String tabFriends(int count);

  /// No description provided for @tabRequests.
  ///
  /// In vi, this message translates to:
  /// **'Lời mời {count}'**
  String tabRequests(int count);

  /// No description provided for @tabSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi {count}'**
  String tabSent(int count);

  /// No description provided for @noFriends.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bạn bè.'**
  String get noFriends;

  /// No description provided for @offline.
  ///
  /// In vi, this message translates to:
  /// **'Ngoại tuyến'**
  String get offline;

  /// No description provided for @viewProfile.
  ///
  /// In vi, this message translates to:
  /// **'Xem hồ sơ'**
  String get viewProfile;

  /// No description provided for @noIncoming.
  ///
  /// In vi, this message translates to:
  /// **'Không có lời mời mới.'**
  String get noIncoming;

  /// No description provided for @noOutgoing.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa gửi lời mời nào.'**
  String get noOutgoing;

  /// No description provided for @distanceHidden.
  ///
  /// In vi, this message translates to:
  /// **'Không hiển thị khoảng cách để bảo vệ riêng tư'**
  String get distanceHidden;

  /// No description provided for @accept.
  ///
  /// In vi, this message translates to:
  /// **'Chấp nhận'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get decline;

  /// No description provided for @settings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get settings;

  /// No description provided for @changeNickname.
  ///
  /// In vi, this message translates to:
  /// **'Đổi biệt danh'**
  String get changeNickname;

  /// No description provided for @memberPro.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên Pro'**
  String get memberPro;

  /// No description provided for @memberFree.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên Free'**
  String get memberFree;

  /// No description provided for @ownedAvatars.
  ///
  /// In vi, this message translates to:
  /// **'Avatar sở hữu'**
  String get ownedAvatars;

  /// No description provided for @myPhotos.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh của tôi'**
  String get myPhotos;

  /// No description provided for @noMyPhotos.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa đăng ảnh nào.'**
  String get noMyPhotos;

  /// No description provided for @collection.
  ///
  /// In vi, this message translates to:
  /// **'Bộ sưu tập'**
  String get collection;

  /// No description provided for @collectionNote.
  ///
  /// In vi, this message translates to:
  /// **'Mỗi avatar chỉ thuộc về bạn, không ai khác có được.'**
  String get collectionNote;

  /// No description provided for @collectionNoteMulti.
  ///
  /// In vi, this message translates to:
  /// **'Chạm một avatar để dùng nó. Mỗi avatar chỉ thuộc về bạn.'**
  String get collectionNoteMulti;

  /// No description provided for @spinAvatarButton.
  ///
  /// In vi, this message translates to:
  /// **'Quay avatar ({count})'**
  String spinAvatarButton(int count);

  /// No description provided for @upgradePro.
  ///
  /// In vi, this message translates to:
  /// **'Nâng cấp Pro'**
  String get upgradePro;

  /// No description provided for @friendsCount.
  ///
  /// In vi, this message translates to:
  /// **'Bạn bè ({count})'**
  String friendsCount(int count);

  /// No description provided for @seeAll.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả'**
  String get seeAll;

  /// No description provided for @friendsLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được bạn bè · Thử lại'**
  String get friendsLoadFailed;

  /// No description provided for @noFriendsYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bạn bè nào.'**
  String get noFriendsYet;

  /// No description provided for @findFriends.
  ///
  /// In vi, this message translates to:
  /// **'Tìm bạn'**
  String get findFriends;

  /// No description provided for @openProfileOf.
  ///
  /// In vi, this message translates to:
  /// **'Mở trang của {name}'**
  String openProfileOf(String name);

  /// No description provided for @profileLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải hồ sơ.'**
  String get profileLoadFailed;

  /// No description provided for @photosOf.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh của {name}'**
  String photosOf(String name);

  /// No description provided for @noPhotosOf.
  ///
  /// In vi, this message translates to:
  /// **'{name} chưa đăng ảnh nào.'**
  String noPhotosOf(String name);

  /// No description provided for @anonymousProfile.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ ẩn danh'**
  String get anonymousProfile;

  /// No description provided for @message.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin'**
  String get message;

  /// No description provided for @unfriend.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ kết bạn'**
  String get unfriend;

  /// No description provided for @report.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo'**
  String get report;

  /// No description provided for @block.
  ///
  /// In vi, this message translates to:
  /// **'Chặn'**
  String get block;

  /// No description provided for @blockQ.
  ///
  /// In vi, this message translates to:
  /// **'Chặn người này?'**
  String get blockQ;

  /// No description provided for @blockBody.
  ///
  /// In vi, this message translates to:
  /// **'Hai người sẽ không thể tìm thấy hoặc nhắn tin cho nhau.'**
  String get blockBody;

  /// No description provided for @reportDetails.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết'**
  String get reportDetails;

  /// No description provided for @sendReport.
  ///
  /// In vi, this message translates to:
  /// **'Gửi báo cáo'**
  String get sendReport;

  /// No description provided for @reportSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi báo cáo.'**
  String get reportSent;

  /// No description provided for @settingsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt và riêng tư'**
  String get settingsTitle;

  /// No description provided for @allowDiscovery.
  ///
  /// In vi, this message translates to:
  /// **'Cho phép khám phá'**
  String get allowDiscovery;

  /// No description provided for @discoveryOffNote.
  ///
  /// In vi, this message translates to:
  /// **'Tắt để xoá vị trí và dừng xuất hiện trong bộ thẻ.'**
  String get discoveryOffNote;

  /// No description provided for @blockedSection.
  ///
  /// In vi, this message translates to:
  /// **'Đã chặn'**
  String get blockedSection;

  /// No description provided for @nobodyBlocked.
  ///
  /// In vi, this message translates to:
  /// **'Chưa chặn ai.'**
  String get nobodyBlocked;

  /// No description provided for @unblock.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ chặn'**
  String get unblock;

  /// No description provided for @signOut.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất'**
  String get signOut;

  /// No description provided for @deleteAccount.
  ///
  /// In vi, this message translates to:
  /// **'Xoá tài khoản'**
  String get deleteAccount;

  /// No description provided for @deleteAccountQ.
  ///
  /// In vi, this message translates to:
  /// **'Xoá tài khoản?'**
  String get deleteAccountQ;

  /// No description provided for @deleteAccountBody.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh, tin nhắn và hồ sơ sẽ bị xoá. Thao tác này không thể hoàn tác.'**
  String get deleteAccountBody;

  /// No description provided for @keepAccount.
  ///
  /// In vi, this message translates to:
  /// **'Giữ tài khoản'**
  String get keepAccount;

  /// No description provided for @finalConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận lần cuối'**
  String get finalConfirm;

  /// No description provided for @typeDeleteWord.
  ///
  /// In vi, this message translates to:
  /// **'Nhập XOÁ để xác nhận'**
  String get typeDeleteWord;

  /// No description provided for @deleteWord.
  ///
  /// In vi, this message translates to:
  /// **'XOÁ'**
  String get deleteWord;

  /// No description provided for @deleteForever.
  ///
  /// In vi, this message translates to:
  /// **'Xoá vĩnh viễn'**
  String get deleteForever;

  /// No description provided for @themeSection.
  ///
  /// In vi, this message translates to:
  /// **'Màu giao diện'**
  String get themeSection;

  /// No description provided for @themeShu.
  ///
  /// In vi, this message translates to:
  /// **'Shu · Son đỏ'**
  String get themeShu;

  /// No description provided for @themeYuzu.
  ///
  /// In vi, this message translates to:
  /// **'Yuzu · Vàng thanh yên'**
  String get themeYuzu;

  /// No description provided for @themeSakura.
  ///
  /// In vi, this message translates to:
  /// **'Sakura · Hồng anh đào'**
  String get themeSakura;

  /// No description provided for @themeSora.
  ///
  /// In vi, this message translates to:
  /// **'Sora · Trời xanh'**
  String get themeSora;

  /// No description provided for @glyphSysAgree.
  ///
  /// In vi, this message translates to:
  /// **'Đồng ý'**
  String get glyphSysAgree;

  /// No description provided for @glyphSysHurry.
  ///
  /// In vi, this message translates to:
  /// **'Gấp nhé'**
  String get glyphSysHurry;

  /// No description provided for @glyphSysBusy.
  ///
  /// In vi, this message translates to:
  /// **'Đang bận'**
  String get glyphSysBusy;

  /// No description provided for @glyphSysCoffee.
  ///
  /// In vi, this message translates to:
  /// **'Đi cà phê không?'**
  String get glyphSysCoffee;

  /// No description provided for @glyphSysHungry.
  ///
  /// In vi, this message translates to:
  /// **'Đói bụng'**
  String get glyphSysHungry;

  /// No description provided for @glyphSysComing.
  ///
  /// In vi, this message translates to:
  /// **'Đang tới'**
  String get glyphSysComing;

  /// No description provided for @view.
  ///
  /// In vi, this message translates to:
  /// **'Xem'**
  String get view;

  /// No description provided for @unfriendQ.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ kết bạn với {name}?'**
  String unfriendQ(String name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
