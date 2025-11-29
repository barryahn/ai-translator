import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'services/theme_service.dart';
import 'services/pro_service.dart';
import 'services/subscription_service.dart';
import 'theme/app_theme.dart';

class ProSubscriptionScreen extends StatefulWidget {
  const ProSubscriptionScreen({super.key});

  @override
  State<ProSubscriptionScreen> createState() => _ProSubscriptionScreenState();
}

class _ProSubscriptionScreenState extends State<ProSubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    // ProService 초기화 (로컬 저장소 및 Firestore 동기화)
    ProService().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;
    final loc = AppLocalizations.of(context);

    // ProService를 이 화면 범위에서 제공 (싱글톤 인스턴스)
    return ChangeNotifierProvider<ProService>.value(
      value: ProService(),
      child: Consumer<ProService>(
        builder: (context, proService, _) {
          final bool isPro = proService.isPro;
          return Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(
              title: Text(loc.get('pro_upgrade')),
              backgroundColor: colors.background,
              elevation: 0,
            ),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(colors, loc, isPro),
                  const SizedBox(height: 12),
                  _buildBenefitsCard(colors, loc),
                  const SizedBox(height: 12),
                  _buildPlans(colors, loc, isPro),
                  const SizedBox(height: 16),
                  _buildCTA(colors, loc, isPro),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(CustomColors colors, AppLocalizations loc, bool isPro) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  isPro ? Icons.verified : Icons.workspace_premium,
                  color: colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPro
                          ? loc.get('pro_thank_you')
                          : loc.get('pro_headline'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isPro
                          ? loc.get('pro_subtitle_thanks')
                          : loc.get('pro_subtitle'),
                      style: TextStyle(fontSize: 13, color: colors.textLight),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsCard(CustomColors colors, AppLocalizations loc) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                loc.get('pro_benefits_title'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _benefitItem(
            colors,
            icon: Icons.all_inclusive,
            title: loc.get('pro_benefit_unlimited_title'),
            desc: loc.get('pro_benefit_unlimited_desc'),
          ),
          _benefitItem(
            colors,
            icon: Icons.psychology_alt,
            title: loc.get('pro_benefit_better_model_title'),
            desc: loc.get('pro_benefit_better_model_desc'),
          ),
          _benefitItem(
            colors,
            icon: Icons.text_fields,
            title: loc.get('pro_benefit_longer_text_title'),
            desc: loc.get('pro_benefit_longer_text_desc'),
          ),
          _benefitItem(
            colors,
            icon: Icons.translate,
            title: loc.get('pro_benefit_quality_title'),
            desc: loc.get('pro_benefit_quality_desc'),
          ),
          _benefitItem(
            colors,
            icon: Icons.block,
            title: loc.get('pro_benefit_no_ads_title'),
            desc: loc.get('pro_benefit_no_ads_desc'),
          ),
          _benefitItem(
            colors,
            icon: Icons.rocket_launch,
            title: loc.get('pro_benefit_extras_title'),
            desc: loc.get('pro_benefit_extras_desc'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _benefitItem(
    CustomColors colors, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: colors.primary, size: 20),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(color: colors.textLight, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlans(CustomColors colors, AppLocalizations loc, bool isPro) {
    final prices = SubscriptionService.getPricesForCurrentUser();
    final String monthlyPriceText = loc.getWithParams('pro_monthly_price', {
      'currency': prices.monthly.currencySymbol,
      'price': prices.monthly.priceText,
    });
    final String yearlyPriceText = loc.getWithParams('pro_yearly_price', {
      'currency': prices.yearly.currencySymbol,
      'price': prices.yearly.priceText,
    });
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _planCard(
            colors,
            title: loc.get('pro_monthly'),
            highlighted: true,
            footer: monthlyPriceText,
          ),
        ),
        Expanded(
          child: _planCard(
            colors,
            title: loc.get('pro_yearly'),
            highlighted: false,
            footer: yearlyPriceText,
          ),
        ),
      ],
    );
  }

  Widget _planCard(
    CustomColors colors, {
    required String title,
    required bool highlighted,
    required String footer,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted
              ? colors.primary.withValues(alpha: 0.25)
              : colors.textLight.withValues(alpha: 0.15),
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              footer,
              style: TextStyle(color: colors.textLight, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTA(CustomColors colors, AppLocalizations loc, bool isPro) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: isPro
              ? null
              : () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(loc.get('pro_upgrade')),
                      content: Text(loc.get('pro_payment_coming_soon')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(loc.get('close')),
                        ),
                      ],
                    ),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.white,
            disabledBackgroundColor: colors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primary, colors.secondary],
              ).createShader(bounds);
            },
            child: Text(
              isPro
                  ? AppLocalizations.of(context).get('pro_thank_you')
                  : AppLocalizations.of(context).get('pro_upgrade_cta'),
              style: const TextStyle(
                color: Colors.white, // gradient를 보이게 하기 위한 placeholder 색
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
