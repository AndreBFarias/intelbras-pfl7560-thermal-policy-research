# 41 - Auto-pareamento do painel: câmera UVC, ausência de ID elétrico e o kit universal

Pesquisa de 2026-10-29 (offline: firmware oficial V1.0.0.9 extraído, binários, web), pedida pelo dono:
*"algo automático deve existir"*, com solução **idempotente, universal e fácil para leigo**, para cor e
térmica. Retoma a LCD-S3 do [doc 29](29-roadmap-troca-lcd.md) ("a forma inteligente").

**Convenção:** `CONFIRMADO` = lido no firmware ou no aparelho (caminho citado). `INFERIDO` = dedução sem
execução. Até 2026-10-29 nada aqui tinha sido executado no aparelho; a primeira rodada no aparelho está
no §8 (2026-10-30).

---

## 1. A câmera interna é USB UVC e dá para ler direto (`CONFIRMADO` no firmware e, desde 2026-10-30, no aparelho: §8)

| Fato | Fonte |
|---|---|
| Kernel `4.9.127_s5` com o driver UVC **embutido** ("USB Video Class driver (1.1.1)") e os controles V4L2 de exposição e balanço de branco manuais | imagem do kernel (record 3 do container) |
| HAL `camera.bigfish.so` = HAL V4L2 do AOSP: lê `/dev/video*` em MJPEG/YUYV, decodifica MJPEG no `hi_vdec` | `vendor/lib/hw/camera.bigfish.so` |
| `/dev/video*` criado pelo ueventd com `0660 system camera` | `vendor/ueventd.rc:19` |
| App de foco/keystone `com.zhiying.autofocus` (`/system/app/AutoFocus3`), API Camera1, analisa **só luma** (`getPicClarityJNI`) | APK desmontado |
| No aparelho: `vendor.newlink.camera_exist=1`, `vendor.focus.camera.is_focused=true`, `cameraserver` rodando, SELinux `permissive` | `artifacts/diagnostico/audit-logs/getprop.txt` |

**Caminho de captura:** um binário ARM pequeno, com root, falando V4L2 direto em `/dev/video0`, compilado
com o mesmo NDK do `lvdsctl` (o NDK **não está instalado** nesta máquina). **Atualização (2026-10-29):** o
NDK r27c foi instalado e o `nl_camcheck` (`artifacts/camcheck/`, só leitura: `info` e `grab`) foi
compilado no commit `e78e2e7`; ainda não rodou no aparelho (bloco 5, E1/E5). Pela API de câmera do Android
não dá para travar exposição e balanço de branco; direto no V4L2 talvez dê, conforme a câmera.

**Riscos:** câmera de baixa resolução, talvez só MJPEG ou monocromática; disputa com o `AutoFocusService`
pelo dispositivo; projeção fora do campo da câmera (parede longe ou escura).

## 2. Não existe ID elétrico do painel (`CONFIRMADO` no bootloader)

- `hi_drv_custom_get_panel_index` (bootloader, VA `0x14031a34`) só **lê um número gravado** na partição
  `deviceinfo`. Não lê GPIO nem ADC: se houvesse pino de ID, seria ali.
- VESA/JEIDA é escolha do transmissor do SoC (byte `0x5c`); o painel não tem EDID.
- Única pista elétrica: o perfil 69 manda 8 comandos I2C para um escravo `0x70` (8 bits) no boot.
  Ler um ID por ali é hipótese aberta e, mesmo que funcionasse, exigiria uma tabela ID→formato
  montada vidro a vidro. **Não é caminho universal.**

## 3. A `panelparam` está no container do `.bin` (`INFERIDO`, contradiz docs 29 e 31)

Um record de 63.876 bytes em `0x144180c` contém `panelheader/paneldatabody` e o nome
`RX058B_4300_5010E_1080P_M` no offset 53160 do payload, igual à `panelparam` do aparelho. Os docs 29
(LCD-S4) e 31 dizem que ela provavelmente **não** está. Consequência prática: **reflashar o `.bin` pode
levar o byte `0x5c` de volta ao de fábrica (VESA)**. Para o painel da 2ª troca (VESA) era inócuo; para quem
tem painel JEIDA, um reflash quebraria a cor, e desde a 3ª troca (2026-10-30, §8) **é o caso deste aparelho**. A confirmar (bloco 4 e bloco 5, E1).

