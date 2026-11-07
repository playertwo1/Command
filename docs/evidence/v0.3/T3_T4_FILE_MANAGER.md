# Evidência de Implementação — Fases T3 e T4: Navegação de Diretórios e Gerenciador Remoto

## 1. Escopo Entregue
- **T3 (Backend):**
  - Modelos `DirectoryItemDto` e `DirectoryBrowseResult` com propriedades tipadas (`name`, `path`, `sizeBytes`, `modifiedAtUtc`, `extension`, `isDirectory`).
  - Implementação de `BrowseDirectory` e enriquecimento de `GetFileForDownload` em `TransferService.cs` com suporte a subdiretórios hierárquicos.
  - Proteção estrita contra Path Traversal: bloqueio de caminhos absolutos, caracteres inválidos, sequências `..` e links simbólicos / pontos de junção (reparse points).
  - Endpoints autenticados `GET /api/transfers/{rootId}/browse` e `GET /api/transfers/{rootId}/download?path=...`.
  - Suíte de 12 testes de integração em `tests/Command.Tests/DirectoryBrowseTests.cs`.
- **T4 (Frontend Mobile):**
  - Modelos `DirectoryBrowseItem` e `DirectoryBrowseResult` em `transfer_models.dart`.
  - Métodos `browseDirectory` e `downloadNestedFile` em `DroidDeckClient`.
  - Tela `RemoteFileManagerPage` com navegação por breadcrumbs, ícones contextuais por extensão, barra de busca/filtro e download com cálculo de SHA-256 no cliente.
  - Botão de acesso ao gerenciador remoto no card de transferências da `StatusPage`.
  - Suíte de 3 testes de widget em `app/test/remote_file_manager_test.dart`.

## 2. Resultados dos Testes
- **Backend:** 12/12 testes passaram em `DirectoryBrowseTests.cs` (241/241 no total da suíte).
- **Mobile:** 3/3 testes passaram em `remote_file_manager_test.dart`.
