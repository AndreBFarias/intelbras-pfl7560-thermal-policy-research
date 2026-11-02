# 49 - Debloat e hardware não usado: o que roda, o que fica ligado, o que o firmware sabe e não usa (2026-11-01)

**Estado em 2026-11-01: pesquisa só de leitura (bloco 22, P1). Nada foi mudado no aparelho.** Pedido em
[`docs/sprints/2026-11-01-bloco-22-debloat-e-hardware.md`](../sprints/2026-11-01-bloco-22-debloat-e-hardware.md).
O que exige experimento com o dono está na §5. O que ficou sem ler por falta de root está na §0.3.

## 0. Resumo, condições da coleta e o que ficou sem ler

### 0.1 Resumo em dez linhas

1. **O maior consumidor de CPU do aparelho é o `hipluginserver`** (correção trapezoidal, 4 cantos): **31% de um
   núcleo**, sozinho cerca de metade de toda a CPU usada (o `TOTAL` é 14-19% de 4 núcleos). Quem gasta é a thread de
   tempo real `HI_VPLUGIN_THRE`, que **sonda** o buffer ~194 vezes por segundo para processar 60 quadros por segundo
   (`/proc/msp/vplugin`: `catch_try_hz 194`, `catch_suc_hz 60`). Cada sonda vazia escreve uma linha
   `CMD_VPLUGIN_CATCH_BUFFER fail`, o que dá **~122-128 linhas por segundo** no logcat. O `logd` soma 2,6-3,3%. O log
   dá para cortar sem mexer na imagem. A sondagem só some junto com o plugin (§1.4). *(Corrigido pelo P2: o P1 tinha
   tirado o `hipluginserver` da tabela da §1.1.)*
2. **Três portas ouvem na rede Wi-Fi, todas como root:** o servidor web `boa` (:80, Boa/0.94.13), o **servidor de
   depuração de imagem e som da HiSilicon dentro do `hwtvmw`** (:4321, que só existe porque a build é `userdebug`) e
   o **`adbd` (:5555) sem autenticação**. O SELinux está em `Permissive`. O `cmdsrv` **não** ouve na rede: ele é um
   socket unix local `0777` (§1.5). *(Corrigido pelo P2: o P1 tinha atribuído a 4321 ao `cmdsrv`.)*
3. **Bluetooth do Android já está desligado** ("Bluetooth never enabled!"). Existem **dois** rádios Bluetooth: o do
   AIC8800 (Android) e um **módulo caixa de som** separado, por UART, que o firmware liga e desliga por comando (§2.1).
4. **O Wi-Fi/BT AIC8800D80 é um dispositivo USB que nunca suspende** (`power/control = on`), e o **`eth0` está
   administrativamente ligado sem cabo** (`flags 0x1003`, `carrier 0`). A câmera e o hub USB já suspendem (§2).
   **E não pode suspender:** com `power/control = auto` o driver derruba o kernel (§2.2.1, 2026-11-02); o
   `wifi_pwr` saiu das chaves no bloco 29.
5. **Não existe microfone:** a única placa de som tem só saída (`pcmC0D0p`) e a câmera USB não tem interface de
   áudio (§2.4).
6. **O POWER do controle desliga de verdade, não é standby:** `persist.sys.suspend.mode = shutdown`, e o aparelho
   religou nesta sessão com `sys.boot.reason = shutdown,userrequested` (§4.4; que esse desligamento veio do botão é
   INFERIDO: o log não registra a tecla).
7. **A política desfaz o `sfs` em rampa:** o primeiro passo vem na avaliação seguinte (**≤ 2 s**). Daí em diante é
   **um passo a cada ~2 s**, e a volta a 999 leva **~2 min** (o pedido em si entra no PWM em ≤ 200 ms). **O `sbri` fica enquanto o alvo da escada não
   muda** e é atropelado quando o alvo muda (§4.1-4.2). Tudo provado no binário, com endereços; a cadência de ~2 s
   está no início da §4.
8. **`FW_SPEED_CURVE` é o eixo X e `FW_PWM_DUTY` o eixo Y** de uma interpolação linear: o `sfs` recebe "velocidade"
   na escala da curva, não duty (§4.3).
9. O firmware tem leitores de configuração para **TEC (Peltier), sensor de distância, motor de atitude, LED de
   respiração, GPIO da placa** e outros que o `ZYCustom.ini` não configura; a maioria corresponde a hardware que
   este modelo **não tem** (§3.3). A CPU tem um ponto de operação de 1,5 GHz no DT que o cpufreq não oferece (§3.1).
10. O ganho térmico grande prometido pelo dono (≈ 5 °C) **não se explica por CPU**: a CPU passa ≈ 80% ociosa. Os
    candidatos são rádio (AIC8800 sempre ativo) e o que o firmware liga junto. Só a medida da §5 separa.

### 0.2 Condições da coleta (ler antes de usar qualquer número)

- Aparelho `192.168.1.5:5555`, PFL7560, Android 9 `userdebug`, build `NL5H00X ... eng.zhilin.20260617`,
  `libhitvservice.so` md5 `4ce869799a82493799be61ff5d922be3` (a mesma do doc 37).
- **adbd sem root na coleta do P1** (`uid=2000(shell)`). Não rodei `adb root`. **Na conferência do P2 (23:07, depois
  do religamento) o adbd já estava root** (`uid=0(root) context=u:r:su:s0`, `service.adb.root = 1`), e o **SELinux
  está `Permissive`** (`getenforce`). Por isso o P2 conseguiu ler o que a §0.3 lista; nada foi escrito.
- **O relógio do aparelho está 1 h à frente do PC** (aparelho `-02`, PC `-03`). Horários abaixo são do aparelho.
- **O aparelho desligou às 22:45:11 e religou** (`sys.boot.reason = shutdown,userrequested`;
  `uptime` 2 min às 22:49:59). Não foi comando meu. O `dumpsys power` tirado às 22:45 pegou o desligamento em
  curso (`PARTIAL_WAKE_LOCK 'ShutdownThread-cpu'`), e parte da coleta de periféricos daquele minuto saiu vazia.
  Tudo de periférico foi refeito depois do boot.
- **CPU:** a coleta de 22:31-22:38 (`artifacts/re-termico/coleta-2026-11-01/top.txt` e `cpuinfo.txt`) está
  **contaminada** pelo `logcat` contínuo do coordenador (aparece um processo `logcat` no `ps.txt` dela). A medida
  usada aqui é de **22:56, com 9 min de boot** (`dumpsys cpuinfo`, janela desde o boot): sem o logcat externo, mas
  ainda com a cauda do boot. Serve para **ordenar** quem gasta, não para valor absoluto. A §5 mede em regime.

### 0.3 O que ficou sem ler como shell (relido pelo P2 como root)

| O quê | Comando | Resultado como shell (P1) | Como root (P2, 23:07-23:12) |
|---|---|---|---|
| GPIOs | `cat /sys/kernel/debug/gpio`; `ls /sys/class/gpio` | vazio / classe não exposta | **continua vazio** como root: o GPIO da HiSilicon não passa pelo `gpiolib` (`/proc/msp/gpio` também não imprime nada) |
| Barramento I2C | `ls /sys/bus/i2c/devices/*` | glob não expande | **o diretório está vazio** mesmo como root e com SELinux `Permissive`: não era negação. O I2C é do driver HiSilicon: `/proc/msp/i2c` lista **7 barramentos a 100 kHz**, sem dispositivos enumerados |
| Zonas térmicas do kernel | `/sys/class/thermal` | **não existe** (o térmico é todo do `libhitvservice`, doc 37) | idem |
| Qual processo ouve a porta 4321 | `/proc/<pid>/fd`, `ss -tlnp` | negado | **`vendor.hisilicon.hardware.hwtvmw@1.0-service` (pid 1603, fd 40)**, não o `cmdsrv` (§1.5) |
| Parar serviço nativo | `stop boa` | precisa de root; nada foi parado | possível agora, mas é escrita: **não foi feito** |

## 1. Inventário do que roda

Classificação usada: **manter** (o dono usa ou o sistema quebra sem), **desligar seguro** (nada do uso declarado
depende), **desligar com cuidado** (dá para desligar, mas tem efeito colateral a conferir), **não mexer** (é do
vídeo, da térmica ou do boot). "Como desligar" é sempre reversível; nada disso foi executado.

### 1.1 Visão geral (22:56, 9 min de boot)

`dumpsys cpuinfo`: **19% do total** (8% user + 11% kernel), em 4 núcleos A53 a 800/1000 MHz (`interactive`). O `top`
do mesmo minuto: `400%cpu ... 321%idle`. Load average 9 é de threads do kernel em espera, não de CPU (o `/proc/stat`
desde o boot dá ≈ 19% ocupado). Memória: 1 GB, `MemAvailable` 425 MB, swap zram 311 MB com 62 MB usados.

