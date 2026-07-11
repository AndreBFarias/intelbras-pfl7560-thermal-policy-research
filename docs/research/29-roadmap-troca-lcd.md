# 29 - Roadmap e sprints: troca de painel LCD, correção de cor e pareamento automático

Planejamento (não-executado) para transformar a descoberta pontual da sessão de 2026-07-10 —
**correção de cor após troca de micro-painel LCD** — em recurso replicável do projeto. Consolida
engenharia reversa, decompilação e a pesquisa dos agentes, e define sprints com proof-of-work.

Base técnica já resolvida e documentada em
[`28-troca-painel-rx058b-diagnostico-cor.md`](28-troca-painel-rx058b-diagnostico-cor.md).

---

## Resumo executivo

Trocar o micro-painel LCD do PFL7560 por outro de sufixo diferente (`RX058B-4300` → `RX058B-0600`)
quebra a cor dos meios-tons por **mapeamento LVDS divergente (VESA vs JEIDA)**. Já sabemos:
- **Diagnosticar** (padrões de teste projetados) e **corrigir por software** (byte `0x5c` do perfil no
  `panelparam` = 1 → JEIDA), com ferramenta própria (`lvdsctl`) que aplica ao vivo e persiste.
- **Onde** cada parâmetro de painel mora e **como** chamá-lo (decompilação da `libhitvservice.so`).

Falta empacotar isso para **qualquer pessoa replicar com facilidade**, catalogar **painéis
compatíveis**, e — a ideia mais ambiciosa — **auto-parear o painel usando a câmera interna do próprio
projetor**. Este documento organiza tudo em 7 sprints.

---

## 1. Consolidação técnica (o que a sessão produziu)

### 1.1 Arquitetura do painel (engenharia reversa)
- SoC HiSilicon **Hi3751 v350** (SDK **HiDPTAndroid V600R001**, fechado), Android 9, LVDS 2-link 8-bit.
- Config do painel vive na partição **`panelparam` (`/dev/block/by-name/panelparam` = `mmcblk0p6`, 8 MB)** —
  tabela de **83 perfis**, struct de **768 bytes** cada; índice = `(offset_do_nome − 168) / 768`.
- Perfil de fábrica: **índice 69 = `RX058B_4300_5010E_1080P_M`** (VESA, 8-bit, 2-link, 1920×1080@60,
  clk 134.4 MHz). Estado ao vivo em `/proc/msp/panel`, `/proc/msp/pdm`, `/proc/msp/tcon`.
- Offsets do struct confirmados: **`0x5c` = lvds_fmt (0=VESA, 1=JEIDA)**, `0x4c` = bit_width,
  `0x60-0x6c` = link map. O SoC **não reescala** (TCON limpo: od/rgbw/demura/pcid = NO) → painel é
  "burro" (1 dado = 1 sub-pixel).

### 1.2 A correção (decompilação)
- `objdump` do sistema não desmonta ARM → usar **capstone (Python)**. Desmontando
  `libhitvservice.so`: `HiPanelCtrl::SetLvdsFormat/BitMode/Swap/Map` **não usam `this`** (operam em
  buffer local + driver). Enum **VESA=0, JEIDA=1**.
- Programa **`lvdsctl`** (NDK 27, `armv7a-linux-androideabi24-clang`): `dlopen` da lib →
  `HI_SYS_Init()` → `HiPanelCtrl::Init()` → `SetLvdsFormat(0, valor)`. Aplica **ao vivo (sem reboot)**
  e **grava no `panelparam`** (persiste). Fonte em `artifacts/lcd-color-fix/lvdsctl.c`.
- Reverter: `lvdsctl fmt 0`. Testar outros eixos: `swap <0-5>`, `bit <0-1>`, `map`.

### 1.3 Achados dos agentes (workflows)
- **VESA↔JEIDA** é a única diferença que corrige "primárias OK, meios-tons embaralhados" mantendo o
  timing (prova matemática das tabelas do kernel; confirmado empiricamente).
