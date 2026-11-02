# Command Android 1.1.2 — correção Multi-PC

Atualização do piloto M1: o segundo PC já pareado passa a conectar em paralelo ao abrir o app, quando existem exatamente dois perfis e não houve desconexão manual. Trocar pelo menu ou pelo cartão mantém alvo e telemetria no mesmo PC e reabre o PC anterior em paralelo. O painel acompanha a criação e remoção da segunda conexão.

## Instalar

1. Baixe `command-app-v1.1.2.apk` desta release e instale sobre a 1.1.1.
2. Abra novamente o app. Os dois perfis já pareados são preservados; não é necessário ler os QRs de novo.
3. Com as duas Bridges abertas e acessíveis na rede, confira os dois estados no painel **Meus 2 PCs** e alterne entre os cartões e o menu superior.

Se você havia escolhido **Desconectar paralelo**, o app respeita essa opção. Para reconectar, abra **Configurações → PCs pareados → Conectar em paralelo** no outro PC. Um PC desligado, sem Bridge ou inacessível na rede continua sem conexão; o app não força o estado Online.

Versão Android: `1.1.2` / versionCode `13`. Mesmo pacote e certificado das versões 1.1.0 e 1.1.1, para preservar os dados ao atualizar. Confira o arquivo `SHA256SUMS-v1.1.2.txt` anexado à release.

## Validação

Testes automatizados cobrem recuperação das duas conexões, desconexão explícita, limite de dois hubs, atualização do painel e seleção coerente entre menu, cartão e telemetria. A instalação e a troca individual em dois PCs na versão anterior foram confirmadas pelo proprietário. A verificação desta correção nas duas máquinas físicas e o aceite visual continuam pendentes; esta é uma prerelease privada.
