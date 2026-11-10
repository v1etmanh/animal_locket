import 'dart:math' as math;

import 'package:animal_locket/core/network/api_problem.dart';
import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:animal_locket/core/widgets/album/gold_badge.dart';
import 'package:animal_locket/core/widgets/album/hanko_stamp.dart';
import 'package:animal_locket/core/widgets/album/paper_button.dart';
import 'package:animal_locket/core/widgets/album/paper_list.dart';
import 'package:animal_locket/core/widgets/album/paper_tile_button.dart';
import 'package:animal_locket/core/widgets/album/polaroid.dart';
import 'package:animal_locket/core/widgets/album_icon.dart';
import 'package:animal_locket/core/widgets/animal_avatar.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/features/discovery/domain/discovery_repository.dart';
import 'package:animal_locket/features/discovery/presentation/discovery_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Khám phá: thẻ polaroid lớn, nút giấy và con dấu (spec §7.5).
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});
  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen>
    with WidgetsBindingObserver {
  bool _routeActive = false;

  // Giữ sẵn để dùng trong dispose (Riverpod 3 cấm gọi ref khi widget đang huỷ).
  late final DiscoveryController _controller;
  @override
  void initState() {
    super.initState();
    _controller = ref.read(discoveryControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.setActive(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => ref
      .read(discoveryControllerProvider.notifier)
      .setActive(_routeActive && state == AppLifecycleState.resumed);
  @override
  Widget build(BuildContext context) {
    final active = TickerMode.valuesOf(context).enabled;
    if (active != _routeActive) {
      _routeActive = active;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(discoveryControllerProvider.notifier).setActive(active);
        }
      });
    }
    final p = context.album;
    final value = ref.watch(discoveryControllerProvider);
    final controller = ref.read(discoveryControllerProvider.notifier);
    return AppPage(
      child: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DiscoveryError(error: error),
        data: (data) {
          if (!data.enabled) return const _EnableDiscovery();
          final card = data.cards.firstOrNull;
          final photo = math.min(260.0, MediaQuery.sizeOf(context).width - 96);
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Khám phá',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/friends'),
                    icon: AlbumIcon(AlbumIcons.friends, color: p.accent),
                    label: const Text('Bạn bè'),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Còn ${data.swipesLeftToday} lượt quẹt phải hôm nay',
                  style: TextStyle(color: p.muted),
                ),
              ),
              if (data.locationOff)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      AlbumIcon(
                        AlbumIcons.locationOff,
                        size: 18,
                        color: p.accentDeep,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Bật vị trí để tìm người ở gần. Hiện chỉ thấy người đang online.',
                          style: TextStyle(color: p.accentDeep),
                        ),
                      ),
                      TextButton(
                        onPressed: controller.requestLocation,
                        child: const Text('Bật vị trí'),
                      ),
                    ],
                  ),
                ),
              if (data.degraded)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Dịch vụ đang chậm, bộ thẻ có thể chưa đầy đủ.',
                    style: TextStyle(color: p.accentDeep),
                  ),
                ),
              const SizedBox(height: 26),
              card == null
                  ? _NoCards(onReload: controller.refresh)
                  : _CardPolaroid(card: card, width: photo),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PaperTileButton(
                    icon: AlbumIcons.close,
                    label: 'Bỏ qua',
                    size: 60,
                    onPressed: card == null || data.busy
                        ? null
                        : () => _swipe(false),
                  ),
                  const SizedBox(width: 20),
                  PaperTileButton(
                    icon: AlbumIcons.bolt,
                    label: 'Dùng Boost',
                    size: 50,
                    onPressed: data.busy ? null : _boost,
                  ),
                  const SizedBox(width: 20),
                  HankoStamp(
                    stamped: true,
                    toggle: false,
                    tooltip: 'Kết bạn',
                    size: 68,
                    onPressed: card == null || data.busy
                        ? null
                        : () => _swipe(true),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _swipe(bool right) async {
    try {
      final result = await ref
          .read(discoveryControllerProvider.notifier)
          .swipe(right);
      if (!mounted) return;
      if (result == 'MATCHED') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã thành bạn! Bạn có thể bắt đầu trò chuyện.'),
          ),
        );
      }
    } on ApiProblem catch (problem) {
      if (!mounted) return;
      if (problem.code == 'SWIPE_LIMIT') context.push('/pro');
    }
  }

  Future<void> _boost() async {
    try {
      await ref.read(discoveryControllerProvider.notifier).boost();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã dùng 1 Boost.')));
      }
    } on ApiProblem catch (problem) {
      if (mounted && problem.code == 'NO_BOOST') context.push('/pro');
    }
  }
}

