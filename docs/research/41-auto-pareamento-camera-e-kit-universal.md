# 41 - Auto-pareamento do painel: câmera UVC, ausência de ID elétrico e o kit universal

Pesquisa de 2026-10-29 (offline: firmware oficial V1.0.0.9 extraído, binários, web), pedida pelo dono:
*"algo automático deve existir"*, com solução **idempotente, universal e fácil para leigo**, para cor e
térmica. Retoma a LCD-S3 do [doc 29](29-roadmap-troca-lcd.md) ("a forma inteligente").

**Convenção:** `CONFIRMADO` = lido no firmware ou no aparelho (caminho citado). `INFERIDO` = dedução sem
execução. Nada aqui foi executado no aparelho ainda.

---

## 1. A câmera interna é USB UVC e dá para ler direto (`CONFIRMADO` no firmware, captura `PENDENTE`)

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
levar o byte `0x5c` de volta ao de fábrica (VESA)**. Para o painel de hoje (VESA) é inócuo; para quem
tem painel JEIDA, um reflash quebraria a cor. A confirmar (bloco 4 e bloco 5, E1).

## 4. O critério que não se engana: "duas metades"

VESA↔JEIDA é uma rotação de 2 bits, igual em R, G e B (tabelas do kernel Linux, ver
[doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §5). Um padrão com duas metades de cinza
**63 | 64** (e uma faixa **127 | 128**):

- formato certo: as metades ficam praticamente iguais (|L−R|/(L+R) ≈ **0,008**);
- formato errado: 63|64 vira **252|1** ou **207|16** (≈ **0,86 a 0,99**), nos dois sentidos.

A comparação é **dentro do mesmo quadro** e **entre os dois formatos**. Balanço de branco, exposição
automática, foco e sensor monocromático afetam o quadro inteiro, não a diferença entre as metades. Serve
ao olho e à câmera. Textos só em branco e preto puros, que não mudam entre os formatos.

## 5. O kit universal (desenho)

Kit único de pendrive, sem serial, sem arquivo para editar, mesmo pendrive para qualquer PFL7560:

1. **Térmica:** estado-alvo = md5 do `.ini` que o firmware lê (`252ab7a7…`). Só troca se o md5 atual for
   de fábrica ou de versão anterior nossa; md5 desconhecido = recusa. Troca atômica e um reboot.
   Avisa se houver `/atv/ini/ZYCustom*.ini` com precedência. **Como ficou (bloco 6, T6.1):** o kit
   reconhece o `.ini` de fábrica dos **dois** modelos (V1.0.0.9 `29d8ba36…` e V1.0.0.1 sem USB-C
   `ed3f314c…`, [doc 42](42-firmware-2026-10-modelo-sem-usbc.md)) e monta o corrigido a partir do `.ini` do
   aparelho, trocando só as seções térmicas; o alvo é `252ab7a7…` no modelo antigo e `bdf5c464…` no novo.
2. **Cor:** projeta "duas metades". **Hoje:** metades iguais → nada a fazer (30 s e segue). Metades
   diferentes → a pessoa aperta **qualquer tecla**, o kit troca o formato ao vivo e mostra de novo; só
   mantém com uma **segunda** tecla; sem ela, reverte e confere relendo o byte. **Depois da prova da
   câmera (E5):** a câmera decide sozinha, e a pessoa só vê "cor ajustada"; margem pequena devolve a
   decisão à pessoa.
3. **Segurança:** backup conferido com `cmp` e journal em `/data` antes de qualquer troca; no boot
   seguinte, journal pendente = restaura o formato original; md5 de cada arquivo do kit conferido antes
   de qualquer escrita; o kit nunca chama `hidebug`/`gtt` (doc 37).

**Por que é idempotente:** a decisão depende só do que se vê na tela, e só grava quando o formato
escolhido difere do byte atual. Segunda execução: metades iguais, nada escrito, nada reiniciado.

**Por que é universal:** vale para qualquer painel LVDS 8 bit em que VESA/JEIDA seja a diferença. O
painel de fábrica mostra metades iguais; errar exige duas teclas, a segunda diante de imagem errada.

## 6. O que continua impossível

- Saber o formato **sem olhar a imagem** (sem EDID, sem pino de ID).
- **Automação sem tecla hoje:** só depois da E5 (captura provada no aparelho).
- Garantir que o autorun rode no 1º boot (o `nl_usb_update.sh` de fábrica só olha o pendrive em
  `sys.boot_completed=1`; se a montagem atrasar, perde a vez; a instrução é religar).
- Garantir, sem a bancada, que as telas aparecem: o kit as mostra por `am start ... VIEW`, que deu tela
  preta em 2026-09-03 (OPT-S13, [doc 39](39-sessao-2026-09-02-optica-e-balanco-termico.md) §4.3). A
  etapa E1(e) do bloco 5 decide.
- Painéis que precisem de `swap`/`bit`/`map`: ficam no wizard com PC, de propósito.
- Térmica em firmware diferente de V1.0.0.9 e V1.0.0.1 (md5 de fábrica desconhecido: o kit recusa). O
  V1.0.0.1, do modelo sem USB-C, passou a ser reconhecido no bloco 6.

## 7. Plano

Etapas E1 a E6 na tarefa do
[bloco 5](../sprints/2026-10-29-bloco-5-kit-universal.md).
