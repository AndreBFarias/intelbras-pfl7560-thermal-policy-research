# 18 - Sprint: produzir um `PFL7560-FIX.bin` que BOOTA (e sai da quarentena)

Plano de engenharia para transformar o `.bin` em quarentena num firmware distribuível que **boota** e
já traz os fixes por padrão. **Nada aqui foi flashado em hardware ainda.** O `.bin` só sai da quarentena
depois do gate **BIN-S4a** (boot real confirmado no aparelho).

---

## STATUS (revisado 2026-07-12)

O trabalho de software desta sprint **já está feito e vive no código**; o que falta é **hardware**.
Antes de executar qualquer sub-sprint, leia este bloco — não refaça o que já existe.

| Sub-sprint | Estado | Evidência |
|---|---|---|
| **BIN-S1** (extrair metadados stock dos 3 arquivos) | **FEITO em código** | `artifacts/bin-build/build_fix_bin.py`: `read_meta()` L135-158, capturado no build (`[2b] metadados stock`) L219-225; fallback medido `META_FALLBACK` L30-43 |
| **BIN-S2** (carimbar rótulo SELinux + mode/uid/gid) | **FEITO em código** | `meta_cmds()` L161-171 (`sif mode` com S_IFREG, `ea_set security.selinux ...\000`); gate fatal `verify_meta()` L174-199 aborta se `.rc` ficar group/world-writable |
| **BIN-S3** (checksum1 + tamanho) | **FEITO em código** | `checksum1 @0x04` conferido L320-330; tamanho `== stock` garantido (assert L297, `ok` L326); CRC vendor recalculado L308/318 |
| **BIN-S3b** (build reprodutível + log versionado) | **FEITO em 2026-07-29** | 2 builds do mesmo stock (`28a2f280…`) + mesma config (`252ab7a7…`) → md5 **idêntico** `eae3a83d…`; log em `firmware/README.md`; verificação independente das invariantes 6 e 10 aprovada |
| **BIN-S4a** (boot real do `.bin` de delta mínimo) | **PENDENTE — REQUER APARELHO + PENDRIVES SEPARADOS** | gate nunca rodou; `.bin` segue em quarentena. **Bloqueado hoje** pelo pré-requisito de mídia (ver abaixo) |
| **BIN-S4b** (respin com o vigia da sprint 19, para distribuição) | **PENDENTE — REQUER APARELHO + sprint 19 fechada** | — |
| **BIN-S5** (diagnóstico, só se S4a falhar) | contingência | — |

**Artefato atual:** `firmware/PFL7560-FIX-escada-NAO-GRADUADO.bin`
(md5 `eae3a83db44f790b64b9a5838a27a977`, local-only por `*.bin` no `.gitignore`; o `.md5` companheiro está
versionado). Embute a **escada de brilho** (`[BacklightPolicy]` `66000..73000` → `1000,950,900,850,850,850`).
CRC da vendor `0x832a0731`; `checksum1` `0x738ebd09` preservado.

Builds superadas — **nenhuma deve ser flashada, ambas reproduzíveis pelo builder:**
`16a4b42a…` (pré-escada, limiares `27000..36000`, removida do disco em 2026-07-29) e o protótipo
`f5ff89c9…` (sem metadados SELinux, **que bricou**, apagado e não recriar).

### BLOQUEIO ATUAL DO BIN-S4a: separação de mídia

O pendrive do dono tem **autorun e resgate na mesma mídia** (`newlink_update.sh` + `ZYCustom.ini` +
`usb_update.bin` + uma cópia `PFL7560.bin` idêntica ao resgate). Isso viola as invariantes 2 e 3, e para o
S4a é pior: no meio de um brick você estaria manipulando justamente o pendrive que contém os dois papéis,
e o loader poderia pegar o `.bin` errado. **O S4a não deve ser tentado antes de existirem 3 papéis em
mídias distintas** (ou no mínimo 2, com o autorun fora do caminho):

