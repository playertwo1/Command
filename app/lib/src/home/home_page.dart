import 'package:command/core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_controller.dart';
import 'audio_page.dart';
import 'status_page.dart';
import '../stream_deck/stream_deck_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final controller = HomeController();
  final PageController _pageController = PageController();
  int selectedIndex = 0;
  void Function()? _deckOnlyCleanup;

  @override
  void initState() {
    super.initState();
    // Modo só deck abre em tela cheia (e sai dela quando é desligado). Roda já na
    // primeira vez, com o valor carregado no startup.
    _deckOnlyCleanup = effect(() {
      final deckOnly = ThemeController.instance.deckOnly.value;
      untracked(() => controller.isFullscreen.value = deckOnly);
    });
    // No web o foco é configurar o deck; não precisa do polling de mixer.
    if (!kIsWeb) controller.startPolling();
  }

  @override
  void dispose() {
    _deckOnlyCleanup?.call();
    controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No navegador (configurador no PC), abre direto no editor de deck.
    if (kIsWeb) {
      return StreamDeckPage(
        onToggleFullscreen: () {},
        isFullscreen: false,
      );
    }
    final pageBody = Watch((context) {
        final deckOnly = ThemeController.instance.deckOnly.value;
        // O deck tem carregamento e modo offline próprios; a espera aqui é só do áudio.
        if (!deckOnly &&
            controller.isLoading.value &&
            controller.outputs.value.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final err = controller.error.value ?? '';
        // 401/403 = pareamento invalido: retry so falha de novo. Oferece voltar
        // ao pareamento pra nao prender o usuario nesta tela. Outros erros (PC
        // desligado) nao bloqueiam: o deck abre com o ultimo perfil salvo.
        final isAuthError = err.contains('401') || err.contains('403');
        if (isAuthError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isAuthError
                        ? tr('O PC não reconheceu este aparelho (a chave mudou ou é de outro PC).\nPareie de novo pelo QR.')
                        : tr('Erro: {error}', {'error': err}),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (!isAuthError)
                    ElevatedButton(
                        onPressed: controller.fetchOutputs,
                        child: Text(tr('Tentar novamente'))),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushReplacementNamed('/config'),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(tr('Refazer pareamento')),
                  ),
                ],
              ),
            ),
          );
        }

        // Toggle System UI based on fullscreen state
        if (controller.isFullscreen.value) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }

        if (deckOnly) {
          return StreamDeckPage(
            onToggleFullscreen: controller.toggleFullscreen,
            isFullscreen: controller.isFullscreen.value,
          );
        }

        return PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
          children: [
            StatusPage(
              isFullscreen: controller.isFullscreen.value,
              onToggleFullscreen: controller.toggleFullscreen,
            ),
            StreamDeckPage(
              onToggleFullscreen: controller.toggleFullscreen,
              isFullscreen: controller.isFullscreen.value,
            ),
            Column(
              children: [
                if (err.isNotEmpty)
                  MaterialBanner(
                    leading: const Icon(Icons.wifi_off),
                    content: Text(tr(
                        'O PC não respondeu. Confira se o Command está aberto nele.')),
                    actions: [
                      TextButton(
                        onPressed: controller.fetchOutputs,
                        child: Text(tr('Tentar novamente')),
                      ),
                    ],
                  ),
                Expanded(
                  child: AudioPage(
                    controller: controller,
                    isFullscreen: controller.isFullscreen.value,
                    onToggleFullscreen: controller.toggleFullscreen,
                  ),
                ),
              ],
            ),
          ],
        );
      });
    final bottomNavigation = Watch((context) {
        if (controller.isFullscreen.value ||
            ThemeController.instance.deckOnly.value) {
          return const SizedBox.shrink();
        }
        return BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: const Icon(Icons.monitor_heart_outlined),
              activeIcon: const Icon(Icons.monitor_heart),
              label: tr('Status'),
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.grid_view),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Deck',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.tune),
              activeIcon: const Icon(Icons.tune),
              label: tr('Áudio'),
            ),
          ],
          currentIndex: selectedIndex,
          onTap: (val) {
            _pageController.animateToPage(
              val,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            setState(() {
              selectedIndex = val;
            });
          },
        );
      });
    final size = MediaQuery.sizeOf(context);
    final compactLandscape = size.width > size.height && size.height < 600;
    return Scaffold(
      body: compactLandscape
          ? Row(
              children: [
                Watch((context) {
                  if (controller.isFullscreen.value ||
                      ThemeController.instance.deckOnly.value) {
                    return const SizedBox.shrink();
                  }
                  return SafeArea(
                    right: false,
                    child: NavigationRail(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: _goToTab,
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        NavigationRailDestination(
                          icon: const Icon(Icons.monitor_heart_outlined),
                          selectedIcon: const Icon(Icons.monitor_heart),
                          label: Text(tr('Status')),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.grid_view),
                          selectedIcon: const Icon(Icons.grid_view_rounded),
                          label: const Text('Deck'),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.tune),
                          label: Text(tr('Áudio')),
                        ),
                      ],
                    ),
                  );
                }),
                Expanded(child: pageBody),
              ],
            )
          : pageBody,
      bottomNavigationBar: compactLandscape ? null : bottomNavigation,
    );
  }

  void _goToTab(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => selectedIndex = index);
  }
}
