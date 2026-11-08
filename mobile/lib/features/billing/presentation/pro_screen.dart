import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:animal_locket/core/widgets/app_page.dart';
import 'package:animal_locket/core/widgets/glass_container.dart';
import 'package:animal_locket/features/billing/domain/billing_repository.dart';
import 'package:animal_locket/features/billing/presentation/billing_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProScreen extends ConsumerStatefulWidget {
  const ProScreen({super.key});

  @override
  ConsumerState<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends ConsumerState<ProScreen> {
  // Thanh toán diễn ra trong trình duyệt; quay lại app (nút "Quay lại app" hoặc tự chuyển) thì tải lại gói/ví.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () =>
        ref.read(billingControllerProvider.notifier).refreshAfterCheckout(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // khởi tạo listener
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(billingControllerProvider);
    return AppPage(
      title: 'Animal Locket Pro',
      child: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(billingControllerProvider),
            child: const Text('Không thể tải cửa hàng · Thử lại'),
          ),
        ),
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
                    leading: Icon(Icons.mark_email_unread_outlined),
                    title: Text('Lời mời kết bạn ưu tiên'),
                  ),
                ],
              ),
            ),
            if (data.me != null) ...[
              const SizedBox(height: 14),
              _CurrentPlan(me: data.me!),
            ],
            const SizedBox(height: 18),
            if (!data.enabled)
              Text(
                data.message ?? 'Tài khoản dưới 18 tuổi không hiển thị ưu đãi.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              )
            else ...[
              if (data.webProducts.isEmpty)
                const Text(
                  'Chưa có sản phẩm bán qua web.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              for (final product in data.webProducts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton(
                    onPressed: data.busy
                        ? null
                        : () => ref
                              .read(billingControllerProvider.notifier)
                              .buyOnWeb(product.sku),
                    child: Text(
                      '${product.label} · ${product.priceLabel ?? ''}',
                    ),
                  ),
                ),
              const Text(
                'Thanh toán trên trang web của Animal Locket (VietQR/PayPal). '
                'Xong bấm "Quay lại app".',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              if (data.storeEnabled) ...[
                const SizedBox(height: 18),
                for (final product in data.products)
                  if (data.details[product.sku] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextButton(
                        onPressed: data.busy
                            ? null
                            : () => ref
                                  .read(billingControllerProvider.notifier)
                                  .buy(product.sku),
                        child: Text(
                          'Qua cửa hàng: ${product.label} · ${data.details[product.sku]!.price}',
                        ),
                      ),
                    ),
                TextButton(
                  onPressed: data.busy
                      ? null
                      : ref.read(billingControllerProvider.notifier).restore,
                  child: const Text('Khôi phục giao dịch cửa hàng'),
                ),
              ],
            ],
            if (data.enabled && data.message != null)
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

class _CurrentPlan extends StatelessWidget {
  const _CurrentPlan({required this.me});
  final BillingMe me;

  @override
  Widget build(BuildContext context) {
    final expires = me.planExpiresAt?.toLocal();
    final boosts = me.wallet['BOOST'] ?? 0;
    final invites = me.wallet['PRIORITY_INVITE'] ?? 0;
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            me.plan == 'PRO'
                ? 'Bạn đang dùng Pro${expires == null ? '' : ' đến ${expires.day}/${expires.month}/${expires.year}'}'
                : 'Bạn đang dùng gói Free',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Boost: $boosts · Lời mời ưu tiên: $invites',
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
