# Tarefa - Logo MeowCast pixelado no começo do boot (2026-11-01)

**Medido.** O dono viu no boot de 2026-11-01 22:47: o logo MeowCast aparece pixelado, logo depois fica nítido e
então entra a home. A imagem que o `pfl7560-marca.sh` grava na partição `logo` (`artifacts/tema/marca/logo-boot.jpg`)
é limpa: 1920x1080, JPEG qualidade ~95, 4:4:4, bordas suavizadas (ampliada 4x em 2026-11-01, sem serrilhado).
A segunda fase, nítida, é o `bootanimation.zip` (a mesma arte, 1920x1080), já com o keystone por hardware.

**Causa (medida em 2026-11-01, adb root, só leitura).** O JPEG que está na partição `logo` NÃO é o que o
repositório gera hoje. Lido com `dd` (256 KB do começo da `logo`; `LOGO_KEY_LEN` = 44491 bytes, JPEG no byte 8192):

| | gravado no aparelho | `logo-boot.jpg` de hoje |
|---|---|---|
| tamanho | 44491 bytes | 95593 bytes |
| qualidade (tabela de quantização) | ~80 (`6,4,4,6`) | 95 (`2,1,1,2`) |
| croma | 4:2:0 | 4:4:4 |
| bordas do texto (ampliado) | serrilhadas | suavizadas |
| fundo fora do quadro | cinza 12,12,12 | preto |
| cantos da distorção | antigos | `CANTOS_DONO` |

Só o `pfl7560-marca.sh` grava a `logo` neste repositório, então o que está lá veio de uma versão antiga dele (antes
do BICUBIC, qualidade 95 e 4:4:4). A tese da tela virtual pequena caiu: o carregador reserva
`GRAPHIC_HIFB_HD=8100K` (`bootargs`), que é exatamente 1920x1080x4 bytes. E **não existe partição `baseparam`**
neste aparelho (partições: `blkdevparts` em `bootargs`).

**Também visto.** Os cantos usados para distorcer o logo (`CANTOS_DONO` no `gerar-marca.py` e o que foi gravado)
não batem mais com os cantos atuais do aparelho (`persist.sys.keystone.*`: lt 45,930, rt 1715,1015, lb 10,15,
rb 1755,20), porque o keystone automático está ligado e refaz o ajuste.

**Como provar a cura.** Depois de regravar: ler de novo os 256 KB da `logo`, o md5 do JPEG tem que bater com o
gerado; e o dono olha o boot.

**Cura.**
1. Regravar o logo com os cantos atuais pelo `pfl7560-marca.sh` (lê `persist.sys.keystone.*` do aparelho; precisa
   de root e da palavra do dono).
2. Só se ainda serrilhar depois disso: arte mais grossa (só PC).

**Feito em 2026-11-01.** Keystone zerado por decisão do dono (doc 46 §13) e logo regravado **reto** pelo
`pfl7560-marca.sh` (cantos `0,1080 1920,1080 0,0 1920,0`; JPEG 86135 bytes, qualidade 95, 4:4:4; relido e
conferido). Backups em `backups-projetor/logo/`. Falta o dono olhar o próximo boot. O ajuste automático virou
`2026-11-01-tarefa-logo-automatico.md`.
