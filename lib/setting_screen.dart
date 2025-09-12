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
      appBar: AppBar(title: const Text('설정')),
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

          _buildMenuHeader(title: loc.get('information'), colors: colors),

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
        style: TextStyle(
          color: textColor ?? colors.text,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
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
}