## 4. O critério: a escada de cinzas (substituiu as "duas metades" no bloco 7)

> **Bloco 7 (2026-10-30, implementado em código, falta a prova no aparelho).** O critério das duas metades
> (texto original logo abaixo, mantido como histórico) **não é confiável**: no formato errado, a tela
> `metades-1` dividiu só a faixa 127|128, e num padrão de 7 pares (31|32 ... 223|224) **nenhuma** faixa
> dividiu. O que aparece sempre é que a **ordem de brilho** embaralha. O kit passou a projetar uma
> **escada de 16 faixas cinza**, níveis `10 + 15k` (k = 0..15), cada uma com 34 px de altura e passo de
> 50 px a partir de y = 140, separadas por preto. Em formato certo ela sobe em ordem; em formato errado a
> rotação de 2 bits a embaralha (simulação com curva monótona aleatória, nos dois sentidos: **no mínimo 3
> inversões** no errado, 0 no certo). A tela `calibracao` traz as mesmas faixas em branco (255) sobre
> preto (0), valores que VESA e JEIDA não alteram, e é por elas que a câmera acha as faixas sem depender do
> formato. Quadros reais (câmera interna, 640x480, painel da 3ª troca): JEIDA = `235 235 235 235 235 232
> 222 210 197 181 164 141 114 91 72 63` (monótona); VESA = `235 235 235 231 192 148 105 86 220 212 156 90
> 185 116 195 128` (fora de ordem). Fixtures em `tests/fixtures/camera/`; análise no `nl_camcheck`
> (`faixas` e `niveis`, [README](../../artifacts/camcheck/README.md)).

### Critério original (histórico): "duas metades"

VESA↔JEIDA é uma rotação de 2 bits, igual em R, G e B (tabelas do kernel Linux, ver
[doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §5). Um padrão com duas metades de cinza
**63 | 64** (e uma faixa **127 | 128**):

- formato certo: as metades ficam praticamente iguais (|L−R|/(L+R) ≈ **0,008**);
- formato errado: 63|64 vira **252|1** ou **207|16** (≈ **0,86 a 0,99**), nos dois sentidos.

A comparação é **dentro do mesmo quadro** e **entre os dois formatos**. Balanço de branco, exposição
automática, foco e sensor monocromático afetam o quadro inteiro, não a diferença entre as metades. Serve
ao olho e à câmera. Textos só em branco e preto puros, que não mudam entre os formatos.

> **CORREÇÃO (2026-10-30)** No aparelho, com o formato errado, a faixa **63 | 64 saiu uniforme** (ciano
> dos dois lados) e só a **127 | 128** se dividiu (verde | marrom). A conta acima vale para o valor que
> chega ao LVDS, mas o pipeline de imagem (gamma, DCI, balanço de branco) muda o valor antes: a fronteira
> 63/64 da imagem não cai necessariamente na fronteira de bit da saída. O critério continua funcionando
> (uma das faixas divide), mas **não é garantido com só duas faixas**. Detalhe e tarefa no §8.

## 5. O kit universal (desenho)

Kit único de pendrive, sem serial, sem arquivo para editar, mesmo pendrive para qualquer PFL7560:

1. **Térmica:** estado-alvo = md5 do `.ini` que o firmware lê (`252ab7a7…`). Só troca se o md5 atual for
   de fábrica ou de versão anterior nossa; md5 desconhecido = recusa. Troca atômica e um reboot.
   Avisa se houver `/atv/ini/ZYCustom*.ini` com precedência. **Como ficou (bloco 6, T6.1):** o kit
   reconhece o `.ini` de fábrica dos **dois** modelos (V1.0.0.9 `29d8ba36…` e V1.0.0.1 sem USB-C
   `ed3f314c…`, [doc 42](42-firmware-2026-10-modelo-sem-usbc.md)) e monta o corrigido a partir do `.ini` do
   aparelho, trocando só as seções térmicas; o alvo é `252ab7a7…` no modelo antigo e `bdf5c464…` no novo.
2. **Cor (bloco 7, em código; falta a prova no aparelho):** **modo automático**, ligado por padrão. O
   `cor.sh` projeta a `calibracao`, o `nl_camcheck faixas` acha as 16 faixas, projeta a `escada-1` e o
   `nl_camcheck niveis` mede a ordem de brilho. Em ordem (0 inversões) → formato certo, **nada escrito**
   (é o caminho idempotente). Fora de ordem (>= 2 inversões em ambos os sentidos) → backup, journal e
   gancho, troca ao vivo, confere o byte, mede de novo; em ordem → mostra "COR CORRIGIDA
   AUTOMATICAMENTE" e **qualquer tecla em 30 s desfaz**; sem tecla confere a partição inteira (só o byte
   `0x5c` pode diferir) e mantém. Se a troca não deixou em ordem → reverte e cai no fluxo manual. Dúvida
   (1 inversão, amplitude da escada < 40 de luma, 15 faixas na calibração, câmera ocupada ou sem
   `/dev/video0`, `nl_camcheck` adulterado) → fluxo **manual**, sem escrever. **Fluxo manual:** a mesma
   `escada-1`; em ordem, nada a fazer (30 s e segue); fora de ordem, a pessoa aperta **qualquer tecla**, o
   kit troca o formato ao vivo e mostra a `escada-2`; só mantém com uma **segunda** tecla; sem ela,
   reverte e confere relendo o byte. Cada medição fica no log com os 16 valores e as inversões. Antes de
   cada tela o `cor.sh` faz `am force-stop` do pacote que resolve o VIEW de PNG (a galeria não trocava de
   imagem, §8). O `nl_camcheck` só lê a câmera (sem `S_CTRL`) e tem o md5 conferido antes de cada
   execução, como o `lvdsctl`.
