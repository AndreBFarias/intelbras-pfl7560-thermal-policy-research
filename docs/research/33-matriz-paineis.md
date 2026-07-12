# 33 - Matriz de painéis compatíveis + auditoria de nomenclatura (LCD-S6 / LCD-S7)

Catálogo vivo dos painéis do PFL7560 (sprint **LCD-S6**) e a decodificação da nomenclatura dos perfis com
classificação dos "driver ICs" (sprint **LCD-S7**). Base técnica:
[`28-troca-painel-rx058b-diagnostico-cor.md`](28-troca-painel-rx058b-diagnostico-cor.md). Guia de uso para
leigo: [`../guide/32-guia-troca-painel-lcd.md`](../guide/32-guia-troca-painel-lcd.md).

---

## 1. Matriz de painéis (LCD-S6)

O firmware traz **83 perfis** de painel (53×1080p, 16×720p, 6×600p, 1×800p). Os da família do PFL7560
(**RX058B**, 5.8", 1920×1080). O método seguro é **manter o perfil 69** (timing bom) e ajustar só o
**formato LVDS** ao painel novo — trocar de perfil inteiro (timing diferente) dá tela preta.

| Painel físico | Perfil/índice | Formato LVDS correto | Byte `0x5c` | Grau plug-and-play | Observação |
|---|---|---|---|---|---|
| `RX058B-4300` (fábrica) | 69 `RX058B_4300_5010E_1080P_M` | **VESA** | `0x00` | — (é o de fábrica) | 1920×1080, driver "SC5010E", 2-link 8-bit, clk 134.4 MHz |
| `RX058B-0600` (= `058-0600-V2` = PengJi PJ058S1) | 69 + JEIDA | **JEIDA** | `0x01` | **Alto** (drop-in mecânico; só muda 1 byte) | Peça do Thundeal TD96. **Testado OK.** 1920×1080 físico real |
| `RX058B-4500` | 72 `RX058B_4500_ST5892B_1080P_M` | ? | ? | Baixo | Timing próprio (deu **sem imagem** no teste; requer perfil casado, não só formato) |
| `RX058B-1800` | 10/30/49 (`ST5892B`) | ? | ? | Não testado | Variantes ST5892B |

**Regra de compatibilidade (ver seção 3):** a chave confiável **não** é o nome do painel — é o timing
(clk/HT/VT) casar com o perfil 69 e o **formato LVDS** (VESA/JEIDA) casar com o painel. Um painel de
timing diferente do 69 dá tela preta, independentemente do formato.

### Projetores irmãos que usam o `-0600` (fonte de peça)
Thundeal TD96, Vivibright F40 (Amlogic), AAO YG620, Rigal RD826 — plataformas mistas
(HiSilicon/Amlogic/MStar). O **firmware não é portável** entre eles; só o **modo LVDS** (VESA/JEIDA) é o
conceito comum.

---

## 2. Como identificar o painel

1. Código serigrafado no flat: `FPX-RX058B-<variante>-V?` (ex.: `-4300`, `-0600`).
2. O sufixo de 4 dígitos (`4300`/`0600`/…) é a **sub-variante elétrica/óptica** — é o que muda o formato
   LVDS. **Não** é a resolução.
3. Painéis LVDS **não têm EDID** — não dá para "perguntar" o formato ao painel; testa-se projetando um
   padrão de cinza (ver o `wizard` do `pfl7560-lcd-color.sh`).

---

## 3. Auditoria de nomenclatura dos perfis (LCD-S7)

Os 83 perfis têm nomes como `RX058B_4300_5010E_1080P_M`. Decodificação de cada campo:

| Campo | Significado | Cuidado |
|---|---|---|
| `RX058B` | Família/glass: `RX`=série do fabricante de painel de projetor; `058`=diagonal 5,8"; `B`=geração da família de vidro/FPC. | **Não fixa a resolução** (`RX058B-01` sai 1280×800; `RX058B-0600` é 1920×1080). |
| `4300`/`0600`/`1800`/`4500` | Sub-variante elétrica/óptica (driver, timing, **formato LVDS VESA/JEIDA**, flip). | **Não é resolução.** É onde perfis "irmãos" (mesmo `RX058B`, mesmo `1080P`) divergem. |
| `5010E`/`ST5892B`/`JD9168`/`HX8283A` | Código do **driver IC on-glass** do painel (source/integrado). | **Dica de chipset, não chave de compatibilidade** — house-numbered, sem datasheet público. |
| `1080P` | Resolução nativa 1920×1080. | Há também 720P/600P (bit_width 6BIT) e 800P na tabela. |
| `M`/`F`/`FM` | Orientação de varredura: `M`=Mirror (espelho H), `F`=Flip (inversão V), `FM`=180°. | Sufixo errado = imagem espelhada/de cabeça para baixo mesmo com o resto certo. |
| `PNS`/`ALLS` | Tags internas de linha/cliente do fornecedor (Newlink/Zhiying). | Sem documentação pública — código interno. |

### Classificação dos "driver ICs" citados

| IC no nome | O que é de fato | Fonte / nota |
|---|---|---|
| **`SC5010`/`SC5010E`** | **Driver de painel** (source/integrado) on-glass do vidro LTPS 1080p. **NÃO é T-CON discreto nem backlight.** | Painel Startek KD045FHFLD005 (4,5" 1920×1080) usa driver "SC5010" em versões HDMI e LVDS — mesma classe do RX058B. **Falso-amigo:** existe um Semtech **SC5010** que é driver de **backlight LED** (8 canais) — chip diferente, só o número colide. |
| **`ST5892B`** | Driver de painel single-chip (source+timing on-glass). NÃO backlight, NÃO T-CON discreto. | Aparece em módulos TFT como controller integrado (SYNC/DE). Prefixo estilo Sitronix (ST7xxx), mas não consta no catálogo público — provável house-number. Citado em `RX058B_4500`, `RX058B_1800_*` e no fallback `CAFH028_ST5892B` — **o mesmo IC em vidros/resoluções diferentes prova que o campo IC não garante intercâmbio.** |
| **`JD9168`** | Single-chip driver TFT (source+gate+TCON integrados), família Fitipower/Jadard `JD9xxx`. NÃO backlight. | Família `JD9xxx` = "a-Si TFT LCD Single Chip Driver" (JD9365D, JD9851/2/3, JD9165A). Driver monolítico — reforça que o "IC do nome" agrega funções; não há T-CON separado. |
| **`HX8283A`** | Source driver TFT Himax (família HX82xx, tipicamente com LVDS TCON integrado). NÃO backlight/gate. | Himax HX82xx são source drivers, vários com TCON embutido (HX8282-A = 1536CH source + LVDS TCON). |
| **`HX8286` + `HX8695`** | Par **source driver + gate driver** Himax on-glass (o glass-classe Tianma TM058JFHG01 usa exatamente isso). | Confirma a arquitetura "burra" do painel: SoC (LVDS-TX) → source (HX8286) + gate (HX8695), **sem scaler/framebuffer**. |

> **Correção ao doc 28:** a nota tentativa da seção final do doc 28 ("SC5010E provavelmente é um driver de
> backlight LED da Semtech, não o T-CON") deve ser lida com ressalva. No contexto do **nome do perfil**,
> `5010E` denota o **driver de imagem do vidro** LTPS 1080p; a coincidência com o Semtech SC5010 (backlight)
> é justamente o falso-amigo que engana quem casa painel "pelo driver IC do nome".

### Conclusão prática (por que o nome NÃO garante compatibilidade)

1. O campo IC é **falso-amigo/ambíguo** (`5010E` colide com o backlight Semtech; e mesmo denotando o
   driver de display, é house-numbered sem datasheet).
2. O nome **não codifica o formato LVDS** (VESA vs JEIDA) — exatamente o byte `0x5c` que quebrou a cor na
   troca `-4300`→`-0600` (mesmo glass, mesmo `1080P`, só muda VESA×JEIDA).
3. O nome **não codifica o timing** (clk/HT/VT): trocar para um perfil irmão de timing próprio (idx 72)
   deu **tela preta**.
4. O mesmo IC (`ST5892B`) aparece em vidros/resoluções diferentes → o campo IC é dica de chipset, não
   chave de intercâmbio.
5. Nem o prefixo `RX058B` fixa a resolução.
6. O sufixo `M/F/FM` muda a direção de varredura (mirror/flip) — sufixo errado = imagem invertida.

**Chave de compatibilidade confiável = os campos elétricos do struct de 768 bytes**, não o nome legível:
`bit_width` (`0x4c`), `lvds_fmt` (`0x5c`), link map (`0x60-0x6c`), `current`/`com_voltage`, e o timing
(`0xa0+`). É por isso que a estratégia segura é manter o perfil 69 (timing certo) e ajustar só o `0x5c`.
