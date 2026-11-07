class AnimalAssetResolver {
  const AnimalAssetResolver();

  static const _emoji = <String, String>{
    'fox': '🦊',
    'panda': '🐼',
    'tiger': '🐯',
    'rabbit': '🐰',
    'otter': '🦦',
    'wolf': '🐺',
    'cat': '🐱',
    'dog': '🐶',
    'bear': '🐻',
  };

  String emojiFor(String? animalCode) {
    if (animalCode == null) return '🐾';
    final normalized = animalCode.toLowerCase();
    for (final entry in _emoji.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return '🐾';
  }

  static String emoji(String? animalCode) =>
      const AnimalAssetResolver().emojiFor(animalCode);
}
