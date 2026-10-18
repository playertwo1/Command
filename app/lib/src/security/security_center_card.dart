import 'package:flutter/material.dart';
import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/security/encrypted_backup_sheet.dart';
import 'package:droiddeck/src/services/biometric_guard_service.dart';

/// Card Amethyst para o Centro de Segurança, RBAC, Backups e Integridade do Sistema (Ondas P0, P1 e P2).
class SecurityCenterCard extends StatefulWidget {
  final DroidDeckClient? client;
  final BiometricGuardService? guardService;

  const SecurityCenterCard({
    super.key,
    this.client,
    this.guardService,
  });

  @override
  State<SecurityCenterCard> createState() => _SecurityCenterCardState();
}

class _SecurityCenterCardState extends State<SecurityCenterCard> {
  static const Color amethystAccent = Color(0xFFA78BFA);
  static const Color cardBg = Color(0xFF161424);
  static const Color buttonBg = Color(0xFF1E1B2E);
  static const Color borderColor = Color(0xFF2E2A4A);

  BiometricGuardService get _guard => widget.guardService ?? BiometricGuardService.instance;

  bool _isCheckingSystem = false;
  UpdateStatusModel? _updateStatus;
  SystemStabilityModel? _stabilityStatus;
  String? _checkError;

  @override
  void initState() {
    super.initState();
    // NUNCA faça requisições de rede no initState de SecurityCenterCard!
  }

  Future<void> _handleCheckUpdatesAndStability() async {
    if (widget.client == null) {
      setState(() {
        _checkError = 'Bridge não conectada.';
      });
      return;
    }

    setState(() {
      _isCheckingSystem = true;
      _checkError = null;
    });

    try {
      final update = await widget.client!.getUpdateStatus();
      final stability = await widget.client!.getSystemStability();

      if (mounted) {
        setState(() {
          _updateStatus = update;
          _stabilityStatus = stability;
          _isCheckingSystem = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkError = 'Erro ao verificar sistema: $e';
          _isCheckingSystem = false;
        });
      }
    }
  }

  Future<void> _handleOpenBackup() async {
    if (widget.client == null) return;

    final authorized = await _guard.confirmCriticalAction(
      context,
      actionTitle: 'Acessar Backup Criptografado',
    );

    if (authorized && mounted) {
      await EncryptedBackupSheet.show(context, widget.client!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: amethystAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: amethystAccent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Centro de Segurança e Integridade',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Command v1.0.0 (Stable)',
                      style: TextStyle(
                        color: amethystAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Switch Guardião de PIN
          AnimatedBuilder(
            animation: _guard,
            builder: (context, _) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: buttonBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      color: amethystAccent,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Exigir PIN em Ações Críticas',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Protege comandos de sessão, backups e rotinas',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      key: const Key('switch_biometric_guard'),
                      value: _guard.isGuardEnabled,
                      activeColor: amethystAccent,
                      activeTrackColor: amethystAccent.withValues(alpha: 0.35),
                      onChanged: (val) {
                        setState(() {
                          _guard.isGuardEnabled = val;
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Botão Backup Criptografado
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('btn_open_encrypted_backup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonBg,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: borderColor),
                ),
              ),
              onPressed: _handleOpenBackup,
              icon: const Icon(Icons.security, color: amethystAccent, size: 20),
              label: const Text(
                'Backup Criptografado (AES-256)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Botão Verificar Atualizações e Estabilidade
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('btn_check_system_stability'),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonBg,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: borderColor),
                ),
              ),
              onPressed: _isCheckingSystem ? null : _handleCheckUpdatesAndStability,
              icon: _isCheckingSystem
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.system_update_alt,
                      color: amethystAccent,
                      size: 20,
                    ),
              label: Text(
                _isCheckingSystem
                    ? 'Consultando Bridge...'
                    : 'Verificar Atualizações e Estabilidade',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),

          if (_checkError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: Text(
                _checkError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ],

          if (_updateStatus != null || _stabilityStatus != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: buttonBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_updateStatus != null) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: amethystAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _updateStatus!.updateAvailable
                              ? 'Atualização disponível: ${_updateStatus!.latestVersion}'
                              : 'Bridge atualizada: ${_updateStatus!.currentVersion} (${_updateStatus!.channel})',
                          style: TextStyle(
                            color: _updateStatus!.updateAvailable
                                ? Colors.amberAccent
                                : Colors.greenAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (_stabilityStatus != null) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: amethystAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Status: ${_stabilityStatus!.healthStatus} | '
                            'Mem: ${_stabilityStatus!.workingSetMb.toStringAsFixed(1)} MB | '
                            'Threads: ${_stabilityStatus!.threadCount} | '
                            'Handles: ${_stabilityStatus!.handleCount}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
