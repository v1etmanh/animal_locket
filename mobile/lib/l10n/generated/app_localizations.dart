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
