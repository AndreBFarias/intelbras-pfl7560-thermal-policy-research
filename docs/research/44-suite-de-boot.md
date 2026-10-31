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
| 2. Ângulo, foco e nitidez | projeta a tela de calibração e roda `nl_camcheck faixas`, `geometria` (inclinação, trapézio, bordas, contraste) e `nitidez` (mapa 3x3). Foco ruim: refaz o autofoco, até 2 vezes, e depois a varredura fina do motor pelo `hidebug` (§16). Imagem torta: dica de nivelar. Borda larga com os 4 pontos ligados: conselho de zerá-los; cantos de um lado borrados: dica pela causa |
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
4. **O app** (`pfl7560.apk`, seção 7) entra como **app do sistema**, em `/vendor/app/PFL7560/PFL7560.apk`.
   - É gravado na mesma abertura rw do `/vendor` que o `.rc` usa, **antes** de lançar a suíte.
   - Vem da cópia conferida em `/data/vendor/pfl7560-kit`.
   - Fica com pasta 0755, arquivo 0644, dono root e rótulo `vendor_app_file`.
   - Só é regravado se faltar ou estiver diferente.
   - Vale a partir do **próximo** boot.
   - O `pm install` deste firmware recusa qualquer app de fora (`INSTALL_FAILED_INVALID_INSTALL_LOCATION`), o que
     foi visto no aparelho em 2026-10-30. O sistema varre o `/vendor/app` no boot, como faz com o
     `KeymasterProvisionDemo` de fábrica, e o app aparece com `flags=[ SYSTEM ]`.
   - Uma falha de instalação só avisa no log, e o kit segue.
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
  outra pasta de firmware; `./install.sh --conferir-firmware` só confere as origens, sem copiar.
- Só para o aparelho **com USB-C** (V1.0.0.9). No modelo sem USB-C (V1.0.0.1) este `usb_update.bin` não serve.

`tests/preparar-pendrive.sh <dispositivo>` formata e prepara do zero: só aceita disco **removível por USB**
(`lsblk` RM=1 e TRAN=usb), informado como o disco inteiro ou uma partição dele, sem nada do sistema montado;
confere o firmware (arquivos e md5, pelo `install.sh --conferir-firmware`) **antes** de formatar; mostra modelo e
tamanho, exige que se **digite** o caminho do dispositivo, formata FAT32 (`mkfs.vfat -F 32 -n PFL7560`), monta,
chama o `install.sh --pendrive ... --com-firmware` e desmonta. Disco fixo, HD externo USB, cartão interno e
dispositivo mapeado (crypt, LVM) são recusados sem perguntar. Provado com `lsblk` e `mkfs.vfat` de mentira;
**nunca foi rodado num disco de verdade**.

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
roda se **algum** dos critérios abaixo valer.

- **(m) A marca.** É o critério que vale neste aparelho. O PFL7560 não tem relógio com bateria: não existe
  `/sys/class/rtc/rtc0`, e o boot começa numa data fixa até a rede acertar a hora. E o motivo do boot apenas
  repete o do último desligamento limpo. Por isso nenhum dos dois, sozinho, diz que a energia caiu.
  - Depois de ler os sinais, a cada boot, o `suite-boot.sh` grava `pfl7560,ligado` em
    `persist.sys.boot.reason`.
  - Um desligamento ou reboot limpo sobrescreve essa marca (`shutdown,userrequested`, `reboot,shell`).
  - Se a marca chega viva ao boot seguinte, a energia caiu com o projetor ligado: `motivo=queda_de_energia`.
  - **Provado no aparelho em 2026-10-30** (`evidencias/boot-tomada/`). Um reset sem desligamento (`sysrq b`, o
    mesmo que tirar da tomada ligado) deixou `pfl7560,ligado` em `sys.boot.reason`, `persist.sys.boot.reason` e
    `ro.boot.bootreason`. Um reboot limpo com a marca gravada deu `reboot,shell`.
  - Com `gatilho=nunca`, a marca não é gravada. O desinstalar a apaga.
  - Limite: um corte antes do fim do boot anterior (antes do `sys.boot_completed`) não deixa a marca e não é
    detectado.
- **(a) O relógio zerado.** O ano do relógio no boot menor que 2020. Não tem efeito neste aparelho, que não tem
  RTC; fica para outro hardware.
- **(b) O desligamento não limpo.** O `sys.boot.reason` não começa com `shutdown,` nem `reboot,` (por exemplo
  `kernel_panic` ou vazio).

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
   sem rodapé. 5 s. Depois `aguardar_autofoco` (uma vez): espera `sys.newlink.auto`
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
   que ela vê inclinado vem da correção. Câmera falhou: itens `pendente`, a suíte segue. Bloco 11 (§16): o mapa
   de nitidez 3x3 a cada medida e, com o foco ainda ruim depois dos autofocos, a varredura fina do motor.
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

