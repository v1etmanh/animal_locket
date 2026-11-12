import 'package:animal_locket/app.dart';
import 'package:animal_locket/core/auth/session_epoch.dart';
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
  final prefs = await _readPrefs();
  runApp(_SessionRoot(theme: prefs.theme, locale: prefs.locale));
}

Future<({AlbumThemeId? theme, Locale? locale})> _readPrefs() async {
  AlbumThemeId? theme;
  try {
    theme = await const SecureThemeStore(FlutterSecureStorage()).read();
  } catch (_) {}
  Locale? locale;
  try {
    locale = await const SecureLocaleStore(FlutterSecureStorage()).read();
  } catch (_) {}
  return (theme: theme, locale: locale);
}

/// Gốc của ứng dụng. Mỗi lần [sessionEpoch] tăng (đăng xuất, phiên hết hạn) thì `ProviderScope`
/// được dựng lại với khóa mới, mọi provider bắt đầu từ đầu và không giữ dữ liệu của tài khoản cũ.
class _SessionRoot extends StatefulWidget {
  const _SessionRoot({required this.theme, required this.locale});

  final AlbumThemeId? theme;
  final Locale? locale;

  @override
  State<_SessionRoot> createState() => _SessionRootState();
}

class _SessionRootState extends State<_SessionRoot> {
  late AlbumThemeId? _theme = widget.theme;
  late Locale? _locale = widget.locale;
  int _epoch = sessionEpoch.value;

  @override
  void initState() {
    super.initState();
    sessionEpoch.addListener(_onReset);
  }

  @override
  void dispose() {
    sessionEpoch.removeListener(_onReset);
    super.dispose();
  }

  Future<void> _onReset() async {
    // Đọc lại theme và ngôn ngữ hiện đang lưu để bản dựng lại không quay về giá trị lúc mở app.
    final prefs = await _readPrefs();
    if (!mounted) return;
    setState(() {
      _theme = prefs.theme;
      _locale = prefs.locale;
      _epoch = sessionEpoch.value;
    });
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    key: ValueKey(_epoch),
    overrides: [
      initialAlbumThemeProvider.overrideWithValue(_theme),
      initialLocaleProvider.overrideWithValue(_locale),
    ],
    child: const AnimalLocketApp(),
  );
}
