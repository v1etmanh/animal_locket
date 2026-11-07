import 'package:animal_locket/core/models/common_models.dart';

class BillingProduct {
  const BillingProduct({
    required this.sku,
    required this.type,
    required this.item,
    required this.quantity,
  });
  factory BillingProduct.fromJson(Map<String, dynamic> json) => BillingProduct(
    sku: json['sku'] as String? ?? '',
    type: json['type'] as String? ?? '',
    item: json['item'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
  );
  final String sku;
  final String type;
  final String item;
  final int quantity;
}

abstract interface class BillingRepository {
  Future<List<BillingProduct>> products();
  Future<MeProfile> verify({
    required String store,
    required String sku,
    required String token,
  });
}