| Quem | CPU | O que é |
|---|---|---|
| **`hipluginserver` (1839)** | **31%** (12% user + 18% kernel) | correção trapezoidal: a thread RT `HI_VPLUGIN_THRE` sondando o buffer (§1.4). **Estava no topo do `cpuinfo` das 22:56** (`c4/cpuinfo.txt` do P1) e ficou de fora desta tabela; relido às 23:07-23:12: 31% (11% user + 19% kernel); na coleta de 22:31: 37% |
| `vendor.hisilicon.hardware.hwtvmw@1.0-service` (1603) | 7,8% | middleware de TV HiSilicon (fontes, imagem, HDMI RX, térmico: é ele que carrega o `libhitvservice.so`) |
| `system_server` | 5,3% | Android |
| `hi_vpss_process` (kernel) | 5% | pós-processamento de vídeo (escala, keystone) |
| `logd` | 3,3% | o daemon de log, alimentado pelo spam do §1.4 |
| `pqserver` | 2,8% | qualidade de imagem HiSilicon |
| `hwsysmanager` | 1,2% | HAL de sistema HiSilicon |
| `HDMIRX main tas`, `surfaceflinger`, `cameraserver`, `audio HAL` | ≤ 1% cada | |

Tudo o mais fica abaixo de 0,5%. Os percentuais por processo do `dumpsys cpuinfo` são de **um núcleo**; o `TOTAL`
é dos 4. Então os 31% do `hipluginserver` são ~0,3 núcleo, cerca de metade dos 14-19% de uso total. **Mesmo assim, a
CPU não explica os 5 °C** (fica ≈ 80% ociosa). Desligar app rende memória e um pouco de `system_server`, não graus.
INFERIDO: 0,3 núcleo de A53 a 1 GHz são da ordem de 0,1 W. A §5 confere.

### 1.2 Serviços nativos (`getprop | grep init.svc.`)

| Serviço | Estado | O que é | Classificação |
|---|---|---|---|
| `hwtvmw-1-0`, `hwsysmanager-1-0`, `hwgraphics-1-0`, `hwaudio-1-0`, `hwandroidmediahal-2-0`, `vendor.tv-input-1-0`, `vendor.audio-hal-2-0`, `surfaceflinger`, `media*`, `vendor.hiavplayer` | running | vídeo, imagem, som, entradas | **não mexer** |
| `hipluginserver` | running | servidor do plugin de vídeo da correção trapezoidal (`/dev/hi_vplugin`, `libkeystone.so`) | **não mexer** (o dono usa os 4 cantos: `persist.hisi.keystone.enable = true`, cantos `45,930 / 1715,1015 / 10,15 / 1755,20` às 23:01). O log dele, sim (§1.4). Nota do P2: às 23:10 os cantos estavam em **identidade** (`0,1080 / 1920,1080 / 0,0 / 1920,0`) e o plugin continuava processando 60 quadros/s com 31% de CPU |
| `pqserver` | stopped no init, 2 processos vivos | qualidade de imagem | **não mexer** |
| `vendor.cec-hal-1-0` | running | HDMI-CEC; loga `Unknown message, type:0x90001` a cada 30 s | desligar com cuidado: `settings put global hdmi_control_enabled 0` (volta com `1`). O PC não fala CEC; ganho mínimo |
| `boa` | running, **root** | servidor web, porta 80 (§1.5) | desligar seguro, mas só com root (`stop boa`); sem root, não dá |
| `cmdsrv` | running, **root** (`u:r:cmdsrv:s0`) | servidor de comandos num **socket unix local** `/data/local/cmdsrv` (`srwxrwxrwx`), **não na rede** (§1.5). Tem `/system/bin/sh` e `###SvrCmd:[%s]###` no binário | desligar com cuidado (root). INFERIDO: é do espelhamento USB e executa comandos de shell para quem conectar |
| `hiaoservice` | running | áudio HiSilicon | não mexer |
| `vendor.hwdlnaservice-1-0` | running, root | DLNA (receber mídia pela rede) | desligar com cuidado (root); o dono não usa |
| `mdnsd` | running | descoberta na rede (mDNS) | desligar com cuidado (root); pode afetar descoberta de cast, que já não existe |
| `perfprofd` | running | coletor de perfil do Android (build userdebug) | desligar seguro (root); ocioso |
| `vendor.bluetooth-1-0` | running | HAL Bluetooth (processo ocioso em `binder_thread_read`) | não mexer: o BT já está desligado no Android; o HAL parado não economiza rádio |
| `vendor.wifi_hal_legacy`, `wificond`, `aic_supplicant` | running | Wi-Fi | manter |
| `vendor.virtualkeypad`, `vendor.ir_user` | running, root | teclado virtual e receptor IR do controle | **não mexer** (o IR é o controle) |
| `pfl7560_suite` | running | a suíte de boot deste projeto (doc 44) | manter |
| `statsd`, `usbd`, `bootanim`, `logcat_service`, `vendor.hiquickplay` | stopped | | |
| `memcserver`, `vendor.breathlight`, `hostapd` | definidos no `.rc`, **não iniciados** | MEMC, LED de respiração, ponto de acesso | nada a fazer |

### 1.3 Apps habilitados (91; `pm list packages -e`) e processos vivos

Já desabilitados pela build: `com.mobisystems.editor.office_registered`, `com.hisilicon.miracast`,
`com.newlink.cast`. Nenhum app de terceiros (`pm list packages -3` vazio). Os 20 `com.pfl7560.tema.*` e
`com.pfl7560.home`/`verificar` são deste projeto.

Comando de desligar para todos os "desligar seguro/com cuidado": `pm disable-user --user 0 <pacote>`;
volta com `pm enable <pacote>`. Não remove nada.

| Pacote | Vivo? (PSS) | O que é | Classificação |
|---|---|---|---|
| `org.videolan.vlc` | não | VLC; o dono não usa | **desligar seguro** (o `pfl7560-vlc.sh` deste repo deixa de servir) |
| `com.newlink.service` | **sim, 33,6 MB** (2º maior) | `BootService`, `DataUploadService`, `RegisterService`, `AutoSystemUpdateService`, receiver de voz | **desligar com cuidado**: é telemetria + OTA + registro. INFERIDO: a home e as teclas de atalho conversam com ele; testar a home depois. O OTA de fábrica é justamente o que o projeto não quer |
| `com.newlink.service2` | não | receiver de boot | desligar com cuidado (par do anterior) |
| `com.newlink.nlprovision` | sim, 14,5 MB | provedor de configurações NewLink, `TempService` | **não mexer** (o tema do doc 48 e a temperatura na tela dependem) |
| `com.newlink.screensaver` | sim, 12 MB | protetor de tela | desligar com cuidado: o dono usa como monitor; o `PowerManagerService` loga `screensaver enable true` em rajadas. Desligar pela UI (tempo do protetor) é a forma limpa |
| `com.newlink.filemanager` | sim, 6,4 MB | gerenciador de arquivos, `UsbDialogService` (pop-up de pendrive) | manter (o kit de pendrive usa) |
| `com.newlink.nlsource` | sim, 18,6 MB | lista de entradas | manter |
| `com.newlink.hisilauncher` | sim, 4,8 MB | launcher de fábrica | desligar com cuidado: a home do projeto é a padrão; o de fábrica pode ser o fallback |
| `com.newlink.wtprovision` | sim, 3 MB | provisionamento | não mexer (sem informação) |
| `com.newlink.autotest`, `com.newlink.factorymenu`, `com.newlink.tvtestingtools`, `com.hikeymasterprovision` | não | teste de fábrica | desligar seguro (não rodam; ganho só de receiver/espaço) |
| `com.newlink.isuperred.ijkplayerdemo` | não | demo de player | desligar seguro |
| `com.newlink.hotkeysservices` | não no momento | teclas de atalho do controle | **manter** |
| `com.zhiying.autofocus` | só no boot (abre a câmera 6 s: `CONNECT 22:47:33`, `DISCONNECT 22:47:39`) | foco automático ao ligar | manter (o dono usa foco; doc 43/46) |
| `com.zhiying.bluetoothmodelservice` | sobe e morre no boot | modo caixa de som Bluetooth | desligar com cuidado (§2.1) |
| `com.zhiying.settings` | sim, 14,4 MB, `HDMIService` | configurações da Zhiying | manter |
| `com.hisilicon.tvinput.external`, `com.hisilicon.tv.service`, `com.hisilicon.rmservice`, `com.android.providers.tv` | sim | entradas HDMI/USB-C e o banco de canais | **não mexer** |
| `com.hisilicon.tvinput.external` `HiCvbsTvInputService`, `HiVgaTvInputService`, `HiYpbprTvInputService` | serviços vivos | entradas analógicas que este modelo não tem | não mexer: são serviços dentro do mesmo app das entradas HDMI |
| `com.hisilicon.android.music`, `videoplayer`, `higallery`, `com.hisilicon.tvui`, `com.hisilicon.tv.menu` | não | players e menus HiSilicon | desligar com cuidado (o menu de imagem pode ser o `tv.menu`; testar) |
| `com.android.bluetooth`, `com.example.bluetoothsetting`, `com.android.bluetoothmidiservice` | `A2dpService`/`HidHostService` registrados | pilha BT do Android | desligar com cuidado: o BT já está desligado; desabilitar a pilha **quebra o pareamento do controle se ele for BT** (o controle atual é IR: `Hi keyboard`) |
| `com.android.location.fused`, `GeofenceHardwareService` | registrados | localização (sem GPS) | desligar seguro: `pm disable-user --user 0 com.android.location.fused` |
| `com.android.webview` | não | WebView | **não mexer** (vários apps de fábrica dependem) |
| demais `com.android.*` | | base do Android | não mexer |

