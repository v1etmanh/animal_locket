import 'package:animal_locket/app.dart';
import 'package:animal_locket/core/auth/session_manager.dart';
import 'package:animal_locket/core/network/token_store.dart';
import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:animal_locket/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer containerWith(ThemeStore store) {
    final c = ProviderContainer(
      overrides: [themeStoreProvider.overrideWithValue(store)],
    );
    addTearDown(c.dispose);
    return c;
  }

  // Cho phép lần đọc store bất đồng bộ trong build() chạy xong.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('empty store starts and stays on Shu', () async {
    final c = containerWith(MemoryThemeStore());
    expect(c.read(albumThemeProvider), AlbumThemeId.shu);
    await settle();
    expect(c.read(albumThemeProvider), AlbumThemeId.shu);
  });

  test('restores the saved theme', () async {
    final c = containerWith(MemoryThemeStore(AlbumThemeId.sakura));
    c.read(albumThemeProvider);
    await settle();
    expect(c.read(albumThemeProvider), AlbumThemeId.sakura);
  });

  test('select applies at once and persists', () async {
    final store = MemoryThemeStore();
    final c = containerWith(store);
    await c.read(albumThemeProvider.notifier).select(AlbumThemeId.sora);
    expect(c.read(albumThemeProvider), AlbumThemeId.sora);
    expect(await store.read(), AlbumThemeId.sora);
  });

  test('a failing store falls back to Shu without throwing', () async {
    final c = containerWith(_ThrowingStore());
    expect(c.read(albumThemeProvider), AlbumThemeId.shu);
    await settle();
    expect(c.read(albumThemeProvider), AlbumThemeId.shu);
    await c.read(albumThemeProvider.notifier).select(AlbumThemeId.yuzu);
    expect(c.read(albumThemeProvider), AlbumThemeId.yuzu);
  });

  test('an unknown stored value parses to null', () {
    expect(parseAlbumThemeId('neon'), isNull);
    expect(parseAlbumThemeId(null), isNull);
    expect(parseAlbumThemeId('sora'), AlbumThemeId.sora);
  });

  testWidgets('the app theme follows the stored choice', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
          themeStoreProvider.overrideWithValue(
            MemoryThemeStore(AlbumThemeId.sora),
          ),
        ],
        child: const AnimalLocketApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // The stored theme lands after the first frames; MaterialApp then lerps
    // to it over ~200ms (AnimatedTheme), so let that animation finish.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    final context = tester.element(find.text('Mở tài khoản demo'));
    expect(
      Theme.of(context).extension<AlbumPalette>()!.accent,
      AlbumPalette.of(AlbumThemeId.sora).accent,
    );
  });
}

class _ThrowingStore implements ThemeStore {
  @override
  Future<AlbumThemeId?> read() async =>
      throw MissingPluginException('no secure storage in tests');
  @override
  Future<void> write(AlbumThemeId id) async =>
      throw MissingPluginException('no secure storage in tests');
}

class _MemoryTokenStore implements TokenStore {
  TokenBundle? value;
  @override
  Future<void> clear() async => value = null;
  @override
  Future<TokenBundle?> read() async => value;
  @override
  Future<void> save(TokenBundle bundle) async => value = bundle;
}