/// Thẻ khám phá: polaroid lớn, biệt danh viết tay, nhãn giấy, huy hiệu Boost.
class _CardPolaroid extends StatelessWidget {
  const _CardPolaroid({required this.card, required this.width});
  final DiscoveryCard card;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Polaroid(
              width: width,
              tiltDegrees: -2,
              caption: card.alias,
              child: AnimalAvatar(
                avatar: card.avatar,
                leadAnimal: card.leadAnimal,
                size: width,
                square: true,
              ),
            ),
            if (card.boosted)
              Positioned(
                right: -14,
                top: -14,
                child: GoldBadge(label: 'Boost'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (card.online)
              const _PaperChip(label: 'Đang online', dot: onlineGreen),
            if (card.distanceLabel != null)
              _PaperChip(label: card.distanceLabel!),
            const _PaperChip(label: 'Con vật ẩn danh'),
          ],
        ),
      ],
    );
  }
}

/// Nhãn giấy nhỏ dưới thẻ.
class _PaperChip extends StatelessWidget {
  const _PaperChip({required this.label, this.dot});
  final String label;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final p = context.album;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.paper,
        boxShadow: const [
          BoxShadow(
            color: Color(0x225A3C1E),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              DecoratedBox(
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                child: const SizedBox.square(dimension: 7),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: p.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hết thẻ: trang giấy trống + nhãn "Tải lại".
class _NoCards extends StatelessWidget {
  const _NoCards({required this.onReload});
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final p = context.album;
    return _PaperPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AlbumIcon(AlbumIcons.discover, size: 64, color: p.muted),
          const SizedBox(height: 16),
          Text(
            'Hết thẻ mới rồi',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          PaperButton.tape(label: 'Tải lại', onPressed: onReload),
        ],
      ),
    );
  }
}

/// Trang giấy có bóng mềm, dùng cho các trạng thái trống.
class _PaperPage extends StatelessWidget {
  const _PaperPage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.album.paper,
      boxShadow: const [
        BoxShadow(
          color: Color(0x225A3C1E),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

class _EnableDiscovery extends ConsumerWidget {
  const _EnableDiscovery();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: _PaperPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AlbumIcon(AlbumIcons.discover, size: 64, color: context.album.accent),
          const SizedBox(height: 16),
          Text(
            'Tìm người bạn mới',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          const Text(
            'Vị trí chỉ được xin khi bạn bật khám phá. Nếu từ chối, bạn vẫn có thể dùng chế độ online.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          PaperButton(
            label: 'Bật khám phá',
            onPressed: ref.read(discoveryControllerProvider.notifier).enable,
          ),
        ],
      ),
    ),
  );
}

class _DiscoveryError extends ConsumerWidget {
  const _DiscoveryError({required this.error});
  final Object error;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          error is ApiProblem
              ? 'Không thể tải khám phá (${(error as ApiProblem).code ?? (error as ApiProblem).status}).'
              : 'Không thể tải khám phá.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        PaperButton.tape(
          label: 'Thử lại',
          onPressed: ref.read(discoveryControllerProvider.notifier).refresh,
        ),
      ],
    ),
  );
}