### Achados do primeiro teste no aparelho (2026-10-30), já no código

| Achado | O que a suíte faz |
|---|---|
| Avisos do sistema por cima da imagem cobrem as faixas que a câmera lê. Com o aviso "Temperatura anormal" (da rampa) a câmera leu 8 e 14 de 16 faixas; com o "Dispositivo conectado. Deseja abrir HDMI1?" leu 5; sem eles, 16 de 16 | Antes de cada tela, fecha o aviso focado. O de temperatura (`com.newlink.nlprovision`) só tem OK, então recebe ENTER. Os outros recebem BACK, que cancela: no da HDMI o botão em destaque é o de ABRIR, e ENTER trocaria de entrada. O descanso de tela também sai com BACK |
| A câmera pode falhar mesmo assim | Até 3 leituras, com o autofoco refeito entre elas. Se ainda falhar, a tela "A câmera não conseguiu ler a tela." espera uma tecla do controle **sem prazo**: a etapa não avança sozinha (pedido do dono). Na cor, a conferência segue à mão com a pessoa presente. Na geometria, são mais 3 leituras; se falharem, a etapa fica "pendente", para que uma câmera quebrada não trave o projetor |
| O `awk` do Android 9 recusa `exit` com negação (`illegal arithmetic operator`): o "LED quente" nunca seria detectado | `if ... exit 0; exit 1`; um teste estático proíbe a forma antiga |
| O `inotifyd` do toybox ignora a 1ª letra da máscara (`:wy` vigiava só `y`) | Máscara `:wwy`; um pedido que já estava na pasta é tratado quando o vigia liga |
| O `pm install` recusa apps de fora | O app vai para `/vendor/app` (seção 2) |
| Pedido do dono: nenhuma frase nem rótulo começa com minúscula | O `nl_tela` põe maiúscula na 1ª letra de cada texto e depois de `. `, `! `, `? ` e ` · ` ("Agora", "Na fila", "Feito", "Nítido") |

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

Desde o bloco 16B o app tem também o descanso de tela `.Descanso` (§14), um serviço sem ícone; o APK leva a
fonte Plex Condensed Bold em `assets/` (`versionCode` 3).

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
- **O descanso de tela volta ao do fabricante** no mesmo `--desinstalar` (§14): se `screensaver_components` ou
  `screensaver_default_component` ainda apontam para o `com.pfl7560.verificar`, voltam para
  `com.newlink.screensaver/com.newlink.screensaver.ScreenService`. Se o dono escolheu outro, não se mexe.
- **O bloco 14 também volta** no mesmo `--desinstalar` (§15): sobreposições de tema desligadas e removidas, a
  prop do gerenciador de arquivos tirada, Office/iOSCast/Espelhamento religados e a marca de fábrica restaurada.
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
| `ESPERA_MONTAGEM=20` e a marca `pfl7560,ligado` com o cabo de verdade | `suite-boot.sh` | o mecanismo da marca foi provado com `sysrq b`; o passo 7 confirma com o cabo tirado com o projetor ligado |
| `SINAL_INCLINACAO=1` e se a câmera vê alguma inclinação real | `suite.sh` | teste 10: o sinal de `geo_inclinacao_graus` com uma inclinação proposital |
| `LIMIAR_BORDA_PX_1280=3.5` (proporcional à largura) | `suite.sh` | bordas reais no aparelho (o 640×480 real passaria dele) |
| `AUTOFOCO_FOLGA=5` e a espera por `sys.newlink.auto` | `suite.sh` | teste 11 |
| Leitura de `persist.sys.mountingmode` (o rótulo do menu não foi provado) e a unidade de `fan speed` (0 = parada) | `suite.sh` | comparar com o menu e o `hidebug` |
| `inotifyd` no toybox do Android 9 e o evento de escrita do app na pasta ext4 | `suite-boot.sh` | teste 5 e 6 |
| `logcat -T 1` no Android 9 (sem ele: "não reagiu" falso, nunca injeção sem limpeza) | `suite.sh` | teste 12 |
| App em `/vendor/app` pelo `exec` do init (pendrive real) | `newlink_update.sh` | teste 1 e 2: o `[OK] app` no `newlink_update.log`. Já provado pela instalação por rede em 2026-10-30, com `codePath=/vendor/app/PFL7560` e `flags=[ SYSTEM ]` |
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
   `vigia.log` diz "a suite terminou ha menos de 10 min, mas o pedido e do dono: roda" e a suíte roda de novo (pedido do dono em 2026-10-31: o ícone sempre roda; só a trava de uma suíte em curso segura). Se o ícone não aparecer: o launcher não
   lista por `LAUNCHER`; olhar `dumpsys package com.pfl7560.verificar` (doc 43 §6 diz que lista).