| Papel | Conteúdo | Estado hoje |
|---|---|---|
| **flash** | só `PFL7560-FIX-escada-NAO-GRADUADO.bin` | não existe |
| **resgate** | só `usb_update.bin` (fábrica) | existe, mas na mídia compartilhada |
| **autorun** | `newlink_update.sh` + `ZYCustom.ini` + `LEIA-ME.txt` | atualizado em 2026-07-29, na mídia compartilhada |

**Resgate verificado (2026-07-29):** o `usb_update.bin` do dono é fábrica genuíno — md5
`28a2f280eee313a4b115567926b2ba4f`, **byte-idêntico** ao `.bin` extraído do zip oficial (cujo sha256 bate
com o BRIEF). Confirmado por conteúdo: contém `HW_VIRTUAL_CHANNEL = 0`, `43000` e
`wifi_disconnect_on_boot=1`, e **zero** ocorrências de `HW_VIRTUAL_CHANNEL = 1` ou `=  70000`. Confira esse
md5 antes de começar o S4a — é a sua rede de segurança.

**O que mudou nesta revisão da spec (2026-07-29):**
1. **BIN-S3b FECHADO** — a build é reprodutível e passou verificação independente.
2. Artefato trocado: o `.bin` agora embute a escada de brilho. O anterior era pré-escada.
3. **Novo bloqueio explícito do S4a:** separação de mídia (tabela acima).
4. Critérios de aceite do S4a **revisados** — o `status` **agora imprime brilho** (o `gbri 0` foi
   adicionado ao `cmd_status` em 2026-07-29), e há dois critérios novos: a **escada** e a **ausência de
   `LSADC Error`**.
5. Adicionado critério de **preservação da correção de cor LCD** (JEIDA) — o dono tem painel `-0600`.

**O que mudou na revisão de 2026-07-12 (histórico):**
1. As BIN-S1/S2/S3 deixaram de ser "pesquisa a fazer" — são "código a validar". Sub-sprints reescritas.
2. O gate único foi **dividido**: `BIN-S4a` (testar a hipótese de metadados, delta mínimo) roda **antes**
   da sprint 19; `BIN-S4b` (build de distribuição com o vigia embarcado) roda depois. A sprint 19 é
   pré-requisito **da distribuição**, não do teste de boot — ver "Ordem e dependências".
3. Critério "brilho 1000" da BIN-S4 corrigido — **superado pelo item 4 de 2026-07-29.**
4. Adicionado o passo manual obrigatório de reconfigurar o Wi-Fi após o flash (o flash formata `/data`).

---

## Objetivo

Um `.bin` de fábrica com a correção **embutida**, que **boota** e ativa os fixes por padrão (2º sensor
destravado + fans/brilho no máximo + shutdown a 75 °C, Wi-Fi reconecta, `xiriservice` silenciado). Alvo:
distribuir a quem **não** usa adb nem pendrive-autorun — bastaria "Atualização local do sistema".

> **Fora de escopo desta sprint (decisão registrada):** a correção de cor LVDS (byte `0x5c` do
> `panelparam`, JEIDA) **NÃO entra neste `.bin`**. Motivo: o `.bin` térmico é universal (serve todo
> PFL7560), mas o byte `0x5c=JEIDA` só vale para quem **trocou** o painel para um `-0600`; embuti-lo
> quebraria a cor de todo aparelho com painel de fábrica (`-4300`, que espera VESA). Além disso a
> partição `panelparam` provavelmente **nem está** no container `.bin` (ver sprint LCD-S4 no doc 29).
> A correção de cor continua sendo pós-boot, por `pfl7560-lcd-color.sh`.

---

## Contexto técnico (o que já sabemos — não recomeçar do zero)

