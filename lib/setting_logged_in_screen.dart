import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'services/theme_service.dart';
import 'services/language_service.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pro_subscription_screen.dart';

class SettingsLoggedInScreen extends StatelessWidget {
  const SettingsLoggedInScreen({super.key});

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
            // 사용자 정보 헤더
            _buildUserHeader(context, colors),
            Divider(
              height: 1,
              thickness: 1,
              color: colors.textLight.withValues(alpha: 0.08),
            ),
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

          // 로그아웃
          _buildMenuHeader(title: loc.get('system'), colors: colors),
          _buildMenuItem(
            icon: Icons.logout,
            title: loc.get('logout'),
            subtitle: loc.get('logout_description'),
            onTap: () async {
              await AuthService.instance.signOut();
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
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

  Widget _buildUserHeader(BuildContext context, CustomColors colors) {
    return Material(
      color: colors.background,
      child: StreamBuilder<User?>(
        stream: AuthService.instance.authStateChanges,
        initialData: FirebaseAuth.instance.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data;
          final String title = (user?.displayName?.trim().isNotEmpty == true)
              ? user!.displayName!
              : (user?.email ?? AppLocalizations.of(context).get('guest_user'));
          final String? subtitle = user?.email;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            color: colors.background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: colors.textLight.withValues(alpha: 0.2),
                  child: Icon(Icons.person, color: colors.text, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  title.contains('@') ? title.split('@')[0] : title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) const SizedBox(height: 4),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(color: colors.textLight, fontSize: 13),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          );
        },
      ),
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
