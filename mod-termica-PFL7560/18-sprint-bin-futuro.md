# 18 - Sprint: produzir um `PFL7560-FIX.bin` que BOOTA (e sai da quarentena)

Data: 2026-07-06. Plano de pesquisa/engenharia, em formato de sprint, para transformar o `.bin` em quarentena
num firmware distribuível. **Isto é um plano — nada aqui foi executado ainda.** O `.bin` só sai da quarentena
depois do gate **BIN-S4** (boot real confirmado em hardware).

## Objetivo

Um `.bin` de fábrica com a correção **embutida**, que **boota** e ativa os **3 fixes por default** (2º sensor +
fans/brilho 100% + shutdown 75 °C, wifi reconecta, xiri silenciado). Alvo: distribuir a quem **não** usa adb
nem pendrive-autorun — bastaria "Atualização local do sistema" com este `.bin`.

> **Dependência declarada — sprint [19](19-sprint-warning-tela.md) primeiro:** o `.bin` distribuível deve
> **embarcar o vigia de tela** da sprint 19 (o aviso que aparece no boot quando a correção não está ativa). Como
> este `.bin` vai justamente para quem **não** usa adb/pendrive, é o público que mais precisa do aviso embutido —
> e um reflash total do stock apagaria um vigia que morasse só no `/vendor`. Logo a sprint 19 é **pré-requisito**:
> fechá-la **antes** de graduar este `.bin`.

## Contexto (o que já sabemos — não recomeçar do zero)

- **Checksum do container DECIFRADO** (ver [`15-bin-definitivo.md`](15-bin-definitivo.md)): o `checksum1`
  (`@0x04`) é **CRC-32/MPEG-2 sobre `[0x00:0x2b4]`** com o próprio campo zerado — cobre **só o cabeçalho + a
  tabela de partições**, não os payloads. Os **rodapés** (`@0x2b8`/`@0x2bc`) **não são verificados** pelo
  loader. O **CRC por partição** também é CRC-32/MPEG-2.
- **A receita de build FUNCIONA e é byte-reproduzível** (`artefatos/bin-build/build_fix_bin.py`): edita **só a
  partição vendor** (record 14) mantendo o **tamanho** do payload — a tabela não muda, então o `checksum1`
  segue válido, e recalcula-se apenas o **CRC daquela partição**. Rodar 2× dá o mesmo md5 (timestamps de inode
  e superbloco são fixados no script).
- **O ÚNICO bloqueador conhecido:** os 3 arquivos reescritos via `debugfs write` ficam **sem rótulo SELinux**
  (`security.selinux` xattr) e **sem o modo/owner exato** do stock → o boot trava num estágio tardio do init
  (ver [`16-recuperacao-brick.md`](16-recuperacao-brick.md), seção 2). No método `/vendor` por adb isso nunca
  aconteceu porque o FS já carregava o contexto correto.
- **ATENÇÃO (achado M7, [doc 20](20-auditoria-integral-2026-07-06.md)):** essa causa é **provável, não isolada
  empiricamente**. O SELinux é **permissivo** nesta build (docs 11/13) — e em modo permissivo um rótulo ausente
  em geral **não** trava o boot por negação de política. Logo a BIN-S1/BIN-S5 devem **isolar a causa real**
  (comparar `ea_get security.selinux` + `stat` mode/uid/gid dos 3 arquivos no `/vendor` do método adb, que
  boota, vs no `.bin`, que trava) ANTES de declarar o `.bin` futuro "corrigido". Pode não ser só o rótulo.
- **A CONFIG está certa.** Prova: mesmo com o boot travado, o **brilho subiu ao máximo e os fans ao talo** — a
  HAL térmica leu e aplicou o nosso `ZYCustom.ini` antes do hang. O defeito é 100% de **metadado de arquivo**,
  não de conteúdo.
- Os 3 arquivos-alvo dentro da imagem vendor: **`/etc/ZYCustom.ini`**, **`/build.prop`**,
  **`/etc/init/hw/init.bigfish.rc`**.

## Sub-sprints

### BIN-S1 — Pesquisa: extrair os metadados STOCK dos 3 arquivos

Extrair, da **imagem vendor de fábrica** (stock, expandida para ext4 raw pela receita), o **contexto SELinux**
e o **mode/uid/gid** de cada um dos 3 arquivos. Esses são os valores-alvo que o `.bin` novo precisa reproduzir.

- Task: expandir o vendor stock para `orig.raw` (a receita já faz isso).
- Task: para cada arquivo, ler o xattr `security.selinux` e o `stat` (mode/uid/gid) do **stock**.

