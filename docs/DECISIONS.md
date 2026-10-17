# Decisões (ADR leve)

Registrar aqui escolhas caras de desfazer. ADRs completos ficam em `docs/adr/`.

| ID | Data | Assunto | Estado |
|---|---|---|---|
| D-001 | 2026-10-17 | Base Android | SUPERSEDED por D-007 (In-tree fork Flutter/Dart DroidDeck v1.9.1) |
| D-002 | 2026-10-17 | Bridge Windows | SUPERSEDED por D-007 (In-tree fork C# .NET 8 DroidDeck v1.9.1) |
| D-003 | 2026-10-12 | Tokens finais do tema Stitch | OPEN — Tema Amethyst Dark integrado como preset no Flutter |
| D-004 | 2026-10-13 | O que é o “Orbit” (FL-2): pasta/projeto e editor usados para abri-lo | OPEN — proprietário informa antes de F4 |
| D-005 | 2026-10-13 | Exigir desbloqueio biométrico/PIN do Android em ações destrutivas | OPEN — avaliar ativação opcional no app |
| D-006 | 2026-10-13 | Tailscale disponível e autorizado para o teste F8-04 | OPEN — se não, suporte declarado só à LAN |
| D-007 | 2026-10-17 | In-tree fork de DroidDeck v1.9.1 com restauração das integrações e pareamento nativo | APPROVED pelo proprietário em 2026-10-17. Stack consolidada: Flutter (Dart) + Bridge .NET 8 WinForms/ASP.NET Core/SignalR |

## Regras
- Decisão substituída permanece registrada como `SUPERSEDED` e aponta para a nova.
- Separar recomendações, evidência técnica e decisão do proprietário.
- Licenças devem referenciar o commit e os avisos exatos avaliados.
