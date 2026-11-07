import 'package:animal_locket/features/chat/domain/glyph.dart';
import 'package:animal_locket/features/chat/domain/glyph_recognizer.dart';
import 'package:animal_locket/features/chat/presentation/chat_controllers.dart';
import 'package:animal_locket/features/chat/presentation/glyph_controllers.dart';
import 'package:animal_locket/features/chat/presentation/widgets/glyph_drawing_pad.dart';
import 'package:animal_locket/features/chat/presentation/widgets/glyph_token.dart';
import 'package:animal_locket/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GlyphComposerPanel extends ConsumerStatefulWidget {
  const GlyphComposerPanel({
    super.key,
    required this.conversationId,
    required this.enabled,
  });

  final String conversationId;
  final bool enabled;

  @override
  ConsumerState<GlyphComposerPanel> createState() => _GlyphComposerPanelState();
}

class _GlyphComposerPanelState extends ConsumerState<GlyphComposerPanel> {
  final _recognizer = const GlyphRecognizer();
  GlyphRecognition? _recognition;
  List<GlyphPoint> _stroke = const [];

  void _recognize(List<GlyphPoint> stroke, List<GlyphDefinition> dictionary) {
    setState(() {
      _stroke = stroke;
      _recognition = stroke.length < 5
          ? null
          : _recognizer.recognize(stroke, dictionary);
    });
  }

  Future<void> _send(List<GlyphDefinition> selected) async {
    if (selected.isEmpty) return;
    final composer = ref.read(
      glyphComposerProvider(widget.conversationId).notifier,
    );
    composer.setBusy(true);
    try {
      final sent = await ref
          .read(conversationControllerProvider(widget.conversationId).notifier)
          .sendGlyphs(selected);
      if (!mounted) return;
      if (sent) {
        composer.clear();
      } else {
        composer.setBusy(false);
      }
    } catch (_) {
      if (mounted) composer.setBusy(false);
    }
  }

