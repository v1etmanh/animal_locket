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
}
