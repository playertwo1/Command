# PROJECT — Command

Contrato de visão do Command. O manual do MVP ([transcrição](docs/MANUAL_MVP.md)) e o `ROADMAP.md` trazem os detalhes.

## Problema
Controlar o PC pessoal pelo celular hoje costuma exigir acesso remoto amplo ou alternar entre ferramentas. O Command deve oferecer operações comuns com estado real, limites claros e confirmação, sem expor um terminal remoto.

## Para quem
Uma pessoa com um celular Android e um PC Windows pessoal. Primeiro piloto: Galaxy S25 Ultra e um PC; notebooks poderão vir depois.

## MVP
1. Parear e revogar o celular com autorização explícita no Windows.
2. Consultar estado online/offline e métricas reais de CPU, RAM, disco e uptime.
3. Executar operações diretas autorizadas: abrir/encerrar apps permitidos, pedir uma screenshot e transferir arquivos em pastas de teste autorizadas, com resultado verificável.

Todas as operações diretas devem funcionar com Hermes desligado. O escopo completo e seus critérios estão no [ROADMAP.md](ROADMAP.md).

## Fora do MVP
- Shell remoto livre, administração arbitrária, acesso público ou bypass de sessão bloqueada/UAC.
- Streaming contínuo de tela, mouse/teclado, captura automática, múltiplos PCs e macros visuais.
- Voz e delegação com poder de execução, integrações avançadas ou dependência operacional do Hermes.

## Restrições
- Android nativo e Bridge Windows em sessão interativa; stack final condicionada à F0.
- Rede local ou transporte privado opcional; Tailscale não substitui autenticação da API.
- Permissões mínimas, allowlist local, pareamento revogável, audit trail sem dados pessoais.
- Licenças e APIs upstream precisam ser verificadas no commit escolhido antes de copiar código.

## Como saberemos que funcionou
Piloto pessoal de sete dias e pelo menos 30 ações diretas; meta recomendada de ≥95% de sucesso, sem execução não autorizada nem corrupção/perda de arquivos. Gate final e critérios de no-go estão no roadmap.

## Autoridade de produto
O proprietário do projeto aprova decisões de base e o gate final do MVP. Revisão técnica independente registra as evidências.

## Alternativas em avaliação
Hermes-Relay, Hy4ri/hermes-mobile, DroidDeck e LibreHardwareMonitor; outras referências e licenças constam do roadmap. Nenhum fork foi aprovado ainda.
