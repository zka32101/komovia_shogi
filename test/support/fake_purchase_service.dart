import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:komovia_shogi/services/purchase_service.dart';

/// テスト用のPurchaseService。プラットフォームプラグインに一切触れず、
/// [emit]でpurchaseStreamに任意の更新を流せる。
class FakePurchaseService extends PurchaseService {
  FakePurchaseService({
    this.available = true,
    Set<String>? knownProducts,
    this.onBuy,
  }) : knownProducts = knownProducts ?? PurchaseService.productIds;

  bool available;
  Set<String> knownProducts;

  /// buy()が呼ばれたときの反応（例: purchasedをemitする）。
  void Function(FakePurchaseService self, ProductDetails product)? onBuy;

  final _controller = StreamController<List<PurchaseDetails>>.broadcast();
  final List<String> completed = [];
  int restoreCalls = 0;

  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetails?> fetchProduct(String productId) async =>
      knownProducts.contains(productId) ? product(productId) : null;

  @override
  Future<bool> buy(ProductDetails product) async {
    scheduleMicrotask(() => onBuy?.call(this, product));
    return true;
  }

  @override
  Future<void> restorePurchases() async => restoreCalls++;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async =>
      completed.add(purchase.productID);
}

ProductDetails product(String id) => ProductDetails(
      id: id,
      title: id,
      description: id,
      price: '¥300',
      rawPrice: 300,
      currencyCode: 'JPY',
    );

PurchaseDetails purchase(String id, PurchaseStatus status) => PurchaseDetails(
      productID: id,
      verificationData: PurchaseVerificationData(
          localVerificationData: '', serverVerificationData: '', source: 'test'),
      transactionDate: '0',
      status: status,
    )..pendingCompletePurchase = true;
