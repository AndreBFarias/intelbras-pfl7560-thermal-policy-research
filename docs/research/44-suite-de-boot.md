# 44 — Suíte de boot: verificação automática ao voltar da tomada, ao inserir o pendrive e pelo ícone (2026-10-30)

**Estado: pronta em código e provada só em simulação (harness com stubs). Nada disto rodou no aparelho.**
O teste no aparelho é a seção 12, em roteiro único e ordenado. O que depende dele está marcado
**PROVISÓRIO** ao longo do texto e reunido na seção 11.

Origem: o pedido do dono de 2026-10-30, depois do [bloco 8](../sprints/2026-10-30-bloco-8-camera-robusta.md):
ao ligar depois de ficar sem energia, o projetor roda a suíte de correção (câmera, cor, ângulo, foco, imagem,
temperatura) e termina numa tela de resumo em tela cheia; o mesmo ao inserir o pendrive. Decisões e
contratos no [bloco 9](../sprints/2026-10-30-bloco-9-suite-de-boot.md); a pesquisa de firmware que a
sustenta, no [doc 43](43-pesquisa-autofoco-keystone-teclas.md).

---

## 1. O que é

Uma conferência completa da imagem que roda **como root, no aparelho**, sem PC:

| Etapa | O que faz |
|---|---|
| 0. Abertura | tela de aviso de 5 s com os 4 passos; depois espera o autofoco de boot (uma vez) |
| 1. Cor | o `cor.sh` no modo `suite`: lê a escada de 16 cinzas pela câmera interna e, se estiver fora de ordem, troca o formato (VESA/JEIDA) com backup e journal |
| 2. Ângulo, foco e nitidez | projeta a tela de calibração e roda `nl_camcheck faixas` e `geometria` (inclinação, trapézio, bordas, contraste). Foco ruim: refaz o autofoco, até 2 vezes. Imagem torta: dica de nivelar. Borda larga com os 4 pontos ligados: conselho de zerá-los |
| 3. Temperatura | só leitura: `zysys.env_temp` (LED), `zysys.light_temp` (placa), ventoinha e brilho pelo `hidebug` **sem `gtt`**, `.ini` efetivo, escada presente. LED a partir de 66 °C: atenção e dica de ventilação |
| 4. Rampa | teste ativo, fiel ao `--vivacidade` do `pfl7560-saude.sh`: injeta 71000 mC por 40 s, a imagem escurece por cerca de 1 min e volta; limpeza em trap |
| 5. Resumo | tela cheia com 19 itens (cor, imagem, temperatura, sistema), 20 s ou qualquer tecla |

Cada etapa grava seu resultado em `resultados.txt` (`chave=valor`, contrato C-res do bloco 9).

## 2. Como instala

Pelo kit de pendrive, no `newlink_update.sh` (nada de adb):

1. Confere o md5 de **cada** arquivo do kit contra a lista embutida (`KIT_LISTA`) antes de escrever qualquer coisa.
2. Copia o kit para `/data/vendor/pfl7560-kit` (pasta só do root) e dali para `/data/vendor/pfl7560-suite`
   (root, 0700; mesmas regras `dir_seguro`/`arq_seguro` do E3b), só o que tem md5 diferente, por uma pasta de
   preparo, conferido antes de cada `mv`. Idempotente: a 2ª vez nada é regravado.
3. Serviço de boot `/vendor/etc/init/pfl7560-suite.rc`, dentro da janela rw do `/vendor`: montado em
   `/vendor/etc/pfl7560-suite.rc.new`, conferido (conteúdo, `0644`, `root:root`, rótulo `vendor_configs_file`,
   copiado do `init.bigfish.rc` vizinho) e só então movido para a pasta que o init lê. Um `.rc` que não confira
   é removido. Vale a partir do **próximo** boot. O brick de julho veio de `.rc` com modo `0664` e sem rótulo
   ([README](../../README.md)): por isso a conferência.
4. **O app** (`pfl7560.apk`, seção 7): `pm install -r`, a partir da cópia conferida em
   `/data/vendor/pfl7560-kit`, **antes** de lançar a suíte, se o app não está instalado ou se o versionCode é
   outro. Falha de instalação só avisa no log: o kit segue.
5. Lança `suite.sh pendrive` destacado (`setsid`). Se a fase térmica mudou algo, o aparelho reinicia antes (como
   sempre); o app já está instalado nessa altura.

