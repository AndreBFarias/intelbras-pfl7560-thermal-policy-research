# Bloco 28 - S5 final: "Cast" verde, logo no firmware e o flash (2026-11-02)

Pedido do dono (2026-11-02): "Após as correções. E conclusões. Vamos flashar o novo"; "MeowCast a parte do cast
deixa verde tipo drácula theme". Decisões pelo AskUserQuestion na mesma hora:

| pergunta | decisão |
|---|---|
| quando gravar | **S5 com o bloco 27**: remontar a S5 com a home nova e o logo verde, um flash só |
| logo no firmware | **sim**: a arte reta vai na partição `logo` (record 6 do container, 106496 B) |
| onde o "Cast" fica verde | **logo de abertura, animação de boot e home** |
| backup antes | **sim**: o coordenador puxa para o PC o que o flash apaga |

Começa só depois que os blocos 26 (S2) e 27 forem integrados no `main` (o 28 mexe na home e no kit).

## O que já existe (medido)

- `artifacts/tema/gerar-marca.py`: `TEXTO = "MeowCast"` numa cor só (`NOME = #9D7AD0`) sobre `FUNDO = #120B1A`;
  gera `marca/logo.jpg` (arte que o logo automático grava), `logo-boot.jpg` e `bootanimation.zip`.
- Doc 47 §12 (bloco 26): partição `logo` = record 6 (106496 B); a arte reta (86135 B) cabe sem mudar o tamanho; o
  gate do `build_fix_bin.py`/`verificar_bin` hoje recusa mudança fora do record 14.
- S5 (bloco 26): md5 `81bb9885…`, com os APKs dos blocos 23 a 25.

## O que fazer

1. **Cast verde:** "Meow" continua `#9D7AD0`, "Cast" em verde Dracula `#50FA7B`, mesma fonte, mesma posição (o
   texto inteiro continua centrado). Vale para `logo.jpg`, `logo-boot.jpg`, `bootanimation.zip` e para todo lugar da
   home onde aparece "MeowCast" (se não aparece em lugar nenhum, relatar, não inventar). Os md5 do kit e do
   `suite-logo.sh` (`ARTE_MD5`) acompanham.
2. **Logo no firmware:** abrir o gate só para o record 6, com prova: a imagem nova da partição tem o mesmo formato
   do stock (cabeçalho, tamanho, como o bootloader lê), CRC do record recalculado, o `verificar_bin` confere
   records 6 e 14 e continua recusando qualquer outro. Se o formato da partição não puder ser provado no PC, **parar e
   relatar** (o logo fica pelo logo automático) em vez de arriscar.
3. **S5 final:** remontar com a home do bloco 27 (versionCode 8), a arte verde e o record 6;
   `firmware/PFL7560-S5-COMPLETO-NAO-GRADUADO.bin` + `.md5` atualizados; reprodutível (duas gerações, mesmo md5);
   `e2fsck -fn` limpo; semente/1º boot simulado verde.
4. **Pendrive do flash:** o roteiro do doc 47 §12 diz o que vai no pendrive (o `.bin` como `usb_update.bin` + o kit
   do bloco 26 em diante). O coordenador monta o pendrive, não o agente.

5. **Pré-voo do flash** (decisão do dono, 2026-11-02): script (ex.: `firmware/preflight-flash.sh <pendrive>`) que
   recusa se qualquer item falhar: `usb_update.bin` = S5 aprovada (md5 do `.md5`), `verificar_bin` aprovado, kit do
   pendrive compatível com o `.rc` da S5, backup presente no PC, stock de resgate (md5 `28a2f280…`) guardado fora do
   pendrive. Com teste, e um ensaio contra uma cópia do pendrive feita no PC.

## Depois do bloco 28 (decisão do dono)

- **Conferente final** (Opus, high), com tudo integrado no `main` (26, 27 e 28): regressão no todo, corrige os erros
  finais, um commit por correção.
- Depois dele, **o coordenador** monta a S5 final no PC (duas gerações, mesmo md5), roda o pré-voo, faz o backup e
  grava com o sim do dono.

## Fora

- Corrigir o `.md5` velho da S4b (anotado no ESTADO). Feito depois, na documentação final (`1716ef6`: `2b1836b8…`).
- Gravar no aparelho: só o coordenador, com o sim do dono, depois do backup.

## Como se prova (tudo no PC)

- Prévias PNG do logo e de quadros da animação para o dono aprovar antes do flash.
- `tests/test-*.sh`, `make check`, `shellcheck -s sh` sem falha nova.

## Antes do flash (coordenador, no aparelho, só leitura)

- Backup para `capturas/` (ou pasta ignorada) de `/data/vendor/pfl7560-*` (diário, logo, logs, escolhas) e do
  `/data/data/com.pfl7560.home/shared_prefs`.
- Conferir o `usb_update.bin` de resgate (stock V1.0.0.9 com USB-C, md5 `28a2f280…`) num lugar à mão.

## Agentes (2)

| agente | modelo | o quê |
|---|---|---|
| F1 | Opus, high | Cast verde, gate do record 6, S5 final |
| F2 | Opus, high | confere e corrige (formato da partição logo, CRC, reprodutibilidade, pré-voo, regressão) |
| final | Opus, high | depois da integração dos blocos 26, 27 e 28: regressão no todo e correções |

## Estado

- [x] blocos 26 e 27 integrados (`c8129b9`, `a73229d`)
- [x] F1 (Cast verde `69d9e4e`, record 6 `15f813d`, S5 `253b01c9` `07b96f6`, pré-voo `ebaa00c`)
- [x] F2; bloco integrado (`8ad5ce4`)
- [ ] prévias aprovadas: **a conferir** (não há registro da aprovação)
- [x] conferente final (`102a717` a `8c5afa5`: Cast verde no descanso, setas da Luz, "Desligar no descanso",
  `install.sh --com-firmware` com a S5, teste do kit, VLC fora do usuário 0) e documentação final
- [ ] S5 final montada pelo coordenador (duas gerações, `--verificar`, `test-semente-s5.sh` com `PFL_S5_BIN`, `.md5`)
  + pendrive pelo `install.sh --com-firmware` + pré-voo verde
- [ ] backup (o ensaio do pré-voo usou o `antes-s5-20261102-0201`; refazer perto do flash)
- [ ] flash (sim do dono na hora, depois do backup; S5 direto, sem a S4a e a S4b: decisão e risco no doc 47 §12)
