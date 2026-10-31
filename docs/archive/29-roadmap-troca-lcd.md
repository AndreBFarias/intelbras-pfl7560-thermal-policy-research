# 29 - Roadmap e sprints: troca de painel LCD, correção de cor e pareamento automático

Planejamento (não-executado) para transformar a descoberta pontual da sessão de 2026-07-10 —
**correção de cor após troca de micro-painel LCD** — em recurso replicável do projeto. Consolida
engenharia reversa, decompilação e a pesquisa, e define sprints com proof-of-work.

Base técnica já resolvida e documentada em
[`28-troca-painel-rx058b-diagnostico-cor.md`](../research/28-troca-painel-rx058b-diagnostico-cor.md).

> **ESTADO DAS SPRINTS (2026-10-30)** — o status de cada sprint abaixo é este; as notas datadas dentro de
> cada uma explicam:
>
> | ID | Status |
> |---|---|
> | LCD-S1 | **IMPLEMENTADO** (`a9d3fa2`, 2026-07-12; backup obrigatório antes de qualquer gravação no bloco 1, `c7a0bbb`). Falta só a prova (c): o fluxo completo do script rodado no aparelho |
> | LCD-S2 | **IMPLEMENTADO** (wizard v2, `a9d3fa2`). Falta a prova no aparelho forçando tela preta |
> | LCD-S3 | **SUBSTITUÍDA** pelo [bloco 5](../sprints/2026-10-29-bloco-5-kit-universal.md) ([doc 41](../research/41-auto-pareamento-camera-e-kit-universal.md)): a câmera interna lê a escada de 16 cinzas (blocos 7 e 8, provada no aparelho; o critério "duas metades" foi abandonado) e a suíte de boot a repete a cada volta da tomada ([doc 44](../research/44-suite-de-boot.md)) |
> | LCD-S4 | **DECIDIDA** (cor fora do `.bin` universal). A premissa da Task 1 caiu: a `panelparam` **provavelmente está** no container (record 4; [doc 41](../research/41-auto-pareamento-camera-e-kit-universal.md) §3, [doc 42](../research/42-firmware-2026-10-modelo-sem-usbc.md) §5); confirmação pendente no aparelho (bloco 5, E1) |
> | LCD-S5 | **ENTREGUE** (guia 32, reescrito em 2026-10-30 para o kit de pendrive e o diagnóstico por barras puras) |
> | LCD-S6 | **ENTREGUE** (doc 33; em 2026-10-30 ganhou o painel da 2ª troca e os perfis 83-86 do firmware de outubro) |
> | LCD-S7 | **ENTREGUE** (doc 33 §3) |
>
> **Fato novo de 2026-10-29** ([doc 40](../research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §1): na 2ª
> troca o painel instalado é um `FPX-RX058B-4300-V0` `20241101 HT` e pediu **VESA** (`0x5c` = 0). Na 3ª
> troca (2026-10-30) o painel pediu **JEIDA**; o aparelho está hoje em JEIDA ([doc 41](../research/41-auto-pareamento-camera-e-kit-universal.md) §8). O JEIDA citado abaixo vale para o `-0600` da 1ª troca. O formato não se deduz do
> nome: decide o teste de cinza.

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

### 1.3 Achados da pesquisa
- **VESA↔JEIDA** é a única diferença que corrige "primárias OK, meios-tons embaralhados" mantendo o
  timing (prova matemática das tabelas do kernel; confirmado empiricamente).
- Registradores do VDP (`LVDS_CTRL/SWAP0`) existem mas a base é do SDK STB, não do HiDPT v350 →
  via registrador travou; via API (decompilação) venceu.
- Painéis RX058B são variantes elétricas do mesmo 5.8"/60-pin; o sufixo NÃO garante o formato — deve
  ser verificado (confirmado em 2026-10-29: o `-4300` da 2ª troca pediu VESA, doc 40 §1). Não há datasheet público do `-0600` (resolução física a confirmar; pesquisa em curso).
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
> **Atualização (2026-10-30):** (a) e (b) foram feitos no commit `a9d3fa2` (2026-07-12), e o bloco 1
> (2026-10-29) tornou o backup obrigatório antes de **qualquer** gravação (`jeida`/`vesa`/`swap`/`bit`, menu
> e `install.bat`). Status: **IMPLEMENTADO**; falta só (c), a prova no aparelho. O texto abaixo é de 2026-07-12.
>
> **Status (revisado 2026-07-12): núcleo IMPLEMENTADO; faltam 3 itens concretos.** Existe
> `pfl7560-lcd-color.sh` (raiz) + `lvdsctl` pré-compilado (ARM) + fonte `.c` + 5 padrões de teste em
> `artifacts/lcd-color-fix/`, com os 9 subcomandos `status/jeida/vesa/swap/bit/test/wizard/backup/restore`
> (verificado no código; só `status` foi exercitado no aparelho). **Falta, em ordem de prioridade:**
> **(a)** endurecer `backup`/`restore` (hoje sem md5/tamanho/read-back — ver Escopo); **(b)** integrar ao
> `pfl7560-menu.sh` e ao `install.bat`; **(c)** rodar o fluxo completo (`jeida`/`vesa`/`wizard`) no
> aparelho e registrar a prova (até aqui, a correção real foi aplicada com `nl_lvdsctl` direto, doc 28
> seção 13).
**Escopo:**
- Versionar o binário `lvdsctl` (ARM) + a fonte (já em `artifacts/lcd-color-fix/`). Ver a decisão de
  versionamento do binário na sprint REPO-S2 (doc 30): manter o ELF exige md5 fixado + versão do NDK e
  flags documentadas no README de `artifacts/lcd-color-fix/`; caso contrário, versionar só o `.c`.
- Script `pfl7560-lcd-color.sh` com: `status`, `jeida`, `vesa`, `test`, `backup`/`restore` do `panelparam`.
- **Endurecer `backup`/`restore` (bloqueante — a partição é lida no início do boot):**
  - `backup`: após o `dd`, **validar o tamanho** (8388608 bytes = 8 MiB) e **gravar o md5** ao lado do
    `.img`; abortar se o `dd` não trouxe a partição inteira (hoje o `stderr` do `dd` é suprimido e um
    backup truncado passa silencioso).
  - `restore`: **exigir tamanho correto antes de gravar**, **checar o exit code do `dd`** (hoje mascarado
    por `dd; sync`) e fazer **read-back com comparação de md5** após gravar. Documentar que um `restore`
    interrompido (queda de adb/energia) deixa o `panelparam` parcialmente escrito e exige nova gravação
    imediata — a rede anti-brick do firmware (doc 28 §4) só foi validada para perfil inválido, não para
    partição arbitrariamente corrompida.
- Empurrar `lvdsctl` para `/data/local/tmp` e rodar com `LD_LIBRARY_PATH=/vendor/lib:/system/lib`.
- Integrar como opção no `pfl7560-menu.sh` e no `install.bat` (o subcomando `map`, que o binário suporta
  mas o script não expõe, fica documentado como "avançado" ou é adicionado ao dispatch).
**Proof-of-work (mensurável):**
1. Correção: `PFL_IP=<ip> ./pfl7560-lcd-color.sh jeida` → `status` mostra `lvds_fmt: jeida`; `vesa`
   reverte para `lvds_fmt: vesa`; **sobrevive a reboot** (rechecar `status` após `adb reboot`).
2. Backup íntegro: `./pfl7560-lcd-color.sh backup pp.img` → `pp.img` tem **8388608 bytes** e um `pp.img.md5`
   é escrito; `restore` do mesmo arquivo passa no read-back (md5 pós-gravação == md5 do backup).
3. Integração: a opção "correção de cor pós-troca de painel" aparece no `pfl7560-menu.sh` e no menu do
   `install.bat`, e executa `pfl7560-lcd-color.sh status` com saída real.
**"Validar em outro aparelho" é NÃO-BLOQUEANTE** (depende de um segundo PFL7560 com painel trocado, que
pode não existir no curto prazo) — registrar como desejável, não como gate. **Esforço:** baixo.

### LCD-S2 — Wizard de pareamento (semi-automático, guiado)
**Objetivo:** assistente que leva o usuário do "cores erradas" ao "certo" em <2 min, sem entender de
LVDS. **Motivação:** nem todo painel será JEIDA; precisa de um fluxo à prova de leigo.
> **Atualização (2026-10-30):** o wizard v2 (backup automático, watchdog de tela preta, eixos avançados
> sobre o formato em uso) entrou no commit `a9d3fa2`. Status: **IMPLEMENTADO**; falta a prova no aparelho.
> O "estado atual" abaixo é de antes desse commit.

**Estado atual (2026-07-12):**
o `wizard` existente é uma v0 "single-shot" (projeta gamma, aplica JEIDA, pergunta 1× s/N) — falta o
loop de eixos e, criticamente, o backup automático e o watchdog de tela preta.
**Escopo (v2):**
- **Backup automático OBRIGATÓRIO antes da primeira mutação:** o wizard **deve** fazer `backup` do
  `panelparam` (com o endurecimento da LCD-S1: 8 MiB + md5) antes de tocar em qualquer byte. Sem backup
  válido, o wizard **aborta**. Motivo: cada passo do wizard **persiste imediatamente** no `panelparam`
  (ver nota abaixo), então uma tela preta + queda de energia deixaria o aparelho bootando cego.
- Projeta o padrão de gamma (patches de cinza) e cicla os eixos via `lvdsctl` **ao vivo (sem reboot)**:
  VESA↔JEIDA → bit 6/8 → swap 0..5, reprojetando a cada passo; para no primeiro cinza neutro.
- **Watchdog de tela preta:** o `read` de "está neutro? (s/N)" **não pode bloquear indefinidamente** —
  com tela preta o usuário não vê o prompt. Usar `read -t <N>` (timeout): sem resposta em N segundos,
  **assumir tela preta e reverter automaticamente** (`lvds fmt 0` e, se preciso, `restore` do backup),
  então seguir para o próximo eixo. Nunca deixar o aparelho num formato sem imagem esperando input.
- Ao acertar, registra o resultado (painel → formato) num arquivo de matriz versionável (alimenta a
  LCD-S6).
- **CORREÇÃO da spec original:** remover a etapa "oferecer tornar permanente" — **toda mutação do
  `lvdsctl` já persiste** no `panelparam` (doc 28 §13). Não existe modo transitório; a "permanência" é
  automática. O que o wizard oferece no fim é **confirmar/manter** ou **reverter para o backup**.
**Proof-of-work:** partindo de um painel com formato errado, o wizard faz backup, chega ao formato
correto respondendo só s/N, e — se o usuário deixar sem responder num formato de tela preta — reverte
sozinho dentro do timeout (comprovar forçando um `swap` que dê tela preta e não responder). **Esforço:** médio.

### LCD-S3 — Auto-pareamento via câmera interna (a "forma inteligente")
> **SUBSTITUÍDA (2026-10-29)** pelo [bloco 5](../sprints/2026-10-29-bloco-5-kit-universal.md), com a
> pesquisa no [doc 41](../research/41-auto-pareamento-camera-e-kit-universal.md): a câmera é UVC e se lê por V4L2
> (§1). O critério "duas metades" (§4) foi trocado pela escada de 16 cinzas no bloco 7, e a câmera decide sem
> tecla desde o bloco 8 (provado no aparelho); as duas teclas ficaram só como reserva quando a câmera não
> ajuda. A suíte de boot repete a verificação a cada volta da tomada ([doc 44](../research/44-suite-de-boot.md)).
**Objetivo:** detectar e aplicar o formato certo **sem input humano**, usando a **câmera de foco/keystone
do próprio PFL7560** para "ver" a projeção e se auto-calibrar. **Motivação:** painéis LVDS não têm
EDID — não dá pra "perguntar" ao painel; mas o projetor pode **olhar a própria imagem**.
**Escopo (pesquisa + protótipo):**
- Confirmar acesso à câmera interna (o firmware usa para auto-keystone; props `persist.newlink.autofocus*`,
  `vendor.newlink.camera*`). Ver se há API/HAL de captura acessível por adb/programa.
- **Pré-requisito de pesquisa (primeiro passo barato, hoje sem base nenhuma):** confirmar acesso à
  câmera. Rodar no aparelho e registrar num doc novo:
  ```bash
  adb -s <ip> shell 'getprop | grep -iE "autofocus|camera"'
  adb -s <ip> shell 'ls -l /dev/video* 2>/dev/null; ls -l /vendor/lib/hw/ | grep -i camera'
  ```
  Sem isso, o protótipo não tem por onde começar (o doc 28 não menciona câmera; o único registro são as
  props `persist.newlink.autofocus*` e `vendor.newlink.camera*`).
- Loop: projetar um alvo de cor conhecido (ex.: patch cinza 50% + barras) → capturar com a câmera →
  medir se o cinza saiu neutro → se não, `lvdsctl` cicla o próximo formato → repetir.
- **Critério de acerto DIFERENCIAL (não absoluto):** o auto white balance / auto-exposição da câmera
  interna pode neutralizar um cinza que está errado no painel (falso positivo de "R≈G≈B"). Em vez do
  critério absoluto, **comparar os formatos entre si na mesma sessão** (travar WB/exposição se a HAL
  permitir) e escolher o de **menor desvio de croma relativo** entre os candidatos, com um **limiar
  numérico** a definir no protótipo. Persistir o vencedor (com backup automático antes, como na LCD-S2).
**Proof-of-work:** com um painel de formato desconhecido, o sistema converge sozinho para o formato
correto e persiste, sem o usuário olhar a tela. **Risco:** acesso à câmera pode ser restrito; a ótica
tem dominante de cor própria (por isso o critério é diferencial, não absoluto). **Esforço:** alto (é P&D).
É o diferencial do projeto.

### LCD-S4 — Integração no `.bin` final
**Objetivo:** avaliar se a correção de cor pode nascer no firmware, sem passo pós-boot.

> **DECISÃO DE ESCOPO (tomada 2026-07-12 — leia antes de qualquer task):** o byte `0x5c=JEIDA` **NÃO
> entra no `.bin` térmico universal.** Dois motivos duros:
> 1. **Quebraria a maioria dos aparelhos.** O `.bin` térmico serve **todo** PFL7560; o `0x5c=JEIDA` só
>    vale para quem **trocou** o painel para um `-0600`. Um `.bin` universal com JEIDA embutido deixaria
>    a cor **errada** em todo aparelho com painel de fábrica (`-4300`, que espera VESA). São públicos
>    disjuntos.
> 2. **A partição provavelmente nem está no container.** A tabela de partições do `.bin` mapeada até hoje
>    (doc 15) só tem a `vendor` (record 14); a inspeção do cabeçalho sugere que `panelparam` (eMMC
>    `mmcblk0p6`, 8 MB) **não** é um record do container — é calibração por-aparelho, não flashada pelo
>    firmware. Enquanto isso não for provado, "editar 0x5c no `.bin`" repousa em premissa falsa.
>
> **Conclusão:** a correção de cor **continua pós-boot** (`pfl7560-lcd-color.sh`). Esta sprint vira uma
> **investigação com decisão registrada**, não uma feature do `.bin` universal.

> **CORREÇÃO (2026-10-29/30)** — a resposta da Task 1 abaixo está **provavelmente errada**. O record 4 do
> container (63.876 bytes em `0x144180c`) contém `panelheader/paneldatabody` e o nome
> `RX058B_4300_5010E_1080P_M`, igual à `panelparam` do aparelho
> ([doc 41](../research/41-auto-pareamento-camera-e-kit-universal.md) §3); no firmware de outubro esse record cresceu
> com os 4 perfis novos e o perfil 69 traz `0x5c` = 0 (VESA)
> ([doc 42](../research/42-firmware-2026-10-modelo-sem-usbc.md) §2.2 e §5). O "nenhum payload tem ~8 MB" comparou com
> o tamanho do slot, não com o dado (~64 KB). Consequência: **regravar o `.bin` pode devolver o byte `0x5c`
> ao de fábrica (VESA)** — inócuo para painel VESA, quebra a cor de painel JEIDA. A decisão de escopo
> (JEIDA fora do `.bin` universal) continua valendo, agora por mais um motivo. Confirmação no aparelho:
> bloco 5, E1(b), e bloco 4.

**Task 1 (RESOLVIDA — 2026-07-12, análise offline do container):** a tabela de partições do `.bin` foi
decodificada por inteiro (19 records de 32 bytes @ `0x40..0x2a0`). **Resposta definitiva: NÃO existe
record de `panelparam` no container.** Os 19 records são só imagens de firmware
(bootloader×2, código ARM, boot, headers, reservado, recovery, DTB/SDK×2, sparse, misc, versão, super,
vendor, atv, cache, securestore, userdata); nenhum payload tem ~8 MB (`0x800000`) compatível com o
`panelparam`. Os nomes `panelparam` (8M), `tconparam` (80M) e `demura` (4M) aparecem **somente** dentro da
string `blkdevparts=` do cmdline embutida no bootloader — são **slots da eMMC** (`mmcblk0`), não payloads
empacotados neste container de update. (Evidência: `blkdevparts` extraído do próprio firmware confirma as
25 partições da eMMC; o dado real de painel é ~512K dentro do slot de 8M, e não está no `.bin`.)

Verificação no aparelho (opcional, confirma o mesmo mapa):
```bash
adb -s <ip> shell 'cat /proc/cmdline | tr " " "\n" | grep -iE "blkdevparts|panelparam|mmcblk"'
```

**Conclusão registrada:** encerra-se a via "patch de record no `.bin`". A correção de cor **é pós-boot,
ponto final** (`pfl7560-lcd-color.sh`, gravando o slot `panelparam` direto no device). Se algum dia se
quiser correção nativa por firmware, seria preciso um empacotador que grave o **slot da eMMC**
`panelparam` (fora deste container), o que não vale o risco frente ao método `/vendor`/device já pronto.

> Observação lateral (não afeta a decisão): o `firmware/PFL7560-FIX-com-metadados.bin` atual tem CRC de
> vendor `0x621e9cb6` — um terceiro valor, distinto do stock (`0xdd5cdc49`) e do FIX antigo em quarentena
> (`0x35ca9b46`, doc 15). Confirma que é o rebuild novo (com metadados/SELinux), não o protótipo apagado.

**Task 2 (consequência para o resgate — corrigir doc 16 e o guia LCD-S5):** como o `panelparam` **não**
é regravado pelo `.bin`/resgate, a correção de cor **sobrevive** a um resgate power-hold (bom).
> **CORREÇÃO (2026-10-30):** com a Task 1 derrubada, o mais provável é o contrário: o resgate **regrava** a
> `panelparam` e volta o formato ao de fábrica. O guia 16 e o guia 32 já mandam refazer o teste de cor
> depois de um reflash.

**Mas confirmar:** se algum dia se descobrir que o resgate toca o `panelparam`, adicionar ao doc 16 e ao guia
leigo (LCD-S5): "após resgate, se as cores voltarem erradas, rode `pfl7560-lcd-color.sh jeida`".
(**Superado (2026-10-30):** o formato não se deduz do painel; os guias 16 e 32 mandam refazer o teste de
cor, não aplicar `jeida` às cegas.)

**Proof-of-work:** a resposta documentada da Task 1 (record de `panelparam` existe? sim/não, com
evidência do header + cmdline). **Esforço:** médio (é análise binária + decisão, não build).

### LCD-S5 — Guia leigo de troca de painel (replicação passo a passo)
> **Status (2026-07-12): ENTREGUE** — [`../guide/32-guia-troca-painel-lcd.md`](../guide/32-guia-troca-painel-lcd.md)
> (identificar, trocar, corrigir a cor, troubleshooting, quando não tem conserto por software).
**Objetivo:** documento de usuário final: como comprar, trocar e corrigir a cor do painel, com fotos.
**Escopo:** identificar o painel novo (part number no flat), passo a passo físico (referência ao
teardown doc 27), aplicar a correção (LCD-S1/S2), troubleshooting (tela preta → reverter; cor errada →
wizard), e quando NÃO tem conserto por software (timing/resolução física incompatível → outro painel).
**Proof-of-work:** um terceiro consegue replicar só com o guia. **Esforço:** baixo.

### LCD-S6 — Matriz viva de painéis compatíveis
> **Status (2026-07-12): ENTREGUE (v1)** — [`33-matriz-paineis.md`](../research/33-matriz-paineis.md) §1, com
> `RX058B-4300` (VESA) e `RX058B-0600` (JEIDA, testado OK). É catálogo vivo: adicionar novos painéis conforme testados.
> Em 2026-10-30 ganhou a linha do painel da 2ª troca (`-4300`, VESA) e os perfis 83-86 do firmware de outubro.
**Objetivo:** catálogo mantido de painéis testados: part number, tamanho, resolução física real,
formato LVDS correto, driver IC, onde comprar (BR/AliExpress), e "grau de plug-and-play".
**Escopo:** tabela versionada; começar com `RX058B-4300` (VESA, fábrica) e `RX058B-0600` (JEIDA,
testado OK); adicionar os demais RX058B e resultados da pesquisa de resolução física. Incluir
recomendação de "melhor custo/benefício" e alertas (fake 1080p, timing incompatível).
**Proof-of-work:** ao trocar por um painel da lista, o usuário sabe de antemão o formato a aplicar.
**Esforço:** contínuo.

### LCD-S7 — Auditoria da nomenclatura dos perfis (o mistério do "SC5010E")
> **Status (2026-07-12): ENTREGUE** — [`33-matriz-paineis.md`](../research/33-matriz-paineis.md) §3. Achado central:
> o campo IC do nome é o **driver on-glass** do painel, não T-CON nem backlight; o "SC5010E" é **falso-amigo**
> do backlight Semtech SC5010 (corrige a nota do doc 28). Chave de compatibilidade real = campos do struct,
> não o nome. Falta só (contínuo) extrair os campos elétricos por perfil dos 83 structs.
**Objetivo:** decifrar a convenção de nome dos 83 perfis e mapear os "driver ICs" citados vs os chips
REAIS. **Motivação (achado da pesquisa):** o perfil `RX058B_4300_5010E_1080P_M` embute "5010E" como se
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

1. **LCD-S1** (aplicador — endurecer backup/restore + integrar ao menu) e **LCD-S5** (guia) — valor
   imediato, esforço baixo. É o caminho principal e definitivo da correção de cor (pós-boot).
2. **LCD-S6** (matriz) + **LCD-S7** (auditoria de nomenclatura/ICs) — em paralelo, alimentam-se mutuamente.
3. **LCD-S2** (wizard v2 — backup automático + watchdog de tela preta) — cobre painéis não-JEIDA.
4. **LCD-S4** — reduzida a uma **investigação com decisão** (o JEIDA não vai para o `.bin` universal;
   ver a decisão de escopo na sprint). Fazer só a Task 1 (mapear a tabela do container) quando houver
   folga; não é bloqueante para nada.
5. **LCD-S3** (câmera) — P&D de maior fôlego; o "auto-pareamento" que diferencia o projeto. Começar pelo
   passo barato (confirmar acesso à câmera) antes de qualquer protótipo.

> **Nota transversal:** a correção de cor LCD é uma **trilha paralela** e **não** está no caminho crítico
> do `.bin` térmico final (sprint 18). O `.bin` universal leva só o fix térmico + o vigia (sprint 19); a
> cor é sempre pós-boot, por aparelho que teve o painel trocado.
