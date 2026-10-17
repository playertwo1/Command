# Monitores e informação

Um botão pode mostrar informação ao vivo. No editor, abra **Mostrar no botão** e escolha uma
**Informação**. O toque continua executando a ação do botão, se houver uma (um botão de CPU pode abrir
o Gerenciador de Tarefas, por exemplo).

## Monitores do PC

| Informação | Mostra |
|---|---|
| **Uso da CPU** | Uso total do processador, em um medidor. |
| **Uso da memória** | Uso de RAM, com "usado/total GB". |
| **Uso da GPU** | Uso do motor 3D da GPU, em um medidor. |
| **Rede** | Velocidade de download ↓ e upload ↑ somando todos os adaptadores de rede ativos (K = KB/s, M = MB/s). |

Os medidores mudam de cor conforme a carga: **verde** até 60 %, **laranja** acima de 60 %,
**vermelho** acima de 85 %.

- Os valores são atualizados **a cada segundo** enquanto houver um celular conectado. O PC para de
  coletá-los quando nenhum celular está conectado.
- O uso da GPU vem dos contadores de desempenho do Windows e exige um driver de vídeo razoavelmente
  recente. Quando não está disponível, aparece 0 %.

## Informação

| Informação | Mostra | Opções |
|---|---|---|
| **Relógio** | Hora e data do celular. | 24 horas, segundos, data. |
| **Clima** | Temperatura e ícone do tempo, pelo [Open-Meteo](https://open-meteo.com) (sem conta). Atualiza a cada 15 min. | Cidade; Fahrenheit. |
| **Tocando agora** | Capa, faixa e artista do que toca no Windows (Spotify, navegador, players). | — |
| **Saída de um comando (PC)** | O que um comando do `cmd` escreve. | Comando, modelo, intervalo. |
| **Valor de uma URL (PC)** | A resposta de um endereço, ou um campo do JSON dela. | URL, campo do JSON, modelo, intervalo. |

- **Modelo**: `{value}` é trocado pelo valor. Ex.: `Dia {value}`, `{value} ★`.
- **Intervalo**: de quantos em quantos segundos o PC busca de novo (mínimo 5, padrão 60).
- **Campo do JSON**: um caminho com pontos e índices, como `current.temp` ou `items[0].name`.
  Vazio = a resposta inteira.
- O comando tem até 10 segundos para terminar. Exemplos: `powershell -c "(Get-Date).DayOfYear"`,
  `echo %TIME:~0,5%`.
- Quando algo falha, o botão mostra um aviso amarelo com o motivo (cidade não encontrada, campo que não
  existe, HTTP 404...).

!!! info "Comando e URL são criados no PC"
    Como os atalhos de teclado, botões que rodam um comando ou leem uma URL no PC só podem ser criados
    ou alterados no [configurador](../getting-started/configurator.md).