6. **Pedido que não é do app.** Root: `adb shell "touch /data/data/com.pfl7560.verificar/pedir-verificacao"`
   (o dono é o root, não o app). Esperado: o `vigia.log` diz "o pedido nao veio do app (dono do arquivo nao e o
   da pasta do app) - ignorado" e **nenhuma suíte** começa. Remova o arquivo se sobrar (`rm`). Este é o caso que o
   harness não consegue montar sem root.
7. **Voltar da tomada com o projetor ligado.** Com a tela inicial no ar, tire o cabo de energia, espere 10 s,
   religue. Esperado: a suíte roda sozinha ("Voltou a energia. Conferindo o projetor.", **sem** a palavra
   pendrive), resumo de 20 s; `adb shell "tail -2 $S/historico-boot.txt; head -20 $S/ultimo.log"` com
   `persist_boot_reason=pfl7560,ligado` e `motivo=queda_de_energia`. **Se não rodar:** copie a linha do
   histórico e, para o resto do teste, use `adb shell "echo sempre > $S/gatilho"` (voltar a `auto` no fim).
8. **Desligar pelo controle e religar.** Esperado: a suíte **não** roda; o histórico mostra
   `boot_reason=shutdown,userrequested` e `motivo=desligamento_limpo`, porque o desligamento limpo sobrescreveu
   a marca.
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

## 13. A luz da home (bloco 15)

O atalho **Luz** da home (doc 45 §11) usa o mesmo vigia do pedido de verificação, com um segundo nome de arquivo.

**Medido no aparelho em 2026-10-31.** `printf 'picture\nsbl N\nquit\n' | /vendor/bin/hidebug` (N de 0 a 100)
baixa a luz do LED de verdade (com 30, "escureceu bem"); a leitura é `printf 'picture\ngbl\nquit\n' | hidebug`,
que devolve `backlight:N`. O `sbl` não mexe no `backlight brightness` do módulo custom (continua 1000), que é onde
a proteção térmica age (1000 para 850 entre 66 e 70 °C): os dois convivem. A gravação do `sbl` pelo fabricante é
**atrasada e não confiável** (com 60 aplicado e reboot logo depois, voltou o 30 anterior); por isso o nível
escolhido é guardado por nós e reaplicado em todo boot. O `hidebug` só roda como root, por isso a ponte pelo
arquivo.

**Fluxo.** O app grava só dígitos em `luz`, na pasta privada dele. O vigia chama o `suite-pedido.sh`, que:

1. aceita o nome `luz` além de `pedir-verificacao`, com o mesmo evento (`w` ou `y`) e a mesma conferência de
   origem (arquivo regular, não link, dono igual ao da pasta, UID de app);
2. lê **só** o conteúdo do arquivo (até 16 bytes, sem `\r\n`) e exige dígitos puros, no máximo 3, valendo de 10
   a 100 (zeros à esquerda saem). Letras, sinal, vazio, `5`, `200`, `1000` e `6.0` são recusados, com log;
3. apaga o pedido; guarda o número em `/data/vendor/pfl7560-suite/luz` (root, 0600);
4. aplica com `sbl N` e confere com `gbl` (até 3 leituras, 1 s entre elas; o log avisa se não confere);
5. devolve o valor lido em `luz-atual` na pasta do app: criado com `noclobber` (nunca segue um link plantado),
   `chown -h` para o dono da pasta, 0600, e `mv` por cima (o rename substitui um link, não o segue). O app lê esse
   arquivo e mostra "100%" no atalho.

Não usa a proteção de 10 min. Com a trava da suíte ocupada (a rampa no meio) só guarda: o próximo boot aplica.
**Boot.** O `suite-boot.sh`, antes de ligar o vigia e com qualquer `gatilho`, chama
`suite-pedido.sh aplicar-luz` (o md5 do `suite-pedido.sh` é conferido antes): se `luz` existe, é do root, não é
link e vale 10 a 100, reaplica e atualiza o `luz-atual`. Sem o arquivo, não mexe em nada. Um pedido de luz que já
estava na pasta antes de o vigia ligar é tratado uma vez ao ligar.

**O `gtt` continua proibido.** O `suite-pedido.sh` só manda ao `hidebug` `picture`/`sbl`/`gbl`/`quit`; o
`suite-boot.sh` não fala com o `hidebug`. O harness confere (estático e em todos os cenários).

