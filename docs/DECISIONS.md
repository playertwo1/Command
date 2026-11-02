# Decisões (ADR leve)

Registrar aqui escolhas caras de desfazer. ADRs completos ficam em `docs/adr/`.

| ID | Data | Assunto | Estado |
|---|---|---|---|
| D-001 | 2026-10-17 | Base Android | SUPERSEDED por D-007 (In-tree fork Flutter/Dart DroidDeck v1.9.1) |
| D-002 | 2026-10-17 | Bridge Windows | SUPERSEDED por D-007 (In-tree fork C# .NET 8 DroidDeck v1.9.1) |
| D-003 | 2026-10-12 | Tokens finais do tema Stitch | OPEN — Tema Amethyst Dark integrado como preset no Flutter |
| D-004 | 2026-10-17 | O que é o “Orbit” (FL-2): pasta/projeto e editor usados para abri-lo | RESOLVED — C:\Users\notefael\projetos\orbit-pj via VS Code / Explorer |
| D-005 | 2026-10-13 | Exigir desbloqueio biométrico/PIN do Android em ações destrutivas | OPEN — avaliar ativação opcional no app |
| D-006 | 2026-10-13 | Tailscale disponível e autorizado para o teste F8-04 | OPEN — se não, suporte declarado só à LAN |
| D-007 | 2026-10-17 | In-tree fork de DroidDeck v1.9.1 com restauração das integrações e pareamento nativo | APPROVED pelo proprietário em 2026-10-17. Stack consolidada: Flutter (Dart) + Bridge .NET 8 WinForms/ASP.NET Core/SignalR |
| D-008 | 2026-11-02 | Unificação do Controle Remoto (R3): correção DPI-aware no backend (.NET) para captura de tela completa e streaming ao vivo integrado na tela de Trackpad/Teclado (Flutter) | APPROVED pelo proprietário em 2026-11-02. Escopo formalizado na fase R3 de `ROADMAP_V1.5.md`. |
| D-009 | 2026-11-02 | Ambientes & Rotinas Customizáveis (R4): permitir exclusão/ocultação de qualquer rotina (incluindo presets padrão) e catálogo expandido de ações (apps do PC, mídia, volume, energia e atalhos) | APPROVED pelo proprietário em 2026-11-02. Escopo formalizado na fase R4 de `ROADMAP_V1.5.md`. |
| D-010 | 2026-11-02 | Controle de Energia Expandido (W2): adição de Desligar PC e Reiniciar PC ao PowerControlCard e ao PowerControlService com confirmação explícita | APPROVED pelo proprietário em 2026-11-02. Escopo formalizado na fase W2 de `ROADMAP_V1.5.md`. |
| D-011 | 2026-11-02 | Simplificação do Dashboard (C0): remoção do card "Ações Autorizadas" da StatusPage do app móvel para despoluir a visualização e eliminar redundância com o Deck | APPROVED pelo proprietário em 2026-11-02. Escopo formalizado na fase C0 de `ROADMAP_V1.5.md`. |
| D-012 | 2026-11-02 | Stream Deck Ultra-Customizável (K0): expansão visual (paleta livre HEX, biblioteca de ícones/GIFs, tipografia e bordas), grades flexíveis por perfil (2×2 a 8×6) e widgets vivos de telemetria/mídia | APPROVED pelo proprietário em 2026-11-02. Escopo formalizado na fase K0 de `ROADMAP_V1.5.md`. |
| D-013 | 2026-11-02 | Sensores de Temperatura Resilientes & Exibição Ampliada (T1): fallbacks WMI/NVAPI/ADL sem admin para evitar "N/D" no PC e visibilidade destacada no app e no Stream Deck | APPROVED pelo proprietário em 2026-11-02. Escopo formalizado na fase T1 de `ROADMAP_V1.5.md`. |

## Regras
- Decisão substituída permanece registrada como `SUPERSEDED` e aponta para a nova.
- Separar recomendações, evidência técnica e decisão do proprietário.
- Licenças devem referenciar o commit e os avisos exatos avaliados.
