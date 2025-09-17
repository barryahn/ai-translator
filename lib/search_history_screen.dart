import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'services/theme_service.dart';
import 'services/language_service.dart';
import 'theme/app_theme.dart';

class SearchHistoryScreen extends StatelessWidget {
  const SearchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).search_history)),
      body: const SizedBox.shrink(),
    );
  }
}
