# Estado do trabalho (atualizado em 2026-11-01)

Arquivo para abrir sessão nova sem depender da conversa.

## Em voo (2026-11-02)

**Próximo passo (atualizado):** workflow final `wyei23aii` em voo na árvore `integracao` (2e do painel Luz já feita,
`8851957`). Quando ele voltar: bloco 29 = `2026-11-02-tarefa-testes-cancelar-e-fundo.md` (T1 + T2, decidido entrar na
S5); depois o coordenador monta a S5 final, pendrive pelo `install.sh --com-firmware`, pré-voo e flash (sim dado).

Blocos 23, 24 e 25 integrados no `main` (`3399c4a`, via branch `integracao`): todos os `tests/test-*.sh` com
0 falha, `make check` ok, `shellcheck` limpo, versionCode 7 nos dois apps. Timer do diário ligado no PC
(`~/.config/pfl7560/diario.env` com `PFL_IP=192.168.1.5`).

Decisões da rodada final (2026-11-02): logo automático com a chave **ligada**; `higallery` fica fora do
`deb_hisi`; curva gravada na `[ThermalPolicy]` vira tarefa do próximo bloco; `DESLIGAR-CHAVES.txt` não desliga o
diário (ok assim).

Instalado no aparelho em 2026-11-02 (kit 53 arquivos, home e app versionCode 7, boot ok). Bloco 26 (S5, só PC)
em voo no workflow `watw88g3r`, branch `bloco-26`.

**Bloco 27 (próximo):** home limpa, rápida e com navegação previsível, mais "Lendo…" nas Ajustes e a chave do
pop-up do `nlprovision`. Tarefa e decisões do dono em `2026-11-02-bloco-27-home-limpa.md`. Ainda sem agente.
Conflito previsto com o bloco 26 só nas listas md5 do kit (resolver com `tests/atualizar-md5-kit.sh`).

**Bloco 28 (depois do 26 e do 27):** "Cast" verde Dracula no logo, na animação e na home; logo na partição do
firmware; S5 final com a home nova; backup; flash. Tarefa em `2026-11-02-bloco-28-s5-final-cast-verde.md`.
Pendente no aparelho quando ele voltar à rede: o dono pediu para desinstalar o VLC (`org.videolan.vlc`) se ainda
estiver lá; confirmar pelo AskUserQuestion antes.

**Prévias pré-aprovadas pelo dono (2026-11-02): "Nem preciso da prévia já pré aprovo agora".**

**Sim do dono (2026-11-02):** "Já tem o meu sim" — gravar a S5 final depois do conferente final e do pré-voo
verde, com backup feito; e desinstalar o VLC se ainda estiver no aparelho. Ordem de lançamento: bloco 28 assim que o
26 for integrado (o F1 precisa do builder do 26); depois de 27 e 28 integrados, um workflow final com 2 agentes
(conferente final que corrige + documentação atualizada e corrigida, incluindo os pendentes MAPA/pc.md e o `.md5`
da S4b).

**Pendrive em modo resgate (2026-11-02, ~02:40):** o projetor travou ("zumbi") depois de o dono desligar segurando
o POWER, com o pendrive no PC (nada foi gravado). Pendrive agora: `usb_update.bin` = stock (`28a2f280…`); a S4a foi
para `.fw-guardado/S4a-usb_update.bin` e o `newlink_update.sh` para `.kit-guardado/` (o kit não roda no boot). Para
voltar ao normal: devolver o `newlink_update.sh` à raiz e tirar o `usb_update.bin` (ou o pendrive da S5 final).

**Medido em 2026-11-02 ~03:00:** o VLC é de fábrica (`/vendor/app/VLC`), não do dono. Feito, com o sim dele:
`pm uninstall --user 0 org.videolan.vlc` (volta com `cmd package install-existing org.videolan.vlc`). O flash da S5
o traria de volta: o workflow final cuida disso. Prop `chaves` = `1111111111` (o dono ligou todas, inclusive
`wifi_pwr`, que pode derrubar o Wi-Fi; resgate `DESLIGAR-CHAVES.txt`). Bloco 26 integrado (`c8129b9`, branch
`integracao`), bloco 28 em voo (`whj87oqgu`).

**Backup feito (2026-11-02, antes da S5):** `backups-projetor/antes-s5-20261102-0201/` (ignorado pelo git):
`pfl-backup.tar` (86 MB, 76 entradas, md5 `6a6e6bbf…` igual no aparelho e no PC) com `/data/vendor/pfl7560-logo`,
`/data/vendor/pfl7560-suite`, prefs da home e dados do app; mais props, settings e lista de pacotes. Refazer só a
parte pequena (suite) logo antes do flash, se passar muito tempo.

## Próximos passos

1. Instalar: `./install.sh --pendrive <ponto>` (sem firmware), o dono pluga o pendrive no projetor.
2. Conferir no aparelho (adb, leitura): `/data/vendor/pfl7560-suite/` com os scripts novos, `vendor.pfl7560.chaves`,
   diário gravando, `/data/vendor/pfl7560-logo/logo.log` (backup, gravação, releitura), keystone reto, `gfs`
   (velocidade ou duty), `Dreaming` no descanso, chaves de risco (`newlink.service`, launcher).
3. O dono olha o logo no boot seguinte e testa a home (Curvas, Logo do boot, Ajustes, Diário).

## Pendentes antigos

- `firmware/PFL7560-S4b...md5` velho: com os APKs dos blocos 23 a 25 a S4b sai com md5 `b212798f` (+3432448 B), e o
  `check-bin` com o stock real falha só nesse caso (achado do S1 do bloco 26, 2026-11-02).

- `docs/MAPA.md` (`requirements.txt`) e `docs/codigo/pc.md` (`--dev`, git-lfs).
- Teams congelando com o projetor como monitor: sem causa.
- `escada=ausente` no relatório da suíte (`suite.sh:799`), anotado em `2026-11-01-tarefa-curas-do-doc-49.md`.
- Curva do dono gravada nas duas políticas da `[ThermalPolicy]` (doc 50 §proposta): o kit precisa aceitar a
  variante do `.ini`. Decidido para o próximo bloco.
- Pedido do dono (2026-11-02): chave na home para desligar o pop-up de "dispositivo conectado" que aparece ao
  plugar o pendrive. Achar qual app mostra (a suíte de 2026-11-02 viu um alerta de `com.newlink.nlprovision` que não fechou com 4 teclas OK) e fazer uma chave reversível.
- `le_temp` (`suite-curvas.sh`) não detecta `env_temp` congelado com anéis defasados (doc 37). Achado do R1 no
  bloco 25; vira tarefa do próximo bloco.
- Roteiro de medida do doc 49 (bloco 22): o dono decidiu pular; o uso do dia a dia confirma.

## Regras que não mudam

- Nunca `gtt`, nunca `stp`, nunca logcat contínuo pela rede. Nada gravado no aparelho sem o sim do dono.
- Commit sem `--no-verify`. Os arquivos `byte-exact` do `.gitattributes` passam intactos pelo pre-commit global
  (fonte em `~/.config/zsh/hooks/pre-commit`, instalado em `~/.config/git/hooks/pre-commit`).
- Worktrees novos com `GIT_LFS_SKIP_SMUDGE=1`.