**Provas no PC** (`tests/test-suite.sh`, caso `c_luz`): pedido válido, 13 inválidos, link, UID abaixo do mínimo,
eventos errados, trava, `gbl` que não confirma, links plantados no app, `hidebug` ausente, boot reaplicando
(inclusive com `gatilho` nunca), boot com arquivo inválido, link ou `suite-pedido.sh` adulterado, pedido pendente,
e a verificação seguindo normal.

**PROVISÓRIO (só o aparelho confirma):** (a) o vigia root conseguir criar e dar `chown` no `luz-atual` dentro da
pasta do app (SELinux `vendor_shell` em `app_data_file`) e o app conseguir lê-lo; sem isso o atalho mostra 100%
sempre, mas a luz muda; (b) o `gbl` logo depois do `sbl` já devolver o valor novo (senão o log avisa e o
`luz-atual` guarda o valor antigo até o próximo boot); (c) o `sbl` aplicado no `boot_completed` pegar (o
fabricante pode regravar depois); (d) a janela de 4 s do app para reler o `luz-atual`.
**Não feito:** aplicar o nível guardado no fim da suíte (o `suite.sh` não foi tocado); com a rampa rodando, o
pedido só vale a partir do próximo boot.

## 14. Descanso de tela MeowCast (bloco 16B)

Pedido do dono: o descanso de tela do fabricante mostrava o logo da Intelbras; o sistema agora se chama
**MeowCast** (marca em `artifacts/tema/gerar-marca.py`: fundo `#120B1A`, nome `#9D7AD0`, IBM Plex Sans Condensed
Bold).

**O serviço.** `com.pfl7560.verificar/.Descanso`, um `DreamService` no app do 9C (`versionCode` 3). No manifesto:
`android:permission="android.permission.BIND_DREAM_SERVICE"` (só o sistema liga o serviço; não é
`uses-permission`, o APK continua sem permissão pedida) e o filtro `android.service.dreams.DreamService`. Tela
inteira no fundo `#120B1A`, o nome "MeowCast" em `#9D7AD0` (a Plex Condensed Bold vai nos `assets/fontes/` do
APK, com a licença `OFL.txt`; se faltar, `sans-serif-condensed` bold) e, menor e mais apagada (`#6C5390`, o
nome a 65% sobre o fundo), a hora `HH:mm`. A cada minuto cheio do relógio o conjunto desliza em 3 s para o
lugar seguinte de uma lista de 5, sempre a 80% da folga da tela, para não ficar parado. `setInteractive(false)`,
`setFullscreen(true)`, sem trabalho além de um `Handler` com um tique por minuto.

**Como liga.** O `suite-boot.sh`, em todo boot e com qualquer gatilho (inclusive `nunca`), logo depois de
reaplicar a luz e antes de ligar o vigia:

1. confere que o sistema enxerga o serviço: `cmd package query-services --components -a
   android.service.dreams.DreamService` com `com.pfl7560.verificar/...Descanso` na saída; se o `cmd` não
   responder, `dumpsys package com.pfl7560.verificar` com o `Descanso`. Sem o serviço, **não mexe em nada** e
   registra no `boot.log`;
2. para cada uma de `screensaver_components` e `screensaver_default_component`: `settings get secure <chave>`
   e, se não for `com.pfl7560.verificar/.Descanso`, `settings put secure <chave> com.pfl7560.verificar/.Descanso`.
   Chave já certa não é regravada. Um `put` que falha só avisa no log; o boot segue.

Cada `settings` e `cmd` leva `timeout` (10 e 15 s). **Desinstalar:** §8.

**Provas no PC** (`tests/test-suite.sh`, caso `c_descanso`, com um `settings` de mentira que guarda as chaves):
do fabricante para o nosso; chave vazia (`null`); segundo boot sem regravar; só uma chave errada regrava só ela;
serviço ausente não mexe; o `dumpsys package` como reserva do `cmd`; gatilho `nunca` também liga; `put` que
falha não derruba o boot. E no `c_desinstalar`: as duas chaves voltam ao `ScreenService` do fabricante.
`aapt2 dump xmltree` do APK mostra o `<service>` com a permissão e o filtro.

**PROVISÓRIO (só o aparelho confirma):** (a) o `cmd package query-services --components` no Android 9 do
projetor (a reserva do `dumpsys` cobre se não existir); (b) `settings put secure` como root no
`boot_completed` pegar e o sistema aceitar o componente `com.pfl7560.verificar/.Descanso` (forma curta); (c) o
descanso entrar de fato depois do tempo ocioso (`screen_off_timeout` e o `screensaver_enabled` estarem
ligados neste firmware; o bloco não mexe neles); (d) o desenho no projetor: tamanho do nome, a hora a 65% legível
na parede, o deslize sem engasgo; (e) o descanso do fabricante (`ScreenService`) ter parado de aparecer;
(f) o `suite-boot.sh` só roda no boot: com o app novo recém-instalado em `/vendor/app` pelo kit, o descanso liga
no primeiro boot em que o serviço já existir (a conferência é feita a cada boot).

