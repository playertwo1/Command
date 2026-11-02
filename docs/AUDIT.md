# AUDIT — auditoria final independente

> Origem: [playertwo1/ideias_standard](https://github.com/playertwo1/ideias_standard) (`template/docs/AUDIT.md`) adaptado ao **Command**.
> Validação técnica e verificações apontam para `docs/RELEASE_CHECKLIST.md`.

Aplique antes de declarar `DONE` uma mudança relevante, e sempre na revisão independente de mudança média, grande ou arriscada (`AGENTS.md`, regra 4). Quem audita age como revisor cético: o objetivo não é confirmar que o agente acertou, é descobrir onde ele pode ter errado. Comece pelo pedido, pelos critérios de aceite, pelo `git diff` e pela saída real dos comandos de teste.

---

## 1. Escopo
- O pedido original do usuário foi atendido de fato?
- Há mudança fora do escopo, código desnecessário ou funcionalidade existente alterada/removida sem aviso?
- A solução seguiu o princípio da menor mudança correta?

## 2. Análise de Diff
Pergunta central: **cada linha adicionada ou alterada tem uma razão clara e justificável ligada à tarefa?**
- Há arquivos alterados acidentalmente?
- Código morto, comentários de debug ou logs residuais foram deixados?
- Há mocks ou dados estáticos mascarando comportamento real?

## 3. Prevenção de Regressão
- Impacto nos fluxos existentes:
  - Controle de energia (bloquear, suspender, wake-on-lan, desligar, reiniciar);
  - Conexão e sincronização paralela de dois PCs (Multi-PC);
  - Streaming da tela e captura Full-DPI;
  - Trackpad, clique direito, gestos e atalhos de teclado remoto;
  - Stream Deck (grades, cores, botões de ação e mídia);
  - Transferência de arquivos e integridade de hashes.

## 4. Qualidade e Robustez
- Tratamento de exceções e timeouts;
- Liberação limpa de recursos em `dispose()` (controllers, subscriptions, timers, handles de GDI/Windows);
- Ausência de leaks ou acúmulo de processos órfãos em background;
- Clareza e manutenibilidade sem overengineering.

## 5. Segurança e Privacidade
- Nenhum token, chave DPAPI, segredo ou endereço privado em código, logs ou evidências;
- Proteção contra comandos arbitrários (allowlist e IDs tipados);
- Nenhuma dependência externa de serviços de IA para operação do PC.

## 6. Validação por Comandos Reais
- **.NET 8:** `dotnet test tests/DroidDeck.Tests/DroidDeck.Tests.csproj` (sem falhas);
- **Flutter:** `flutter test` e `flutter analyze` (sem erros ou avisos);
- `NOT_RUN` nunca é aceito como `PASS`; afirmação em texto de agente não substitui saída do terminal.

## 7. Classificação de Achados
- 🔴 **CRITICAL:** Quebra grave de segurança, vazamento de credenciais, perda de dados ou comportamento destrutivo.
- 🟠 **HIGH:** Regressão de funcionalidade existente ou falha no fluxo principal da entrega.
- 🟡 **MEDIUM:** Código morto, débito técnico desnecessário ou documentação desatualizada.
- 🟢 **LOW:** Ajuste cosmético ou sugestão de melhoria futura.

## 8. Resultado da Auditoria
Registre o veredito final:
```text
AUDIT RESULT: PASS
```
ou `AUDIT RESULT: FAIL` (acompanhado da lista de achados por severidade e correção necessária).  
Qualquer achado CRITICAL ou HIGH aberto impede o fechamento do marco.

---
*Não pergunte "como provo que funciona?". Pergunte "como isso pode quebrar?" e tente falsificar a solução. Aprove só quando não encontrar problemas relevantes.*