- **Checksum do container DECIFRADO** (ver [`15-bin-definitivo.md`](../research/15-bin-definitivo.md)):
  o `checksum1` (`@0x04`, big-endian) é **CRC-32/MPEG-2 sobre `[0x00:0x2b4]`** com o próprio campo
  zerado — cobre **só o cabeçalho + a tabela de partições**, não os payloads. Os **rodapés**
  (`@0x2b8`/`@0x2bc`) **não são verificados** pelo loader. O **CRC por partição** também é CRC-32/MPEG-2.
- **A receita de build FUNCIONA e é byte-reproduzível** (`artifacts/bin-build/build_fix_bin.py`): edita
  **só a partição vendor** (record 14, prefixo `0x4b0b1d54`) mantendo o **tamanho** do payload — a tabela
  não muda, o `checksum1` segue válido, recalcula-se só o **CRC daquela partição**. Timestamps de inode e
  superbloco são fixados no script para dar o mesmo md5 a cada build.
- **A hipótese do brick (achado M7):** os 3 arquivos reescritos pelo protótipo antigo ficaram
  `0664` (group-writable) e **sem** o rótulo SELinux/owner do stock. A tese mais forte
  ([`16-recuperacao-brick.md`](../guide/16-recuperacao-brick.md), seção "Causa mais provável") é que
  **o init do Android recusa parsear um `.rc` group/world-writable** — causa suficiente, sozinha, do hang
  na logo. **PORÉM essa causa é analítica, não isolada empiricamente** (o SELinux é permissivo nesta
  build, então "rótulo ausente" por si só provavelmente não trava). **O gate BIN-S4a é justamente o
  experimento que fecha o M7:** se o `.bin` novo (agora com `0644` + rótulo + owner corretos) **bootar**,
  a hipótese está confirmada na prática; se **travar**, a BIN-S5 isola o que resta.
- **A CONFIG está certa.** Mesmo com o boot travado no protótipo antigo, o brilho subiu ao máximo e os
  fans foram ao talo — a HAL térmica leu e aplicou o `ZYCustom.ini` antes do hang. O defeito era 100%
  **metadado de arquivo**, não conteúdo.
- Os 3 arquivos-alvo dentro da imagem vendor: **`/etc/ZYCustom.ini`**, **`/build.prop`**,
  **`/etc/init/hw/init.bigfish.rc`**. Metadados stock que o builder reproduz:

  | Arquivo | mode | uid/gid | security.selinux |
  |---|---|---|---|
  | `/etc/ZYCustom.ini` | `0644` | 0/0 | `u:object_r:vendor_configs_file:s0` |
  | `/build.prop` | `0600` | 0/0 | `u:object_r:vendor_file:s0` |
  | `/etc/init/hw/init.bigfish.rc` | `0644` | 0/0 | `u:object_r:vendor_configs_file:s0` |

---

## PRÉ-REQUISITO ABSOLUTO — kit de resgate antes de qualquer flash

Qualquer sub-sprint marcada **[REQUER APARELHO]** só começa depois deste checklist. **Não flashe sem
isto pronto e à mão.** O resgate é o que garante que o aparelho é sempre recuperável.

1. **Pendrive de RESGATE** — FAT32/MBR, com o firmware **DE FÁBRICA** renomeado para `usb_update.bin`
   na raiz. Extraia o `.bin` de fábrica do zip oficial:
   ```bash
   unzip -j "firmware/Software PFL7560.zip" "*.bin" -d /tmp/resgate/
   # copie /tmp/resgate/<arquivo>.bin para o pendrive como  usb_update.bin
   ```
   **NUNCA** renomeie o `.bin` de correção para `usb_update.bin` — isso bricaria em vez de resgatar.
2. **Pendrive de resgate FISICAMENTE SEPARADO** do pendrive de autorun (`newlink_update.sh` +
   `ZYCustom.ini`). Nunca junte os dois arquivos no mesmo pendrive.