**O ícone "Verificar projetor" só passa a valer no boot SEGUINTE à instalação**: o vigia do pedido é ligado
pelo `suite-boot.sh`, e esse só roda no boot. Antes disso, tocar no ícone grava o pedido e nada o lê. Isto está
dito no `LEIA-ME.txt` do kit; o app não tem como saber se o pedido foi atendido.

**Pendrive pelo PC:** `./install.sh --pendrive <ponto de montagem>` (Windows: `install.bat`, opção 5) copia o
kit inteiro (suíte, `nl_tela`, `fontes/`, APK, `kit/*.png`) e confere o md5 de cada arquivo depois da cópia.
`--com-firmware` (no `.bat`, a pergunta "Incluir o firmware de resgate?") leva também o firmware de resgate:

- `usb_update.bin` na raiz = o `PFL7560.bin` **oficial V1.0.0.9**, tirado do `firmware/Software PFL7560.zip` e
  conferido pelo md5 `28a2f280eee313a4b115567926b2ba4f`. **Nunca** o `Firmware PFL7560.zip`, que é do modelo
  sem USB-C ([doc 42](42-firmware-2026-10-modelo-sem-usbc.md)).
- `firmware-nosso-NAO-GRADUADO/` com `PFL7560-FIX-escada-NAO-GRADUADO.bin` (md5
  `eae3a83db44f790b64b9a5838a27a977`, local only: não vem no git) e um `LEIA-ME.txt` dizendo que **não está
  ativo**, não foi provado no hardware e só vale com a palavra do dono. Nunca com o nome `usb_update.bin`.
- Faltou um dos arquivos de origem ou o md5 não bate: erro claro e **nada** é copiado (as origens são
  conferidas antes de tocar o pendrive; falha no meio remove o firmware). `PFL_FIRMWARE_DIR=<pasta>` aponta
  outra pasta de firmware.

`tests/preparar-pendrive.sh <dispositivo>` formata e prepara do zero: só aceita disco **removível por USB**
(`lsblk` RM=1 e TRAN=usb) sem nada do sistema montado, mostra modelo e tamanho, exige que se **digite** o
caminho do dispositivo, formata FAT32 (`mkfs.vfat -F 32 -n PFL7560`), monta, chama o `install.sh --pendrive ...
--com-firmware` e desmonta. Disco fixo, HD externo USB e cartão interno são recusados sem perguntar. Provado com
`lsblk` e `mkfs.vfat` de mentira; **nunca foi rodado num disco de verdade**.

Um pendrive com `--com-firmware` é o arranjo B do `LEIA-ME.txt` (kit de emergência): ligar **segurando o power**
com ele plugado reflasha o aparelho e apaga o `/data`. Mantenha-o desconectado no uso normal.

## 3. Gatilhos

| Gatilho | Quem dispara | Modo da suíte | Observação |
|---|---|---|---|
| Voltou da tomada | serviço `pfl7560_suite` → `suite-boot.sh`, em `sys.boot_completed=1` | `tomada` | nenhuma tela fala de pendrive |
| Pendrive do kit | o firmware roda o `newlink_update.sh` do pendrive | `pendrive` | a última tela pede para tirá-lo |
| Ícone "Verificar projetor" | o app grava o pedido; o vigia root o lê | `pedido` | só a partir do boot seguinte à instalação |

**Tomada (`suite-boot.sh`).** Sempre registra em `historico-boot.txt` (últimos 30 boots) uma linha com a data, o
`sys.boot.reason`, o `persist.sys.boot.reason`, o `ro.boot.bootreason`, a linha do `dmesg` com `setting system
clock to` (o ano do relógio no boot), o RTC, o resumo de `/proc/msp/pm`, o contador `incompletas` e a decisão.
O modo vem do arquivo `/data/vendor/pfl7560-suite/gatilho`: `auto` (padrão), `sempre` ou `nunca`. Em `auto`,
roda se **algum**: (a) o ano do relógio no boot é menor que 2020 (o RTC zerou: ficou sem energia); (b) o
`sys.boot.reason` não começa com `shutdown,` nem `reboot,` (o desligamento não foi limpo). **PROVISÓRIO:** o
valor depois de faltar energia com o projetor ligado não foi medido; o histórico existe para calibrar isto.

