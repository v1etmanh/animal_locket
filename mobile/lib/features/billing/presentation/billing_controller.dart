import 'dart:async';

import 'package:animal_locket/core/auth/auth_controller.dart';
import 'package:animal_locket/core/config/app_config.dart';
import 'package:animal_locket/core/models/common_models.dart';
import 'package:animal_locket/features/billing/data/billing_repository_impl.dart';
import 'package:animal_locket/features/billing/domain/billing_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class BillingState {
  const BillingState({
    required this.enabled,
    this.products = const [],
    this.details = const {},
    this.busy = false,
    this.message,
  });
  final bool enabled;
  final List<BillingProduct> products;
  final Map<String, ProductDetails> details;
  final bool busy;
  final String? message;
  BillingState copyWith({bool? busy, String? message}) => BillingState(
    enabled: enabled,
    products: products,
    details: details,
    busy: busy ?? this.busy,
    message: message,
  );
}

class BillingController extends AsyncNotifier<BillingState> {
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  @override
  Future<BillingState> build() async {
    final config = ref.watch(appConfigProvider);
    final profile = ref.watch(authControllerProvider).profile;
    if (!config.enableBilling || profile?.ageGroup == AgeGroup.minor) {
      return const BillingState(enabled: false);
    }
    final store = InAppPurchase.instance;
    if (!await store.isAvailable()) {
      return const BillingState(
        enabled: false,
        message: 'Cửa hàng chưa sẵn sàng.',
      );
    }
    _subscription = store.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) {
        final current = state.value;
        if (current != null) {
          state = AsyncData(
            current.copyWith(busy: false, message: 'Giao dịch gặp lỗi.'),
          );
        }
      },
    );
    ref.onDispose(() => _subscription?.cancel());
    final products = await ref.read(billingRepositoryProvider).products();
    final response = await store.queryProductDetails(
      products.map((item) => item.sku).toSet(),
    );
    return BillingState(
      enabled: true,
      products: products,
      details: {for (final item in response.productDetails) item.id: item},
      message: response.error?.message,
    );
  }

  Future<void> buy(String sku) async {
    final current = state.value;
    final details = current?.details[sku];
    if (current == null || details == null || current.busy) return;
    state = AsyncData(current.copyWith(busy: true));
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
  }

  Future<void> restore() async {
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(busy: true));
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          await ref
              .read(billingRepositoryProvider)
              .verify(
                store: defaultTargetPlatform == TargetPlatform.iOS
                    ? 'APPLE'
                    : 'GOOGLE',
                sku: purchase.productID,
                token: purchase.verificationData.serverVerificationData,
              );
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
          final current = state.value;
          if (current != null) {
            state = AsyncData(
              current.copyWith(
                busy: false,
                message: 'Giao dịch đã được xác minh.',
              ),
            );
          }
        } catch (error) {
          final current = state.value;
          if (current != null) {
            state = AsyncData(
              current.copyWith(
                busy: false,
                message: 'Backend chưa xác minh giao dịch. Giao dịch chưa được hoàn tất.',
              ),
            );
          }
        }
      } else if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        final current = state.value;
        if (current != null) {
          state = AsyncData(
            current.copyWith(
              busy: false,
              message: purchase.error?.message ?? 'Đã huỷ giao dịch.',
            ),
          );
        }
      }
    }
  }
}

final billingControllerProvider =
    AsyncNotifierProvider<BillingController, BillingState>(
      BillingController.new,
    );