### 1.4 O spam de log do `hipluginserver` (o achado de CPU)

O serviço `hipluginserver` (`/vendor/bin/hipluginserver`, md5 `37fe6dbca6d324f9e2b82f7c11273082`, root,
`oneshot`) abre `/dev/hi_vplugin` e roda a thread `HI_VPLUGIN_THREAD`. Ela escreve **duas linhas a cada ~16,7 ms**
(espaçadas de 2 ms e 15 ms no `logcat -d` das 23:08; 122 linhas no último segundo inteiro sem poda), e não uma a
cada 33 ms como o P1 tinha escrito:

```
I HI_VPLUGIN: [NOTICE-HI_VPLUGIN]:mpi_keystone_server_catch[339]:CMD_VPLUGIN_CATCH_BUFFER fail,inst_id:0,buf_type:1,ret=-2141192189!
```

- No log contínuo de 22:05:47 a 22:45:14 (boot anterior): **305 514 linhas** desta mensagem em 306 089; **mediana de
  128 linhas por segundo**, em todos os 2 368 segundos.
- No boot atual continua: `logcat -d` às 22:59 mostra o `chatty` deduplicando `HI_VPLUGIN_THRE` a cada 33 ms.
- Custo: o `logd` aparece com 3,3% de CPU (§1.1), mais o `chatty`. **O próprio servidor gasta mais que o log:** a
  thread `HI_VPLUGIN_THRE` (tid 3604, prioridade RT) acumulou 16 384 + 27 253 jiffies (utime + stime) em ~23 min de
  boot, o que dá ~31% de um núcleo, batendo com o `dumpsys cpuinfo` (§1.1).
- **Não é defeito, é sondagem** (lido pelo P2 em `/proc/msp/vplugin`): `server_type KEYSTONE`, `catch_try_hz 194`,
  `catch_suc_hz 60`, `que/send_suc_hz 61`. A thread tenta ~3 vezes por quadro, consegue 1, e **cada quadro de 60 Hz
  é processado**; as ~130 tentativas vazias por segundo são as linhas de log. O `ret = 0x80600003` é o "ainda não há
  buffer" desse laço.
- **O spam apaga os logs térmicos.** O buffer `main` tem **64 KB** (`logcat -g`) e às 23:08 guardava só **~22 s**
  (672 linhas). O `logd` poda o uid que mais escreve (`chatty: uid=0(root) HI_VPLUGIN_THRE expire 21 lines`), e o
  `hwtvmw`, que escreve as linhas `ZYThermalManager`, também é uid 0: `chatty ... atvservice expire 10 lines`. Um
  `logcat -d` tirado minutos depois de um evento térmico não acha o evento. Isso afeta a §5.3.

**O plugin é necessário** (desligar mata a correção trapezoidal dos 4 cantos). **O que dá para cortar sem mexer na
imagem é só o log.** INFERIDO e **não testado**: com os cantos em identidade (como às 23:10),
`persist.hisi.keystone.enable = false` pararia a sondagem e devolveria ~0,3 núcleo. Isso muda o caminho da imagem,
então só com o dono olhando. Proposta reversível, **não testada**: `setprop log.tag.HI_VPLUGIN S` (o liblog do
Android 9 consulta `log.tag.<TAG>` antes de escrever; volta sozinho no reboot ou com `setprop log.tag.HI_VPLUGIN ""`).
INFERIDO que o shell tem permissão de `log.tag.*` e que a lib usa o caminho do liblog que respeita a prop; a §5
mede.

### 1.5 Portas abertas na rede (`ss -tlnp`, `netstat -tlnp`, como root, P2 23:08)

| Porta | Escuta em | Processo (pid, fd) | O que é | Risco |
|---|---|---|---|---|
| **80** | `0.0.0.0` | `boa` (1862, fd 4), uid 0, **`u:r:shell:s0`** (`seclabel` do `boa-service.rc`) | `Boa/0.94.13` (`/vendor/bin/boa -c /vendor/etc/boa/ -d`; `boa.conf`: `User 0`, `DocumentRoot /data/local/boa` com `itag/` e `log/` vazios e `0777`, `ScriptAlias /cgi-bin/` com só o `test.cgi` de exemplo, que roda como root e devolve o ambiente e a query) | **médio-alto**: HTTP sem autenticação, root, código de 2005 sem manutenção, sem contenção (SELinux `Permissive`). INFERIDO: não há função para o dono |
| **4321** | `0.0.0.0` | **`vendor.hisilicon.hardware.hwtvmw@1.0-service` (1603, fd 40)**, uid 0 | servidor de depuração de mídia da HiSilicon (`HI_UNF_MDBG`, `mpi_pq_dbg_*`, `mpi_aq_dbg_register_cmd_func`) em `/vendor/lib/libhi_msp.so`, que tem a string **`android user version, close port 4321`**: só fecha a porta em build `user`, e esta é `userdebug` | **alto para a imagem e o som**. INFERIDO: quem estiver na mesma rede lê e escreve parâmetros de PQ/áudio sem senha. **Não dá para desligar sozinho**: é parte do `hwtvmw` (não mexer). Mitigação: Wi-Fi desligado ou rede confiável |
| 5555 | `::` | `adbd` (3667), **root**, `ro.adb.secure` vazio | adb pela rede **sem autenticação** | **o maior**: shell root para quem estiver na rede. Manter enquanto o projeto usa adb; é o preço do método |
| 5037 | `127.0.0.1` | `adbd` | servidor adb local | nenhum (só local) |

**`cmdsrv` não está na rede (correção do P2):** o único socket dele (fd 3, inode 1636) é unix,
`/data/local/cmdsrv`, `srwxrwxrwx root root`. O binário tem `/system/bin/sh` e `###SvrCmd:[%s]###`. Risco **local**:
INFERIDO que qualquer app que conecte executa comando como root. Hoje não há app de terceiros
(`pm list packages -3` vazio), então o risco prático é baixo.

Não testei nenhuma porta (não é escopo e seria escrita). Para o dono: com o Wi-Fi ligado, qualquer um na mesma rede
alcança as portas 80, 4321 e 5555. Para tirar o `boa` e o `cmdsrv` é preciso root (`stop boa`, `stop cmdsrv`, que não
sobrevivem ao reboot) ou tirar o `.rc` na imagem. A 4321 só fecha com uma build `user`.

### 1.6 Receivers de boot, alarmes, wakelocks, jobs

- **Receivers de `BOOT_COMPLETED`/`LOCKED_BOOT_COMPLETED`** (de `dumpsys package`): além do Android, os de fábrica
  são `com.hisilicon.tvsetting`, `com.android.tv.settings` (3, um deles `hiHid.BootCompleteBroadCastReceiver`),
  `com.newlink.cast` (desabilitado), `com.newlink.service` (2) e `com.newlink.service2`, `com.zhiying.settings`
  (`HDIMBroadcastReceiver`, `NetChangeReceiver`), `com.mobisystems...` (desabilitado), `org.videolan.vlc` (3).
- **Alarmes** (`dumpsys alarm`, Top Alarms): só do Android (`job.delay`, `NETWORK_STATS_POLL`, `TIME_TICK`, ...) e
  `com.android.providers.tv` `CLEAN_UP_EPG_DATA` (3 em 1 h). Nenhum alarme de fábrica relevante.
- **Wakelocks** (`dumpsys power`, 22:57): um só, `SCREEN_BRIGHT_WAKE_LOCK 'WindowManager'` (a tela ativa mantém o
  projetor ligado; esperado no uso como monitor). Nenhum wakelock parcial de app.
- **Jobs** (`dumpsys jobscheduler`): 9, todos do Android (`BackgroundDexOptService`, backup, `MountServiceIdler`,
  `CameraStatsJobService`, ...). Nenhum de fábrica.

## 2. Rádios e periféricos

O barramento USB (`/sys/bus/usb/devices`, 22:5x):

