# Licenciamento por Componente e Obrigações de Distribuição — Command

Este documento detalha o modelo de licenciamento de software do ecossistema **Command**, em conformidade com o critério **I0.2** do Roadmap.

---

## 1. Matriz de Licenças por Componente

O repositório do Command é composto por múltiplos subsistemas que possuem licenças distintas herdadas ou adotadas:

| Componente | Diretório | Licença | Arquivo | Descrição / Restrições |
|---|---|---|---|---|
| **Windows Bridge & Servidor Web** | `DroidDeck/`, `tests/`, raiz | **Apache-2.0** | [`LICENSE`](file:///c:/Users/notefael/projetos/Command/LICENSE) | Código .NET 8 (C#) e Win32. Permissiva, com proteção de patente e exigência de preservação de avisos de copyright. |
| **Aplicativo Mobile & Web Configurator** | `app/` | **GPL-3.0** | [`app/LICENSE`](file:///c:/Users/notefael/projetos/Command/app/LICENSE) | Código Flutter / Dart. Copyleft forte: modificações distribuídas exigem disponibilização do código-fonte correspondente sob GPL-3.0. |
| **Ferramentas de Pesquisa e Upstream** | `research/` | Misto / Referência | [`research/UPSTREAM.md`](file:///c:/Users/notefael/projetos/Command/research/UPSTREAM.md) | Documentação de proveniência de commits, SHAs e licenças originais auditadas. |

---

## 2. Empacotamento e Distribuição de Binários

Ao distribuir artefatos compilados (como o instalador `Command-Setup.exe` ou o arquivo `.zip` portátil):

1. **Inclusão Obrigatória de Licenças:**
   - O instalador embute tanto a licença Apache-2.0 (`publish/LICENSE`) quanto a licença GPL-3.0 (`publish/LICENSE-APP-GPL-3.0`).
   - A interface web local servida pelo Bridge (`wwwroot/`) é compilada a partir de `app/` (GPL-3.0), logo a obrigação de disponibilização do código-fonte correspondente se aplica a este componente.

2. **Aplicativo Android (`Command.apk`):**
   - O APK distribuído é regido pela **GPL-3.0**.
   - Qualquer liberação pública do APK deve apontar diretamente para a release correspondente e o código-fonte exato do commit no GitHub.

3. **Isolamento de Segredos e Propriedade Intelectual:**
   - Nenhum token, credencial privada, assinatura comercial ou chave de API de terceiros deve ser embutida em binários ou no código versionado.

---

## 3. Preservação de Avisos e Atribuições

- O Command é um *in-tree fork* originado do projeto **DroidDeck** de autoria de `ggfto` (sob Apache-2.0).
- Os cabeçalhos de atribuição originais foram mantidos nos arquivos herdados, adicionando-se os metadados do Command nas modificações incrementais.