Não roda: se a suíte terminou há menos de 10 minutos (proteção contra laço); se há um pendrive com
`newlink_update.sh` montado (o fluxo do pendrive cobre; registra e sai); se outra instância tem a trava
(`/dev/pfl7560-suite.lock`); se duas suítes seguidas começaram e não chegaram ao fim (arquivo `incompletas`; o
histórico registra o motivo `interrompida_2x_seguidas`). Uma suíte pelo pedido ou pelo pendrive que **termine**
zera o contador.

**Pedido do app.** O app grava `pedir-verificacao` na **pasta privada dele**,
`/data/data/com.pfl7560.verificar`. O vigia (`inotifyd` na pasta, eventos `w` e `y`; sem `inotifyd`, um laço de
30 s) chama o `suite-pedido.sh`, que: aceita só o arquivo `pedir-verificacao`; exige que seja um arquivo
**regular** (um link é recusado) cujo **dono seja o dono da pasta**, com UID de app (≥ 10000); apaga o arquivo;
respeita a trava e os 10 minutos; e lança `suite.sh pedido` com o md5 conferido na hora. Por que a pasta
privada: em `/sdcard` qualquer app gravaria o arquivo e dispararia, como root, uma suíte com a rampa ativa
(revisão de segurança de 2026-10-30, commit `3c92cdb`). **Consequência para quem usa:** um pedido feito até 10
minutos depois do fim de outra suíte é ignorado em silêncio (a tela do app diz "Verificação pedida" de
qualquer modo, porque o app não sabe).

## 4. Etapas, em detalhe