```
usb1 EHCI 1d6b:0002            active
 1-2  USB2.0 Hub 05e3:0608     runtime_status=suspended  control=auto
  1-2.2 Integrated Camera 0c45:64ab  suspended  control=auto   (bMaxPower 500mA)
 1-3  AIC 8800D80 a69c:8d81    runtime_status=active  control=on  suspended_ms=0   (bMaxPower 500mA)
usb2 OHCI 1d6b:0001            suspended
```

### 2.1 Bluetooth: são dois

1. **O BT do Android, no combo AIC8800D80** (USB 1-3, mesmo chip do Wi-Fi). `dumpsys bluetooth_manager`:
   `enabled: false`, `state: OFF`, **`Bluetooth never enabled!`** neste boot (o P2 confirmou às 23:10). No kernel:
   `rfkill0` (`ap6356S`, tipo `bluetooth`) está com `state = 0` (bloqueado). As duas interfaces HCI do AIC8800
   (`1-3:1.0` e `1-3:1.1`, classe `e0`) estão **sem driver ligado**: só a `1-3:1.2` tem o `aic8800_fdrv`. Já está
   desligado; o resto de consumo é do chip, que fica ativo pelo Wi-Fi (§2.2). Reversível: `svc bluetooth disable`/`enable` ou
   `settings put global bluetooth_on 0`.
2. **Um módulo "caixa de som Bluetooth" separado, por UART.** O `ZYCustom.ini` tem `[Global] BLUETOOTH_CONTROLLER = Y`,
   `[BTSink]` (`UART_RETRY_TIMES`, `EXT_UART_TIMEOUT`, `BT_DEFAULT_VOLUME`) e `[BTSinkCmdline]` com 10 comandos
   seriais, entre eles `POWER_OFF = 55 AA 52 06 00 5A` e `POWER_ON = 55 AA 52 05 00 5A`. Props:
   `vendor.zy.power.btc.enable = true`, `zysy.wifi_bt.sink_enable = true`. É o "modo caixa de som"
   (`com.zhiying.bluetoothmodelservice`, `com.pfl7560.tema.zyspeakermodel`). **Não sei se o módulo fica energizado
   fora do modo caixa de som** (não há leitura dele pelo shell). INFERIDO: o `POWER_OFF` existe para isso, e o
   `btc.enable = true` sugere que o controlador está ativo. A §5 testa desligando o modo caixa de som pela UI.

### 2.2 Wi-Fi

AIC8800D80 em USB (`aic8800_fdrv`, `aic_load_fw` carregados). `wlan0` `operstate up`. O dispositivo USB está com
**`power/control = on`**, `runtime_status = active`, embora o próprio dispositivo anuncie
`supports_autosuspend = 1` (P2, 23:10): nunca entra em autosuspend, nem com o Wi-Fi desligado pela home (INFERIDO;
a §5 confere lendo `runtime_status` com o Wi-Fi desligado). Este é o candidato mais forte para os ≈ 5 °C do dono: rádio 2,4/5 GHz
transmitindo e um chip com 500 mA de orçamento USB. Reversível: o botão da home, ou `svc wifi disable`/`enable`.

**Driver sobrando:** `skw_usb` e `skw_bootcoms` (Seekwave, outro fornecedor de Wi-Fi/BT) estão carregados
(`/proc/modules`) sem nenhum dispositivo Seekwave no USB. É a build servindo duas listas de peças. Custo:
memória do kernel, não CPU. Tirar exige mexer no `.rc` (fora do escopo).

#### 2.2.1 Autosuspend no chip Wi-Fi derruba o kernel (2026-11-02, bloco 29)

**Medido no aparelho (só leitura, 2026-11-02 05:08).** O dono viu a suíte de testes "rodando sem parar". Os três
últimos boots tinham `sys.boot.reason = kernel_panic,NULL`, e a suíte roda sozinha no modo `tomada
desligamento_nao_limpo` a cada boot depois de um panic: cada panic virava uma suíte nova na tela.

- `pstore/console-ramoops-0`: `Unable to handle kernel NULL pointer dereference` em **`aicwf_usb_bus_start`**
  (módulo **`aic8800_fdrv`**), na workqueue **`usb_hub_wq`**, aos **1526 s** de uptime.
- `chaves.escolhas` tinha `wifi_pwr=1`: o chip (USB `1-3`, `a69c:8d81`) estava com **`power/control = auto`**.
- O `dmesg` mostra **suspend/resume do driver a cada ~4 s** com o `auto`. Cada resume passa pelo
  `aicwf_usb_bus_start`; uma das voltas cai no NULL e derruba tudo. Com `on`, não há suspend e não há panic.
- O padrão de instalação de `wifi_pwr` era 0 e a linha já tinha saído da home no bloco 27; não se sabe quem gravou 1.

**Na hora (coordenador, com o pedido do dono de parar):** `kill` da suíte, `echo on >
/sys/bus/usb/devices/1-3/power/control`, `suite-chaves.sh aplicar wifi_pwr desligar`.

**Cura (bloco 29, decisão do dono: "só remove o gatilho das escolhas"):** `wifi_pwr` deixou de ser uma escolha do
`suite-chaves.sh`. `aplicar`/`pedido` recusam o id (rc 2, "não é mais uma escolha" no log); o `boot` não reaplica,
apaga a linha `wifi_pwr=` que estiver no `chaves.escolhas` e escreve `on` no `power/control` do chip (achado pelo id
`a69c:8d80/8d81`, nunca pelo `1-3` fixo), antes de qualquer outra coisa; o `resgate` faz o mesmo. A posição 8 da prop
`vendor.pfl7560.chaves` fica reservada e é **sempre `-`**, para não deslocar os ids seguintes. Prova:
`tests/test-chaves.sh` (`c_wifi_retirado`).

**Consequência para a §5:** o "ganho possível em autosuspend" do fim da §5.2 está descartado neste firmware. O
`echo auto` no chip não é experimento seguro: derruba o kernel em minutos.

### 2.3 Ethernet que não tem conector

O DT declara `ethernet@f9840000` (`hisilicon,hi3751v600-eth`, dois PHYs `mii`) e o kernel cria o `eth0`:
`operstate down`, `carrier 0`, **`flags 0x1003` (IFF_UP)**; o `ip link` mostra `<NO-CARRIER,BROADCAST,MULTICAST,UP>`
(confirmado pelo P2). A interface está administrativamente ligada; INFERIDO que, por isso, o PHY interno fica
energizado procurando link. INFERIDO que o PFL7560 não tem conector RJ45 (não há porta de rede no
gabinete descrito nos docs de teardown). Desligar: `ip link set eth0 down` (precisa de root; volta com `up`). Ganho
provável pequeno (dezenas a poucas centenas de mW, INFERIDO).

### 2.4 Câmera e microfone

- **Câmera** USB 0c45:64ab (Sonix), `Integrated Camera`, atrás do hub 05e3:0608. **Já suspende:** hub e câmera em
  `runtime_status = suspended` (631 s suspensos em 647 s de boot). Só é aberta pelo foco automático ao ligar
  (`persist.newlink.poweron.autoFocus_enabled = 1`, `zysys.newlink.poweron_camera = true`), por 6 s. O
  `cameraserver` vive (5 MB, 0,6% de CPU no boot). Nada a fazer; desligar o foco ao ligar não é o pedido.
- **Microfone: não há.** `/sys/class/sound` tem só `card0`, `controlC0`, **`pcmC0D0p`** (o `p` é playback); a câmera
  USB expõe só as interfaces `1-2.2:1.0` e `1-2.2:1.1` (vídeo). O botão da câmera aparece como teclado `input3`.

### 2.5 USB-C

Não existe nada de USB-C no kernel: sem `/sys/class/typec`, sem `usb_role`, sem `extcon`. O `dumpsys usb` não vem
vazio: tem só o `host_manager` (lista o AIC8800 e a câmera), sem `port_manager`;
`sys.usb.config = adb` (a porta de dados é a de serviço). Do lado do firmware, `zysys.typec_count = 1` e
`zysys.source.typec1 = 9`: o USB-C é uma **fonte de vídeo** (entrada 9, ao lado das HDMI), INFERIDO que via um
conversor DisplayPort-para-HDMI ligado ao HDMI RX, com o seu próprio controlador de PD. Esse controlador não é
visível nem desligável pelo Android. `zysys.usb_signal_enable = 0`. Nada a fazer por software.

## 3. Hardware que o software não usa

### 3.1 Device tree (`artifacts/firmware-extraido/full_dts.txt`)

O DT do Hi3751V350 é curto (668 linhas) porque os periféricos HiSilicon (LSADC, PWM, GPIO, I2C, IR) são
configurados pelos drivers `hi_*` do kernel do fornecedor, não pelo DT. O que o DT diz:

