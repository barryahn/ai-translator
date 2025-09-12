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
            _buildSettingsMenu(loc, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsMenu(AppLocalizations loc, CustomColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          _buildMenuHeader(title: loc.get('system'), colors: colors),

          _buildMenuItem(
            icon: Icons.language,
            title: loc.get('app_language_setting'),
            subtitle: LanguageService.getUiLanguageFromCode(
              LanguageService.appLanguageCode,
            ),
            onTap: () => _showLanguageSettings(loc),
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

  void _showLanguageSettings(AppLocalizations loc) {
    debugPrint("open language settings: ${loc.get('app_language_setting')}");
  }
}
