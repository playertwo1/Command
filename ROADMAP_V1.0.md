# ROADMAP v1.0 — Command: Robustez Operacional, Segurança Avançada, Backup Encriptado e Auto-Update

**Status:** CONCLUÍDO  
**Pré-requisito:** Onda v0.6 (`v0.6.0` — 413 testes PASS)  
**Meta Principal:** Consolidar o Command como produto final `v1.0.0` estável, seguro e auditável para operação diária, entregando **Permissões Granulares por Dispositivo e Biometria/PIN (D-005)**, **Backup e Restauração Criptografada (AES-256-GCM)**, **Verificação Segura de Atualizações (Velopack / SHA-256)** e **Autodiagnóstico de Estabilidade de Longa Duração**.

---

## 1. Regras Inegociáveis da Onda v1.0

1. **Zero Regressão de Segurança (Regras 2, 3, 4 e 5):** O controle do PC permanece 100% funcional sem IA; nenhum endpoint aceita comandos de shell arbitrário; backups nunca exportam chaves privadas/tokens em texto claro.
2. **Criptografia Autenticada Real:** O backup exportado deve usar **AES-256-GCM** com chave derivada via **PBKDF2-SHA256 (100.000 iterações)**, nonce de 12 bytes, tag de autenticação de 16 bytes e validação de integridade SHA-256.
3. **Proteção de Ações Críticas (D-005):** Ações destrutivas ou de bloqueio de sessão respeitam a role do dispositivo (`ViewerOnly` vs `FullControl`) no backend e o guardião de PIN/Biometria no app móvel.
4. **Compatibilidade Estrita com Suíte de Testes:** Novos cards na `StatusPage` não devem usar `Icons.bolt` (reservado para o indicador de bateria) nem disparar requisições `Dio` não-mockadas no `initState`.

---

## 2. Estrutura de Fases e Subfases (v1.0)

### 🛡️ Fase P0 — Permissões Granulares por Dispositivo, Auditoria e Guardião de PIN/Biometria (D-005)
**Objetivo:** Permitir restringir dispositivos pareados ao modo somente-leitura (`ViewerOnly`) ou controle total (`FullControl`), auditar decisões de acesso e exigir confirmação por PIN/Biometria no celular para ações críticas.

- [x] **P0.1:** Criar modelos e serviço de política de segurança no Backend (`DroidDeck/Models/SecurityPolicyModels.cs`, `DroidDeck/Services/ISecurityPolicyService.cs`, `DroidDeck/Services/SecurityPolicyService.cs`):
  - Enum/string de role: `"FullControl"` (padrão) e `"ViewerOnly"`.
  - Método `bool CanExecuteMutation(string? deviceId, string actionType, out string? denialReason)` que bloqueia mutações quando o dispositivo está em `"ViewerOnly"` e registra o evento no log de auditoria (`SecurityAuditEntryDto`).
- [x] **P0.2:** Expor `DroidDeck/Controllers/SecurityPolicyController.cs` (`/api/security` e `/api/v1/security`):
  - `GET /api/security/devices` — lista permissões por dispositivo.
  - `POST /api/security/devices/role` — define role (`FullControl` ou `ViewerOnly`) de um `DeviceId`.
  - `GET /api/security/audit` — retorna os últimos 100 registros de auditoria sanitizados.
- [x] **P0.3:** Criar `BiometricGuardService` (`app/lib/src/services/biometric_guard_service.dart`) e `SecurityCenterCard` (`app/lib/src/security/security_center_card.dart`):
  - Suporte a bloqueio por PIN/Biometria antes de ações críticas, exibição de role do aparelho, versão/estabilidade do Bridge e acesso ao modal de Backup Criptografado.
- [x] **P0.4:** Criar testes unitários e de widget em `tests/DroidDeck.Tests/SecurityPolicyTests.cs` e `app/test/security_center_test.dart`.

---

### 🔐 Fase P1 — Backup e Restauração Criptografada (AES-256-GCM + SHA-256)
**Objetivo:** Permitir exportar e restaurar todas as configurações do usuário (perfis, rotinas encadeadas e políticas) em um pacote `.cmdbak` criptografado com senha.

- [x] **P1.1:** Implementar `DroidDeck/Models/EncryptedBackupModels.cs`, `DroidDeck/Services/IEncryptedBackupService.cs` e `DroidDeck/Services/EncryptedBackupService.cs`:
  - `ExportEncryptedBackup(string passphrase)`: serializa rotinas (`IRoutineService`), políticas (`ISecurityPolicyService`) e metadados em JSON, deriva chave de 256 bits via `Rfc2898DeriveBytes` (PBKDF2-SHA256, 100.000 iterações) e criptografa com `AesGcm`.
  - `RestoreEncryptedBackup(EncryptedBackupEnvelopeDto envelope, string passphrase)`: valida hash SHA-256, descriptografa e autentica tag GCM (rejeitando senhas incorretas ou bytes adulterados com `CryptographicException`), restaurando as configurações.
- [x] **P1.2:** Expor endpoints em `DroidDeck/Controllers/EncryptedBackupController.cs` (`/api/backup/encrypted` e `/api/v1/backup/encrypted`):
  - `POST /api/backup/encrypted/export`
  - `POST /api/backup/encrypted/restore`
