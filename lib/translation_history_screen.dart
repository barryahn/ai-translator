import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'services/theme_service.dart';
import 'services/language_service.dart';
import 'services/translation_history_service.dart';

class TranslationHistoryScreen extends StatelessWidget {
  const TranslationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translation_history),
      ),
      body: StreamBuilder<List<TranslationHistoryItem>>(
        stream: TranslationHistoryService.instance.watchAll(),
        builder: (context, snapshot) {
          final themeService = context.watch<ThemeService>();
          final colors = themeService.colors;

          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(colors.textLight),
              ),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context).get('no_history'),
                style: TextStyle(color: colors.textLight),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: colors.textLight.withValues(alpha: 0.08),
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return Dismissible(
                key: ValueKey('history_${item.id}'),
                background: Container(
                  color: Colors.redAccent.withValues(alpha: 0.9),
                ),
                onDismissed: (_) {
                  TranslationHistoryService.instance.deleteById(item.id);
                },
                child: ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colors.text.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _localized(context, item.fromUiLanguage),
                                style: TextStyle(
                                  color: colors.text.withValues(alpha: 0.6),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_right_alt,
                                size: 18,
                                color: colors.text.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _localized(context, item.toUiLanguage),
                                style: TextStyle(
                                  color: colors.text.withValues(alpha: 0.6),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        item.inputText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textLight),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.resultText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _localized(BuildContext context, String uiCode) {
  final items = LanguageService.getLocalizedTranslationLanguages(
    AppLocalizations.of(context),
  );
  final match = items.firstWhere(
    (m) => m['code'] == uiCode,
    orElse: () => {'name': uiCode},
  );
  return match['name'] ?? uiCode;
}
