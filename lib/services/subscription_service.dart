import 'dart:ui' as ui;

class PlanPrice {
  final String currencySymbol;
  final String priceText;
  const PlanPrice({required this.currencySymbol, required this.priceText});
}

class SubscriptionPrices {
  final String countryCode; // ISO 3166-1 alpha-2 (예: KR, US)
  final String currencyCode; // (예: KRW, USD)
  final PlanPrice monthly;
  final PlanPrice yearly;

  const SubscriptionPrices({
    required this.countryCode,
    required this.currencyCode,
    required this.monthly,
    required this.yearly,
  });
}

/// 구독 및 가격 관련 유틸리티
///
/// - 기준 가격(한국): 월 ₩1,200 / 연 ₩12,000
/// - 요청에 따라 환율을 "대략" 반영하여 국가별 가격을 정해둡니다.
/// - 지정 국가 외에는 USD로 표시합니다.
class SubscriptionService {
  static const SubscriptionPrices _kr = SubscriptionPrices(
    countryCode: 'KR',
    currencyCode: 'KRW',
    monthly: PlanPrice(currencySymbol: '₩', priceText: '1,200'),
    yearly: PlanPrice(currencySymbol: '₩', priceText: '12,000'),
  );

  static const SubscriptionPrices _us = SubscriptionPrices(
    countryCode: 'US',
    currencyCode: 'USD',
    monthly: PlanPrice(currencySymbol: '\$', priceText: '0.99'),
    yearly: PlanPrice(currencySymbol: '\$', priceText: '8.99'),
  );

  static const SubscriptionPrices _cn = SubscriptionPrices(
    countryCode: 'CN',
    currencyCode: 'CNY',
    monthly: PlanPrice(currencySymbol: '¥', priceText: '5.99'),
    yearly: PlanPrice(currencySymbol: '¥', priceText: '59.99'),
  );

  static const SubscriptionPrices _jp = SubscriptionPrices(
    countryCode: 'JP',
    currencyCode: 'JPY',
    monthly: PlanPrice(currencySymbol: '¥', priceText: '120'),
    yearly: PlanPrice(currencySymbol: '¥', priceText: '1,200'),
  );

  static const SubscriptionPrices _tw = SubscriptionPrices(
    countryCode: 'TW',
    currencyCode: 'TWD',
    monthly: PlanPrice(currencySymbol: 'NT\$', priceText: '25'),
    yearly: PlanPrice(currencySymbol: 'NT\$', priceText: '250'),
  );

  static const SubscriptionPrices _es = SubscriptionPrices(
    countryCode: 'ES',
    currencyCode: 'EUR',
    monthly: PlanPrice(currencySymbol: '€', priceText: '0.89'),
    yearly: PlanPrice(currencySymbol: '€', priceText: '8.99'),
  );

  static const SubscriptionPrices _de = SubscriptionPrices(
    countryCode: 'DE',
    currencyCode: 'EUR',
    monthly: PlanPrice(currencySymbol: '€', priceText: '0.89'),
    yearly: PlanPrice(currencySymbol: '€', priceText: '8.99'),
  );

  static const SubscriptionPrices _fr = SubscriptionPrices(
    countryCode: 'FR',
    currencyCode: 'EUR',
    monthly: PlanPrice(currencySymbol: '€', priceText: '0.89'),
    yearly: PlanPrice(currencySymbol: '€', priceText: '8.99'),
  );

  /// 플랫폼 로케일에서 국가 코드를 추정합니다. 없으면 'US'를 반환합니다.
  static String resolveUserCountryCode() {
    try {
      final ui.Locale? locale =
          ui.PlatformDispatcher.instance.locales.isNotEmpty
              ? ui.PlatformDispatcher.instance.locales.first
              : ui.PlatformDispatcher.instance.locale;
      final String? code = locale?.countryCode;
      if (code != null && code.trim().isNotEmpty) {
        return code.toUpperCase();
      }
    } catch (_) {}
    return 'US';
  }

  /// 국가 코드에 따른 가격표를 반환합니다.
  static SubscriptionPrices getPricesForCountry(String countryCode) {
    switch (countryCode.toUpperCase()) {
      case 'KR':
        return _kr;
      case 'US':
        return _us;
      case 'CN':
        return _cn;
      case 'JP':
        return _jp;
      case 'TW':
        return _tw;
      case 'ES':
        return _es;
      case 'DE':
        return _de;
      case 'FR':
        return _fr;
      default:
        return _us; // 지정 국가가 아니면 USD 기본
    }
  }

  /// 현재 사용자 추정 국가 기준의 가격표를 반환합니다.
  static SubscriptionPrices getPricesForCurrentUser() {
    final String code = resolveUserCountryCode();
    return getPricesForCountry(code);
  }
}