## 15. Bloco 14: o que o kit leva do que foi feito à mão (2026-10-31)

Tudo isto foi feito no projetor do dono por adb em 2026-10-31 e provado lá. Agora o kit do pendrive (e o
`suite-boot.sh`) faz sozinho, para um aparelho novo ou este depois de regravar o firmware. Spec:
`docs/sprints/2026-10-31-bloco-14-kit-tema-vlc.md`. Tudo é **idempotente** (a 2ª vez nada é regravado) e
**uma falha só avisa no log**: o resto do kit segue.

| O quê | Quem faz | Como |
|---|---|---|
| Sobreposições Drácula (`artifacts/overlay/apk/*.apk`, blocos 13A e 16A) | `newlink_update.sh` grava; `suite-boot.sh` liga | `KIT_OVERLAYS`: `/vendor/overlay/<Nome>/<Nome>.apk` (pasta 0755, arquivo 0644, root, rótulo `vendor_overlay_file`) na mesma janela rw do `/vendor` dos apps; só regrava se faltar ou diferir (conteúdo). A do `android` vai **sempre por último**. Vale no **próximo boot**: o PackageManager só varre `/vendor/overlay` no boot. O `cmd overlay enable` precisa do `system_server`, então o `suite-boot.sh` liga, uma vez por boot e com qualquer gatilho, as que o sistema lista como desligadas (`[ ] com.pfl7560.tema.<x>`), a do `android` por último, esperando (até 6 consultas, 10 s) o PackageManager listar todas as pastas; as já ligadas (`[x]`) não são tocadas |
| Gerenciador de arquivos abrindo direto na lista | `newlink_update.sh` | linha `vendor.nl.filemanage_file=1` no `/vendor/build.prop`, como a da home (`gravar_fm_prop`); vale no próximo boot |
| Office, iOSCast e Espelhamento desligados | `suite-boot.sh` | `pm disable-user --user 0` em `com.mobisystems.editor.office_registered`, `com.newlink.cast` e `com.hisilicon.miracast`, só nos instalados e ligados; depois espera aparecer `enabled="3"` no `package-restrictions.xml` (o sistema grava com uns 10 s de atraso; até 8 leituras de 2 s) e registra no `boot.log` se gravou. **Não reinicie logo depois**: um reboot antes da gravação perde o estado |
| Marca MeowCast em `/atv/bootvideo/logo.jpg` e `bootanimation.zip` (`artifacts/tema/marca/`) | `newlink_update.sh` | `cat` por cima (preserva dono e rótulo SELinux), depois de guardar **uma vez** o arquivo de fábrica em `/data/vendor/pfl7560-suite/marca-original/` (pasta 0700; só se o arquivo ainda difere do nosso); confere o md5 e, se não bater, devolve o original. Não precisa da janela rw do `/vendor`. Arquivo de fábrica ausente ou link: avisa e não escreve |
| Marca na partição `logo` (a imagem do carregador) | **fora do pendrive**: `pfl7560-marca.sh` (PC) | ver abaixo |
| VLC 3.7.1 em `/vendor/app/VLC` | **fora do git e do pendrive**: `pfl7560-vlc.sh` (PC) | ver abaixo |

**Os APKs e a marca no kit são cópias geradas por script.** `bash tests/atualizar-md5-kit.sh` copia cada
`artifacts/overlay/apk/*.apk` para `pendrive-autorun/overlay/` (sem lista fixa: um APK novo lá entra sozinho),
copia `logo.jpg` e `bootanimation.zip` de `artifacts/tema/marca/` para `pendrive-autorun/marca/`, escreve o bloco
`KIT_OVERLAYS` do `newlink_update.sh` (a do `android` por último) e põe tudo na `KIT_LISTA` com o md5. Com
`--check` só confere (entra no `make check-kit`). Depois de acrescentar um APK de sobreposição, rodar o script
de novo basta.

**Desinstalar** (`DESINSTALAR-SUITE.txt`, §8) agora também: desliga as sobreposições (`cmd overlay disable`, a do
`android` primeiro) e apaga `/vendor/overlay/PFL7560Tema*`; tira a linha `vendor.nl.filemanage_file=1`; religa os
três apps (`pm enable --user 0`, só os que estão desligados); restaura `logo.jpg` e `bootanimation.zip` do
backup (`cmp` confere) e, só então, apaga a pasta da suíte. **Se algum não voltar, a pasta da suíte fica**, com o
backup, e o log diz `ERRO`.

