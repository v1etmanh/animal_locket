import 'package:animal_locket/app.dart';
import 'package:animal_locket/core/avatar/avatar_library.dart';
import 'package:animal_locket/core/l10n/locale_controller.dart';
import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:animal_locket/core/theme/theme_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Thư viện avatar đóng gói theo app: vẽ được ngay, không cần mạng.
  await AvatarLibraries.instance.loadBundled();
  // Đọc theme đã chọn trước khung hình đầu để không nháy màu Shu.
  AlbumThemeId? theme;
  try {
    theme = await const SecureThemeStore(FlutterSecureStorage()).read();
  } catch (_) {}
  Locale? locale;
  try {
    locale = await const SecureLocaleStore(FlutterSecureStorage()).read();
  } catch (_) {}
  runApp(
    ProviderScope(
      overrides: [
        initialAlbumThemeProvider.overrideWithValue(theme),
        initialLocaleProvider.overrideWithValue(locale),
      ],
      child: const AnimalLocketApp(),
    ),
  );
}
