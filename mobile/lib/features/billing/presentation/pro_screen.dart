import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/core/widgets/glass_container.dart';
import 'package:animal_locket/features/billing/presentation/billing_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProScreen extends ConsumerWidget {
  const ProScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(billingControllerProvider);
    return AppPage(
      title: 'Animal Locket Pro',
      child: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Không thể tải cửa hàng.')),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.auto_awesome, size: 80, color: AppColors.purple),
            const SizedBox(height: 18),
            Text(
              'Nhiều cách kết nối hơn',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 18),
            const GlassContainer(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.bolt),
                    title: Text('Boost khám phá'),
                  ),
                  ListTile(
                    leading: Icon(Icons.pets),
                    title: Text('Đổi con vật chủ đạo'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (!data.enabled)
              const Text(
                'Mua hàng đang tắt cho đến khi có tài khoản store sandbox. Tài khoản dưới 18 tuổi cũng không hiển thị ưu đãi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              )
            else ...[
              for (final product in data.products)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton(
                    onPressed: data.busy || data.details[product.sku] == null
                        ? null
                        : () => ref
                              .read(billingControllerProvider.notifier)
                              .buy(product.sku),
                    child: Text(
                      '${product.item} × ${product.quantity} · ${data.details[product.sku]?.price ?? 'Không có giá store'}',
                    ),
                  ),
                ),
              TextButton(
                onPressed: data.busy
                    ? null
                    : ref.read(billingControllerProvider.notifier).restore,
                child: const Text('Khôi phục giao dịch'),
              ),
            ],
            if (data.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(data.message!, textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }
}