- Registradores do VDP (`LVDS_CTRL/SWAP0`) existem mas a base é do SDK STB, não do HiDPT v350 →
  via registrador travou; via API (decompilação) venceu.
- Painéis RX058B são variantes elétricas do mesmo 5.8"/60-pin; o sufixo NÃO garante o formato — deve
  ser verificado. Não há datasheet público do `-0600` (resolução física a confirmar; workflow em curso).
- Projetores irmãos que usam o `-0600`: Thundeal TD96, Vivibright F40 (Amlogic), AAO YG620, Rigal RD826
  — plataformas mistas (HiSilicon/Amlogic/MStar), então firmware não é portável; só o **modo LVDS** é.

---

## 2. Matriz de painéis compatíveis (base)

O firmware traz **83 perfis** (53×1080p, 16×720p, 6×600p, 1×800p). Os da família do PFL7560
(**RX058B, 5.8", 1920×1080**), diretamente selecionáveis por `sample_pdm 4 <idx>`:

| Índice | Perfil | Driver IC | LVDS fmt* | Observação |
|---|---|---|---|---|
| 69 | `RX058B_4300_5010E_1080P_M` | SC5010E | VESA | **painel de fábrica** |
| 72 | `RX058B_4500_ST5892B_1080P_M` | ST5892B | ? | timing próprio (deu sem imagem no teste; requer perfil casado) |
| 10 | `RX058B_1800_ST5892B_1080P_F` | ST5892B | ? | variante |
| 30 | `RX058B_1800_..._F_ALLS` | ST5892B | ? | variante |
| 49 | `RX058B_1800_..._PNS` | ST5892B | ? | variante |

\* fmt do perfil vs. fmt que o painel físico espera — **a verificar empiricamente** por painel.

**Painel testado nesta sessão:** `RX058B-0600` (peça do Thundeal TD96) → funciona no **perfil 69 com
LVDS = JEIDA** (byte 0x5c = 1). Timing do 69 é compatível; só o formato divergia.

**Regra prática:** manter o perfil 69 (timing bom) e ajustar só o **formato LVDS** ao painel novo é
mais seguro do que trocar de perfil inteiro (perfis de timing diferente dão tela preta).

A matriz viva completa é a Sprint **LCD-S6**.

---

## 3. Sprints planejadas

### LCD-S1 — Aplicador da correção de cor (fácil replicação)
**Objetivo:** um comando único que aplica/reverte o formato LVDS após troca de painel, no mesmo estilo
do `pfl7560-fix.sh` térmico. **Motivação:** hoje exige adb manual + binário; o usuário quer 1 passo.
> **Status (2026-07-11): primeira versão IMPLEMENTADA.** Existe `pfl7560-lcd-color.sh` (raiz) +
> `lvdsctl` pré-compilado + 5 padrões de teste em `artifacts/lcd-color-fix/`, com subcomandos
> `status/jeida/vesa/swap/bit/test/wizard/backup/restore` (testado: `status` OK no aparelho). **Falta:**
> integrar ao `pfl7560-menu.sh` e `install.bat`; validar em outro aparelho.
**Escopo:**
- Versionar o binário `lvdsctl` (ARM) + a fonte (já em `artifacts/lcd-color-fix/`).
- Script `pfl7560-lcd-color.sh` com: `status` (lê `/proc/msp/panel` lvds_fmt), `jeida`, `vesa`,
  `test` (projeta os padrões de teste), `backup`/`restore` do `panelparam`.
- Empurrar `lvdsctl` para `/data/local/tmp` e rodar com `LD_LIBRARY_PATH=/vendor/lib:/system/lib`.
- Integrar como opção no `pfl7560-menu.sh` e no `install.bat`.
**Proof-of-work:** `pfl7560-lcd-color.sh jeida` → `/proc/msp/panel` mostra `lvds_fmt: jeida`; `vesa`
reverte; sobrevive a reboot. **Risco:** requer root/adb (já disponível). **Esforço:** baixo.

### LCD-S2 — Wizard de pareamento (semi-automático, guiado)
**Objetivo:** assistente que leva o usuário do "cores erradas" ao "certo" em <2 min, sem entender de
LVDS. **Motivação:** nem todo painel será JEIDA; precisa de um fluxo à prova de leigo.
**Escopo:**
- Projeta o padrão de gamma (patches de cinza) e pergunta em loop: "os cinzas estão neutros? (s/n)".
- Se não, cicla os eixos via `lvdsctl` **ao vivo (sem reboot)**: VESA↔JEIDA → bit 6/8 → swap 0..5,
  reprojetando a cada passo. Para no primeiro que der cinza neutro.
- Ao acertar, oferece "tornar permanente" (já persiste no `panelparam`) e salva o resultado na matriz.
**Proof-of-work:** partindo de um painel com formato errado, o wizard chega ao correto e o usuário só
responde s/n. **Risco:** alguns formatos dão tela preta (tratar com timeout + reversão automática).
**Esforço:** médio.

### LCD-S3 — Auto-pareamento via câmera interna (a "forma inteligente")
**Objetivo:** detectar e aplicar o formato certo **sem input humano**, usando a **câmera de foco/keystone
do próprio PFL7560** para "ver" a projeção e se auto-calibrar. **Motivação:** painéis LVDS não têm
EDID — não dá pra "perguntar" ao painel; mas o projetor pode **olhar a própria imagem**.
**Escopo (pesquisa + protótipo):**
- Confirmar acesso à câmera interna (o firmware usa para auto-keystone; props `persist.newlink.autofocus*`,
  `vendor.newlink.camera*`). Ver se há API/HAL de captura acessível por adb/programa.
- Loop: projetar um alvo de cor conhecido (ex.: patch cinza 50% + barras) → capturar com a câmera →
  medir se o cinza saiu neutro (R≈G≈B) → se não, `lvdsctl` cicla o próximo formato → repetir.
- Critério de acerto: menor desvio de croma no patch cinza. Persistir o vencedor.
**Proof-of-work:** com um painel de formato desconhecido, o sistema converge sozinho para o formato
correto e persiste, sem o usuário olhar a tela. **Risco:** acesso à câmera pode ser restrito; a ótica
tem dominante de cor própria (calibrar baseline). **Esforço:** alto (é P&D). É o diferencial do projeto.

### LCD-S4 — Integração no `.bin` final
**Objetivo:** correção nativa desde o bootloader no firmware distribuível, sem passo pós-boot.
**Escopo:**
- No build do `.bin`: editar o byte **`0x5c` do perfil ativo** dentro da partição `panelparam` (ou do
  `panel.img` fonte) para o formato do painel-alvo. Alternativa: embutir `lvdsctl` + serviço de init.
- Casar com os cuidados de metadados que já quebraram o `.bin` antes (modo 0644 + xattr SELinux —
  ver README §"por que o `.bin` experimental não funcionou").
**Proof-of-work:** flashar o `.bin`, painel inicia no formato correto desde o logo. **Risco:** o `.bin`
completo está em quarentena; testar com resgate de fábrica ao lado. **Esforço:** médio.

### LCD-S5 — Guia leigo de troca de painel (replicação passo a passo)
**Objetivo:** documento de usuário final: como comprar, trocar e corrigir a cor do painel, com fotos.
**Escopo:** identificar o painel novo (part number no flat), passo a passo físico (referência ao
teardown doc 27), aplicar a correção (LCD-S1/S2), troubleshooting (tela preta → reverter; cor errada →
wizard), e quando NÃO tem conserto por software (timing/resolução física incompatível → outro painel).
**Proof-of-work:** um terceiro consegue replicar só com o guia. **Esforço:** baixo.

### LCD-S6 — Matriz viva de painéis compatíveis
**Objetivo:** catálogo mantido de painéis testados: part number, tamanho, resolução física real,
formato LVDS correto, driver IC, onde comprar (BR/AliExpress), e "grau de plug-and-play".
**Escopo:** tabela versionada; começar com `RX058B-4300` (VESA, fábrica) e `RX058B-0600` (JEIDA,
testado OK); adicionar os demais RX058B e resultados da pesquisa de resolução física. Incluir
recomendação de "melhor custo/benefício" e alertas (fake 1080p, timing incompatível).
**Proof-of-work:** ao trocar por um painel da lista, o usuário sabe de antemão o formato a aplicar.
**Esforço:** contínuo.

### LCD-S7 — Auditoria da nomenclatura dos perfis (o mistério do "SC5010E")
**Objetivo:** decifrar a convenção de nome dos 83 perfis e mapear os "driver ICs" citados vs os chips
REAIS. **Motivação (achado dos agentes):** o perfil `RX058B_4300_5010E_1080P_M` embute "5010E" como se
fosse o timing controller — mas o único **SC5010E** documentado é um **driver de backlight LED da
Semtech** (gestão de energia, 8 canais), não um T-CON nem source/gate driver. Ou seja, a Newlink/Zhiying
rotula os perfis com códigos de conveniência que **podem não corresponder ao chip de imagem** — o que
engana quem tenta casar painel por "driver IC" do nome.
**Escopo:**
- Decodificar cada campo do nome: `RX058B` (código de FPC/tamanho = 5.8") · `4300`/`0600`/`1800`
  (revisão/variante elétrica) · `5010E`/`ST5892B`/`JD9168`/`HX8283A` (campo "IC" — a auditar) · `1080P`
  (resolução) · `M`/`F`/`FM`/`PNS`/`ALLS` (flip/mirror e variantes de linha).
- Cruzar cada código de IC citado nos 83 perfis com datasheets reais e classificar: **T-CON / source+gate
  driver / backlight driver / código interno**. Referência já achada: o vidro-classe Tianma TM058JFHG01
  usa Himax **HX8286** (source) + **HX8695** (gate), sem framebuffer.
- Extrair do struct de 768 bytes os campos elétricos por perfil (`current`, `com_voltage`, `spread`,
  `bit_width`, `link_info`) e ver se agrupam por "família de IC" real — isso dá afinidade de compatibilidade
  melhor do que o nome.
**Proof-of-work:** tabela decodificada da nomenclatura + classificação dos ICs de (ao menos) todos os
perfis RX058B, com fonte por chip. **Risco:** ICs "house-numbered" sem datasheet → pode ficar parcial.
**Esforço:** médio (pesquisa + análise binária do struct). **Valor:** precisão da matriz S6 e entendimento
de por que perfis "irmãos" (mesmo IC citado) às vezes não são intercambiáveis.

---

## 4. Riscos e dependências transversais

- **Root/adb** já disponível (Wi-Fi, `service.adb.root=1`); SELinux **Permissive**.
- **Tela preta** em formatos/timings incompatíveis: sempre com reversão automática (`fmt 0`) + backup
  do `panelparam`. Nunca sobrescrever o perfil 69 sem backup.
- **Câmera (S3):** acesso e calibração de baseline são incertos — tratar como P&D.
- **`.bin` (S4):** herdar os cuidados de metadados/SELinux já documentados.
- **Resolução física (S6):** **resolvido** — o RX058B-0600 é **1920×1080 físico real** (confiança alta;
  4 frentes convergentes: teste de linha 1px no TD96, aspect ratios distintos na família, LVDS dual-link
  60-pin, painel sem scaler). A nitidez limitada é da **óptica** (lente), não do painel. Prova absoluta
  só por foto macro do vidro. Identidade: = 058-0600-V2 = PJ58S1V1 = PengJi PJ058S1.

## 5. Ordem sugerida

1. **LCD-S1** (aplicador) e **LCD-S5** (guia) — valor imediato, esforço baixo.
2. **LCD-S6** (matriz) + **LCD-S7** (auditoria de nomenclatura/ICs) — em paralelo, alimentam-se mutuamente.
3. **LCD-S2** (wizard) — cobre painéis não-JEIDA.
4. **LCD-S4** (`.bin`) — quando houver um alvo de firmware estável.
5. **LCD-S3** (câmera) — P&D de maior fôlego; o "auto-pareamento" que diferencia o projeto.
