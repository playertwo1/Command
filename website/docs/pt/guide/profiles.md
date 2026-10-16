# Perfis

Um **perfil** é uma página de botões. No celular, arraste para os lados para trocar de perfil; o app
abre no último perfil que você usou. Um botão **Abrir perfil** mostra outro perfil como uma pasta
(veja [Botões e ações](actions.md#open-profile-and-back)), e o **Voltar** do Android fecha a pasta.

O botão **Perfil** (ícone de ajustes) na barra do deck abre o nome e a troca automática do perfil.
No configurador do PC, o mesmo diálogo abre pelo lápis no topo da grade.

## Trocar de perfil pelo app em foco { #auto-switch }

Em **Perfil → Abrir com o app em foco**, liste os programas que trazem este perfil para a frente.
Quando um deles ganha o foco no PC, o deck vai para o perfil sozinho; quando o foco vai para outro
programa, o deck volta para onde estava.

- Use o nome do processo, sem `.exe`: `obs64`, `Code`, `chrome`, `Photoshop`. O diálogo sugere os
  programas que estão abertos no PC agora.
- Se você trocar de página com o dedo enquanto um perfil automático está na tela, o deck não volta
  sozinho depois.
- Para desligar a troca automática num celular, use **Configuração → Aparência → Seguir o app em foco**.

## Backup { #backup }

O backup é um arquivo `.droiddeck` com todos os perfis, incluindo as imagens dos botões.

- **No configurador do PC**: **Exportar backup** e **Importar backup**, na barra lateral.
- **No celular**: **Configuração → Exportar backup do deck** abre o compartilhamento do Android
  (Drive, e-mail, "Salvar em arquivos"…). Para importar, use o configurador no PC.

Importar adiciona os perfis do arquivo. Um perfil que já existe (o mesmo perfil, de um backup
anterior) é substituído pela versão do arquivo; os outros ficam como estão. Os botões **Abrir perfil**
continuam apontando para as pastas certas.

!!! info "Backups com ações privilegiadas"
    Um backup com botões de atalho de teclado, abrir programa ou requisição HTTP só pode ser
    importado pelo configurador no PC, pela mesma regra de segurança dos botões.

## Sem conexão com o PC { #offline }

O celular guarda o último deck que recebeu. Se o PC estiver desligado ou fora da rede, o app abre
esse deck na hora, com o aviso **PC desconectado**, e os botões avisam que o PC não respondeu. Quando
a conexão volta, o deck é recarregado sozinho.

## Modo de edição

No celular, segurar um botão abre o editor. Num botão que tem uma ação de **toque longo**, segurar
executa a ação; para editá-lo, toque no **lápis** da barra do deck (modo de edição): enquanto ele
estiver ligado, um toque em qualquer botão abre o editor.