3. **O procedimento de resgate decorado** (ver [`16-recuperacao-brick.md`](../guide/16-recuperacao-brick.md),
   seção 3): tirar a energia → plugar o pendrive de resgate → segurar o botão de power → religar a
   energia mantendo o botão ~10-15 s → o loader entra em modo upgrade e regrava o stock.
   **O resgate formata o `/data`** (perde apps/config e as credenciais de Wi-Fi).
4. **PC com adb por Wi-Fi** pronto (o USB-C deste aparelho **não** expõe adb; adb só via Wi-Fi
   configurada no launcher — ver memória `pfl7560-conexao-adb`).
5. **(Contingência)** kit UART USB-TTL (CH340/CP2102, 115200 8N1) disponível para a BIN-S5, caso o boot
   trave cedo demais para o logcat.

---

## Sub-sprints

### BIN-S3b — Gerar a build oficial e provar reprodutibilidade (offline, SEM aparelho)

**Objetivo:** produzir a build atual **a partir do stock oficial** com este builder, capturar a saída de
prova e confirmar que 2 builds dão o mesmo md5. Isso fecha a lacuna "o `.bin` existe mas ninguém tem o
log de que ele foi gerado corretamente e de forma determinística".

**Pré-condições (verifique antes):**
```bash
python3 --version                 # qualquer 3.x
which debugfs e2fsck              # e2fsprogs instalado (sudo apt install e2fsprogs)
ls artifacts/bin-build/sparse.py  # deve existir ao lado do builder
```
Se `debugfs`/`e2fsck` faltarem: `sudo apt install e2fsprogs` (Debian/Ubuntu/Pop). **Anote a versão**
(`debugfs -V`) no log — `sif`/`ea_set` são sensíveis à versão do e2fsprogs.

**Passos (comando literal):**
```bash
# 1) extrair o stock de fábrica do zip oficial (se ainda nao tiver o .bin solto)
unzip -j "firmware/Software PFL7560.zip" "*.bin" -d /tmp/stock/
STOCK=$(ls /tmp/stock/*.bin | head -1)

# 2) primeira build, capturando TODA a saida
python3 artifacts/bin-build/build_fix_bin.py \
    "$STOCK" artifacts/ZYCustom_390.ini /tmp/build1.bin 2>&1 | tee /tmp/build1.log

# 3) segunda build (determinismo)
python3 artifacts/bin-build/build_fix_bin.py \
    "$STOCK" artifacts/ZYCustom_390.ini /tmp/build2.bin 2>&1 | tee /tmp/build2.log

# 4) md5 das duas builds
md5sum /tmp/build1.bin /tmp/build2.bin
```

**Proof-of-work esperado (saída literal a conferir):**
- Em `/tmp/build1.log`, as linhas devem incluir, para os 3 arquivos:
  ```
  [4b] verificando metadados pos-edit:
       OK /etc/ZYCustom.ini: mode=0644 selinux=u:object_r:vendor_configs_file:s0
       OK /build.prop: mode=0600 selinux=u:object_r:vendor_file:s0
       OK /etc/init/hw/init.bigfish.rc: mode=0644 selinux=u:object_r:vendor_configs_file:s0
  [5b] revalidacao pos-pack:  (mesmos 3 OK, type=regular)
  [8] checksum1 @0x04 = 0x738ebd09 (armazenado 0x738ebd09) -> OK
  [done] /tmp/build1.bin  VALIDO (conteudo + metadados stock nos 3 arquivos)
  ```
- `md5sum` das duas builds: **os dois hashes IGUAIS entre si** (determinismo). O valor deve bater com
  `firmware/PFL7560-FIX-com-metadados.bin.md5` (`16a4b42a65f57cccd7bc458d6a3e2dde`) **se** o stock e o
  `ZYCustom_390.ini` forem os mesmos que geraram o artefato atual.

**Se falhar:**
- Se `[8] ... -> ERRO`: a tabela do container mudou — **NÃO** use a build; investigue (não deveria
  acontecer editando só o payload vendor).
