import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'pro_service.dart';

class InAppPurchaseService extends ChangeNotifier {
  InAppPurchaseService._internal();
  static final InAppPurchaseService _instance =
      InAppPurchaseService._internal();
  factory InAppPurchaseService() => _instance;

  static const String monthlyProductId = 'ai_translator_pro_monthly';
  static const String yearlyProductId = 'ai_translator_pro_yearly';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _initialized = false;
  bool _storeAvailable = false;
  bool _isLoadingProducts = false;
  bool _isProcessingPurchase = false;
  String? _lastMessage;
  List<ProductDetails> _products = [];

  bool get isStoreAvailable => _storeAvailable;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isProcessingPurchase => _isProcessingPurchase;
  String? get lastMessage => _lastMessage;
  List<ProductDetails> get products => List.unmodifiable(_products);

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _purchaseSubscription ??=
        _inAppPurchase.purchaseStream.listen(_onPurchaseUpdated,
            onError: (Object error) {
      _lastMessage = '결제 스트림 오류: $error';
      _isProcessingPurchase = false;
      notifyListeners();
    }, onDone: () {
      _purchaseSubscription?.cancel();
      _purchaseSubscription = null;
    });
    _initialized = true;
    await reloadProducts();
  }

  Future<void> reloadProducts() async {
    _isLoadingProducts = true;
    notifyListeners();
    try {
      _storeAvailable = await _inAppPurchase.isAvailable();
      if (!_storeAvailable) {
        _products = [];
        _lastMessage = '스토어에 연결할 수 없습니다.';
        return;
      }
      const productIds = <String>{
        monthlyProductId,
        yearlyProductId,
      };
      final response = await _inAppPurchase.queryProductDetails(productIds);
      if (response.error != null) {
        _lastMessage = response.error!.message;
      } else if (response.notFoundIDs.isNotEmpty) {
        _lastMessage =
            '다음 상품 ID를 스토어에서 찾을 수 없습니다: ${response.notFoundIDs.join(', ')}';
      } else {
        _lastMessage = null;
      }
      _products = response.productDetails;
    } catch (e) {
      _lastMessage = '상품 정보를 불러오는 중 오류가 발생했습니다: $e';
      _products = [];
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  String? priceLabelForPlan(String plan) {
    final product = _productForPlan(plan);
    return product?.price;
  }

  Future<bool> purchasePlan(String plan) async {
    await ensureInitialized();
    if (!_storeAvailable) {
      _lastMessage = '스토어를 사용할 수 없습니다. 잠시 후 다시 시도해주세요.';
      notifyListeners();
      return false;
    }
    final product = _productForPlan(plan);
    if (product == null) {
      _lastMessage =
          '선택한 플랜 정보를 찾을 수 없습니다. 잠시 후 다시 시도해주세요.';
      notifyListeners();
      await reloadProducts();
      return false;
    }
    final purchaseParam = PurchaseParam(productDetails: product);

    _isProcessingPurchase = true;
    _lastMessage = null;
    notifyListeners();
    try {
      final bool launched =
          await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      if (!launched) {
        _lastMessage = '결제 플로우를 시작하지 못했습니다.';
        _isProcessingPurchase = false;
        notifyListeners();
      }
      return launched;
    } catch (e) {
      _lastMessage = '결제 요청 중 오류가 발생했습니다: $e';
      _isProcessingPurchase = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> restorePurchases() async {
    await ensureInitialized();
    if (!_storeAvailable) {
      _lastMessage = '스토어를 사용할 수 없습니다.';
      notifyListeners();
      return;
    }
    await _inAppPurchase.restorePurchases();
  }

  ProductDetails? _productForPlan(String plan) {
    final String productId =
        plan == 'yearly' ? yearlyProductId : monthlyProductId;
    try {
      return _products.firstWhere((element) => element.id == productId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _onPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _isProcessingPurchase = true;
          _lastMessage = null;
          notifyListeners();
          break;
        case PurchaseStatus.canceled:
          _lastMessage = '결제를 취소했습니다.';
          _isProcessingPurchase = false;
          notifyListeners();
          break;
        case PurchaseStatus.error:
          _lastMessage =
              purchaseDetails.error?.message ?? '결제 중 오류가 발생했습니다.';
          _isProcessingPurchase = false;
          notifyListeners();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            await ProService().setPro(true);
            _lastMessage = 'Pro 권한이 활성화되었습니다.';
          } else {
            _lastMessage = '영수증 검증에 실패했습니다.';
          }
          _isProcessingPurchase = false;
          notifyListeners();
          break;
      }
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // TODO: 실제 서버에서 영수증 검증 로직을 구현하세요.
    return true;
  }
}