  Future<void> _openBuilder(List<GlyphDefinition> dictionary) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _GlyphBuilderSheet(initialStroke: _stroke, dictionary: dictionary),
    );
    if (saved == true) {
      ref.invalidate(personalGlyphsProvider);
      ref.invalidate(conversationGlyphsProvider(widget.conversationId));
    }
  }

  Future<void> _openDictionary(List<GlyphDefinition> dictionary) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _GlyphDictionarySheet(
          conversationId: widget.conversationId,
          glyphs: dictionary,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dictionary = ref.watch(
      conversationGlyphsProvider(widget.conversationId),
    );
    final composer = ref.watch(glyphComposerProvider(widget.conversationId));
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .96),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: dictionary.when(
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => SizedBox(
            height: 140,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.glyphDictionaryError),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => ref.invalidate(
                      conversationGlyphsProvider(widget.conversationId),
                    ),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
          data: (glyphs) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlyphDrawingPad(
                semanticsLabel: l10n.glyphDrawLabel,
                hint: l10n.glyphDrawHint,
                clearLabel: l10n.glyphClearStroke,
                onStrokeComplete: (stroke) => _recognize(stroke, glyphs),
              ),
              const SizedBox(height: 8),
              _RecognitionResult(
                recognition: _recognition,
                onAdd: (glyph) => ref
                    .read(glyphComposerProvider(widget.conversationId).notifier)
                    .add(glyph),
              ),
              if (glyphs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(l10n.glyphDictionaryEmpty),
                )
              else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.glyphQuickPick,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: glyphs.take(12).length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, index) {
                      final glyph = glyphs[index];
                      return Semantics(
                        button: true,
                        label: glyph.meaning,
                        child: IconButton.filledTonal(
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 48,
                          ),
                          tooltip: glyph.meaning,
                          onPressed: widget.enabled && !composer.busy
                              ? () => ref
                                    .read(
                                      glyphComposerProvider(
                                        widget.conversationId,
                                      ).notifier,
                                    )
                                    .add(glyph)
                              : null,
                          icon: GlyphIcon(glyph: glyph, size: 28),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (composer.selected.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.glyphComposerEmpty,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < composer.selected.length; i++)
                        GlyphToken(
                          glyph: composer.selected[i],
                          removeLabel: l10n.glyphRemoveToken(
                            composer.selected[i].meaning,
                          ),
                          onRemove: widget.enabled && !composer.busy
                              ? () => ref
                                    .read(
                                      glyphComposerProvider(
                                        widget.conversationId,
                                      ).notifier,
                                    )
                                    .removeAt(i)
                              : null,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: l10n.glyphDictionary,
                    child: IconButton(
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      tooltip: l10n.glyphDictionary,
                      onPressed: () => _openDictionary(glyphs),
                      icon: const Icon(Icons.menu_book_outlined),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l10n.glyphCreate,
                    child: IconButton(
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      tooltip: l10n.glyphCreate,
                      onPressed: widget.enabled
                          ? () => _openBuilder(glyphs)
                          : null,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ),
                  const Spacer(),
                  if (composer.selected.isNotEmpty)
                    Semantics(
                      button: true,
                      label: l10n.glyphClearComposer,
                      child: IconButton(
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        tooltip: l10n.glyphClearComposer,
                        onPressed: composer.busy
                            ? null
                            : ref
                                  .read(
                                    glyphComposerProvider(widget.conversationId)
                                        .notifier,
                                  )
                                  .clear,
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed:
                        widget.enabled &&
                            composer.selected.isNotEmpty &&
                            !composer.busy
                        ? () => _send(composer.selected)
                        : null,
                    icon: composer.busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(l10n.glyphSend),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecognitionResult extends StatelessWidget {
  const _RecognitionResult({required this.recognition, required this.onAdd});

  final GlyphRecognition? recognition;
  final ValueChanged<GlyphDefinition> onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (recognition == null) return const SizedBox.shrink();
    if (recognition!.ambiguous) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.glyphAmbiguous),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: recognition!.alternatives
                .map(
                  (candidate) => ActionChip(
                    avatar: GlyphIcon(glyph: candidate.glyph, size: 24),
                    label: Text(candidate.glyph.meaning),
                    onPressed: () => onAdd(candidate.glyph),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      );
    }
    if (!recognition!.matched || recognition!.best == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(l10n.glyphNoMatch),
      );
    }
    final glyph = recognition!.best!;
    return Row(
      children: [
        Expanded(child: Text(l10n.glyphMatched(glyph.meaning))),
        TextButton.icon(
          onPressed: () => onAdd(glyph),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.glyphAddToComposer),
        ),
      ],
    );
  }
}

class _GlyphBuilderSheet extends ConsumerStatefulWidget {
  const _GlyphBuilderSheet({
    required this.initialStroke,
    required this.dictionary,
    this.editing,
  });

  final List<GlyphPoint> initialStroke;
  final List<GlyphDefinition> dictionary;
  final GlyphDefinition? editing;

  @override
  ConsumerState<_GlyphBuilderSheet> createState() => _GlyphBuilderSheetState();
}

class _GlyphBuilderSheetState extends ConsumerState<_GlyphBuilderSheet> {
  late final TextEditingController _meaning;
  final _recognizer = const GlyphRecognizer();
  late List<GlyphPoint> _stroke;
  late int _color;
  var _saving = false;

  static const _palette = [
    0xFF818CF8,
    0xFF34D399,
    0xFFFBBF24,
    0xFFF472B6,
    0xFF38BDF8,
    0xFFFB923C,
    0xFFC084FC,
  ];

  @override
  void initState() {
    super.initState();
    _meaning = TextEditingController(text: widget.editing?.meaning ?? '');
    _stroke = widget.editing?.points ?? widget.initialStroke;
    _color = widget.editing?.colorArgb ?? 0xFFF472B6;
  }

  @override
  void dispose() {
    _meaning.dispose();
    super.dispose();
  }

  double get _collision => widget.dictionary
      .where((glyph) => glyph.id != widget.editing?.id)
      .fold<double>(0, (value, glyph) {
        if (_stroke.length < 5) return value;
        final similarity = _recognizer.similarity(_stroke, glyph);
        return similarity > value ? similarity : value;
      });

  Future<void> _save() async {
    if (_stroke.length < 5 || _meaning.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await ref
        .read(personalGlyphsProvider.notifier)
        .save(
          meaning: _meaning.text.trim(),
          colorArgb: _color,
          points: _stroke,
          localId: widget.editing?.id,
        );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.glyphCreate,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            GlyphDrawingPad(
              semanticsLabel: l10n.glyphDrawLabel,
              hint: l10n.glyphDrawHint,
              clearLabel: l10n.glyphClearStroke,
              initialPoints: _stroke,
              color: Color(_color),
              onStrokeComplete: (points) => setState(() => _stroke = points),
            ),
            if (_collision >= .85)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.glyphCollisionWarning,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _meaning,
              maxLength: 64,
              decoration: InputDecoration(
                labelText: l10n.glyphMeaningLabel,
                hintText: l10n.glyphMeaningHint,
              ),
              onChanged: (_) => setState(() {}),
            ),
            Text(l10n.glyphColorLabel),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              children: _palette
                  .map(
                    (color) => Semantics(
                      button: true,
                      selected: color == _color,
                      label:
                          '${l10n.glyphColorLabel} ${_palette.indexOf(color) + 1}',
                      child: InkWell(
                        onTap: () => setState(() => _color = color),
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(color),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == _color
                                  ? Colors.black
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    !_saving &&
                        _stroke.length >= 5 &&
                        _meaning.text.trim().isNotEmpty &&
                        _collision < .85
                    ? _save
                    : null,
                child: Text(l10n.glyphSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlyphDictionarySheet extends ConsumerWidget {
  const _GlyphDictionarySheet({
    required this.conversationId,
    required this.glyphs,
  });

  final String conversationId;
  final List<GlyphDefinition> glyphs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final groups = [
      glyphs.where((item) => item.kind == GlyphKind.system).toList(),
      glyphs.where((item) => item.kind == GlyphKind.personal).toList(),
      glyphs.where((item) => item.kind == GlyphKind.conversation).toList(),
    ];
    return DefaultTabController(
      length: 3,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.glyphDictionary,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TabBar(
              tabs: [
                Tab(text: l10n.glyphSystemTab),
                Tab(text: l10n.glyphPersonalTab),
                Tab(text: l10n.glyphConversationTab),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final group in groups)
                    group.isEmpty
                        ? Center(child: Text(l10n.glyphDictionaryEmpty))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: group.length,
                            itemBuilder: (_, index) {
                              final glyph = group[index];
                              return ListTile(
                                minTileHeight: 56,
                                leading: GlyphIcon(glyph: glyph),
                                title: Text(glyph.meaning),
                                onTap: glyph.kind == GlyphKind.personal
                                    ? () async {
                                        final saved =
                                            await showModalBottomSheet<bool>(
                                              context: context,
                                              isScrollControlled: true,
                                              useSafeArea: true,
                                              builder: (_) =>
                                                  _GlyphBuilderSheet(
                                                    initialStroke: glyph.points,
                                                    dictionary: glyphs,
                                                    editing: glyph,
                                                  ),
                                            );
                                        if (saved == true) {
                                          ref.invalidate(
                                            personalGlyphsProvider,
                                          );
                                          ref.invalidate(
                                            conversationGlyphsProvider(
                                              conversationId,
                                            ),
                                          );
                                        }
                                      }
                                    : null,
                                trailing: glyph.kind == GlyphKind.personal
                                    ? Semantics(
                                        button: true,
                                        label: l10n.glyphDelete,
                                        child: IconButton(
                                          constraints:
                                              const BoxConstraints.tightFor(
                                                width: 44,
                                                height: 44,
                                              ),
                                          tooltip: l10n.glyphDelete,
                                          onPressed: () async {
                                            await ref
                                                .read(
                                                  personalGlyphsProvider
                                                      .notifier,
                                                )
                                                .deactivate(glyph.id);
                                            ref.invalidate(
                                              conversationGlyphsProvider(
                                                conversationId,
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      )
                                    : null,
                              );
                            },
                          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