- Se um `[4b]`/`[5b]` abortar com "group/world-writable" ou "Type ... esperado regular": problema de
  versão do `debugfs`/`sif`; registre a versão e reporte.
- Se os dois md5 **diferirem** entre si: o determinismo quebrou — algum timestamp não foi fixado;
  reporte a divergência (não flashe uma build não-reprodutível).

**Entrega:** versionar `/tmp/build1.log` como `artifacts/bin-build/build-proof.log` (é texto, sem dado
pessoal) e anotar aqui a versão do e2fsprogs usada. **Não versione o `.bin`** (`*.bin` é gitignored).

---

### BIN-S4a — GATE: boot real do `.bin` de delta mínimo  [REQUER APARELHO — avisar o dono]

**Objetivo duplo:** (a) confirmar que o `.bin` com metadados carimbados **boota** (gradua o `.bin` da
quarentena); (b) **fechar o achado M7** — provar empiricamente que corrigir mode/rótulo/owner era o que
faltava. Esta build **não** traz o vigia da sprint 19 ainda — é o delta mínimo (só os 3 arquivos), de
propósito, para que um eventual hang não tenha variável confusa.

> **Por que antes da sprint 19:** misturar o vigia (feature nova, arquivos novos) com o teste de
> metadados no mesmo flash tornaria impossível saber qual mudança causou um eventual travamento. O teste
> da hipótese é de delta mínimo; a distribuição é que espera o vigia (BIN-S4b).

**Pré-condições (todas obrigatórias — o gate não começa sem elas):**

1. **Mídia separada** (bloqueio atual, ver "BLOQUEIO ATUAL DO BIN-S4a" no STATUS): um pendrive só com o
   `.bin` de flash, outro só com `usb_update.bin`. O de autorun **desconectado e longe**.
2. **Resgate conferido antes de começar:**
   `md5sum <pendrive-resgate>/usb_update.bin` → deve dar `28a2f280eee313a4b115567926b2ba4f`.
   Se der outro valor, **pare** — sua rede de segurança não é o que você pensa.
3. Build da BIN-S3b validada: `md5sum firmware/PFL7560-FIX-escada-NAO-GRADUADO.bin` →
   `eae3a83db44f790b64b9a5838a27a977`.
4. **Dono presente e ciente** de que o `/data` será formatado (Wi-Fi e adb caem, pareamento se perde) e de
   que o pior caso é ~1 h reflashando o stock.
5. **Linha de base registrada ANTES do flash** (para comparar depois):
   ```bash
   PFL_IP=<ip> ./pfl7560-fix.sh status                    # inclui brilho desde 2026-07-29
   PFL_IP=<ip> ./pfl7560-lcd-color.sh status              # esperado: lvds_fmt: jeida
   adb -s <ip>:5555 shell "logcat -d | grep -c 'LSADC Error'"   # esperado: 0
   ```

**Passos:**
1. Flashar `firmware/PFL7560-FIX-escada-NAO-GRADUADO.bin` por **"Atualização local do sistema"** (copie o
   `.bin` para o pendrive de **flash**, distinto do de resgate — e use o menu do aparelho).
2. Aguardar o boot. **Observar até onde chega:**
   - **PASSA:** o boot chega ao **launcher** (não fica preso na logo do Android).
   - **FALHA:** trava na logo → pule para a **recuperação** abaixo e depois para a BIN-S5.
3. **[Passo manual obrigatório]** o flash formatou o `/data` → o Wi-Fi está desconfigurado e o adb caiu.
   No launcher, reconecte o aparelho à rede Wi-Fi e reative o adb por Wi-Fi (o mesmo IP pode mudar).
4. Rodar o status e conferir os fixes:
   ```bash
   PFL_IP=<ip-do-projetor> ./pfl7560-fix.sh status
   ```