**Saída de emergência das sobreposições** (doc 48 §7): `cmd overlay disable <pacote>`; se a interface não sobe, o
pendrive do kit com o firmware de resgate (arranjo B do `LEIA-ME.txt`) regrava tudo e apaga o `/data`. A do
`android` entra em todo processo: instale o kit com o pendrive de resgate à mão.

### `pfl7560-marca.sh` (PC): marca na partição `logo`

Fora do pendrive porque a imagem depende dos 4 cantos do keystone **de cada aparelho** (o carregador mostra a
imagem já distorcida) e a partição é a do carregador. `PFL_IP=<ip> ./pfl7560-marca.sh [--sim]`:

1. conecta por adb (só Wi-Fi), vira root, confere `ro.product.model=PFL7560`;
2. lê `persist.sys.keystone.{lt,rt,lb,rb}` e gera a imagem com `artifacts/tema/gerar-marca.py` numa pasta
   temporária (`PFL_MARCA_SAIDA`), sem tocar nos arquivos versionados;
3. **backup da partição inteira** (`/dev/block/by-name/logo`, 40 MiB exatos) em
   `backups-projetor/logo/logo-<data>.img`, conferido por md5 contra a leitura direta do aparelho;
4. confere o cabeçalho `LOGO_TABLE` do backup (`###\0`, `LOGO_TABLE`, `LOGO_KEY_LEN`), monta a imagem esperada
   (o JPEG novo no byte 8192 e o `LOGO_KEY_LEN`, 4 bytes little-endian no 0x78, com o tamanho dele) e confere
   de novo; pergunta "digite GRAVAR" (ou `--sim`);
5. grava **só essas duas regiões** com `dd` (sem `conv`, que o toybox recusa): o JPEG com `bs=4096 seek=2` e o
   `LOGO_KEY_LEN` com `bs=1 seek=120`, depois de conferir o md5 dos dois arquivos no aparelho e de a partição
   ainda ser igual ao backup;
6. **relê a partição inteira** e confere o md5 contra a imagem esperada.

`--restaurar <backup.img>` devolve a partição inteira (confere cabeçalho e tamanho do arquivo, grava com `dd` e
relê). Vale na próxima ligação do projetor.

### `pfl7560-vlc.sh` (PC): VLC como app do sistema

`PFL_IP=<ip> ./pfl7560-vlc.sh [--sem-reiniciar]`. Baixa de `get.videolan.org/vlc-android/3.7.1/` o
`VLC-Android-3.7.1-armeabi-v7a.apk` (47 073 346 bytes) para `backups-projetor/vlc/` (fora do git) e só segue se:
o sha256 do arquivo = o publicado em `.apk.sha256` = o fixado no script
(`a6a7f940e4bd190c9a70f3f0dc97c1c402c10200af20edac7a1d452b24abd8a0`); a assinatura passa no `apksigner` e o
certificado tem o SHA-256 `c8768d2cea0c4b622e419b4b4715981946821e4ebc035fb41776cad395a7f68e` (VideoLAN
Mobile); o APK traz `lib/armeabi-v7a/*.so`. Depois confere o modelo, que o aparelho lista `armeabi-v7a` e o
espaço livre do `/vendor`; abre o `/vendor` rw (com prova de escrita); grava `/vendor/app/VLC/VLC.apk` e as
`.so` em `/vendor/app/VLC/lib/arm/` (cada arquivo como `.new`, conferido por md5 no aparelho e só então movido;
0755/0644, root, `vendor_app_file`); fecha o `/vendor` e reinicia. `--remover` apaga `/vendor/app/VLC` e
reinicia. Os dois valores fixados foram lidos do `.sha256` publicado e do APK baixado em 2026-10-31.

### Provas no PC

- `tests/test-kit-pendrive.sh`, caso `c_bloco14`: sobreposições ausentes viram todas as pastas (modos, `chcon`,
  a do `android` por último, sem `cmd overlay` no kit); 2ª vez sem remount; APK velho atualizado; um APK que
  não grava não impede os outros nem o kit; pasta que é link; remount falho (a marca entra mesmo assim); APK ou
  marca adulterados no pendrive abortam; `DESINSTALAR-SUITE.txt` não grava nada do bloco; prop do gerenciador
  (ausente, com outro valor, `build.prop` que não grava); marca (backup uma vez, 2ª vez, firmware que troca o
  logo, arquivo ausente ou link, arquivo somente leitura, desinstalar que não restaura deixa o backup).
