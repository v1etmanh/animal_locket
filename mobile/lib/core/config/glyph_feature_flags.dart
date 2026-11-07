import 'package:flutter_riverpod/flutter_riverpod.dart';

class GlyphFeatureFlags {
  const GlyphFeatureFlags({
    required this.readEnabled,
    required this.personalLibraryEnabled,
    required this.publishEnabled,
    required this.sendEnabled,
  });

  factory GlyphFeatureFlags.fromEnvironment() => const GlyphFeatureFlags(
    readEnabled: bool.fromEnvironment('GLYPH_READ_ENABLED', defaultValue: true),
    personalLibraryEnabled: bool.fromEnvironment(
      'GLYPH_PERSONAL_LIBRARY_ENABLED',
      defaultValue: true,
    ),
    publishEnabled: bool.fromEnvironment(
      'GLYPH_PUBLISH_ENABLED',
      defaultValue: false,
    ),
    sendEnabled: bool.fromEnvironment(
      'GLYPH_SEND_ENABLED',
      defaultValue: false,
    ),
  );

  final bool readEnabled;
  final bool personalLibraryEnabled;
  final bool publishEnabled;
  final bool sendEnabled;
}

final glyphFeatureFlagsProvider = Provider<GlyphFeatureFlags>(
  (_) => GlyphFeatureFlags.fromEnvironment(),
);
