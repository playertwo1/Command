# Profiles

A **profile** is a page of buttons. On the phone, swipe sideways to switch profiles; the app opens on
the last profile you used. An **Open profile** button shows another profile as a folder (see
[Buttons & actions](actions.md#open-profile-and-back)), and Android's **Back** closes the folder.

The **Perfil** (profile) button, the sliders icon in the deck's top bar, opens the profile's name and
automatic switching. In the PC configurator the same dialog opens from the pencil above the grid.

## Switch profile with the focused app { #auto-switch }

Under **Perfil → Abrir com o app em foco** (open with the focused app), list the programs that bring
this profile up. When one of them gets focus on the PC, the deck switches to the profile on its own;
when focus moves to another program, the deck goes back to where it was.

- Use the process name without `.exe`: `obs64`, `Code`, `chrome`, `Photoshop`. The dialog suggests
  the programs open on the PC right now.
- If you swipe to another page while an automatic profile is showing, the deck won't switch back
  on its own afterwards.
- To turn automatic switching off on a phone, use **Configuração → Aparência → Seguir o app em foco**.

## Backup { #backup }

A backup is a `.droiddeck` file with every profile, button images included.

- **In the PC configurator**: **Exportar backup** (export) and **Importar backup** (import), in the
  sidebar.
- **On the phone**: **Configuração → Exportar backup do deck** opens Android's share sheet (Drive,
  e-mail, "Save to files"…). To import, use the configurator on the PC.

Importing adds the file's profiles. A profile that already exists (the same profile, from an earlier
backup) is replaced by the file's version; the others stay as they are. **Open profile** buttons keep
pointing to the right folders.

!!! info "Backups with privileged actions"
    A backup with hotkey, launch-app or HTTP-request buttons can only be imported from the configurator
    on the PC, under the same security rule as the buttons themselves.

## Without a connection to the PC { #offline }

The phone keeps the last deck it received. If the PC is off or off the network, the app opens that
deck right away with a **PC desconectado** (PC disconnected) notice, and buttons tell you the PC didn't
answer. When the connection comes back the deck reloads on its own.

## Edit mode

On the phone, holding a button opens the editor. On a button that has a **long-press** action,
holding runs that action instead; to edit it, tap the **pencil** in the deck's top bar (edit mode):
while it is on, tapping any button opens the editor.
