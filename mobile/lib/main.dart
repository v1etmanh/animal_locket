import 'package:animal_locket/app.dart';
import 'package:animal_locket/core/avatar/avatar_library.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Thư viện avatar đóng gói theo app: vẽ được ngay, không cần mạng.
  await AvatarLibraries.instance.loadBundled();
  runApp(const ProviderScope(child: AnimalLocketApp()));
}
