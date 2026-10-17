import 'package:droiddeck/core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DroidDeckAppConfig extends StatelessWidget {
  const DroidDeckAppConfig({
    super.key,
    this.bindings,
    this.modules,
    this.pageBuilders,
    this.pages,
    required this.title,
  });

  final String title;
  final ApplicationBindings? bindings;
  final List<FlutterGetItPageRouter>? pages;
  final List<FlutterGetItPageBuilder>? pageBuilders;
  final List<FlutterGetItModule>? modules;

  @override
  Widget build(BuildContext context) {
    return FlutterGetIt(
      debugMode: kDebugMode,
      bindings: bindings,
      pages: [...pages ?? [], ...pageBuilders ?? []],
      modules: modules,
      builder: (context, routes, flutterGetItNavObserver) {
        return AsyncStateBuilder(
          loader: AppLoader(),
          builder: (navigatorObserver) {
            // Reconstrói o app quando a aparência muda (tela Aparência).
            return Watch((context) {
              final theme = ThemeController.instance.settings.value;
              // Trocar o idioma remonta o app inteiro (os textos vêm de tr()).
              final language = AppLanguage.current.value;
              return MaterialApp(
                key: ValueKey(language),
                locale: Locale(language),
                debugShowCheckedModeBanner: false,
                routes: routes,
                title: title,
                navigatorObservers: [
                  navigatorObserver,
                  flutterGetItNavObserver,
                ],
                theme: buildAppTheme(theme, Brightness.light),
                darkTheme: buildAppTheme(theme, Brightness.dark),
                themeMode: theme.mode,
              );
            });
          },
        );
      },
    );
  }
}
