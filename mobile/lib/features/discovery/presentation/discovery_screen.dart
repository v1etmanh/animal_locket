import 'package:animal_locket/core/network/api_problem.dart';
import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/animal_avatar.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/core/widgets/glass_container.dart';
import 'package:animal_locket/core/widgets/gradient_button.dart';
import 'package:animal_locket/features/discovery/presentation/discovery_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});
  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen>
    with WidgetsBindingObserver {
  bool _routeActive = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(discoveryControllerProvider.notifier).setActive(false);
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
    final value = ref.watch(discoveryControllerProvider);
    return AppPage(
      child: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DiscoveryError(error: error),
        data: (data) {
          if (!data.enabled) return const _EnableDiscovery();
          final card = data.cards.firstOrNull;
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
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Bạn bè'),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Còn ${data.swipesLeftToday} lượt quẹt phải hôm nay',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
              if (data.locationOff)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_off_outlined,
                        size: 18,
                        color: AppColors.orange,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Bật vị trí để tìm người ở gần. Hiện chỉ thấy người đang online.',
                          style: TextStyle(color: AppColors.orange),
                        ),
                      ),
                      TextButton(
                        onPressed: ref
                            .read(discoveryControllerProvider.notifier)
                            .requestLocation,
                        child: const Text('Bật vị trí'),
                      ),
                    ],
                  ),
                ),
              if (data.degraded)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Dịch vụ đang chậm, bộ thẻ có thể chưa đầy đủ.',
                    style: TextStyle(color: AppColors.orange),
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                height: 430,
                child: card == null
                    ? GlassContainer(
                        borderRadius: 36,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.travel_explore,
                              size: 70,
                              color: AppColors.sketchPurple,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Hết thẻ mới rồi',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            TextButton(
                              onPressed: ref
                                  .read(discoveryControllerProvider.notifier)
                                  .refresh,
                              child: const Text('Tải lại'),
                            ),
                          ],
                        ),
                      )
                    : GlassContainer(
                        borderRadius: 36,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (card.boosted)
                              const Align(
                                alignment: Alignment.topRight,
                                child: Chip(
                                  avatar: Icon(Icons.bolt, size: 16),
                                  label: Text('Boost'),
                                ),
                              ),
                            AnimalAvatar(
                              avatar: card.avatar,
                              leadAnimal: card.leadAnimal,
                              size: 190,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              card.alias,
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (card.online)
                                  const InfoPill(
                                    label: 'Đang online',
                                    icon: Icons.circle,
                                  ),
                                if (card.distanceLabel != null)
                                  InfoPill(
                                    label: card.distanceLabel!,
                                    icon: Icons.near_me_outlined,
                                  ),
                                InfoPill(
                                  label: 'Con vật ẩn danh',
                                  icon: Icons.pets_outlined,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundAction(
                    label: 'Bỏ qua',
                    icon: Icons.close,
                    size: 64,
                    onTap: card == null || data.busy
                        ? null
                        : () => _swipe(false),
                  ),
                  const SizedBox(width: 16),
                  _RoundAction(
                    label: 'Dùng Boost',
                    icon: Icons.bolt,
                    size: 52,
                    onTap: data.busy ? null : _boost,
                  ),
                  const SizedBox(width: 16),
                  _RoundAction(
                    label: 'Kết bạn',
                    icon: Icons.favorite,
                    size: 72,
                    green: true,
                    onTap: card == null || data.busy
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

class _EnableDiscovery extends ConsumerWidget {
  const _EnableDiscovery();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: GlassContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.travel_explore, size: 72, color: AppColors.purple),
          const SizedBox(height: 16),
          Text(
            'Tìm người bạn mới',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          const Text(
            'Vị trí chỉ được xin khi bạn bật khám phá. Nếu từ chối, bạn vẫn có thể dùng chế độ online.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GradientButton(
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
        ),
        TextButton(
          onPressed: ref.read(discoveryControllerProvider.notifier).refresh,
          child: const Text('Thử lại'),
        ),
      ],
    ),
  );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.label,
    required this.icon,
    required this.size,
    required this.onTap,
    this.green = false,
  });
  final String label;
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final bool green;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: green
              ? const LinearGradient(
                  colors: [AppColors.greenLight, AppColors.green],
                )
              : null,
          color: green ? null : Colors.white,
          boxShadow: const [
            BoxShadow(
              color: Color(0x221E1B2E),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: green ? Colors.white : AppColors.purple),
      ),
    ),
  );
}
