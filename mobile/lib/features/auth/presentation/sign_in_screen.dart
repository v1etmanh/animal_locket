import 'package:animal_locket/core/auth/auth_controller.dart';
import 'package:animal_locket/core/avatar/avatar_library.dart';
import 'package:animal_locket/core/network/api_problem.dart';
import 'package:animal_locket/core/network/error_messages.dart';
import 'package:animal_locket/core/theme/album_palette.dart';
import 'package:animal_locket/core/widgets/album/paper_button.dart';
import 'package:animal_locket/core/widgets/album/polaroid.dart';
import 'package:animal_locket/core/widgets/album_icon.dart';
import 'package:animal_locket/core/widgets/animal_avatar.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Màn đăng nhập như bìa sổ ảnh: hai polaroid con vật origami (spec §7.3).
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  static const _fox = '1:fox:0:none';
  static const _panda = '1:panda:3:none';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.album;
    final auth = ref.watch(authControllerProvider);
    final busy = auth.status == AuthStatus.checking;
    final problem = auth.error is ApiProblem ? auth.error! as ApiProblem : null;
    final controller = ref.read(authControllerProvider.notifier);
    Widget polaroid(String code, double width, double tilt) => Polaroid(
      width: width,
      tiltDegrees: tilt,
      caption: AvatarLibraries.instance.animalName(code) ?? '',
      child: AnimalAvatar(avatar: code, size: width, square: true),
    );
    return AppPage(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height - 64,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            // Hai ảnh dán lệch nhau như bìa sổ.
            Center(
              child: SizedBox(
                width: 260,
                height: 210,
                child: Stack(
                  children: [
                    Positioned(left: 8, top: 6, child: polaroid(_fox, 128, -6)),
                    Positioned(
                      right: 6,
                      top: 52,
                      child: polaroid(_panda, 110, 7),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Gần nhau hơn,\nvẫn là chính mình.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 14),
            Text(
              'Chia sẻ khoảnh khắc với bạn bè. Mỗi người là một con vật duy nhất, không lộ tên thật.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, height: 1.5),
            ),
            const SizedBox(height: 30),
            PaperButton(
              label: busy ? 'Đang mở đăng nhập…' : 'Đăng nhập bằng email',
              icon: AlbumIcons.mail,
              onPressed: busy ? null : controller.signIn,
            ),
            if (problem == null && auth.error != null) ...[
              const SizedBox(height: 12),
              Text(
                'Đăng nhập thất bại: ${auth.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.danger, fontSize: 12),
              ),
            ],
            if (problem != null) ...[
              const SizedBox(height: 12),
              Text(
                messageForApiCode(problem.code, status: problem.status),
                textAlign: TextAlign.center,
                style: TextStyle(color: p.danger),
              ),
            ],
            const SizedBox(height: 22),
            Center(
              child: PaperButton.tape(
                label: 'Mở tài khoản demo',
                onPressed: busy ? null : controller.enterDemo,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chúng tôi không hiển thị tên thật, email hay vị trí chính xác của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 11, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