| Nó | Estado | Uso |
|---|---|---|
| `ethernet@f9840000` + 2 PHYs | sem `status` (ativo) | **não usado** (§2.3) |
| `uart@f8b00000`, `uart@f8006000` (pl011) | `okay` | console e uma segunda UART. INFERIDO: a segunda é a do módulo BT caixa de som (`[BTSink]`) ou a `[DebugUart]` |
| `timer@f8002000` (sp804) | `disable` | |
| `emmc@f9830000` | `ok` | armazenamento |
| relógios `sdio0_*` e `sdio1_*` | declarados | **não há host SDIO** no DT: sem leitor de cartão |
| `hifmc100@f9800000` | sem status | controlador de flash SPI. INFERIDO sem uso (o boot é do eMMC) |
| `gpu@0xff500000` (Mali-450) | `okay` | |
| `opp_table1`: 800 MHz (`opp-suspend`), 1000 MHz, **1500 MHz** | | o cpufreq só oferece `800000 1000000`. O ponto de 1,5 GHz existe e não é usado. **Bom para a térmica**; não mexer |
| `idle-states`: `cpu-powerdown`, `cpu-standby` | | cpuidle ativo |
| `ramoops@20000000` | | log do kernel sobrevive a reboot (útil para diagnóstico) |

### 3.2 O que o kernel mostra (`/sys/class`, `/proc`)

- `/sys/class/thermal` e `/sys/class/hwmon` **não existem**: o kernel não lê temperatura nenhuma; o térmico inteiro é
  do `libhitvservice.so` lendo o LSADC (docs 08, 37).
- `/sys/class/pwm`, `/sys/class/backlight`, `/sys/class/leds` (só `mmc0::`), `gpio`: não expostos. O PWM dos
  ventiladores e o LED são escritos pelo driver HiSilicon. Mesmo como root (P2), `/sys/class/gpio`, `/sys/class/i2c-dev`
  e `/dev/i2c*` não existem e `/sys/class/i2c-adapter` está vazio: os barramentos aparecem só em `/proc/msp/i2c`
  (7 barramentos, 100 kHz), o caminho do driver `hi_*`.
- `sensorservice`: **`No Sensors on the device`** (`devInitCheck : -19`). O acelerômetro do keystone automático
  (`[Orientation]`, `[AutoKeystone] BYPASS_SENSORS = N`) é lido pelo firmware diretamente, não pelo Android.
- Entradas: `Hi keyboard` (o controle IR, `Vendor_0001_Product_0001.kl`), `Hi mouse`, `qwerty`, `Hi Keypad`
  (botões do gabinete) e o botão da câmera.
- Módulos carregados: `aic8800_fdrv`, `aic_load_fw`, `skw_usb`, `skw_bootcoms` (sobrando, §2.2), `tntfs` (NTFS).

### 3.3 Chaves e seções que o firmware aceita e o `ZYCustom.ini` não configura

O `libhitvservice.so` tem leitor de configuração (`ZYConfig::<Classe>::init*`, nos símbolos do
`.gnu_debugdata`) para 25 classes. O `.ini` instalado (md5 `252ab7a7...`) tem seção para 13 delas. (Conferido
pelo P2: 25 classes com `init*` nos símbolos; 13 com seção no `.ini`, os 12 restantes são os da tabela; o desvio
`0x1fc7a6` vai mesmo para `ThermoElectricCoolerControl::RunCheckAndUpdate`.)

| Classe sem seção no `.ini` | O que seria | Hardware presente? | Ganho / risco |
|---|---|---|---|
| `FanMonitor` | tacômetro dos ventiladores | não (sopradores de 2 fios, doc 34) | nenhum; **armar sem fiação é pior** (doc 34) |
| `ThermoElectricCooler`, `ThermoElectricCoolerPolicy` | Peltier | não (teardown, docs 01/27) | nenhum. O tick chama `ThermoElectricCoolerControl::RunCheckAndUpdate` mesmo assim (`0x1fc7a6`), custo desprezível |
| `Distance` | sensor de distância (ToF) para foco | INFERIDO não (`vendor.zy.power.fc.distance = 0`) | nenhum |
| `AttitudeMotor`, `DCMotor` | motores de inclinação/zoom | não | nenhum |
| `LedLight` | ciclador de LED (`[Global] LED_LIGHT_CYCLER = N`) | não (é para LED RGB sequencial) | nenhum |
| `BoardGpio` | GPIOs genéricos da placa | desconhecido (o GPIO não é legível nem como root: não passa pelo `gpiolib`, §0.3) | só com o mapa de GPIOs; ver §0.3 |
| `SensorsDevice` | sensores genéricos | o acelerômetro existe, configurado por `[Orientation]` | nenhum |
| `MonotonicTask` | atuador extra no fim do tick (`TASK_MODE`, doc 34) | | nenhum |
| `AutoFocus`, `Decoder` | defaults internos | o foco funciona sem seção | nenhum |

Dentro das seções existentes, as chaves não configuradas já documentadas: as 6 de sense do `[CoolingFan_N]`
(`SW_SENSE_TYPE`, `FW_SENSE_FG_POLES`, `FW_SENSE_FG_FULL_RPM`, ...) e as 9 do `FanMonitor` (doc 34). As políticas
`stp` `COOLING:1 QUIET:2 FAST:3 MAXSPEED:-1` e `sbp CUS1:2` existem e o `.ini` não as define (doc 34).

**Conclusão da §3:** não há hardware útil escondido. O que o firmware sabe e a fábrica não ligou corresponde a
peças que este modelo não tem (Peltier, ToF, motores, tacômetro), ou é o tacômetro que exigiria trocar os
sopradores. Os achados reais são de energia: o `eth0` ligado sem conector, o AIC8800 sem autosuspend, o driver
Seekwave sobrando e o ponto de 1,5 GHz que (felizmente) não é usado.

## 4. Respostas que o bloco 23 precisa (estático)

Tudo em `libhitvservice.so` md5 `4ce869799a82493799be61ff5d922be3`, Thumb, endereços virtuais. Desassemblado com
capstone (o método do `artifacts/re-termico/README.md`).

**Cadência (corrigida e provada no binário pelo P2; listagem em `artifacts/re-termico/p2-cadencia-tick.txt`):**

- `ZYPowerManager::Run` (`0x1eb8d0`) roda **um módulo por chamada** (índice `[this+0x2c]`, 0 a 5, `0x1eb8fa`-`0x1eb906`)
  e dorme `ptms` ms (`nanosleep`, `0x1eb932`). `ptms = property_get_int32("vendor.zy.power.ptms", 33)` (`0x1eaf26
  movs r1, #0x21`), ×10 se o bit 0 do `vendor.zy.power.enable` estiver desligado.
- A tabela `tbb` de `RunInternalModuleMain` (`0x1eb9aa`) tem 6 módulos: 0 = Common (`RunInternalModuleCommon` →
  `RunThermalMngrCommon`, `0x1ebc64`: **aplica os pendentes do `hidebug`**), 1 = `RunThermalMngrMain` (política),
  2 = BTSink, 3 = LedLight, 4 = ProjFocus, 5 = ProjAttitude. Cada passada (Common ou Main) volta a cada
  6 × 33 ms ≈ **198 ms**.
- `RunDaulRigalMode` (`0x1fd170`-`0x1fd1b8`) só avalia quando o anel do termistor está cheio. O
  `Thermistor::getTemperature` (`0x21d9a0`-`0x21d9ac`) zera o contador quando ele chega a `SW_N` e depois soma 1;
  então o anel fica "cheio" **uma vez a cada `SW_N` = 10 passadas**: uma avaliação da política a cada
  10 × 198 ms ≈ **1,98 s**. Bate com os logs de rampa de ≈ 2 s do doc 34.
- Nesta seção, **"tick" = uma avaliação da política (≈ 2 s)**. O pendente de um `sfs`/`sbri`/`sbl` é aplicado na
  passada Common seguinte, **em até ≈ 200 ms**, e não no "tick".

### 4.0 O mecanismo comum: comando pendente + rampa da política

Os comandos do `hidebug` não escrevem no hardware; deixam um **pedido pendente** que a thread térmica aplica no tick:

- `setThermalFanSpeed` (`sfs`, `0x1fbb88`): se `CoolingFan::getControlSpeed() != v`, grava `ctl[+0x10] = v`,
  `ctl[+0x14] = 1` (`0x1fbc42 strd r4, r0, [r3, #0x10]`).
- `setThermalBrightness` (`sbri`, `0x1fc518`): grava `ctl[+0x10] = Backlight::calcBrightnessCurve(v)`,
  `ctl[+0x14] = 1` (`0x1fc5e0`).
- `setThermalBacklightLevel` (`sbl`, `0x1fc1f0`): se `Backlight[+0xc] != v` e `v <= 1000`, grava `ctl[+0x10] = v`
  cru, `ctl[+0x14] = 1` (`0x1fc2aa`). Mesmo slot do `sbri`.

