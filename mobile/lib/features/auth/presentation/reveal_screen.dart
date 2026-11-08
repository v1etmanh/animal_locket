import 'dart:async';
import 'dart:math';

import 'package:animal_locket/core/avatar/avatar_library.dart';
import 'package:animal_locket/core/auth/auth_controller.dart';
import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/core/network/api_problem.dart';
import 'package:animal_locket/core/network/error_messages.dart';
import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/animal_avatar.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/core/widgets/gradient_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RevealScreen extends ConsumerStatefulWidget {
  const RevealScreen({super.key, required this.birthDate});
  final String birthDate;

  @override
  ConsumerState<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends ConsumerState<RevealScreen> {
  static const aliases = [
    'Mây Tinh Nghịch',
    'Cáo Mơ Màng',
    'Nắng Lấp Lánh',
    'Gấu Bồng Bềnh',
  ];
  late final TextEditingController _alias = TextEditingController(
    text: aliases.first,
  );
  MeProfile? _profile;
  bool _busy = false;
  String? _error;

  /// Mã đang hiện trong lúc chạy hiệu ứng quay; null = đã dừng ở avatar thật.
  String? _spinning;
  Timer? _spinTimer;

  @override
  void dispose() {
    _spinTimer?.cancel();
    _alias.dispose();
    super.dispose();
  }

  /// Hiệu ứng quay ~1,2 giây rồi dừng ở avatar server đã cấp (kết quả có trước khi hiệu ứng chạy).
  void _playSpin() {
    final random = Random();
    var ticks = 0;
    _spinTimer?.cancel();
    _spinTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) return timer.cancel();
      ticks++;
      setState(() {
        _spinning = ticks >= 15
            ? null
            : AvatarLibraries.instance.randomCodeForAnimation(random);
      });
      if (ticks >= 15) timer.cancel();
    });
  }

  Future<void> _register() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await ref
          .read(authControllerProvider.notifier)
          .registerProfile(birthDate: widget.birthDate, alias: _alias.text);
      if (mounted) {
        setState(() => _profile = profile);
        _playSpin();
      }
    } on ApiProblem catch (problem) {
      if (mounted) {
        setState(() {
          _error = messageForApiCode(problem.code, status: problem.status);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final spinning = _spinning != null;
    final animalName =
        AvatarLibraries.instance.animalName(profile?.avatar) ??
        profile?.leadAnimal;
    return AppPage(
      child: Column(
        children: [
          const SizedBox(height: 28),
          const SectionLabel('Avatar của riêng bạn'),
          const SizedBox(height: 22),
          AnimalAvatar(
            avatar: _spinning ?? profile?.avatar,
            leadAnimal: profile?.leadAnimal,
            locked: profile == null,
            size: 184,
          ),
          const SizedBox(height: 22),
          Text(
            _profile == null
                ? 'Sẵn sàng nhận con vật?'
                : 'Chào ${_profile!.displayAlias}',
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _profile == null
                ? 'Biệt danh của bạn không cần là tên thật.'
                : spinning
                ? 'Đang quay…'
                : '${animalName ?? 'Con vật'} · không ai khác có avatar này',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 32),
          if (_profile == null)
            TextField(
              controller: _alias,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: 'Biệt danh',
                errorText: _error,
                suffixIcon: Semantics(
                  label: 'Tạo biệt danh ngẫu nhiên',
                  button: true,
                  child: IconButton(
                    onPressed: () => setState(() {
                      _alias.text = aliases[Random().nextInt(aliases.length)];
                    }),
                    icon: const Icon(Icons.casino_outlined),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          GradientButton(
            label: _profile == null
                ? (_busy ? 'Đang đăng ký…' : 'Quay avatar')
                : 'Vào app',
            icon: Icons.arrow_forward_rounded,
            onPressed: _busy || spinning
                ? null
                : _profile == null
                ? _register
                : () => ref
                      .read(authControllerProvider.notifier)
                      .finishRegistration(_profile!),
          ),
        ],
      ),
    );
  }
}
