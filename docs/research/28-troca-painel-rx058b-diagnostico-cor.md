# 28 - Troca do painel LCD RX058B-4300 -> RX058B-0600: diagnóstico e correção de cor

Registro integral (tentativa e erro incluído) da investigação iniciada em **2026-07-10** após o
dono trocar o micro-painel LCD do motor óptico do PFL7560. Documento vivo — atualizado conforme
avançamos. Sessão conduzida via adb ao vivo no aparelho (`94.140.14.52:5555`, root).

---

## TL;DR

- O PFL7560 é um **projetor LCD de painel único** (não TV). O "LCD trocado" é o micro-painel do
  motor óptico, acionado pelo SoC via **LVDS 2-link 8-bit**.
- Painel **original**: `FPX-RX058B-4300-V0` (driver IC **SC5010E**, fab. 2024-11-01).
  Painel **novo** instalado: `RX058B-0600-V2` / `058-0600-V2` (peça do projetor **Thundeal TD96**).
  Ambos família RX058B (5.8" 1080p), variantes diferentes.
- Sintoma: imagem **nítida e com geometria certa**, **cores primárias e branco/preto corretos**, mas
  **os tons intermediários (meios-tons) ficam embaralhados/psicodélicos**.
- Causa-raiz identificada: **descasamento do empacotamento de bits LVDS**. Decodificação por padrão de
  teste provou que os **bits altos (32/64/128) estão perfeitos** e o **bit 4 (valor 16) de cada canal
  está sendo roteado para o canal errado**.
- A config do painel vive na **partição `panelparam` (`mmcblk0p6`)** — tabela de **83 perfis** de painel.
  O firmware está usando o perfil do painel **antigo** (índice 69 = `RX058B_4300_5010E`).
- **Status:** correção ainda não fechada. Testes de campo (link map, bit-depth, flags) descartados.
  Falta localizar o parâmetro exato de formato LVDS (VESA/JEIDA) — pesquisa por agentes em curso.

---

## 1. O hardware e a troca

| Item | Valor |
|---|---|
| Aparelho | Projetor LCD single-panel Intelbras **PFL7560** |
| SoC | HiSilicon **Hi3751 V553** (marca HS352), plataforma Android **bigfish** (HiDPT) |
| SO / kernel | Android 9 / Linux 4.9.127, build `NL5H00X ... eng ... dev-keys` (userdebug, rootável) |
| ODM / projeto | Newlink / Zhiying (ZY) — `KJM_5H039_412`, projectid **390** |
| Interface do painel | **LVDS 2-link, 8-bit**, 1920x1080 @ 60 Hz |
| Painel de fábrica | `RX058B-4300` — flat serigrafado `FPX-RX058B-4300-V0`, driver IC **SC5010E** |
| Painel novo | `RX058B-0600` (`058-0600-V2`) — vendido p/ **Thundeal TD96** (tb. Vivibright F40, AAO YG620) |
| Acesso | adb via Wi-Fi (`94.140.14.52:5555`), `adb root` funciona (userdebug); `/vendor` ext4 persistente |

O painel novo é **drop-in mecânico** (mesmo conector/flat, pino a pino). A diferença que importa é
**elétrica/de formato de dados**, não física.

---

## 2. A saga do diagnóstico (como o alvo foi mudando)

A investigação foi um funil — cada evidência derrubou uma hipótese e afinou a seguinte.

1. **"Cores nada a ver"** (relato inicial) -> hipótese: swap de canais LVDS (RGB<->BGR).
2. **"Cores certas, mas parece 320px"** + **"estourado, ultra saturado"** -> hipótese migrou para
   resolução/timing e depois gamma.
3. **Fotos do launcher** (fundo verde, cards marrom, texto branco nítido) -> hipótese: rotação de canais.
4. **Barras de cor puras projetadas** -> **primárias R/G/B/C/M/Y corretas**, logo **NÃO é swap de canal**
   (swap trocaria as primárias). Mas a barra `CINZA50` apareceu **turquesa**.
5. **Padrão de gamma (gradientes + patches de cinza)** -> patches de cinza aparecem coloridos e
   **alternando por nível** (32->verde, 64->ciano, 96->rosa, 128->turquesa). Primeira leitura: gamma/PQ.
   Confirmado que WB está neutro (ganhos R/G/B = 256) e que o desvio não é de temperatura de cor.
6. **Foto do menu de keystone** (veleiro totalmente psicodélico, UI/texto legível) -> confirma:
   **áreas de cor sólida e texto OK; imagens com meios-tons = embaralhadas**.
7. **Padrão de decodificação de bits (bit isolado por canal)** -> veredito final:
   **bits 5,6,7 (32/64/128) perfeitos; bit 4 (16) roteado para o canal errado.** É **empacotamento
   de bits LVDS**, não gamma nem swap.

**Lição:** a descrição verbal ("cores certas / 320px / saturado") despistou; só os **padrões de teste
projetados** (barras, gamma, bits) cravaram a natureza real do defeito.

---

## 3. Arquitetura: onde vive a config do painel

Varredura exaustiva do `/vendor` e do device tree:

- **NÃO** está no `ZYCustom.ini` (lido inteiro: só térmico/backlight/fan/keystone/motor/IMU/mux).
- **NÃO** está em `board.ini` (não existe em `/vendor/etc`).
- **NÃO** está no DTB (só o IRQ `hi_vo_irq`; zero nós de painel/lvds/vo).
- **NÃO** há `panel.bin` (todos os `.bin` do `/vendor` são firmware de Wi-Fi).

**Vive na partição de bloco `panelparam`:**

```
/proc/cmdline: ... 8M(panelparam),80M(tconparam),4M(demura) ...  androidboot.projectid=390
/dev/block/by-name/panelparam -> mmcblk0p6  (8 MB)
```

- Tabela de **83 perfis** de painel; cada perfil é um **struct de 768 bytes**.
- **Índice do perfil = (offset_do_nome - 168) / 768** (validado: perfil de fábrica no offset 53160 =
  índice **69** = `RX058B_4300_5010E_1080P_M`, que bate com o `Panel Current Index` do `/proc/msp/pdm`).
- Estado ao vivo em `/proc/msp/panel`, `/proc/msp/pdm`, `/proc/msp/tcon`, `/proc/msp/pq`, `/proc/msp/disp1`.

**Campos do struct mapeados (por engenharia reversa, comparando os 83 perfis):**

| Offset | Campo | Valor no -4300 (idx 69) |
|---|---|---|
| 0x00-0x2F | nome ASCII | `RX058B_4300_5010E_1080P_M` |
| 0x30 / 0x34 | res_width / res_high (u32) | 1920 / 1080 |
| **0x4c** | **bit_width** | **1 = 8BIT** (0 = 6BIT nos 720p/600p) |
| 0x3c, 0x54, 0x5c | flags de timing/estrutura | 0, 0, 0 |
| **0x60-0x6c** | **link map** (link1-4 -> pixel0-3) | 0, 1, 2, 3 |
| 0x70 | link_info (2_link) | 2 |
| 0xa0+ | timing (clk, HT, VT, porches) | clk 134400000, HT 2000, VT 1120 |

**Parâmetros LVDS lidos em `/proc/msp/panel` (idx 69):** `lvds_fmt=vesa`, `bit_width=8BIT`,
`link_info=2_link`, `link1..4=pixel0..3`, `current=300MV`, `com_vol=1200MV`. O byte que codifica
`lvds_fmt` (VESA/JEIDA) **ainda não foi localizado** no struct.

---

## 4. Ferramentas e método de teste

| Ferramenta | Uso |
|---|---|
| `/vendor/bin/sample_pdm 4 <idx>` | troca o perfil de painel (aplica **no reboot**). `3 null`=info; `0 0`=projectid; `5`=tcon |
| `/vendor/bin/himm <addr> [val]` | peek/poke de registrador do SoC (não usado ainda p/ escrita) |
| `libhitvservice.so` | API `SetLvdsFormat/Map/Swap/BitMode`, `ResetLvdsSetting`, `HI_UNF_PDM_SetPanelIndex` (sem CLI direto) |
| `/proc/msp/panel` | estado decodificado do painel ativo |
| `dd` na partição | editar/gravar perfis (com backup) |
| `am start -a VIEW -d file:///sdcard/X.png` | exibir padrões de teste direto por adb (via higallery) |

**Método seguro validado:** editar **slots descartáveis** (perfis 600p/720p que não uso), **nunca o
69**; ativar com `sample_pdm 4 <slot>`; reverter sempre com `sample_pdm 4 69`. Backup completo das
partições em `scratchpad/backup-particoes/` (panelparam, deviceinfo, dtbo, bootargs).

**Rede de segurança do firmware:** perfis inválidos (ex.: `bit_width=6`) são **rejeitados no boot** e o
sistema cai num **fallback** (`CAFH028_ST5892B_1080P_F`, slot 50), mantendo imagem — não brica.

---

## 5. Tentativa e erro (tabela de testes)

Todos os testes mantêm o **timing do -4300** (que dá imagem nítida) e variam só o formato de dados.

| # | Perfil / mudança | Resultado | O que ensinou |
|---|---|---|---|
| 0 | **69** `RX058B_4300` (fábrica) | imagem OK, cor errada nos meios-tons | baseline |
| 1 | **72** `RX058B_4500_ST5892B` (perfil inteiro) | **SEM IMAGEM** (LED fraco, nada projetado) | timing do -4500 incompatível -> não trocar perfil inteiro |
| 2 | **TST1** link map `1,0,2,3` (8-bit) | imagem OK, **cor idêntica ao baseline** | link map = arranjo espacial de pixel, **não** afeta bits de cor |
| 3 | **TST2** `bit_width=6` | **fallback** (CAFH028) | firmware **rejeita 6-bit**; painel não é 6-bit |
| 4 | **TST_EXTREMO** flags `0x3c/0x54/0x5c=1` + link reverso (8-bit) | **SEM IMAGEM** | esses flags são **timing/estrutura**, não cor -> `lvds_fmt` não está aí |
| - | reversão para **69** | imagem OK (volta ao baseline) | reversibilidade confirmada em todos os ciclos |

**Conclusão dos testes de campo:** nenhum byte facilmente identificável do struct corrige a cor. O
parâmetro de formato LVDS (VESA/JEIDA) não está entre `0x3c/0x54/0x5c` nem no link map nem no bit_width.

---

## 6. A decodificação de bits (o achado central)

Padrão projetado: 12 quadros = cada **bit isolado** (16/32/64/128) de cada canal (R/G/B), rotulado.
Resultado (perfil 69, baseline) — `[X]` = cor errada, `[ok]` = correto:

| bit | Vermelho | Verde | Azul |
|---|---|---|---|
| **16** | `[X]` cinza-esverdeado | `[ok]` verde | `[X]` **amarelo/oliva** |
| 32 | `[ok]` vermelho | `[ok]` verde | `[ok]` azul |
| 64 | `[ok]` vermelho | `[ok]` verde | `[ok]` azul |
| 128 | `[ok]` vermelho | `[ok]` verde | `[ok]` azul |

**Interpretação:** os 3 bits mais significativos (5,6,7) chegam corretos em todos os canais. O **bit 4
(valor 16)** — e presumivelmente os bits abaixo — de cada canal está sendo **desviado para o canal
errado** (`R=16` vaza para verde; `B=16` vira amarelo = R+G). Como as cores puras (255) e os tons altos
dependem dos bits altos (corretos), elas ficam certas; os meios-tons (onde o bit 4 pesa) embaralham.

Isso é a assinatura de um **descasamento de empacotamento LVDS** — a fronteira entre os bits que vão
nos primeiros pares LVDS e os que vão no par extra (típico de **VESA vs JEIDA** e de mapeamento
6-vs-8-bit) está diferente entre o que o firmware emite (formato do -4300) e o que o -0600 espera.

---

## 7. Estudos dos agentes (pesquisas disparadas)

Três workflows multi-agente (fan-out web + verificação adversarial + síntese):

1. **`pfl7560-lcd-cor-vendor`** (concluído) — arquitetura de vídeo do Hi3751/bigfish; confirmou que a
   config de painel vive em partição de "screen-param" dedicada, lida cedo no boot; ferramenta Windows
   **HiTool-DPT / HiPanel** gera a imagem de painel; factory menu presente; não está no DTB/ini.
2. **`pfl7560-rx058b-variantes`** (concluído) — RX058B-4300 vs -0600: mesmo tamanho/classe LVDS,
   diferença é de **timing/formato**, não pinout; specs do -0600 não têm datasheet público (só
   marketplace); interface é LVDS/P2P (não MIPI).
3. **`pfl7560-lvds-bitmap-conversao`** (em curso) — foco cirúrgico: tabela de bits **VESA vs JEIDA** em
   LVDS 8-bit, **offset exato do `lvds_fmt`** no struct do panelparam, **registrador do LVDS-TX** do
   Hi3751 para virar VESA/JEIDA via `himm` ao vivo, e o formato que o -0600 espera.

Relatórios completos salvos em `.../tasks/*.output` da sessão.

---

## 8. Monitoramento térmico (durante os testes)

O tema original do projeto é térmico, então acompanhamos a óptica minuto a minuto durante a sessão.
A rajada de reboots deu um "descanso térmico" involuntário:

| Momento | env (óptica) | Observação |
|---|---|---|
| 20:58 | 59,0 C | início (aparelho ligado há tempo) |
| 21:05-21:16 | 59 -> **26,4 C** | queda durante os reboots (LED apagado nos boots) |
| 21:17-21:29 | 26 -> **58,5 C** | reaquecimento com uso normal |

Limites do firmware (board.ini do aparelho): WARNING 70 C, EMERGENCY 75 C (desligamento). Toda a
sessão ficou com boa margem. Ver política térmica em [`02-sistema-termico-atual.md`](02-sistema-termico-atual.md).

---

## 9. Estado atual e próximos passos

**Estado:** projetor revertido ao perfil **69** (baseline: imagem OK, meios-tons errados). Nada
permanente foi alterado; todos os slots de teste estão em posições descartáveis; o 69 está intacto.

**Próximos passos (em ordem de probabilidade):**
1. Do resultado dos agentes: localizar o **byte de `lvds_fmt`** no struct **ou** o **registrador do
   LVDS-TX** do Hi3751 -> testar **VESA<->JEIDA** (a hipótese ainda não testada, e a mais forte).
2. Decodificar completamente o mapa de bits (padrão com todos os bits) e casar com um formato padrão.
3. Se não for corrigível por config: **HiTool/HiPanel** (Windows) para gerar um perfil com os
   parâmetros do -0600, **ou** obter o `panelparam` de um firmware do Thundeal TD96.
4. Alternativa pragmática: voltar ao **painel `-4300` original**, se disponível.

---

## 10. Comandos de referência

```bash
# conectar
adb connect 94.140.14.52:5555 && adb -s 94.140.14.52:5555 root

# estado do painel ativo
adb shell "cat /proc/msp/panel | grep -iE 'panel_name|bit_width|lvds_fmt|link|intf_enable'"

# trocar perfil (aplica no reboot) e reverter
adb shell "/vendor/bin/sample_pdm 4 <indice>"   # ativa
adb shell "/vendor/bin/sample_pdm 4 69"          # reverte ao original
adb reboot

# backup / restauro da partição de painel
adb exec-out "dd if=/dev/block/by-name/panelparam" > panelparam.bak.img
adb shell "dd if=/sdcard/panelparam.img of=/dev/block/by-name/panelparam bs=4096; sync"

# exibir padrão de teste direto no projetor
adb push teste.png /sdcard/teste.png
adb shell "am start -a android.intent.action.VIEW -d file:///sdcard/teste.png -t image/png"

# temperatura
adb shell "getprop zysys.env_temp zysys.light_temp"
```

---

## 11. Segurança e reversibilidade

- **Backup** de `panelparam`, `deviceinfo`, `dtbo`, `bootargs` feito antes de qualquer escrita.
- O **69** nunca foi sobrescrito; todos os testes usam slots descartáveis (600p/720p).
- Reversão em 1 comando (`sample_pdm 4 69` + reboot); o firmware ainda tem **fallback** anti-brick.
- adb blindado para sobreviver a reboots (`persist.adb.tcp.port=5555`, `service.adb.root=1`).

> **Aviso:** editar `panelparam` mexe numa partição lida no início do boot. Pior caso observado =
> tela sem imagem (reversível por adb). Nenhum brick ocorreu. Sempre com backup à mão.

---

## 12. Atualização — decodificação de bits e vias de baixo nível

### 12.1. Prova de que NÃO é VESA/JEIDA (workflow `pfl7560-lvds-bitmap-conversao`)

Os agentes derivaram das tabelas do kernel (`panel-lvds.txt`) um resultado **matematicamente
confirmado**: trocar VESA<->JEIDA em 8-bit é um "rotate de 2 bits" aplicado **igual e independente**
a R, G e B — **sem cruzar canais**. Consequência: cinza neutro (R=G=B) **permanece neutro** sob
VESA/JEIDA. Como nós observamos **cinza virar cor** (turquesa/verde), o defeito **cruza canais** e,
portanto, **não é VESA/JEIDA nem bit-depth** (que também são por-canal). É um **bit-order que cruza
canais**.

### 12.2. Decodificação por bit isolado (padrão de teste)

Padrão com cada bit isolado de cada canal, no perfil 69:

| bit | R | G | B |
|---|---|---|---|
| 16 (bit 4) | ERRADO (cinza-esverdeado) | ok | ERRADO (amarelo) |
| 32/64/128 (bits 5,6,7) | ok | ok | ok |

Ou seja: **os 3 bits mais significativos chegam certos; o bit 4 (e abaixo) de cada canal é roteado
para o canal errado.** Por isso primárias puras (só bits altos) ficam certas e meios-tons embaralham.

### 12.3. Via registrador (himm) — travada

- Chip real: **`Hi3751(0x43)_v350`**, SDK **`HiDPTAndroidV600R001C00SPC070`** (não o SDK STB de onde
  os agentes tiraram os offsets `0xd400`).
- `himm` **lê hardware** (validado: `0xf8a22000 = 0x12555555`), mas os blocos de vídeo candidatos
  (via `/proc/vmallocinfo`: `f8840000` 528KB, blocos de 1MB em `ff000000`/`ff080000`/`ff1a0000`/`f8b20000`)
  leem zero nos offsets testados. O bloco do VDP/LVDS **não foi isolado** de forma confiável, e o SDK
  HiDPT é fechado. Conclusão: **ajuste por registrador ao vivo não convergiu** sem a documentação.

### 12.4. Direção atual

- **Via A (perfil do TD96):** workflow `pfl7560-td96-perfil-0600` em curso — buscar o firmware do
  Thundeal TD96 (usa o -0600 nativamente) e extrair o perfil de painel correto para **copiar na
  partição `panelparam`** (temos root). É a via mais limpa.
- **Via B (HiTool/HiPanel Windows):** gerar um perfil com o mapeamento do -0600, se conseguirmos o SDK.
- **Via C (pragmática):** reinstalar/comprar o painel `-4300` original (SC5010E) — resolve 100%.

> **Nota importante (root não é o gargalo):** temos acesso root total; o limite é **informação** —
> qual o mapeamento LVDS exato do -0600 e onde configurá-lo. Assim que tivermos (via A ou B), a
> aplicação é trivial com o acesso que já temos (editar/copiar a partição de painel).

---

## 13. SOLUÇÃO (RESOLVIDO — 2026-07-10)

**O painel RX058B-0600 usa mapeamento LVDS `JEIDA`; o firmware do -4300 emitia `VESA`.** Trocar
VESA→JEIDA corrige 100% (gradiente de cinza liso, patches de cinza neutros, gradientes R/G/B lisos,
texto sem franja — confirmado por foto do padrão de gamma).

### Como foi descoberto e aplicado (decompilação + programa próprio)

1. **`objdump` do sistema não desmonta ARM** → usei **capstone (Python)** para desmontar
   `libhitvservice.so` (Thumb; `.text` VMA `0x9b110` / off `0x93110`). Descobri que
   `HiPanelCtrl::SetLvdsFormat/BitMode/Swap/Map` **não usam o `this`** — operam num buffer local e
   aplicam via `hi_mpi_panel_*`. Enum: **`VESA=0, JEIDA=1`**.
2. **Programa `lvdsctl`** (compilado com NDK 27, `armv7a-linux-androideabi24-clang`) que faz:
   `dlopen("/vendor/lib/libhitvservice.so")` → `HI_SYS_Init()` → `HiPanelCtrl::Init()`
   (`_ZN11HiPanelCtrl4InitEv`) → `SetLvdsFormat(0, valor)`
   (`_ZN11HiPanelCtrl13SetLvdsFormatE22HI_MW_PANEL_LVDS_FMT_E`). Sem o `Init` dá
   `hi_mpi_panel: PANEL is not init`. Uso: `LD_LIBRARY_PATH=/vendor/lib:/system/lib ./lvdsctl fmt 1`.
   Fonte em `scratchpad/re/lvdsctl.c`. Aplica **ao vivo (sem reboot)**.
3. **Bônus: `SetLvdsFormat` também grava no `panelparam`** (não só runtime). Comparando o perfil 69
   antes/depois: **exatamente 1 byte muda — offset `0x5c` do struct de 768: `0x00`(VESA)→`0x01`(JEIDA)**.
   Por isso a correção **persiste no reboot nativamente**, sem janela de cor errada e sem serviço extra.

### Mapa de offsets do struct de perfil (768 bytes) — confirmado

| Offset | Campo | VESA/-4300 | JEIDA/-0600 (corrigido) |
|---|---|---|---|
| **0x5c** | **lvds_fmt** | 0 (VESA) | **1 (JEIDA)** |
| 0x4c | bit_width | 1 (8BIT) | 1 (8BIT) |
| 0x60-0x6c | link map | 0,1,2,3 | 0,1,2,3 |

### Estado permanente e reversão

- Perfil 69 (`RX058B_4300`) no `panelparam` agora tem `lvds_fmt=JEIDA` (byte 0x5c=1). Confirmado após
  reboot: `/proc/msp/panel` → `lvds_fmt: jeida`, painel ativo, imagem correta.
- Ferramenta mantida em `/vendor/bin/nl_lvdsctl` para reajuste. **Reverter para VESA:**
  `LD_LIBRARY_PATH=/vendor/lib:/system/lib /vendor/bin/nl_lvdsctl fmt 0` (ou `dd` o byte 0x5c=0).
- Também testável ao vivo: `nl_lvdsctl <fmt|swap|bit|map> <valor>` (fmt: 0=VESA 1=JEIDA).

### Afinação verificada

- **Cor/gamma:** o "estourado/saturado" inicial era o próprio descasamento VESA/JEIDA; com JEIDA os
  gradientes de cinza ficam lisos e os patches neutros (confirmado por foto). WB neutro (R/G/B=256).
- **Refresh (hertz):** painel a **60,00 Hz estáveis** (clk 134.4MHz / HT2000 / VT1120 = 60.0;
  `expect_info: PANEL/60000`; PLL travado). Sem dessincronização; o "piscar" inicial era artefato do
  VESA/JEIDA.
- **Resolução nativa: 1920×1080 FÍSICO REAL (confiança alta)** — workflow `pfl7560-rx058b-0600-resolucao-fisica`
  cruzou 4 frentes: teste de linha de 1px numa review do Thundeal TD96 (linhas separadas → FHD real);
  a família RX058B tem aspect ratios distintos (16:10 vs 16:9 → resolução é do vidro, não de scaler);
  LVDS dual-link 60-pin = classe 1080p (single-link satura em ~85MHz); painel "burro" sem scaler
  (drivers source+gate, sem framebuffer). Identidade: RX058B-0600 = 058-0600-V2 = PJ58S1V1 = PengJi
  PJ058S1, 5.8", 1920×1080, 60-pin. A **nitidez limitada é da ÓPTICA** (lente plástica barata), não do
  painel — confirmado por reviews de projetores irmãos. Prova 100% definitiva só por foto macro do vidro.
  Nota: "SC5010E" no nome do perfil provavelmente é um driver de backlight LED (Semtech SC5010), não o T-CON.