No tick, `RunThermalMngrCommon` (`0x1fc764`) chama, para cada controle, `BrightnessControl::RunCheckAndUpdate`
(aplica `Backlight::setLevel(ctl[+0x10])`, `0x1fc818`, e zera o pendente), depois as duas políticas, depois
`FanSpeedControl::RunCheckAndUpdate` (aplica `updateSpeed(ctl[+0x10])`, `0x1fca52`). A política ativa
(`THERMAL_MODE = 0x1001` → `RunDaulRigalMode`, que chama `RunThermalDualProcess(int,int)` em `0x1fd448`) calcula o
alvo e chama a **rampa** de cada atuador.

### 4.1 A política reescreve o `sfs`? **Sim, em rampa, em ≈ 2 min. Sem `stp -1`.**

- `FanSpeedControl::updateSpeed` (o caminho do `sfs`) grava o duty calculado no **estado da política**:
  `0x2023aa str r7, [r4, #0xc]` (`r7 = calcSpeedCurve(v)`).
- A cada tick, `RunThermalDualProcess` (`0x203048`) calcula o alvo de cada ventilador, passa por `calcSpeedCurve`,
  limita a `[100, 1000]` e chama `RunPwmChange(alvo, bMax = alvo >= 950, bAbnormal = 0)` (`0x20310c`, `0x20315c`,
  um por ventilador). **Correção do P2:** o ventilador 0 recebe o maior dos dois alvos das `[ThermalPolicy]`
  (`0x2030d2 cmp r6, sb; movlo r6, sb`). O ventilador 1 recebe **só o alvo da política 1** (`0x203128 mov r1, sb`,
  sem comparação). Com o `.ini` instalado não faz diferença (todos os alvos são 1000).
- Fora das funções `Run*Process` da política, ninguém chama `RunPwmChange` (varredura de chamadores, P2).
- `RunPwmChange` (`0x202094`): com `x = ctl[+0xc]` e `alvo`:
  - `x < alvo`: `x = x + ((alvo - x) >> 4) + 1` (`0x202104`, log `PWM Duty Up to`);
  - `x > alvo`: `x = x - ((x - alvo) >> 5) - 1` (`0x20212a`, log `PWM Duty Down to`);
  - `x == alvo`: **retorna sem escrever** (`0x202120 bls → 0x2021ba`);
  - depois grava `ctl[+0xc] = x` e só chama `CoolingFan::setPwmDuty(x)` se `|x - CoolingFan[+0x14]| >= 10`
    (`0x202148`-`0x202158`).

Como o `.ini` tem `POLICY_x_SPEED` = 1000 em todos os degraus, o alvo é sempre 1000. Depois de um `sfs` que deixe o
duty em 600, a rampa sobe 600 → 626 → 650 → 672 → ... Simulação da fórmula: o PWM chega a **999 na 58ª avaliação**
(27 escritas no PWM). Na 59ª, `x = 1000`, mas a diferença para o PWM é 1 (< 10), então **o duty final fica em 999**.
São 59 × 1,98 s ≈ **117 s ≈ 2 min**.

**A contradição "s × min" (pedida ao P2) se resolve assim; as duas escalas valem, cada uma no seu passo:**

- o `sfs` entra no PWM **em até ≈ 200 ms** (passada Common, `0x1ebc64` → `FanSpeedControl::RunCheckAndUpdate`
  → `updateSpeed`);
- o primeiro passo da política vem **em até ≈ 2 s** (próxima avaliação com o anel cheio);
- a volta inteira a 999 leva **≈ 2 min** (59 avaliações de ≈ 1,98 s).

Com `ctl[+0xc] == 0` ou `bAbnormal`, o `RunPwmChange` pula direto para o alvo, sem rampa. **Para segurar um `sfs`, o alvo da
política tem que ser igual ao pedido**: ou `[ThermalPolicy]` no `.ini`, ou uma política (`stp`) cujo alvo coincida.
O bloco 23 não precisa de `stp -1` para isso, e não deve usá-lo.

Previsão verificável (§5.3): depois de `sfs`, o `logcat -d` mostra `CoolingFan_0 PWM Duty Up to 626!` no tick
seguinte, e `Up to` de novo a cada tick até ≈ 999.

### 4.2 `sbri` ao vivo briga com a escada? **Só quando o alvo da escada muda.** E `sbl` × `sbri`.

- O caminho do `sbri`/`sbl` (`BrightnessControl::RunCheckAndUpdate`, `0x1fc7ac`) chama `Backlight::setLevel`
  **sem** atualizar o estado da política `ctl[+0xc]` (ao contrário do ventilador).
- A política (`0x203176`-`0x2031a8`) pega o **menor** dos dois alvos das `[BacklightPolicy]`, passa por
  `calcBrightnessCurve` e chama `RunStepChange` (`CLASS = 1`) ou **`RunLineChange` (`CLASS = 0`, o instalado)**.
- `RunLineChange` (`0x2024e4`): com `x = ctl[+0xc]`:
  - `x < alvo`: `x = x + ((alvo - x) >> 5) + 1` (subida lenta, `Level Up to`);
  - `x > alvo`: `x = x - ((x - alvo) >> 4) - 1` (descida rápida, `Level Down to`);
  - `x == alvo`: **retorna sem escrever** (`0x20254c`-`0x202550`);
  - grava `ctl[+0xc] = x` e só chama `setLevel(x)` se `|x - Backlight[+0xc]| >= 10` (`0x20257c`-`0x202590`).
- `RunStepChange` (`0x202454`): escreve só se `alvo != ctl[+0xc]`, direto, sem rampa.

**Consequência:** com o `gtt1` abaixo de 66 °C, o alvo da escada fica parado em 1000, `x == alvo`, e um `sbri 0 900`
**fica** (a política não escreve). Quando o `gtt1` cruza um limiar (66, 67,5, ... °C) e o alvo interpolado muda, o
`RunLineChange` dá um passo a partir do **seu** `x` (1000), não do valor do `sbri`, e escreve (diferença ≥ 10): o
brilho **pula de volta para perto do alvo da escada**. Simulação: 1000 → 850 em 44 ticks; 850 → 1000 em 70 ticks.

**`sbl` × `sbri`:** os dois escrevem o mesmo pendente e o mesmo `Backlight::setLevel`; vale o último. A diferença é
a unidade: o `sbl` recebe o **nível cru** (a lista `gbll`, doc 34), o `sbri` recebe brilho 0-1000 e passa por
`calcBrightnessCurve`. Como `FW_BRIGHTNESS_CURVE` = `FW_LEVEL` = `750 ... 1000`, a curva é a identidade nessa faixa
e **satura em 750 abaixo dela**: `sbri 0 500` vira nível 750 (`0x2099d0`: `x <= X[0] → Y[0]`). O `sbl` não passa
pela curva (o `sbl 0` do doc 34 chegou ao piso). INFERIDO: o botão **Luz** da UI usa o caminho do `sbl` (escolhe um
nível da lista); não achei o chamador Java.

### 4.3 A semântica de `FW_SPEED_CURVE` e dos degraus da `[BacklightPolicy]`

`ZYConfig::CoolingFan::initFW` (`0x1d1a8c`) lê `FW_PWM_DUTY` para `+0xc` (`0x1d1c1c`) e `FW_SPEED_CURVE` para
`+0x18` (`0x1d1d10`). `CoolingFan::calcSpeedCurve` (`0x20a498`) é **interpolação linear com `X = FW_SPEED_CURVE`,
`Y = FW_PWM_DUTY`**:

```
X vazio            -> 1000
v >= X[ultimo]     -> Y[ultimo]
v <= X[0]          -> Y[0]
X[i] < v < X[i+1]  -> Y[i] + (v - X[i]) * (Y[i+1] - Y[i]) / (X[i+1] - X[i])
```

`Backlight::calcBrightnessCurve` (`0x209978`) é a mesma conta com `X = FW_BRIGHTNESS_CURVE`, `Y = FW_LEVEL`
(`0x1d85cc`), com uma diferença: X vazio devolve `v != 0` (0 ou 1).

Com o `.ini` instalado:

| `sfs` (velocidade) | `CoolingFan_0` duty | `CoolingFan_1` duty |
|---|---|---|
| ≤ 500 | 200 | 325 |
| 650 | 475 | 575 |
| 725 | 600 | 725 |
| 925 | 850 | 875 |
| 1000 | 1000 | 1000 |

Depois da curva, `RunThermalDualProcess` limita o duty a `[100, 1000]` (`0x2030e0`-`0x203104`). **O `sfs` recebe
velocidade na escala `FW_SPEED_CURVE`, não duty.** Abaixo de 500 não há diferença.

