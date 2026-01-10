import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'services/theme_service.dart';
import 'services/language_service.dart';
import 'theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Scaffold(
      appBar: AppBar(title: Text(loc.get('settings'))),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 설정 메뉴
            _buildSettingsMenu(context, loc, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsMenu(
    BuildContext context,
    AppLocalizations loc,
    CustomColors colors,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          _buildMenuHeader(title: loc.get('system'), colors: colors),

          _buildMenuItem(
            icon: Icons.language,
            title: loc.get('app_language_setting'),
            subtitle: LanguageService.getAppLanguageDisplayName(
              LanguageService.appLanguageCode,
              loc,
            ),
            onTap: () => _showLanguageSettings(context, loc, colors),
            colors: colors,
          ),
          _buildMenuItem(
            icon: Icons.swap_vert,
            title: loc.get('language_order'),
            subtitle: loc.get('language_order_description'),
            onTap: () => _showLanguageOrderDialog(context, loc, colors),
            colors: colors,
          ),

          _buildMenuHeader(title: loc.get('information'), colors: colors),

          /*
          // PRO 업그레이드 숨기기
          _buildMenuItem(
            icon: Icons.workspace_premium,
            title: loc.get('pro_upgrade'),
            subtitle: loc.get('pro_upgrade_description'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProSubscriptionScreen()),
              );
            },
            colors: colors,
          ),
          */
          _buildMenuItem(
            icon: Icons.info,
            title: loc.get('app_info'),
            subtitle: loc.get('app_version'),
            onTap: () {},
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuHeader({
    required String title,
    required CustomColors colors,
  }) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 20, top: 20, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          color: colors.textLight,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? textColor,
    required CustomColors colors,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.only(left: 6, right: 8),
        child: Icon(icon, color: textColor ?? colors.text),
      ),
      title: Text(
        title,
        style: TextStyle(color: textColor ?? colors.text, fontSize: 15),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: textColor?.withValues(alpha: 0.7) ?? colors.text,
                fontSize: 12,
              ),
            )
          : null,
      trailing: Icon(Icons.chevron_right, color: colors.textLight),
      onTap: onTap,
    );
  }

  void _showLanguageSettings(
    BuildContext context,
    AppLocalizations loc,
    CustomColors colors,
  ) {
    final messengerContext = context;
    final langs = LanguageService.getLocalizedAppLanguages(loc);
    final current = LanguageService.appLanguageCode;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Text(
                  loc.get('app_language_setting'),
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: colors.textLight.withValues(alpha: 0.08),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: langs.length,
              itemBuilder: (_, index) {
                final item = langs[index];
                final code = item['code']!;
                final label = item['name']!;
                final selected = code.toLowerCase() == current.toLowerCase();
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: selected
                      ? Icon(Icons.check, color: colors.primary)
                      : const SizedBox(width: 24),
                  title: Text(label, style: TextStyle(color: colors.text)),
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    await LanguageService.setAppLanguageCode(code);
                    // 새 로케일 기준으로 메시지/언어명을 생성하여 스낵바 표시
                    final newLocale = LanguageService.createLocale(code);
                    final newLoc = AppLocalizations(newLocale);
                    final newLabel = LanguageService.getAppLanguageDisplayName(
                      code,
                      newLoc,
                    );
                    ScaffoldMessenger.of(messengerContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          newLoc.getWithParams('language_changed', {
                            'language': newLabel,
                          }),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(loc.cancel),
            ),
          ],
        );
      },
    );
  }

  void _showLanguageOrderDialog(
    BuildContext context,
    AppLocalizations loc,
    CustomColors colors,
  ) {
    final messengerContext = context;
    final nameMap = {
      for (final m in LanguageService.getLocalizedTranslationLanguages(loc))
        m['code']!: m['name']!,
    };
    List<String> order = LanguageService.getTranslationLanguageOrder();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Text(
                loc.get('language_order'),
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.get('language_order_description'),
                      style: TextStyle(
                        color: colors.textLight,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 320,
                      child: ReorderableListView(
                        buildDefaultDragHandles: false,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = order.removeAt(oldIndex);
                            order.insert(newIndex, item);
                          });
                        },
                        children: [
                          for (int i = 0; i < order.length; i++)
                            ListTile(
                              key: ValueKey(order[i]),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              title: Text(
                                nameMap[order[i]] ?? order[i],
                                style: TextStyle(color: colors.text),
                              ),
                              trailing: ReorderableDragStartListener(
                                index: i,
                                child: Icon(
                                  Icons.drag_handle,
                                  color: colors.textLight,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(loc.cancel),
                ),
                TextButton(
                  onPressed: () async {
                    await LanguageService.setUserLanguageOrder(order);
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(messengerContext).showSnackBar(
                      SnackBar(
                        content: Text(loc.get('language_order_saved')),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Text(loc.get('confirm')),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