**Critério de sucesso MENSURÁVEL (o que o `status` realmente imprime):**
- boot chega ao **launcher**;
- `HW_VIRTUAL_CHANNEL = 1` no `ZYCustom.ini` do aparelho (mux destravado);
- `gtt1` lê **temperatura real** (~55-60 °C com o aparelho aquecido), **diferente** de `gtt0` (~24-26 °C)
  — se `gtt1 == gtt0` byte a byte, o mux **não** comutou;
- fans **1000/1000** (via `gfs 0`/`gfs 1` do `hidebug`);
- `vendor.newlink.wifi_disconnect_on_boot=0`;
- `init.svc.xiriservice` **ausente/stopped** (serviço `disabled`).
- **Brilho — critério revisado (o `status` AGORA imprime, desde 2026-07-29):** o `cmd_status` inclui
  `gbri 0`. No patamar normal (`gtt1` 61-63 °C) o esperado é **`backlight brightness: 1000`** — a escada
  **não** deve estar atuando com o aparelho apenas morno. E a escada tem de estar no config:
  ```bash
  adb -s <ip>:5555 shell "grep -a 'POLICY_0_THRESHOLD\|POLICY_0_BRIGHTNESS' /vendor/etc/ZYCustom.ini"
  # esperado: = 66000, 67500, 69000, 70000, 71500, 73000  /  = 1000, 950, 900, 850, 850, 850
  ```
- **Escalada térmica viva (critério NOVO, 2026-07-29):**
  ```bash
  adb -s <ip>:5555 shell "logcat -d | grep -c 'LSADC Error'"     # DEVE ser 0
  adb -s <ip>:5555 shell "logcat -d | grep -c 'Achieve Balance'" # DEVE ser > 0
  ```
  `LSADC Error` significa que `getAverageTemperature` está devolvendo a sentinela `MIN_VALUE-1` e o
  `ThermalSense::dispatchProcess` aborta **antes** de avaliar WARNING/EMERGENCY — a proteção fica cega.
  Se aparecer, reinicie e reavalie antes de declarar o gate passado (doc 34, armadilha do LSADC).
- **Correção de cor LCD preservada (critério NOVO — só neste aparelho, painel `-0600`):**
  ```bash
  PFL_IP=<ip> ./pfl7560-lcd-color.sh status   # esperado: lvds_fmt: jeida
  ```
  O `panelparam` **não** é record do container (LCD-S4), então o flash **não deveria** tocá-lo e o byte
  `0x5c=1` sobrevive. Este check existe para **provar** isso na prática. Se a cor quebrar, reaplique com
  `./pfl7560-lcd-color.sh jeida` e registre o achado — significa que o flash mexe em mais partições do que
  o container declara, o que é informação relevante para a invariante 10.

**Recuperação (se travar):** kit de resgate — tire a energia, plugue o pendrive de resgate
(`usb_update.bin` = fábrica), segure o power e religue a energia por ~10-15 s. O stock volta (o fix some,
o `/data` é formatado). Reaplique o fix depois pelo método `/vendor` (autorun ou `./pfl7560-fix.sh apply`).

**NÃO considere o `.bin` graduado até este gate passar.** Ao passar: mover o `.bin` para fora da
quarentena na documentação e registrar a saída do `status` como prova.

---

### BIN-S2b — Metadados canônicos para arquivos NOVOS (pré-requisito da BIN-S4b)

**Motivação:** o vigia da sprint 19, se embarcado no `.bin`, cria **arquivos que não existem no stock**
(ex.: `/vendor/etc/init/pfl7560-warn.rc` e o script/asset do aviso). O builder atual só sabe **copiar os
metadados do stock** dos 3 arquivos que já existem — não há regra para arquivos inéditos. Sem isso, um
arquivo novo entraria com mode/rótulo default do `debugfs write` e poderia repetir o brick.