**`[BacklightPolicy]`:** `POLICY_n_THRESHOLD` em m°C do `gtt1` (doc 34), `POLICY_n_BRIGHTNESS` o brilho em cada
limiar, `CLASS = 0` interpola entre limiares (LINE) e `1` degrau (STEP). Com duas políticas, vale o **menor**
brilho (`0x203176 cmp r8, fp; movlo fp, r8`). O brilho da política passa por `calcBrightnessCurve` (identidade aqui)
e pela rampa do §4.2. A `[ThermalPolicy]` é igual para o ventilador, com uma assimetria (corrigida pelo P2): o
`CoolingFan_0` segue o **maior** dos dois alvos (`0x2030d2`); o `CoolingFan_1` segue **só a política 1**
(`0x203128`).

### 4.4 O botão POWER do controle e como fazer o mesmo pelo shell

**O que faz: desliga o Android inteiro; não há standby com RAM.** Evidência:

- `persist.sys.suspend.mode = shutdown` e `persist.sys.suspend = 0` (o `services.vdex` do aparelho tem as strings
  `persist.sys.suspend.mode` e `persist.suspend.mode`);
- o desligamento das 22:45:11 desta sessão: `ShutdownThread-cpu`/`ShutdownThread-screen` no `dumpsys power`,
  `HiMW_logic_system OffOne: setup gpio to mute audio device & set led on`, `SetScartPreSuspend`,
  `ShutdownTiming SystemServerShutdown took 2838ms`; o boot seguinte com `ro.boot.bootreason =
  sys.boot.reason = shutdown,userrequested` e `uptime` de 2 min;
  **Ressalva do P2:** o log desse desligamento não registra tecla nenhuma, e `userrequested` é também o motivo de
  um `svc power shutdown` ou do menu da UI. Que as 22:45 tenham vindo do botão POWER é INFERIDO; o que está provado
  é que um desligamento pedido pelo usuário vira desligamento total;
- o controle é o `Hi keyboard` (IR), cujo `Vendor_0001_Product_0001.kl` mapeia `key 116 POWER` (e `152 POWER`,
  `142 SLEEP`, `143 WAKEUP`) (conferido pelo P2);
- o caminho da tecla (P2, leitura de `/proc/<pid>/fd`): `/dev/hi_ir` → `android_ir_user` (pid 1813, root) →
  `/dev/vinput` → `event0` `Hi keyboard`, aberto só pelo `system_server` (fd 105). Ou seja, a tecla POWER do IR
  chega ao Android como tecla comum de teclado, pelo `InputReader`. O `android_ir_user` tem também
  `hi_unf_pmoc_set_wakeup_condition` e `pmoc_set_wakeup_condition ir power key`: ele programa o microcontrolador
  de standby (PMOC) para **acordar pela tecla POWER do IR**.

Ligar de novo é boot frio. INFERIDO: no "desligado" fica vivo só o microcontrolador de standby da HiSilicon (IR e o
LED, o `set led on` do `OffOne`; o PMOC programado pelo `android_ir_user` reforça isso); nada do Android, nada do
térmico. **Os ventiladores e o LED do projetor ficam sem
controle do firmware nesse estado**; o bloco 23 não deve contar com política térmica em standby.

**Pelo shell (nada foi executado; tudo desliga o aparelho e derruba o adb):**

| Comando | Equivale ao botão? |
|---|---|
| `input keyevent KEYCODE_POWER` (26) | INFERIDO **sim**: é injetado no `InputDispatcher`, depois do `InputReader`, e cai no mesmo `PhoneWindowManager.interceptKeyBeforeQueueing` que a tecla do IR. Não testado (`input` é proibido nesta tarefa) |
| `svc power shutdown` | INFERIDO sim no efeito (no AOSP 9 usa o motivo `userrequested`), sem passar pela política de tecla |
| `reboot -p` | **não**: pula o desligamento ordenado do Android (`ShutdownThread`, o `OffOne` do middleware). Evitar |

## 5. Roteiro de medida (para o coordenador rodar com o dono)

Regras: o gravador só lê props e `/sys`, **nunca `gtt`**, e roda no aparelho porque desligar o Wi-Fi derruba o
adb. Tudo é parado por arquivo de controle. Horários no arquivo saem do relógio do aparelho (+1 h do PC).

### 5.1 O gravador (`/data/local/tmp/grava-temp.sh`)

```sh
#!/system/bin/sh
# Grava a temperatura publicada pelo firmware (props, nunca gtt) a cada INT segundos.
# Para: rm /data/local/tmp/grava-temp.on
INT=${1:-15}
OUT=/data/local/tmp/grava-temp.tsv
MARCA=/data/local/tmp/marca.txt
touch /data/local/tmp/grava-temp.on "$MARCA"
[ -s "$OUT" ] || printf 'epoch\tup_s\tenv_temp\tlight_temp\twlan0\twifi_usb\trfkill_bt\trfkill_wlan\tcpu_busy\tcpu_total\tvplugin_ticks\tmarca\n' > "$OUT"
while [ -e /data/local/tmp/grava-temp.on ]; do
  set -- $(head -1 /proc/stat)            # cpu user nice system idle iowait irq softirq ...
  busy=$(( $2 + $3 + $4 + $7 + $8 )); total=$(( busy + $5 + $6 ))
  vp=0                                    # CPU do hipluginserver (3 processos), utime+stime em ticks
  for p in $(pidof hipluginserver); do set -- $(cat /proc/$p/stat); vp=$(( vp + ${14} + ${15} )); done
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date +%s)" "$(cut -d' ' -f1 /proc/uptime)" \
    "$(getprop zysys.env_temp)" "$(getprop zysys.light_temp)" \
    "$(cat /sys/class/net/wlan0/operstate 2>/dev/null || echo ausente)" \
    "$(cat /sys/bus/usb/devices/1-3/power/runtime_status 2>/dev/null)" \
    "$(cat /sys/class/rfkill/rfkill0/state 2>/dev/null)" \
    "$(cat /sys/class/rfkill/rfkill1/state 2>/dev/null)" \
    "$busy" "$total" "$vp" "$(tail -1 "$MARCA")" >> "$OUT"
  sleep "$INT"
done
```

`zysys.env_temp` é o sensor **quente** (`gtt1`, bloco do LED) e `zysys.light_temp` o frio (`gtt0`, placa); os
nomes estão trocados em relação à física (doc 34). O `cpu_busy`/`cpu_total` são contadores do `/proc/stat`: a CPU
de um intervalo é a diferença entre linhas.

**Ajuste do P2:** a coluna `bt_hci` original (`ls /sys/class/bluetooth`) sai sempre vazia neste aparelho (a classe
não existe), ligado ou não. Foi trocada por `rfkill_bt`/`rfkill_wlan` (`/sys/class/rfkill/rfkill{0,1}/state`; 0 =
bloqueado, 1 = liberado; `rfkill0` é o `bluetooth`, `rfkill1` o `wlan`). Também entrou `vplugin_ticks` (soma de
`utime + stime` dos 3 processos `hipluginserver`, em ticks de 10 ms), que mostra se o P1 da §5.2 baixou a CPU.
O corpo do laço foi rodado uma vez no aparelho, com saída para a tela, sem gravar arquivo:
`... 61.2℃  31.9℃  up active 0 1 122926 735032 63616`. As props de temperatura vêm com `℃` e um espaço no fim:
limpar ao ler. A aritmética do `/proc/stat` está certa. O `toybox 0.7.6` tem `setsid`, `nohup`, `timeout` e
`pidof`.

Subir e deixar rodando sem o adb (o `setsid` e o `nohup` existem no aparelho, `toybox 0.7.6`):

```sh
adb -s 192.168.1.5:5555 push grava-temp.sh /data/local/tmp/
adb -s 192.168.1.5:5555 shell 'chmod 755 /data/local/tmp/grava-temp.sh; setsid nohup /data/local/tmp/grava-temp.sh 15 >/dev/null 2>&1 < /dev/null &'
# marcar um passo (com adb ligado):
adb -s 192.168.1.5:5555 shell 'echo "P2 apps desligados" >> /data/local/tmp/marca.txt'
# fim:
adb -s 192.168.1.5:5555 shell 'rm /data/local/tmp/grava-temp.on'; adb -s 192.168.1.5:5555 pull /data/local/tmp/grava-temp.tsv
```

Antes de começar: conferir que o processo sobrevive a uma desconexão (`adb disconnect`, reconectar, `ps -A | grep
grava`). Não use `logcat` contínuo durante a medida (contamina a CPU, §0.2).

### 5.2 Os passos

Cada passo dura até o `env_temp` parar de subir ou descer (variação < 0,5 °C em 10 min; o ADC tem degrau de
≈ 0,5 °C, doc 34). Brilho, fonte de vídeo, volume e sala constantes; o dono anota a temperatura da sala no início e
no fim. Os passos que derrubam o adb são feitos pelo dono no controle; o gravador registra o estado sozinho
(`wlan0`, `wifi_usb`, `rfkill_bt`, `rfkill_wlan`).