1. **Abertura** (`aviso`): título por modo ("Voltou a energia. Conferindo o projetor.", "Pendrive do kit
   encontrado. Conferindo o projetor.", "Verificação pedida. Conferindo o projetor."), 4 passos em `fila`,
   rodapé "não precisa apertar nada". 5 s. Depois `aguardar_autofoco` (uma vez): espera `sys.newlink.auto`
   (doc 43 §2.3), não `vendor.focus.camera.is_focused`, que não indica fim de foco.
2. **Cor:** prepara `/data/vendor/pfl7560-kit` a partir da pasta da suíte e roda `cor.sh <mp ou vazio> <aviso>
   <md5> suite`. No modo `suite` o `cor.sh` não mostra a tela final e grava `cor-resultado.txt`
   (`ordem|corrigido|manual_mantido|manual_trocado|erro`, formato antes e depois, faixas). Sem pendrive, backup e
   journal ficam na pasta da suíte (persistente).
3. **Ângulo, foco e nitidez:** `nl_camcheck faixas` e `geometria` (contrato C-geo). Foco ruim = borda de um lado
   maior que 1,6 vezes a do centro, ou maior que `LIMIAR_BORDA_PX`: refaz o autofoco
   (`am startservice -n com.zhiying.autofocus/.AutoFocusService -a com.zhiying.AUTO_FOCUS_SERVICE --ei
   auto_focus_keystone 0`, doc 43 §2.1), espera `sys.newlink.auto` ir a 1 (até 5 s) e a 0 (até 70 s) e mede de
   novo, até 2 vezes. Inclinação maior que 1,5° ou trapézio maior que 3 %: dica de nivelar; **com os 4 pontos
   ligados** (`persist.sys.keystone.*`), vira o conselho de zerá-los, porque a câmera é presa ao projetor e o
   que ela vê inclinado vem da correção. Câmera falhou: itens `pendente`, a suíte segue.
4. **Temperatura:** ver seção 1. Sem `hidebug gtt` (o `gtt` força o mux e é suspeito do "LSADC Error": doc 35).
5. **Rampa:** só injeta se o `WARNING_VALUE` e o `EMERGENCY_VALUE` do `.ini` efetivo, lidos agora, deixam 71000
   entre os dois; exige o `.ini` com o md5 de um corrigido e o LED abaixo de 66 °C (o override mascara o
   sensor por 40 s). 71000 fixo, nunca configurável; 75000 desliga o aparelho. Trap EXIT/INT/TERM/HUP limpa e
   confere lendo de volta. O override não é persistente: um SIGKILL (que pula o trap) se desfaz no boot.
6. **Resumo:** 19 itens, na ordem do dono (cor: formato, câmera, painel; imagem: resolução, ângulo, foco,
   nitidez, 4 pontos, modo de projeção; temperatura: LED, placa, brilho, ventoinha, rampa; sistema: firmware,
   correção térmica, Wi-Fi, motivo do boot, data e hora). Até 3 dicas. Depois, `force-stop` da galeria e
   `input keyevent KEYCODE_HOME`. No modo `pendrive` ainda vem a tela "Pode tirar o pendrive." até ele sair (até
   60 s); com a fase térmica do kit falhando, essa tela sai em alerta e manda ver o `newlink_update.log`.

## 5. Telas

Geradas no aparelho pelo `nl_tela` (C, NDK; contrato C-tela; IBM Plex, licença OFL) em PNG 1920×1080 e abertas
pela galeria: `force-stop` do pacote resolvido e `am start` (o mesmo `mostrar` do `cor.sh`); nome único por
execução (a galeria guarda cache). Se o `nl_tela` falhar, vão os PNG estáticos do kit. Nos modos `tomada` e
`pedido` as de reserva são só `aguarde` e `calibracao` (`pronto` e `erro` falam de pendrive); sem o `nl_tela`,
o resumo não aparece e o resultado fica só no `resultados.txt`. Visual: fundo `#0E1116`, cartões `#171B21`,
estados ok `#6FD6A6`, corrigido `#F2B451`, atenção `#F07560`; margem de 110 px; nada passa da margem (corta com
reticências e avisa). Detalhes em [`artifacts/tela/README.md`](../../artifacts/tela/README.md).

## 6. Arquivos

No aparelho:

| Caminho | O quê |
|---|---|
| `/data/vendor/pfl7560-suite/` (root, 0700) | a suíte: `suite.sh`, `suite-boot.sh`, `suite-pedido.sh`, `cor.sh`, `lvdsctl`, `nl_camcheck`, `nl_tela`, `kit/*.png`, `fontes/*` |
| `…/ultimo.log`, `resultados.txt` | o relatório da última suíte e as medidas brutas (`chave=valor`: `geo_inclinacao_graus`, `geo_borda_centro_px`, `temp_led_c`, `cor_resultado`, `foco_tentativas`, `rampa`, …) |
| `…/historico-boot.txt` | os sinais de cada boot (últimos 30), `incompletas=N` e a decisão |
| `…/gatilho`, `incompletas`, `ultimo-fim` | modo do gatilho (`auto`, `sempre`, `nunca`), contador de suítes interrompidas, hora do fim da última |
| `…/boot.log`, `vigia.log`, `lancador.log`, `cor-resultado.txt`, `panelparam-backup-<serial>.img` | saída do serviço, do vigia e do lançador; resultado da cor; backup da `panelparam` do modo sem pendrive |
| `/vendor/etc/init/pfl7560-suite.rc` (0644 root:root, `vendor_configs_file`) | o serviço de boot |
| `/data/data/com.pfl7560.verificar/pedir-verificacao` | o pedido do app (some depois de lido) |
| `/sdcard/pfl7560-suite/` | os PNG que a galeria abre |
| `/dev/pfl7560-suite.lock`, `/dev/pfl7560-suite.vigia` | a trava e o pid do vigia (somem no reboot) |
| `/data/vendor/pfl7560-kit/` | a pasta de trabalho do kit (`cor.sh`, `journal`, backup) |

No pendrive (modo `pendrive`): `newlink_update.log`, `newlink_cor.log`, `newlink_suite.log` e, quando a cor
troca o formato, `panelparam-backup-<serial>.img` com `.md5`.

## 7. O app

Pacote `com.pfl7560.verificar`, `minSdk 28`, `targetSdk 28`, **nenhuma permissão**. Fonte em
[`artifacts/app/`](../../artifacts/app/README.md); `artifacts/app/build.sh` monta o APK sem Gradle (`aapt2`,
`javac --release 8`, `d8`, `zipalign`, `apksigner`) e é determinístico. Duas atividades, com ícone próprio e
`LAUNCHER` (o launcher lista só `MAIN` + `LAUNCHER` com `loadIcon`: doc 43 §6; o `LEANBACK_LAUNCHER` e o banner
vão junto porque custaram pouco):

- **Verificar projetor:** grava `pedir-verificacao` em `getDataDir()` com `FileOutputStream` (o arquivo nasce com
  o dono certo), mostra por 3 s "Verificação pedida. O projetor começa em instantes." e fecha. Se não conseguir
  gravar, diz isso e o que fazer.
- **Wi-Fi:** abre `android.settings.WIFI_SETTINGS`; se não resolver, `com.zhiying.settings/.network.WifiSettingActivity`
  (a tela escondida aberta na parede em 2026-10-30); se nada abrir, mostra a mensagem e fecha.

Assinado com a chave estável `artifacts/app/assinatura.keystore` (senha no `build.sh`; não é segredo: só garante
que um APK novo instale por cima do anterior). Versão: `VERSAO_CODIGO` no `build.sh` e `APP_VERSION_CODE` no
`newlink_update.sh` têm de ser iguais (o harness confere, e confere com o `aapt2 dump badging`). Para publicar
uma versão nova: subir os dois números, `bash artifacts/app/build.sh`, `bash tests/atualizar-md5-kit.sh`.

## 8. Como desligar

- **Parar de vez, pelo pendrive:** um arquivo **vazio** `DESINSTALAR-SUITE.txt` na raiz e ligar com ele
  plugado. O `newlink_update.sh` chama `suite.sh --desinstalar <pendrive>` em vez de instalar: leva para o
  pendrive a cópia do backup da `panelparam` que a suíte guardou no aparelho, como
  `suite-panelparam-backup-<serial>.img` (com `.md5`, conferida com `cmp`); para o serviço (`ctl.stop`) e o
  vigia; limpa o override de temperatura se a suíte morreu no meio da rampa; remove o `.rc` (com remount), a
  pasta da suíte, a pasta das telas e o pedido pendente; e o kit roda só a fase de cor, como antes do bloco 9.
- **Só o gatilho da tomada:** `adb shell 'echo nunca > /data/vendor/pfl7560-suite/gatilho'` (root). O pedido
  pelo ícone e o pendrive continuam.
- **O app não sai com a suíte:** a pasta é dele. Tirar: `adb uninstall com.pfl7560.verificar`. Sem a suíte, o
  ícone não faz nada.

## 9. Limites e riscos conhecidos

- **Telas a partir de `/sdcard/pfl7560-suite`:** um app poderia trocar o PNG entre a gravação e a exibição e
  mostrar uma tela falsa. O impacto é só visual: o sdcardfs não aceita links simbólicos, então a troca não vira
  escrita como root em outro lugar. É o caminho que o `cor.sh` já usa e que foi provado no aparelho.
- O `suite-boot.sh` roda pelo init sem conferência de md5 (um `.rc` não confere nada): a garantia é a pasta ser
  só do root dentro de `/data/vendor` (0771 root). O `inotifyd` executa o `suite-pedido.sh` a cada evento com o
  md5 conferido só ao ligar o vigia (mesma garantia).
- O trap da rampa só roda quando o `sleep 40` em primeiro plano acaba: um TERM no meio limpa o override no
  máximo 40 s depois (o mesmo tempo que ele duraria).
- **Pendrive deixado plugado:** a suíte (com a rampa) roda a cada boot pelo fluxo do pendrive, e a proteção de
  `incompletas` não vale para ele (como o `cor.sh` antes). Tire o pendrive.
- Sem o app instalado, o vigia não liga e o log diz isso.
- O pedido do app dentro dos 10 minutos do fim de outra suíte é ignorado sem aviso na tela.
- `inotifyd`: pelo código do toybox e do busybox, `y` é "movido para dentro" e `m` "movido para fora" (a ajuda
  de uma das versões diz o contrário). O teste 6 confirma.

## 10. Não feito, e por quê

- **Tecla do controle que chama a suíte.** Pela pesquisa ([doc 43](43-pesquisa-autofoco-keystone-teclas.md)
  §4), não é possível com confiança: o mapa de teclas é fixo no `PhoneWindowManager`, e a única ação
  configurável vem das props `vendor.nl.facir.{7,8,9}.*`, presas às teclas de fábrica `NEWLINK7..9`, que o
  controle comum provavelmente não tem (a tabela IR→scancode do `android_ir_user` não foi decodificada). Mesmo
  configurada, a ação seria um componente Android, não um script. Nada foi implementado para teclas.
- **Item no menu de configurações.** O menu é do app do fabricante (`com.zhiying.settings`) e não tem ponto de
  extensão conhecido. O ícone "Verificar projetor" na lista de apps cobre o pedido.
- **Ajuste automático dos 4 pontos.** A suíte mede e aconselha zerar; escrever as props de keystone não tem
  caminho por shell que faça o mesmo que a tela oficial (doc 43 §3). O conselho deve abrir a `FourPointActivity`.
- **Colocar o app direto na fileira da tela inicial:** não se achou modo (doc 43 §6). Ele fica na lista de apps.
- **Desinstalar o app junto com a suíte:** não foi pedido; fica o comando da seção 8.

## 11. O que ficou PROVISÓRIO (o teste no aparelho confirma)

| Item | Onde | O que confirmar |
|---|---|---|
| Critérios do gatilho `auto`: `ANO_MIN=2020`, prefixos `shutdown,`/`reboot,`, `ESPERA_MONTAGEM=20` | `suite-boot.sh` | o que o aparelho mostra depois de faltar energia com ele ligado (o `historico-boot.txt` guarda os sinais) |
| `SINAL_INCLINACAO=1` e se a câmera vê alguma inclinação real | `suite.sh` | teste 10: o sinal de `geo_inclinacao_graus` com uma inclinação proposital |
| `LIMIAR_BORDA_PX_1280=3.5` (proporcional à largura) | `suite.sh` | bordas reais no aparelho (o 640×480 real passaria dele) |
| `AUTOFOCO_FOLGA=5` e a espera por `sys.newlink.auto` | `suite.sh` | teste 11 |
| Leitura de `persist.sys.mountingmode` (o rótulo do menu não foi provado) e a unidade de `fan speed` (0 = parada) | `suite.sh` | comparar com o menu e o `hidebug` |
| `inotifyd` no toybox do Android 9 e o evento de escrita do app na pasta ext4 | `suite-boot.sh` | teste 5 e 6 |
| `logcat -T 1` no Android 9 (sem ele: "não reagiu" falso, nunca injeção sem limpeza) | `suite.sh` | teste 12 |
| `pm install -r` a partir de `/data/vendor/pfl7560-kit`, como root no `exec` do init | `newlink_update.sh` | teste 1 |
| Formato do `top` do Android 9 (toybox, `S[%CPU]`) no `pfl7560-processos.sh` | `pfl7560-processos.sh` | teste 14 |
| Tempo de geração e abertura do PNG do `nl_tela` pela galeria | `nl_tela`, `suite.sh` | teste 13 |
| `tests/preparar-pendrive.sh` e a opção 5 do `install.bat` com firmware | `tests/`, `install.bat` | teste 15 (o `.bat` e o `.ps1` nunca rodaram: não há Windows aqui) |

## 12. Teste no aparelho

O roteiro único, **em ordem**, que o coordenador segue com o dono. Cada passo tem o comando e o que se espera
ver. `IP` é o do projetor; os comandos de `adb` valem com `adb connect $IP:5555` e, quando o passo diz
"root", depois de `adb root` (o aparelho é `eng`). Lembrete: o adb só responde pela rede e o Wi-Fi do projetor
só fica ativo na **tela inicial** do Android (não numa fonte HDMI externa). Defina antes:
`S=/data/vendor/pfl7560-suite`.

**Antes de tudo (P0).** Prepare dois pendrives FAT32: um **sem firmware** (`./install.sh --pendrive <ponto>`),
para os testes 1 a 15, e, depois, o de resgate (`--com-firmware`; teste 16). Rode `PFL_IP=$IP ./pfl7560-saude.sh`
e anote o resultado (a linha de base). Espera: tudo verde.

1. **Instalar pelo pendrive real.** Com o projetor desligado, plugue o pendrive e ligue.
   Esperado: a térmica já está aplicada, então **não reinicia**; aparece a abertura "Pendrive do kit encontrado.
   Conferindo o projetor.", as telas das etapas, o resumo de 20 s com 19 itens e por fim "Pode tirar o
   pendrive". No pendrive: `newlink_update.log`, `newlink_cor.log`, `newlink_suite.log`. Se aparecer
   "AJUSTANDO", espere o reboot e a suíte roda de novo no boot seguinte (com o pendrive ainda plugado).
2. **Conferir a instalação.**
   `adb shell "ls -ld $S; ls -lZ /vendor/etc/init/pfl7560-suite.rc; pm list packages --show-versioncode com.pfl7560.verificar; tail -30 $S/ultimo.log"`.
   Esperado: pasta `drwx------ root`; `.rc` `-rw-r--r-- root root` com `vendor_configs_file`; o pacote com
   `versionCode:1`; no `newlink_update.log`, `[OK] app: ... instalado` e `[OK] suite: servico de boot instalado`.
3. **Idempotência.** Desligue, plugue o mesmo pendrive, ligue. Esperado: `suite: arquivos ja estavam em dia`,
   `app: ... ja estava instalado`, `servico de boot ja estava instalado`; a suíte roda de novo (modo pendrive)
   sem regravar nada; o aparelho não reinicia.
4. **Boot normal, sem pendrive.** Desligue pelo botão ou controle, tire o pendrive, ligue.
   `adb shell "tail -3 $S/historico-boot.txt; cat /dev/pfl7560-suite.vigia; tail -5 $S/boot.log; ps -A | grep -e inotifyd -e pfl7560"`.
   Esperado: uma linha nova no histórico com `boot_reason=shutdown,userrequested` (ou parecido), `decisao=nao` e
   `motivo=desligamento_limpo`; o vigia ligado (`inotifyd` ou laço) e o `boot.log` dizendo qual. **Anote**
   todos os sinais da linha: calibram o gatilho.
5. **Os dois ícones.** Na tela inicial/lista de apps devem existir "Verificar projetor" e "Wi-Fi". Toque em
   **Wi-Fi**: abre a tela de Wi-Fi (`WIFI_SETTINGS`; se não, a do fabricante). Toque em **Verificar projetor**:
   mensagem "Verificação pedida" por 3 s e a abertura "Verificação pedida. Conferindo o projetor." em instantes;
   `adb shell "tail -5 $S/vigia.log; ls -ln /data/data/com.pfl7560.verificar/"` mostra a linha "pedido de
   verificacao recebido" e a pasta sem o arquivo. Toque de novo **antes de 10 minutos**: nada acontece e o
   `vigia.log` diz "terminou ha menos de 10 min - pedido ignorado". Se o ícone não aparecer: o launcher não
   lista por `LAUNCHER`; olhar `dumpsys package com.pfl7560.verificar` (doc 43 §6 diz que lista).
6. **Pedido que não é do app.** Root: `adb shell "touch /data/data/com.pfl7560.verificar/pedir-verificacao"`
   (o dono é o root, não o app). Esperado: o `vigia.log` diz "o pedido nao veio do app (dono do arquivo nao e o
   da pasta do app) - ignorado" e **nenhuma suíte** começa. Remova o arquivo se sobrar (`rm`). Este é o caso que o
   harness não consegue montar sem root.