**Escopo (código — a implementar quando a sprint 19 definir os arquivos do vigia):**
- Definir o **metadado canônico** de cada arquivo novo:
  - `.rc` de init: `mode 0644`, uid/gid `0/0`, `security.selinux u:object_r:vendor_configs_file:s0`;
  - script/binário executável: `mode 0755`, uid/gid `0/0`, rótulo coerente com executáveis de vendor
    (a confirmar no stock: comparar com um executável existente em `/vendor/bin` via `ea_get`).
- Estender `TARGET_PATHS`/`meta_cmds` no `build_fix_bin.py` para escrever esses arquivos com o carimbo
  explícito (não herdar do stock, pois não há stock), e incluí-los no `verify_meta` (gate fatal:
  nenhum `.rc` group/world-writable; `Type: regular`).

**Proof-of-work esperado (offline):** rebuild com o vigia; no log, os arquivos novos aparecem no bloco
`[4b]`/`[5b]` com o mode/rótulo canônico e `type=regular`; `checksum1 -> OK`.

---

### BIN-S4b — GATE de distribuição: `.bin` com o vigia embarcado  [REQUER APARELHO + sprint 19 fechada]

**Pré-requisitos:** BIN-S4a passou (o `.bin` de delta mínimo boota); sprint 19 fechada com o vigia
ancorado em **arquivo novo no `/vendor`** (não no `init.bigfish.rc`); BIN-S2b implementada.

**Passos:** iguais aos da BIN-S4a, mas com a build que inclui o vigia. **Além** dos critérios da BIN-S4a:
- com o fix ativo, **nenhum aviso** aparece na tela (projeção limpa);
- prova do vigia de forma reversível **antes** de confiar no `.bin`: no aparelho já bootado,
  `./pfl7560-fix.sh revert` + reboot → o aviso **aparece**; `apply` + reboot → o aviso **some** (esse
  teste do vigia pertence à sprint 19 e é feito por adb, sem reflash).

**Critério de sucesso:** tudo da BIN-S4a **mais** o comportamento correto do vigia (aparece sem fix,
some com fix) e boot íntegro com os arquivos novos.

---

### BIN-S5 — Diagnóstico (só se a BIN-S4a falhar)  [REQUER APARELHO + UART]

Se o boot travar mesmo com os metadados corretos, a causa do brick **não** era (só) o mode `0664`.
Descobrir o estágio exato do hang.

- **Caminho primário: console serial UART** (não o logcat). Num hang cedo do init, o `logd` pode nem
  subir e o `/data` fica inacessível — o logcat persistente não é confiável. Conecte o USB-TTL aos pads
  TX/RX/GND perto do SoC (115200 8N1; TX do adaptador → RX da placa e vice-versa; GND comum; **não** ligue
  VCC). Ver [`16-recuperacao-brick.md`](../guide/16-recuperacao-brick.md), seção 4. Alternativa sem abrir:
  HiFactoryMenu "Open UartDebug".
- **Comparar `/vendor` que boota vs `/vendor` que trava:** no aparelho corrigido pelo método adb (que
  **boota**), leia os metadados reais dos 3 arquivos e compare com os do `.bin`:
  ```bash
  # no /vendor do metodo adb (aparelho bootado):
  adb -s <ip> shell 'for f in /vendor/etc/ZYCustom.ini /vendor/build.prop /vendor/etc/init/hw/init.bigfish.rc; do
      echo "== $f"; stat -c "%a %u %g" "$f"; ls -Z "$f"; done'
  ```
  e o equivalente do `.bin` (via `debugfs` na `edit.raw` do build — ver BIN-S1 abaixo). **Qualquer campo
  que divirja é a próxima pista.**
- Refinar a BIN-S2/S2b com o achado e voltar à BIN-S3b.

**Proof-of-work esperado:** um diff explícito de `stat`/`ls -Z` (mode/uid/gid + rótulo SELinux) entre o
`/vendor` do `.bin` e o do método adb, apontando o campo que diverge — ou a última linha do console UART
antes do hang.