3. **Segurança:** backup conferido com `cmp` e journal em `/data` antes de qualquer troca; no boot
   seguinte, journal pendente = restaura o formato original; md5 de cada arquivo do kit conferido antes
   de qualquer escrita; o kit nunca chama `hidebug`/`gtt` (doc 37).

**Por que é idempotente:** a decisão depende só do que se vê na tela, e só grava quando o formato
escolhido difere do byte atual. Segunda execução: escada em ordem, nada escrito, nada reiniciado.

**Por que é universal:** vale para qualquer painel LVDS 8 bit em que VESA/JEIDA seja a diferença. No
painel de fábrica a escada sai em ordem; no modo manual errar exige duas teclas, a segunda diante de
imagem errada, e no automático uma tecla em 30 s desfaz.

## 6. O que continua impossível

- Saber o formato **sem olhar a imagem** (sem EDID, sem pino de ID).
- **Automação sem tecla:** implementada no bloco 7 (§5), mas ainda **sem prova no aparelho**: o
  coordenador roda o `cor.sh` real via adb a partir de JEIDA e de VESA e confere com `cmp -l` e com a câmera.
- Garantir que o autorun rode no 1º boot (o `nl_usb_update.sh` de fábrica só olha o pendrive em
  `sys.boot_completed=1`; se a montagem atrasar, perde a vez; a instrução é religar).
- Garantir, sem a bancada, que as telas aparecem: o kit as mostra por `am start ... VIEW`, que deu tela
  preta em 2026-09-03 (OPT-S13, [doc 39](39-sessao-2026-09-02-optica-e-balanco-termico.md) §4.3). A
  etapa E1(e) do bloco 5 decide. **Atualização (2026-10-30):** a primeira tela abre (PNG em `/sdcard`), mas
  a segunda não substitui a primeira sem `am force-stop` da galeria (§8).
- Painéis que precisem de `swap`/`bit`/`map`: ficam no wizard com PC, de propósito.
- Térmica em firmware diferente de V1.0.0.9 e V1.0.0.1 (md5 de fábrica desconhecido: o kit recusa). O
  V1.0.0.1, do modelo sem USB-C, passou a ser reconhecido no bloco 6.

## 7. Plano

Etapas E1 a E6 na tarefa do
[bloco 5](../sprints/2026-10-29-bloco-5-kit-universal.md).