7. **Voltar da tomada com o projetor ligado.** Com a tela inicial no ar, tire o cabo de energia, espere 10 s,
   religue. Esperado: a suíte roda sozinha ("Voltou a energia. Conferindo o projetor.", **sem** a palavra
   pendrive), resumo de 20 s; `adb shell "tail -2 $S/historico-boot.txt; head -20 $S/ultimo.log"` com o motivo
   `queda de energia` e os sinais (relógio, `sys.boot.reason`). **Se não rodar:** copie a linha do histórico, e
   para o resto do teste use `adb shell "echo sempre > $S/gatilho"` (voltar a `auto` no fim); o critério `auto`
   precisa ser refeito com os sinais reais.
8. **Desligar pelo controle e religar.** Esperado: a suíte **não** roda (se os sinais permitem distinguir
   do passo 7); se rodar, decidir com o dono (o `gatilho` e os critérios, seção 3).
9. **VESA à mão + tirar da tomada.** `adb shell "$S/lvdsctl fmt 0"` (grava VESA), confirme que a imagem ficou
   com cinzas tingidos, tire da tomada e religue. Esperado: a suíte corrige para JEIDA sozinha; resumo com "Formato
   do painel: VESA → JEIDA" em `corrigido` e "1 correção feita"; `adb shell "cat $S/cor-resultado.txt; ls $S/panelparam-backup-*"`
   (resultado `corrigido`, backup na pasta da suíte). `PFL_IP=$IP ./pfl7560-saude.sh`: a checagem de cor
   passa. **Guarde esse backup**: o passo 15 o leva para o pendrive.
