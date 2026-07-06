# 19 - Sprint: aviso na tela quando a correção NÃO estiver ativa

Status: **PLANEJADA (não executada)**. Ordem: fazer **antes** da sprint do `.bin` (doc 18).

## Objetivo

Mostrar um aviso VISÍVEL na tela do projetor no boot quando a correção térmica **não** estiver ativa
(ex.: alguém reverteu ou reflashou o stock e o `/vendor` voltou ao de fábrica), para o usuário não rodar
o aparelho superaquecendo sem perceber. Com a correção aplicada, nenhum aviso.

## Contexto (o que já sabemos — não recomeçar do zero)

- **`cmd notification post` NÃO existe** neste Android 9 (testado: "Unknown command: post"). Um toast simples
  por shell não sai de graça.
- Existem: `cmd` e `am` (`/system/bin`), e o framebuffer de overlay **`/proc/msp/hifb0`** (o firmware usa
  `echo hide/show > /proc/msp/hifb0` no `init.bigfish.rc`). SELinux permissivo; adb root aberto.
- **Marcador da correção:** `/vendor/etc/ZYCustom.ini` com `HW_VIRTUAL_CHANNEL = 1` (md5 `1ad641ed`). É o mesmo
  gate que o autorun usa.
- O firmware roda scripts no boot: `nl_usb_update.sh` em `sys.boot_completed=1`; `update_after_boot.sh` em
  `/data/local/nlsu/`. Serviços podem ser declarados em `init.bigfish.rc` (no `/vendor`, persistente).
- A correção é permanente (`/vendor` sobrevive a reset de fábrica); só um **reflash total** a remove.

## PARADOXO DE ANCORAGEM (resolver logo na S1 — decide o resto)

Onde o "vigia" (o que detecta a ausência do fix + mostra o aviso) deve morar?
- Se morar no **`/vendor`** (junto do fix): um `revert` parcial do config → o vigia sobrevive e avisa. **MAS** um
  **reflash total do stock** apaga o `/vendor` inteiro → apaga o vigia junto → ele não consegue avisar da própria
  remoção. Cobre o cenário "revert", não o "reflash".
- Se morar no **`/system`**: sobrevive a um `revert` do config, mas um reflash total também o apaga.
- Conclusão provável: o vigia só cobre 100% se for **embutido no firmware distribuível** (a nossa build `.bin`
  já traria o vigia) — o que **acopla esta sprint à do `.bin`** (por isso talvez faça sentido fazê-la antes,
  para o `.bin` já sair com o vigia). Para o aparelho do dono (já corrigido via `/vendor`), o vigia em `/vendor`
  cobre o caso realista (revert acidental). **Decisão de escopo é a primeira task.**

## Sub-sprints

### WARN-S1 (pesquisa — o gate de viabilidade)
Descobrir COMO mostrar algo na tela sem app, e DECIDIR a ancoragem (paradoxo acima).
- Tasks: testar `cmd notification` (outras subcmds), `am start`/`am broadcast` para um toast/atividade,
  `service call SurfaceFlinger/…`, e escrever texto/imagem em `/proc/msp/hifb0` (overlay de hardware).
- **Proof-of-work (runtime-real):** um comando de shell único que faz aparecer QUALQUER coisa visível na tela
  do projetor (confirmado por foto/screenshot). Se nada funcionar por shell → o caminho é APK (WARN-S3).

### WARN-S2 (caminho shell — se a S1 achar um método por shell)
Script de boot que checa o marcador e mostra o aviso se ausente.
- Tasks: script que faz `grep -q "HW_VIRTUAL_CHANNEL = 1" /vendor/etc/ZYCustom.ini` e, se falhar, dispara o
  método visual da S1; ancorar num serviço no `init.bigfish.rc` (`/vendor`) ou no `update_after_boot.sh`.
- **Proof-of-work:** `pfl7560-fix.sh revert` + reboot → o aviso APARECE na tela; `apply` + reboot → o aviso SOME.

### WARN-S3 (caminho APK — se a S1 disser que shell não dá)
Especificar e construir um APK mínimo.
- Tasks: `BroadcastReceiver` de `BOOT_COMPLETED` que lê o marcador e mostra um `Toast`/overlay
  (`TYPE_APPLICATION_OVERLAY`) se ausente; assinar com dev-keys; instalar como app de sistema
  (`/system/app` ou `/vendor/app`) para persistir + autostart.
- **Proof-of-work:** mesmo teste da WARN-S2 (revert → aviso; apply → some), + o APK sobrevive a reboot.

### WARN-S4 (integração + decisão de ancoragem final)
Fechar o paradoxo: se o vigia for para o firmware distribuível, coordenar com a sprint do `.bin` (doc 18)
para o `.bin` já embarcar o vigia. Definir o texto do aviso (ex.: "ATENCAO: correcao termica INATIVA -
reaplique o pendrive") e o tempo/estilo (não atrapalhar a projeção normal).

## Critério de sucesso (mensurável)
Com o fix REMOVIDO (revert/reflash), o projetor mostra um aviso legível na tela no boot; com o fix aplicado,
nenhum aviso. O vigia não atrapalha o uso normal (projeção limpa quando tudo está ok).

## Riscos
- Overlay mal-feito pode cobrir/atrapalhar a projeção — usar timeout/transparência.
- O paradoxo de ancoragem (o vigia some junto com o fix num reflash total) — pode limitar o escopo ao caso
  "revert" ou empurrar o vigia para dentro do `.bin`.
- SELinux/permissões para escrever no framebuffer ou instalar app de sistema.

## Recuperação
Nada aqui toca no bootloader. Qualquer serviço/app problemático se remove por adb (`/vendor` rw) ou por
reflash. Ver [`16-recuperacao-brick.md`](16-recuperacao-brick.md).