**Proof-of-work esperado (runtime-real):**
```
debugfs -R "ea_list /etc/ZYCustom.ini"            orig.raw   # lista os xattr; deve conter security.selinux
debugfs -R "ea_get /etc/ZYCustom.ini security.selinux"  orig.raw   # ex.: u:object_r:vendor_configs_file:s0
debugfs -R "stat /etc/ZYCustom.ini"               orig.raw   # Mode/User/Group do inode stock
# idem para /build.prop e /etc/init/hw/init.bigfish.rc
```
Saída registrada: para cada arquivo, `security.selinux = <ctx>` + `mode/uid/gid = <valores>`.

### BIN-S2 — Build: carimbar rótulo + modo/owner iguais ao stock

No `build_fix_bin.py`, **depois** de escrever cada arquivo no ext4, setar os metadados aos valores da BIN-S1.

- Task: para cada arquivo reescrito, `debugfs -R "ea_set <arq> security.selinux <ctx>"` com o contexto da S1.
- Task: `sif <arq> mode <m>` + `sif <arq> uid <u>` + `sif <arq> gid <g>` iguais ao stock.

**Proof-of-work esperado (runtime-real):** no arquivo **reescrito** (`edit.raw`), os metadados **batem com o
stock** da S1:
```
debugfs -R "ea_get /etc/ZYCustom.ini security.selinux"  edit.raw   # == valor stock (S1)
debugfs -R "stat /etc/ZYCustom.ini"               edit.raw         # Mode/User/Group == stock (S1)
# idem para os outros 2 arquivos
```

### BIN-S3 — Build: rebuild + verificar checksums e determinismo

Rodar a receita completa e confirmar que os invariantes do container continuam válidos após as escritas de
metadado da S2.

- Task: rebuild com `build_fix_bin.py`; confirmar `checksum1 @0x04` **inalterado** e válido, CRC da partição
  recalculado, e tamanho do `.bin` == stock.
- Task: rodar 2× e comparar md5 (determinismo).

**Proof-of-work esperado (runtime-real):** os checks internos do script imprimem `VALIDO`
(`checksum1 ... OK`, tamanho preservado), e:
```
md5sum PFL7560-FIX.bin   # roda 2× -> mesmo hash (determinismo)
```

### BIN-S4 — GATE (proof-of-work runtime-real — o que realmente importa)

Flashar o `.bin` novo num aparelho e confirmar **boot completo + os 3 fixes ativos**. **Ter o pendrive de
resgate (`usb_update.bin` de fábrica) pronto ANTES de flashar** (ver Riscos).

- Task: flashar por "Atualização local do sistema".
- Task: confirmar que o boot **chega ao launcher** (não trava na logo).
- Task: rodar o status e conferir os 3 fixes ativos.

**Critério de sucesso MENSURÁVEL:** boot chega ao launcher; `gtt1` lê temperatura real (~55–60 °C); fans
**1000/1000**; brilho **1000**; `wifi_disconnect_on_boot=0`; `xiriservice` **disabled**. Comando:
```
./pfl7560-fix.sh status
```
**NÃO considerar o `.bin` pronto até este gate passar.**

### BIN-S5 — Diagnóstico (só se a BIN-S4 falhar)

Se o boot ainda travar, descobrir o **estágio exato** do hang e comparar com o `/vendor` que o método adb
(que funciona) produz.

- Task: capturar a **última mensagem antes do hang** — logcat persistente ou **console serial UART 115200**
  (ver [`16-recuperacao-brick.md`](16-recuperacao-brick.md), seção 4).
- Task: comparar rótulo/modo/owner dos 3 arquivos no `/vendor` **do `.bin`** com os do `/vendor` produzido
  **pelo método adb** (que boota) — qualquer divergência é a próxima pista.
- Task: refinar a BIN-S2 com o achado e voltar à BIN-S3.

**Proof-of-work esperado (runtime-real):** um diff explícito de `ea_get security.selinux` + `stat` entre o
`/vendor` do `.bin` e o `/vendor` do método adb, apontando o campo que diverge.

## Riscos e recuperação

- **SEMPRE ter o resgate pronto ANTES de flashar:** pendrive **separado** com `usb_update.bin` = firmware **de
  fábrica** (nunca o `.bin` da correção) + **power-hold ao ligar** (ver [`16-recuperacao-brick.md`](16-recuperacao-brick.md),
  seção 3). Isso reflasha o stock e desbrica — ao custo de apagar o fix e formatar o `/data`.
- **O bootloader é intocável** (nem a build nem o flash o alteram) → o modo de upgrade USB está **sempre**
  disponível → o aparelho é **sempre recuperável**. Plano B: UART/console U-Boot 115200.

## Regra de ouro

> O `.bin` só sai da quarentena (`firmware/PFL7560-FIX.NAO-USAR-brica-SELinux.bin`) **depois** do gate
> **BIN-S4** — boot real confirmado em hardware, com os 3 fixes ativos e medidos. Até lá, o método `/vendor`
> (autorun/adb) é o caminho seguro e definitivo.
