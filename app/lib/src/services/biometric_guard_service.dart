import 'package:flutter/material.dart';

/// Serviço Guardião de PIN e Biometria para Ações Críticas (Onda P0).
class BiometricGuardService extends ChangeNotifier {
  static final BiometricGuardService instance = BiometricGuardService();

  bool _isGuardEnabled = false;
  String _pin = '1234';

  bool get isGuardEnabled => _isGuardEnabled;
  set isGuardEnabled(bool value) {
    if (_isGuardEnabled != value) {
      _isGuardEnabled = value;
      notifyListeners();
    }
  }

  String get pin => _pin;
  void setPin(String newPin) {
    _pin = newPin;
    notifyListeners();
  }

  /// Método estático de conveniência delegando para a instância compartilhada.
  static Future<bool> confirm(
    BuildContext context, {
    required String actionTitle,
  }) {
    return instance.confirmCriticalAction(context, actionTitle: actionTitle);
  }

  /// Solicita autorização via PIN para operações críticas se a proteção estiver ativada.
  Future<bool> confirmCriticalAction(
    BuildContext context, {
    required String actionTitle,
  }) async {
    if (!_isGuardEnabled) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final controller = TextEditingController();
        String? errorMessage;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161424),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF2E2A4A), width: 1.5),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA78BFA).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFFA78BFA),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Guardião de Segurança',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ação protegida: $actionTitle',
                      style: const TextStyle(
                        color: Color(0xFFA78BFA),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Digite seu PIN de 4 dígitos para autorizar a operação crítica:',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        letterSpacing: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1E1B2E),
                        counterText: '',
                        errorText: errorMessage,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2E2A4A)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFA78BFA),
                            width: 2,
                          ),
                        ),
                      ),
                      onSubmitted: (val) {
                        if (val == _pin) {
                          Navigator.of(dialogContext).pop(true);
                        } else {
                          setDialogState(() {
                            errorMessage = 'PIN incorreto. Tente novamente.';
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA78BFA),
                    foregroundColor: const Color(0xFF161424),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    if (controller.text == _pin) {
                      Navigator.of(dialogContext).pop(true);
                    } else {
                      setDialogState(() {
                        errorMessage = 'PIN incorreto. Tente novamente.';
                      });
                    }
                  },
                  child: const Text(
                    'Autorizar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? false;
  }
}
