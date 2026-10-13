---
name: "Amethyst Command — design"
description: "Direção visual de referência baseada no projeto COMMAND Android Control Center do Stitch; ainda não aplicada nem aceita em implementação."
colors:
  canvas: "#050408"
  shell: "#13101B"
  surface: "#1E1829"
  elevated: "#271E35"
  border: "#352B45"
  foreground: "#F7F4FC"
  muted: "#A99FB8"
  primary: "#A78BFA"
  secondary: "#7C3AED"
  accent: "#C4B5FD"
  success: "#34D5A0"
  warning: "#F0B65F"
  danger: "#F87171"
typography:
  heading:
    fontFamily: "Roboto Flex"
    fontSize: "26px"
    fontWeight: 600
    lineHeight: "32px"
  body:
    fontFamily: "Roboto Flex"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: "20px"
  telemetry:
    fontFamily: "JetBrains Mono"
    fontSize: "11px"
    fontWeight: 500
    lineHeight: "16px"
rounded:
  control: "12px"
  card: "16px"
  pill: "9999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
---

# Amethyst Command — direção visual

## Overview
- **Personalidade:** técnica, precisa, discreta.
- **Para quem e onde:** operador usando o celular para verificar e controlar seu PC pessoal.
- **Modo:** operação. **Plataforma:** Android, primeiro alvo Galaxy S25 Ultra. **Tema:** escuro AMOLED.
- **Referência visual:** projeto [COMMAND Android Control Center no Stitch](https://stitch.withgoogle.com/projects/5594973370148065118), com capturas locais em `references/stitch/`.
- **Estado:** direção visual de referência fornecida pelo proprietário; não prova implementação nem aceite de cada fluxo.

## Colors
O design markdown do projeto Stitch descreve canvas preto `#050408`, shell `#13101B`, cartões `#1E1829`, elevação `#271E35` e contorno `#352B45`. Amethyst `#A78BFA`, roxo `#7C3AED` e lavanda `#C4B5FD` são acentos. Estado online usa verde `#34D5A0`, atenção âmbar `#F0B65F` e falha/offline vermelho `#F87171`; estado também deve ter texto ou ícone.

**Nota de alinhamento:** os tokens textuais do Stitch usam cores-base diferentes dos `namedColors` Material emitidos nos metadados do projeto (`#141218` e `#CEBDFF`). Verifique as telas de referência antes de fechar os tokens de produção; não trate a exportação automática do Stitch como uma decisão adicional.

## Typography
Roboto Flex para títulos e texto. JetBrains Mono para métricas, identificadores e rótulos operacionais, mantendo números tabulares. Material Symbols Rounded para ícones. Não reduza texto operacional abaixo de 12 px sem validação de legibilidade.

## Layout
Grade estrutural de 8 dp com passos de 4 dp; margem padrão de 16 dp, cartões separados por 16 dp e padding de 16–24 dp. Composição vertical para celular, priorizando conexão real do PC, métricas e ações comuns. Telas do MVP segundo o manual: Início, Computadores, Detalhe do PC, Ações, Atividade e Hermes (somente estado “Não configurado” no v0.1); navegação final definida em F3. Adaptar para larguras reais sem rolagem horizontal.

## Elevation & Depth
Separar níveis por tom, contorno fino e realce amethyst. Evitar sombras fortes em fundo AMOLED. Estado carregando, offline, erro, confirmação e sucesso confirmado precisam de apresentação distinta.

## Shapes
Cartões em torno de 16 dp; controles entre 12–16 dp; chips de estado em cápsula. Alvos de toque devem ser confortáveis e acessíveis.

## Components
- Botão primário violeta com rótulo que descreve o efeito real; ações destrutivas recebem confirmação explícita.
- Cartões de telemetria devem mostrar valor, unidade e momento/origem da coleta. Métrica antiga nunca aparece como atual.
- Estados do PC e de cada ação usam texto/ícone além da cor.
- Screenshots e arquivos só aparecem após ação explícita do usuário.

## Do's and Don'ts
- Preservar hierarquia e composição das telas Stitch ao implementar; justificar diferenças aqui.
- Não inferir da existência de uma tela no Stitch que a funcionalidade está no MVP.
- Não mostrar sucesso otimista; distinguir aceito, executando e concluído.
- Validar contraste, foco, escala de fonte e estados reais antes de pedir aceite visual.