## 8. Primeira rodada no aparelho (2026-10-30, terceira troca de LCD)

O dono trocou o LCD de novo. O aparelho bootou em VESA (byte `0x5c` = 0, o da 2ª troca) e as cores
"voltaram ao defeito anterior". Térmica intacta (`ZYCustom.ini` `252ab7a7`).

| Item (bloco 5, E1) | Resultado | Estado |
|---|---|---|
| (a) `/proc/msp/panel` | `lvds_fmt vesa`, `cut_idx 69`, `RX058B_4300_5010E_1080P_M` | `CONFIRMADO` |
| (b) a API grava só o byte `0x5c` | `cmp -l` antes/depois de `lvdsctl fmt 1`: **uma** linha, `53253 0 1`. A imagem em JEIDA tem md5 `4899eefc…`, **idêntico** ao backup JEIDA de 2026-10-29 | `CONFIRMADO` |
| (e) `am start ... VIEW` de `/sdcard` | a **1ª** tela abre; a **2ª** não substitui a 1ª ("intent has been delivered to currently running top-most instance": a galeria `com.hisilicon.higallery` continua na imagem antiga). Com `am force-stop com.hisilicon.higallery` antes, troca | `CONFIRMADO`, defeito do kit |
| (f) câmera | `/dev/video0` `0660 system:camera`, driver `uvcvideo`, "Integrated Camera", MJPG e YUYV em 1280x720/640x480/640x360. `nl_camcheck grab` funcionou como root. O quadro sai **espelhado de cima para baixo** (bloco 8; antes anotado como "girado 180°") e **sem cor** (só luma) | `CONFIRMADO` |

**Decisão do formato, pela câmera e pelo olho.** Luma média das metades no quadro da câmera,
|L−R|/(L+R):

| Formato | Faixa 63 \| 64 | Faixa 127 \| 128 | Olho (foto do dono) |
|---|---|---|---|
| VESA | 0,055 | **0,281** | 63\|64 ciano uniforme; 127\|128 verde \| marrom |
| JEIDA | 0,013 | 0,034 | as duas faixas cinza neutro e iguais; barras de cor certas |

Painel desta troca = **JEIDA**, gravado por `lvdsctl fmt 1` (persiste). `saude.sh`: 11 OK, 0 aviso,
0 falha. Backup antes da mudança: `private/panelparam-2026-10-30-antes-jeida-placa3.img` (md5
`92c63448579190a19aab5138856baf23`, ainda VESA). Quadros da câmera em `evidencias/2026-10-30/camera/`
(ignorado pelo Git).

**O que isto ensina:**
1. A câmera **separa** os formatos (razão 8 na faixa 127\|128), mas não com a margem que o portão da E5
   pedia (errado > 0,4): a câmera tem exposição automática e o quadro inclui a parede. Recalibrar o portão
   pela razão, não pelo valor absoluto.
2. A faixa 63\|64 **não dividiu** no formato errado (§4, correção): o pipeline de imagem muda o valor
   antes do LVDS. O padrão precisa de **vários pares** em níveis diferentes, para que algum caia numa
   fronteira de bit na saída.
3. O `cor.sh` encadeia telas (`aguarde` → `metades-1` → `metades-2`) só com `am start`: no aparelho, a
   1ª tela ficaria parada. Corrigir com `force-stop` da galeria antes de cada tela.

Tarefas no [bloco 5](../sprints/2026-10-29-bloco-5-kit-universal.md) (E2b e E3d).

## 9. Modo automático provado no aparelho (2026-10-30, [bloco 8](../sprints/2026-10-30-bloco-8-camera-robusta.md))

A janela larga de colunas (35 a 65 %) falhou com a imagem inclinada para a câmera (10 de 16 faixas). Com
a janela de 47 a 53 % e a captura em 1280x720, o kit real, a partir de VESA gravado à mão e depois de
um reboot, achou as 16 faixas, viu a escada fora de ordem, trocou para JEIDA, conferiu a escada em
ordem e gravou só o byte 0x5c (`4899eefc`). Num 2º reboot, JEIDA persistiu e o kit não escreveu nada.
