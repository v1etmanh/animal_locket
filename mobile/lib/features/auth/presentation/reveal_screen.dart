import 'dart:math';

import 'package:animal_locket/core/assets/animal_asset_resolver.dart';
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

  @override
  void dispose() {
    _alias.dispose();
    super.dispose();
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
      if (mounted) setState(() => _profile = profile);
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
    final leadAnimal = _profile?.leadAnimal;
    final emoji = const AnimalAssetResolver().emojiFor(leadAnimal);
    return AppPage(
      child: Column(
        children: [
          const SizedBox(height: 28),
          const SectionLabel('Con vật đầu tiên của bạn'),
          const SizedBox(height: 22),
          AnimalAvatar(emoji: emoji, size: 184),
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
                : 'Con vật chủ đạo: ${leadAnimal ?? 'đang cập nhật'}',
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
                ? (_busy ? 'Đang đăng ký…' : 'Nhận con vật')
                : 'Vào app',
            icon: Icons.arrow_forward_rounded,
            onPressed: _busy
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