- [x] **P1.3:** Criar modal `EncryptedBackupSheet` (`app/lib/src/security/encrypted_backup_sheet.dart`) com campos de senha, exportação e restauração validada.
- [x] **P1.4:** Criar testes unitários e de widget em `tests/DroidDeck.Tests/EncryptedBackupTests.cs` e `app/test/encrypted_backup_test.dart`.

---

### 🔄 Fase P2 — Verificação Segura de Atualizações e Integridade de Pacotes (Auto-Update & Velopack)
**Objetivo:** Garantir que o usuário saiba a versão exata instalada (`1.0.0`), o estado do gerenciador Velopack e possa verificar a integridade criptográfica SHA-256 de atualizações.

- [x] **P2.1:** Implementar `DroidDeck/Models/UpdateModels.cs`, `DroidDeck/Services/IUpdateVerificationService.cs`, `DroidDeck/Services/UpdateVerificationService.cs` e `DroidDeck/Controllers/UpdateController.cs`:
  - `GET /api/system/update/status` (`/api/v1/system/update/status`) retornando `CurrentVersion` (`"1.0.0"`), `Channel` (`"stable"`), `UpdateAvailable`, `LatestVersion`, `IsVelopackReady` e `BinarySha256`.
  - `POST /api/system/update/verify` validando o hash SHA-256 de um manifesto/pacote contra o hash esperado.
- [x] **P2.2:** Integrar consulta de versão e botão **"Verificar Atualização"** no `DroidDeckClient` e no `SecurityCenterCard`.
- [x] **P2.3:** Criar testes unitários em `tests/DroidDeck.Tests/UpdateVerificationTests.cs`.

---

### 📊 Fase P3 — Autodiagnóstico de Estabilidade e Recursos da Bridge (Long-Run QA Monitor)
**Objetivo:** Monitorar continuamente o consumo de recursos do próprio processo Command Bridge (Memória Privada, Handles Win32, Threads e Uptime da Bridge) para garantir operação contínua sem vazamentos (memory/handle leaks).

- [x] **P3.1:** Implementar `DroidDeck/Services/ISystemStabilityMonitor.cs` e `DroidDeck/Services/SystemStabilityMonitor.cs`:
  - Coleta `WorkingSetMb`, `HandleCount`, `ThreadCount`, `BridgeUptimeSeconds` e `HealthStatus` (`"Healthy"` quando RAM < 350 MB e Handles < 2500, `"Warning"` caso contrário).
  - Expor em `GET /api/system/stability` (`/api/v1/system/stability`) no `UpdateController` ou `StabilityController`.
- [x] **P3.2:** Criar testes unitários em `tests/DroidDeck.Tests/SystemStabilityTests.cs`.

---

### 🏁 Fase P4 — Homologação Final `v1.0.0`, Pacotes de Produção, Maestro E2E e Sincronização
**Objetivo:** Fechar o ciclo `v1.0.0` com 100% dos testes passando, pacotes assinados com SHA-256, validação no emulador via Maestro e atualização completa da documentação e NexusVault.

- [x] **P4.1:** Integrar `SecurityCenterCard` na `StatusPage` (`app/lib/src/home/status_page.dart`) abaixo de `PowerControlCard` e executar suíte completa (`dotnet test` + `flutter test -j 1` + `flutter analyze --no-fatal-infos` exit 0).
- [x] **P4.2:** Atualizar versão para `1.0.0` em `DroidDeck/DroidDeck.csproj` e `1.0.0+10` em `app/pubspec.yaml`, gerar `dist/command-bridge-v1.0.0-win-x64.zip`, `dist/command-app-v1.0.0-debug.apk` e `dist/SHA256SUMS-v1.0.0.txt`.
- [x] **P4.3:** Executar fluxo E2E no Maestro (`e2e_maestro/flow_command_v10.yaml`) no emulador `Pixel_9` (`emulator-5554`) e salvar screenshot em `docs/assets/emulator_v10_status.png` e `docs/evidence/v1.0/`.
- [x] **P4.4:** Marcar `ROADMAP_V1.0.md` como `CONCLUÍDO`, atualizar `STATE.md`, `docs/RELEASE_CHECKLIST.md`, sincronizar `C:\Users\notefael\NexusVault\01_Projetos\Command.md` e executar `git commit` + `git push`.

---

## 3. Checklist Mestre de Progresso (v1.0)

- [x] **P0** — Fullstack: Permissões Granulares (`ViewerOnly`/`FullControl`), Auditoria e Guardião de PIN/Biometria
- [x] **P1** — Fullstack: Backup e Restauração Criptografada (AES-256-GCM + PBKDF2-SHA256)
- [x] **P2** — Fullstack: Verificador Seguro de Atualização e Integridade SHA-256 (Velopack Ready)
- [x] **P3** — Backend: Monitor de Estabilidade de Longa Duração (RAM, Handles Win32, Threads)
- [x] **P4** — QA/Release: Homologação E2E via Maestro no Pixel 9 e Release `v1.0.0`