10. **Inclinar de propósito.** Calce um dos pés por uns 2° e toque em "Verificar projetor" (espere 10 min desde a
    última suíte). `adb shell "grep -E 'geo_|quatro_pontos|dicas' $S/resultados.txt"`. Esperado:
    `geo_inclinacao_graus` com módulo perto do real e a dica "Imagem inclinada: abaixe o pé ..." (se os 4 pontos
    estão ligados, o conselho é zerá-los). **Confirme o lado:** a dica diz esquerdo ou direito conforme
    `SINAL_INCLINACAO` (`suite.sh`); se estiver trocado, inverta a constante (`1` ↔ `-1`), rode
    `bash tests/atualizar-md5-kit.sh` e regrave o pendrive. Anote também as bordas, o trapézio e o contraste reais
    para calibrar `LIMIAR_BORDA_PX_1280`.
11. **Foco.** Desfoque a imagem à mão (se a lente permitir) ou use a tela em foco ruim e peça uma verificação.
    `adb shell "grep -i foco $S/ultimo.log; grep foco_tentativas $S/resultados.txt"`. Esperado: o autofoco
    refeito (`sys.newlink.auto` 1 e depois 0, no máximo 70 s) e a medida repetida, até 2 vezes; o item "Foco" do
    resumo coerente.