- `tests/test-suite.sh`, casos `c_overlays_boot`, `c_apps_boot` e `c_desinstalar14`: ligação das sobreposições
  (ordem, já ligadas, PackageManager atrasado, nunca listadas, `enable` que falha, gatilho `nunca`); os três
  apps (já desligado, não instalado, gravação atrasada do xml, xml que nunca grava, `pm` que falha ou não
  responde); desinstalar do bloco inteiro.
- `tests/test-pc-marca-vlc.sh` (no `make check-kit`): os dois scripts de PC com um adb de mentira.

### PROVISÓRIO (só o aparelho confirma)

1. O PackageManager do Android 9 do projetor aceitar APK de sobreposição em `/vendor/overlay` gravado pelo kit,
   o `cmd overlay list` mostrá-las como `[ ]` no boot seguinte e o `cmd overlay enable` pegar como root no
   `boot_completed` (o formato `[ ] pacote` / `[x] pacote` / `--- pacote` é o do código do Android 9).
2. O `pm disable-user --user 0` pelo `suite-boot.sh` no `boot_completed` e a gravação do `enabled="3"` no xml
   dentro dos ~16 s de espera; o `pm list packages -d` mostrar os três como desligados.
3. `/atv/bootvideo` aceitar o `cat` sem remount (como na mão) e o `bootanimation.zip` de fábrica existir também
   no modelo sem USB-C.
4. Modelo sem USB-C (V1.0.0.1): as sobreposições foram conferidas só contra os APKs do V1.0.0.9; o `android`
   é a que importa (framework-res). Não testado.
5. `pfl7560-marca.sh`: `blockdev --getsize64`, `dd ... bs=4096 seek=2` e `bs=1 seek=120` e `md5sum` sobre o
   bloco `logo` no toybox do aparelho; `adb exec-out dd` entregar os 40 MiB sem alteração.
6. `pfl7560-vlc.sh`: o `df -k /vendor` com a coluna "Available" por último; o PackageManager registrar o
   `org.videolan.vlc` com as `.so` de `lib/arm`; o espaço do `/vendor` para ~90 MB.

## 16. Bloco 11: mapa de nitidez 3x3 e varredura fina de foco (2026-10-31)

Pesquisa no [doc 46](46-foco-e-qualidade.md); tarefa em
[bloco 11](../sprints/2026-10-31-bloco-11-qualidade-e-foco.md). Feito no PC, sem o aparelho.

**Mapa 3x3.** A cada `medir_geo`, depois da geometria, `nl_camcheck nitidez <dev> faixas.txt` (contrato no
`artifacts/camcheck/README.md`): a largura de borda 10-90 % em 9 regiões, com as colunas tiradas da imagem
achada no quadro (não das janelas fixas da geometria). Se a nitidez falhar, a geometria vale e o item usa a
borda do centro, como antes. O quadro vem espelhado de cima para baixo: `r1` é a linha de baixo na parede; as
colunas não se espelham (`c1` = esquerda).

**Item "Nitidez" e a dica.** O valor é o centro (`r2c2`) e o pior canto (`r1`/`r3` de `c1` e `c3`):
"1,9 · canto 3,1 px" (a coluna do resumo cabe 18 caracteres; com números de 2 dígitos sai sem o "px"). A
causa (`nitidez_causa`):

| Causa | Quando | Item | Dica |
|---|---|---|---|
| `centro` | o centro passa do limiar da borda | atenção | "Centro borrado (X px): foco refeito. Se continuar, limpe a lente e confira a distância até a parede." (sem foco refeito: "refaça o foco pela tecla do controle") |
| `lado_esquerdo` / `lado_direito` | só o pior canto de um lado passa de `RAZAO_BORDA` (1,6) x o centro | atenção | 4 pontos ligados: "Cantos do lado X borrados (C px; centro Y px): zere os 4 pontos e alinhe o projetor de frente." (substitui o conselho genérico dos 4 pontos). Zerados: "... alinhe o projetor de frente para a parede." |
| `cantos` | os dois lados | atenção só acima do limiar | nenhuma (a borda da lente ou da câmera; o mapa se compara contra ele mesmo) |
| `nenhuma` | | ok, ou atenção acima do limiar | nenhuma |

Com uma dica de causa, a dica genérica "Foco irregular ..." não sai.

**Varredura fina de foco.** Só quando o foco continua ruim (os limiares de sempre: `RAZAO_BORDA` e
`LIMIAR_BORDA_PX_1280`) depois dos `FOCO_TENTATIVAS` autofocos, e nunca com `sys.newlink.auto=1`. Pelo
`hidebug`, módulo `custom`, só `gfd` (posição), `gfdr` (faixa) e `sfd <pos>` (vai à posição); `hb_foco`
recusa qualquer outra coisa (nada de `sfd2`, `sfd3`, `saps` ou GPIO; `gtt` nunca):

