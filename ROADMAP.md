# ROADMAP — Command

**Visão e MVP:** [PROJECT.md](PROJECT.md) · **Ponto de Retomada:** [STATE.md](STATE.md) · **Detalhamento do Escopo Ativo:** [ROADMAP_V1.5.md](ROADMAP_V1.5.md)

---

## Marcos do Projeto

| Marco | Resultado Verificável | Estado | Gate de Fechamento |
|---|---|---|---|
| **v0.1 — MVP Inicial** | 5 fluxos essenciais (Obsidian, Orbit, Screenshot, Transferência, Encerrar app) | `DONE` | Homologado em `docs/MVP_APPROVAL.md` |
| **v0.2–v0.6 — Expansão** | Multi-PC, Automação/Rotinas, Wake-on-LAN, Energia e Modo Dock | `DONE` | Histórico arquivado em `docs/history/` |
| **v1.0 — Hardening & Segurança** | Permissões granulares, Backup AES-256-GCM, Velopack, Auto-diagnóstico | `DONE` | Release v1.0.0 e v1.1.0 no GitHub |
| **v1.5 — Mobilidade & Multi-PC** | 2 PCs simultâneos, Entrada remota, mDNS, Transferências retomáveis | `DONE` | Release v1.5.0 no GitHub (`c985086`) |
| **v1.6 — Desktop Remoto & Customização** | Live Screen Full-DPI no Trackpad, Rotinas Livres, Energia, Deck Customizável, Temperaturas | `IN_PROGRESS` | Código das fases fechado. Suítes .NET (405) e Flutter (259) PASS. Homologação física H0 pendente |

---

## Marco Ativo — Onda v1.6 (Desktop Remoto, Rotinas e Customização)

**Objetivo:** Permitir controle remoto total do PC pela tela do celular com transmissão Full-DPI, rotinas totalmente personalizáveis e painéis altamente customizáveis.  
**Quem valida:** Dono do projeto no aparelho Android e nas máquinas físicas.

| Fase | Entrega Técnica | Prioridade | Dependência | Estado | Evidência Exigida |
|---|---|:---:|:---:|:---:|---|
| **R3** | Desktop Remoto Integrado (Live Screen Full-DPI + Trackpad & Teclado Sobrepostos) | P0 | R1, R2 | `DONE` | `WindowsDesktopCaptureProvider.cs` com `GetDeviceCaps` + 12 testes no `trackpad_page_test.dart` PASS |
| **R4** | Ambientes & Rotinas Customizáveis (Exclusão de Presets + Expansão Massiva de Ações) | P0 | R3 | `DONE` | Exclusão de qualquer preset no backend + builder de rotinas com catálogo de apps, atalhos, volume e energia |
| **W2** | Controle de Energia Expandido (Desligar e Reiniciar no card da StatusPage) | P1 | R4 | `DONE` | Allowlist `shutdown`/`restart`, `ExitWindowsEx`, diálogo no card; 402 testes .NET e 253 Flutter PASS. PC real `NOT_RUN` |
| **C0** | Simplificação do Dashboard (Remoção do Card "Ações Autorizadas") | P2 | W2 | `DONE` | Card e `getApps()` saíram da StatusPage; catálogo segue no deck e nas rotinas |
| **K0** | Stream Deck Ultra-Customizável (Grades 2x2 a 8x6, Cores HEX Livres, GIFs, Tipografia) | P1 | C0 | `DONE` | HEX, SVG/GIF, tipografia, borda, grade, fundo, widgets e atalho allowlist no celular. 403 .NET e 258 Flutter PASS |
| **T1** | Sensores de Temperatura Resilientes (Fallback sem Admin WMI/NVAPI + Destaque no App e no Deck) | P1 | K0 | `DONE` | ACPI, NVAPI e ADL depois do LibreHardwareMonitor. Card "Meus 2 PCs" e banner acima de 85°C. 405 .NET e 259 Flutter PASS |

*Detalhamento de tarefas e critérios por fase: consulte [`ROADMAP_V1.5.md`](ROADMAP_V1.5.md).*