12. **A rampa.** Durante uma suíte, observe a etapa 4: a imagem escurece por cerca de 1 min e volta sozinha.
    `adb shell "getprop vendor.zy.power.tm.temp; logcat -d -s ZYThermalManager | tail -8; grep rampa $S/resultados.txt"`.
    Esperado: a prop **vazia**; no log `Overheat Warning` e `Level Change X => 850!` e depois `=> 1000!`;
    `rampa_limpeza` ok. Em seguida `PFL_IP=$IP ./pfl7560-saude.sh --vivacidade` verde.
13. **As telas.** Durante a suíte, `adb exec-out screencap -p > resumo.png` (ou fotografe a parede). Esperado: a
    galeria abre os PNG do `nl_tela` sem truncar texto, sem cortar na margem, com o resumo legível; anote o tempo
    entre a etapa e a tela. Se o `nl_tela` falhar, o `ultimo.log` diz e vão as telas estáticas.
14. **Processos em repouso.** Espere 10 min depois da última suíte, deixe o projetor na tela inicial, sem nada
    aberto, e rode `PFL_IP=$IP ./pfl7560-processos.sh` (60 s; só leitura). Esperado: o resumo em
    `evidencias/processos/<data>.txt` com os 10 que mais gastam; **se disser "nao reconheci uma tela do top",**
    guarde a saída crua (`adb shell top -b -n 2 -d 5`) e ajuste o parser com ela (o formato do Android 9 não foi
    visto). Anote a carga média e quem aparece em estado D: é a resposta à pergunta do dono sobre processos em
    segundo plano.
