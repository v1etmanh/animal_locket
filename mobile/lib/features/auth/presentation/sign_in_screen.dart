import 'package:animal_locket/core/auth/auth_controller.dart';
import 'package:animal_locket/core/network/api_problem.dart';
import 'package:animal_locket/core/network/error_messages.dart';
import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/animal_avatar.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/core/widgets/glass_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final busy = auth.status == AuthStatus.checking;
    final problem = auth.error is ApiProblem ? auth.error! as ApiProblem : null;
    return AppPage(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height - 64,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AnimalAvatar(emoji: '🦊', size: 86),
                Transform.translate(
                  offset: const Offset(-10, 18),
                  child: const AnimalAvatar(
                    emoji: '🐼',
                    size: 66,
                    colorIndex: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Gần nhau hơn,\nvẫn là chính mình.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 14),
            const Text(
              'Chia sẻ khoảnh khắc với bạn bè. Khuôn mặt luôn được thay bằng con vật trước khi đăng.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 34),
            GlassContainer(
              child: Column(
                children: [
                  _LoginButton(
                    icon: Icons.email_outlined,
                    label: busy ? 'Đang mở đăng nhập…' : 'Đăng nhập bằng email',
                    onTap: busy
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .signIn(),
                  ),
                  if (problem == null && auth.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Đăng nhập thất bại: ${auth.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (problem != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      messageForApiCode(problem.code, status: problem.status),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: busy
                  ? null
                  : () => ref.read(authControllerProvider.notifier).enterDemo(),
              child: const Text('Mở tài khoản demo'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chúng tôi không hiển thị tên thật, email hay vị trí chính xác của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
