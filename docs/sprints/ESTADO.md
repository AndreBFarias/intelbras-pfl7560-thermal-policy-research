# Estado do trabalho (atualizado em 2026-11-02)

Arquivo para abrir sessão nova sem depender da conversa.

## Em voo (2026-11-02)

Blocos 26, 27 e 28 integrados na branch `integracao` (`c8129b9`, `a73229d`, `8ad5ce4`), mais o conferente final
(`102a717` a `8c5afa5`: "Cast" verde no descanso, app versionCode 8, home 9 com "Desligar no descanso", setas da
Luz, `install.sh --com-firmware` com a S5, VLC fora pelo `suite-boot.sh` com `pm uninstall --user 0`) e a
documentação final (MAPA, `docs/codigo/`, READMEs, doc 47 §12, LEIA-ME do kit, `.md5` da S4b). Ainda não está no
`main`. A S5 final **não foi montada**: o `firmware/PFL7560-S5-COMPLETO-NAO-GRADUADO.bin.md5` ainda traz a
`253b01c9` do bloco 28, superada pelo conferente final, e o `check-bin` com o stock real falha nela de propósito
até a montagem. Uma geração de teste com o kit de hoje deu `98998d92…`, CRC `0x29c2ba04`, record 14 com 85737620 B
(+5144576 B): só informativo, a conferir com as duas gerações da montagem.

**Decisão do dono (2026-11-02, AskUserQuestion):** "S5 com o bloco 27", em vez de "Provar a S4a antes": a S5 final
é gravada direto, sem a S4a nem a S4b antes. **Risco:** nenhuma build modificada foi gravada no aparelho até hoje;
se travar na logo, o resgate é o stock pelo POWER (doc 47 §8), com o pendrive de resgate ao lado.

**Sim do dono (2026-11-02):** "Já tem o meu sim" — gravar a S5 final depois do conferente final e do pré-voo verde,
com backup feito; e desinstalar o VLC se ainda estiver no aparelho (a S5 faz isso no 1º boot, uma vez).

**Pendrive em modo resgate (2026-11-02, ~02:40):** o projetor travou ("zumbi") depois de o dono desligar segurando
o POWER, com o pendrive no PC (nada foi gravado). Pendrive naquela hora: `usb_update.bin` = stock (`28a2f280…`); a
S4a em `.fw-guardado/S4a-usb_update.bin` e o `newlink_update.sh` em `.kit-guardado/`. Estado de agora: a conferir
antes do passo 2.

## Próximos passos (roteiro inteiro no doc 47 §12)

1. **Montagem final** (coordenador, no PC): gerar a S5 duas vezes em `build-s5/` (ignorada; `TMPDIR` lá dentro,
   porque o `/tmp` não comporta), mesmo md5; `--verificar` com o `conteudo-s5.txt` APROVADO;
   `PFL_S5_BIN=<.bin> bash tests/test-semente-s5.sh`; o `.md5` (dois espaços, só o nome), a linha da S5 no
   `firmware/README.md` e a tabela do doc 47 §12 no mesmo commit; depois
   `PFL_STOCK_ANTIGO=build-s5/PFL7560.bin python3 tests/test-builder-bin.py` verde.
2. **Backup** do aparelho no PC, perto do flash (`/data/vendor/pfl7560-*` e o `shared_prefs` da home; o ensaio do
   pré-voo usou o `antes-s5-20261102-0201`). Pendrive de resgate separado, com o stock (`28a2f280…`).
3. **Pré-voo:** `./install.sh --pendrive <ponto> --com-firmware` e
   `sh firmware/preflight-flash.sh <pendrive> --backup <pasta> --resgate <PFL7560.bin>`: só grava com
   `PRE-VOO APROVADO`.
4. **Flash** pela "Atualização local do sistema"; no 1º boot, esperar o launcher e reconfigurar o Wi-Fi; conferir
   por adb (leitura) a cópia da semente, o VLC fora e o logo.
5. Integrar a `integracao` no `main`.

## Pendentes antigos

- Teams congelando com o projetor como monitor: sem causa.
- `escada=ausente` no relatório da suíte (`suite.sh:799`), anotado em `2026-11-01-tarefa-curas-do-doc-49.md`.
- Curva do dono gravada nas duas políticas da `[ThermalPolicy]` (doc 50 §proposta): o kit precisa aceitar a
  variante do `.ini`. Decidido para o próximo bloco.
- `le_temp` (`suite-curvas.sh`) não detecta `env_temp` congelado com anéis defasados (doc 37). Achado do R1 no
  bloco 25; vira tarefa do próximo bloco.
- A conferir: prévias dos blocos 27 e 28 aprovadas pelo dono; relato do USB-C pedido no bloco 27 (nenhum doc nem
  commit desta árvore o traz); se a imagem stock traz o VLC (o log do `suite-boot.sh` fala em `/vendor/app/VLC`, o
  doc 44 diz que ele veio do `pfl7560-vlc.sh`); o logo JPEG 4:4:4 no aparelho (doc 47 §12).
- Roteiro de medida do doc 49 (bloco 22): o dono decidiu pular; o uso do dia a dia confirma.

Resolvidos na documentação final: o `.md5` da S4b (`2b1836b8…`, duas gerações iguais, `1716ef6`); MAPA e
`docs/codigo/pc.md` (`requirements.txt`, `--dev`, git-lfs); a chave do pop-up de dispositivo conectado (`pop_disp`,
bloco 27, `cd22852`).

## Regras que não mudam

- Nunca `gtt`, nunca `stp`, nunca logcat contínuo pela rede. Nada gravado no aparelho sem o sim do dono.
- Commit sem `--no-verify`. Os arquivos `byte-exact` do `.gitattributes` passam intactos pelo pre-commit global
  (fonte em `~/.config/zsh/hooks/pre-commit`, instalado em `~/.config/git/hooks/pre-commit`).
- Worktrees novos com `GIT_LFS_SKIP_SMUDGE=1`.