15. **Desinstalar e reinstalar.** Crie `DESINSTALAR-SUITE.txt` (vazio) na raiz do pendrive, plugue e ligue.
    Esperado: `adb shell "ls $S; ls /vendor/etc/init/pfl7560-suite.rc"` não acham nada; o vigia não existe mais;
    no pendrive aparece `suite-panelparam-backup-<serial>.img` (do passo 9) com `.md5`; o kit roda só a cor. O
    app continua instalado. **Deixe tudo como o dono quer:** apague o `DESINSTALAR-SUITE.txt`, rode o pendrive de
    novo (reinstala a suíte) e reinicie uma vez para o vigia voltar.
16. **O pendrive de resgate (sem ligar segurando o power).** Prepare `sudo bash tests/preparar-pendrive.sh /dev/sdX`
    num pendrive que possa ser apagado (**confira o dispositivo duas vezes**). No PC:
    `md5sum <ponto>/usb_update.bin` deve dar `28a2f280eee313a4b115567926b2ba4f`;
    `ls <ponto>/firmware-nosso-NAO-GRADUADO/` com o `.bin` e o `LEIA-ME.txt`. Plugue-o no projetor **ligado
    normalmente** (sem segurar o power): a suíte roda como no passo 1 e o firmware não é tocado. **Não** teste o
    power-hold. No Windows, repita a opção 5 do `install.bat` com a pergunta do firmware e o mesmo `md5sum`.
17. **Fechamento.** `PFL_IP=$IP ./pfl7560-saude.sh` e `--vivacidade` verdes; `gatilho` de volta em `auto`;
    `$S/ultimo.log` sem `[ERRO]`. Registre o resultado de cada passo na seção "Estado" das tarefas 9, 9A, 9B e
    9C.