| Passo | Ação | Como | Reverte |
|---|---|---|---|
| P0 | linha de base: Wi-Fi ligado, BT desligado, uso normal como monitor | nada | |
| P1 | silenciar o log do vplugin (§1.4) | `setprop log.tag.HI_VPLUGIN S` e conferir com `logcat -d \| grep -c HI_VPLUGIN` antes/depois | `setprop log.tag.HI_VPLUGIN ""` |
| P2 | desligar os "desligar seguro" da §1.3 | `pm disable-user --user 0` em `org.videolan.vlc`, `com.newlink.autotest`, `com.newlink.factorymenu`, `com.newlink.tvtestingtools`, `com.hikeymasterprovision`, `com.newlink.isuperred.ijkplayerdemo`, `com.android.location.fused` | `pm enable <pacote>` |
| P3 | desligar telemetria/OTA (com cuidado) | `pm disable-user --user 0 com.newlink.service com.newlink.service2`, depois **conferir a home, as teclas de atalho e o tema** | `pm enable` |
| P4 | **Wi-Fi desligado** (o adb cai) | o dono, pela home | o dono, pela home |
| P5 | Wi-Fi ligado de novo, puxar o arquivo | | |
| P6 | modo caixa de som Bluetooth: entrar e sair, para ver se o módulo UART muda a temperatura | o dono, pela UI | |

A leitura que importa é **P0 × P4** (Wi-Fi) e **P0 × P2/P3** (apps). Se P4 der a maior parte dos 5 °C, conferir no
arquivo se o `wifi_usb` continuou `active` com o Wi-Fi desligado: se sim, o chip não dorme e há ganho possível em
autosuspend (precisa de root: `echo auto > /sys/bus/usb/devices/1-3/power/control`). **Descartado em 2026-11-02:**
com `auto` o `aic8800_fdrv` derruba o kernel (§2.2.1); não fazer.

### 5.3 Experimentos de `sfs`/`sbri` ao vivo (só se o bloco 23 precisar confirmar a §4)

O estático fecha as quatro perguntas; estes testes só confirmam. Mudam o ventilador e a imagem, então **só com o
dono presente** e com o `gtt1` abaixo de 66 °C. Ler pelo `logcat -d` depois, nunca contínuo.

**Ressalva do P2 sobre o `logcat -d`:** o buffer `main` tem só **64 KB** (`logcat -g`). Com o vplugin escrevendo
≈ 125 linhas/s, ele cobre **≈ 22 s**. Além disso, o `chatty` poda o uid 0, e essa poda leva junto as linhas do
`hwtvmw` (`PWM Duty Up to`, `Level Up to`). Um `logcat -d` feito 2 min depois do `sfs` **não mostra a rampa**.
Antes destes testes, uma das duas:

- fazer o P1 da §5.2 (`setprop log.tag.HI_VPLUGIN S`); INFERIDO que isso basta para o buffer cobrir minutos;
- ou ler com `logcat -d` várias vezes, a cada ≈ 15 s, para um arquivo **no aparelho**, e puxar depois.
  Exemplo: `logcat -d -s ZYThermalManager > /data/local/tmp/f1-N.txt`. A tag é `ZYThermalManager`, nível `D`;
  visto num `logcat` desta sessão: `D ZYThermalManager: [RunPwmChange:1453] CoolingFan_0 PWM Duty Change 1000 => 1000!`.

| Teste | Comando | Previsão do binário | Volta |
|---|---|---|---|
| F1 | `sfs 0 725` | duty 600 em ≤ 200 ms; na avaliação seguinte (≤ 2 s) `CoolingFan_0 PWM Duty Up to 626!`; volta a ≈ 999 em ≈ 2 min sozinho | sozinho |
| B1 | `sbri 0 900` | brilho 900 e **fica**; nenhum `Level Up to` enquanto o `gtt1` não cruzar 66 °C | `sbri 0 1000` |
| B2 | `sbri 0 500` | nível 750 (satura na curva), não 500 | `sbri 0 1000` |
| B3 | `sbl 0 900` e depois `sbri 0 1000` | o último vence | `sbri 0 1000` |

## 6. Evidência e reprodução

- Coleta de texto: `artifacts/re-termico/coleta-2026-11-01/` (`ps`, `getprop`, `top`, `cpuinfo`, `meminfo`, listas de
  pacotes; a CPU dessa coleta está contaminada, §0.2).
- Desassembly: capstone sobre `artifacts/re-termico/libhitvservice.so`, com os símbolos locais do
  `.gnu_debugdata` (README do diretório). Funções lidas: `RunThermalMngrCommon`, `RunThermalMngrMain`,
  `RunDaulRigalMode`, `RunThermalDualProcess(int,int)`, `FanSpeedControl::{RunCheckAndUpdate, Run, updateSpeed,
  RunPwmChange}`, `BrightnessControl::{RunCheckAndUpdate, Run, RunLineChange, RunStepChange, updateLevel}`,
  `setThermal{FanSpeed, Brightness, BacklightLevel}`, `CoolingFan::{calcSpeedCurve, setPwmDuty}`,
  `Backlight::calcBrightnessCurve`, `ZYConfig::{CoolingFan, Backlight}::initFW`.
- Comandos do aparelho (todos de leitura): `dumpsys {cpuinfo, meminfo, power, alarm, jobscheduler, package,
  activity services, bluetooth_manager, wifi, media.camera, sensorservice, input}`, `getprop`, `ps -A`, `top -b`,
  `cat /proc/{net/tcp,net/tcp6,modules,stat,meminfo,bus/input/devices}`, `ls/cat /sys/class/*`,
  `/sys/bus/usb/devices/*/power/*`, `logcat -d`, `adb pull` de `hipluginserver`, `cmdsrv` e `services.vdex`.
- Conferência do P2 (23:07-23:30, `adbd` já como root, só leitura):
  - `artifacts/re-termico/coleta-2026-11-01/p2-conferencia.txt`: `ss -tlnp`, o socket unix do `cmdsrv`, cmdline e
    contexto do `boa`/`cmdsrv`, as strings do servidor de depuração 4321 no `libhi_msp.so`, `cpuinfo`, as threads e o
    `/proc/msp/vplugin` do `hipluginserver`, `logcat -g`, USB/rfkill/`eth0`, `/proc/msp/i2c`, o caminho do IR;
  - `artifacts/re-termico/p2-cadencia-tick.txt`: o desassembly da cadência (§4), a tabela de módulos, o default do
    `ptms`, o contador do anel e o alvo do ventilador 1.
- Única escrita no aparelho durante a conferência: um arquivo temporário `/data/local/tmp/p2-lc.txt` (cópia do
  `logcat -d`), criado e apagado logo em seguida. Imagem, som, ventilador, props e serviços não foram tocados.

## 7. Conferência do P2 (o que mudou neste doc)

| Seção | Antes (P1) | Depois (P2) |
|---|---|---|
| 0.1, 1.1, 1.4 | `hipluginserver` fora da tabela de CPU; log "falha" de captura | 31% de um núcleo (o maior consumidor); sondagem de 194/s para 60 quadros/s, ~125 linhas/s |
| 0.1, 1.2, 1.5 | porta 4321 = `cmdsrv` | 4321 = servidor de depuração HiSilicon dentro do `hwtvmw`; `cmdsrv` é socket unix local |
| 0.2, 0.3 | sem root; GPIO/I2C "negados" | `adbd` root, SELinux `Permissive`; GPIO/I2C não existem em `/sys`, só em `/proc/msp` |
| 1.1 | CPU por processo lida como fração do total | por processo é de um núcleo; `TOTAL` é de 4 núcleos |
| 2.5 | `dumpsys usb` vazio | tem `host_manager`, sem `port_manager` |
| 4 (cadência) | ≈ 2 s, citando o doc 34 | provado: 33 ms × 6 módulos × anel de 10 ≈ 1,98 s; pendente aplicado em ≤ 200 ms |
| 4.1, 4.3 | com duas políticas, o ventilador segue o maior alvo | só o ventilador 0; o ventilador 1 segue só a política 1 |
| 4.1 | 59 ticks até 999 | PWM em 999 na 58ª avaliação; `x` = 1000 na 59ª, sem escrita; ≈ 117 s |
| 4.4 | desligamento das 22:45 = botão POWER | causa da tecla INFERIDA (o log não tem a tecla); caminho do IR e PMOC provados |
| 5.1, 5.2 | coluna `bt_hci` | `rfkill_bt`, `rfkill_wlan`, `vplugin_ticks` (corpo testado no aparelho) |
| 5.3 | ler a rampa com `logcat -d` depois | buffer de 64 KB ≈ 22 s, e o `chatty` poda: silenciar o vplugin antes ou ler a cada 15 s |