---

### BIN-S1 (referência) — como inspecionar os metadados dentro do `.bin`

Já implementado no builder, mas se precisar inspecionar manualmente (para a BIN-S5), extraia a
`orig.raw`/`edit.raw` — o builder usa um tempdir que é apagado ao fim. Snippet para preservar:
```bash
# extrai o payload vendor (sparse) do .bin e expande para ext4 raw:
python3 - "$STOCK" <<'PY'
import sys, struct, sparse
PFX=0x4b0b1d54
f=open(sys.argv[1],'rb'); f.seek(PFX); size=struct.unpack('>I',f.read(4))[0]
f.seek(PFX+8); open('/tmp/vendor.img','wb').write(f.read(size))
sparse.expand('/tmp/vendor.img','/tmp/orig.raw')
print('orig.raw pronto')
PY
# (rode de dentro de artifacts/bin-build/ para achar o sparse.py)

# ler rotulo + stat de cada arquivo:
for f in /etc/ZYCustom.ini /build.prop /etc/init/hw/init.bigfish.rc; do
  echo "== $f"
  debugfs -R "ea_get $f security.selinux" /tmp/orig.raw
  debugfs -R "stat $f" /tmp/orig.raw | grep -E 'Type|Mode|User|Group'
done
```
Saída esperada (stock): rótulos conforme a tabela do Contexto; `Mode 0644`/`0600`; `User 0 Group 0`.

---

## Ordem e dependências (resolvido — sem ciclo)

O texto antigo dizia "sprint 19 primeiro" de forma que criava um ciclo (18 depende de 19, 19 devolve a
decisão para 18). Resolvido assim:

```
BIN-S3b (offline)  ──  BIN-S4a (boot do delta mínimo, fecha o M7)  ──┐
                                                                       │
Sprint 19 (vigia, testada por adb, reversível)  ──────────────────── BIN-S2b ─ BIN-S4b (distribuição)
```

- **BIN-S4a NÃO espera a sprint 19.** Ela testa a hipótese de metadados com o delta mínimo. Pode rodar
  assim que houver aparelho + resgate.
- **A sprint 19 é pré-requisito apenas da BIN-S4b** (o `.bin` de **distribuição**, que precisa levar o
  vigia embarcado porque o público-alvo não usa adb/pendrive). A sprint 19 se desenvolve e valida por
  adb, de forma reversível, **sem** depender de nenhum flash.
- Portanto a sprint 19 **decide sozinha** onde o vigia mora (arquivo novo em `/vendor`); a sprint 18
  apenas **embarca** esse resultado na BIN-S4b. Sem ciclo.

---

## Riscos e recuperação

- **SEMPRE ter o resgate pronto ANTES de flashar** (seção "Pré-requisito absoluto"). O resgate reflasha
  o stock de fábrica e formata o `/data` — desbrica sempre, ao custo de apagar o fix.
- **O bootloader é intocável** (nem a build nem o flash o alteram) → o modo de upgrade USB está **sempre**
  disponível → o aparelho é **sempre recuperável**. Plano B: UART/console U-Boot 115200.
- **Não confundir logística de evidências com o gate.** Fotos (termômetro IR, tela antes/depois) são do
  roteiro de disclosure ([`../disclosure/roteiro-evidencias.md`](../disclosure/roteiro-evidencias.md)),
  **não** são critério da BIN-S4a — o critério é o boot real medido pelo `status`.

## Regra de ouro

> Nenhum `.bin` sai da quarentena antes de **bootar em hardware** com os fixes ativos e medidos. Até lá,
> o método `/vendor` (autorun/adb) é o caminho seguro e definitivo. O protótipo antigo sem metadados foi
> apagado e **não deve ser recriado** — só o builder atual (`build_fix_bin.py`), que carimba mode/rótulo/
> owner, produz uma build candidata.