1. `p0 = gfd`; sem número reconhecido, não mexe no motor (`foco_varredura=sem_hidebug`, saída crua no log).
2. Anda de `p0 - 3 x 40` a `p0 + 3 x 40` em passos de 40, sempre subindo (folga de direção do motor, doc 46
   §7), dentro do `gfdr` quando ele responde. Depois de cada `sfd`, pausa de 2 s e o `gfd` relido (até 3
   vezes) tem de estar a até 20 da posição pedida; senão para (o "Motor is too hot!" recusa o movimento).
3. Em cada posição, a borda do **centro** pela geometria. Fica com a menor, se melhorar pelo menos 0,15 px.
4. Vai à melhor (chegando por baixo) e mede de novo. Confirmou: fica (`melhorou`, item "Foco" = "ajuste
   fino", corrigido) e a geometria e o mapa são medidos de novo. Senão, ou se algo falhou: volta a `p0`
   chegando por baixo e confere pelo `gfd` (`sem_ganho`, `falhou`; sem confirmação, `nao_voltou` e o log manda
   refazer o foco pela tecla). A suíte morta no meio (TERM, INT, HUP): o trap manda `sfd p0`
   (`interrompida`).

Constantes no `suite.sh` (todas PROVISÓRIO): `VARRE_PASSO=40`, `VARRE_LADO=3`, `VARRE_PAUSA=2`,
`VARRE_CHEGADA=3`, `VARRE_TOLERANCIA=20`, `VARRE_GANHO=0.15`.

**Chaves novas em `resultados.txt`:** `nitidez_r1c1` ... `nitidez_r3c3`, `nitidez_centro_px`,
`nitidez_pior_canto_px`, `nitidez_causa`, `foco_varredura` (`nao_precisou`, `melhorou`, `sem_ganho`,
`falhou`, `sem_hidebug`, `pulada`, `nao_voltou`, `interrompida`) e, quando a varredura roda,
`foco_pos_inicial`, `foco_pos_final`, `foco_borda_antes`, `foco_borda_depois`.

**`pfl7560-qualidade.sh` (PC, adb).** Lê pelo `hidebug` (módulo `picture`) o modo de imagem, a nitidez, o NR,
o MEMC, o DCI e o overscan, e pelas props e `wm size` a saída para o painel, e compara com o "máximo" do doc 46
§3.2. Só muda com `--aplicar <ajuste>` (vai ao sugerido) e a palavra MUDAR digitada; o valor antigo fica em
`backups-projetor/qualidade/<ajuste>.txt` (o de antes da primeira mudança, nunca sobrescrito) e `--voltar
<ajuste>` o devolve. Relê depois de cada mudança.

### Provas no PC

- `tests/test-camcheck.sh`: o mapa nos 5 quadros reais (`calibracao-hd-f1`, o caso do dono: esquerda ~1,5x o
  meio, pior em `r1c1`), sintéticos de borda conhecida por coluna e por linha, e as saídas de erro.
- `tests/test-suite.sh`, caso `c_etapas_foco`: as quatro causas e as dicas (sem a dica repetida dos 4 pontos),
  o valor de 2 dígitos, a nitidez que falha (o item volta à geometria), a varredura que acha a melhor posição
  (as 9 posições pedidas, a pausa antes de cada leitura, só `gfd`/`gfdr`/`sfd`), a que não ganha (volta por
  baixo), o motor que recusa, o `hidebug` que para de responder, o autofoco em curso e a suíte morta no meio.
- `tests/test-qualidade.sh` (no `make check-kit`): leitura só de leitura, `--aplicar` e `--voltar`, a palavra
  errada, o valor que não se lê, o aparelho que não muda, sem root, `errno = 13`, outro modelo.

### PROVISÓRIO (só o aparelho confirma)

1. O formato da saída do `gfd` e do `gfdr` (a suíte procura "focus" ou "distance" e o último número; "[" e os
   dois primeiros números na faixa). Se não bater, a varredura nunca mexe no motor e o log mostra a resposta.
2. A unidade do `gfd`/`sfd` e se 40 é um passo pequeno; se o `sfd` alinha a posição (a tolerância de 20).
3. O critério do "Motor is too hot!" contra a pausa de 2 s.
4. O mapa 3x3 no aparelho, sobre a calibração de agora, e se o lado esquerdo cai para perto do centro com os 4
   pontos zerados (doc 46 §7, passo 2).
5. O formato da saída do `hidebug` no módulo `picture` (o `pfl7560-qualidade.sh` lê o último número de cada
   resposta) e se o `s...` persiste e relê igual.
