# Notas do código: o kit do pendrive (`pendrive-autorun/`)

O porquê das decisões que estão no código do kit. O código não tem comentário; o que ele faz em detalhe está nos
docs [41](../research/41-auto-pareamento-camera-e-kit-universal.md) (kit e cor) e
[44](../research/44-suite-de-boot.md) (suíte). Mapa geral: [`../MAPA.md`](../MAPA.md).

## Regras que valem para os cinco scripts

- **ASCII puro, sem bashismo.** Rodam no `/vendor/bin/sh` do projetor (mksh e toybox do Android 9, locale
  incerto) e vivem em FAT32, onde acento vira mojibake ou quebra o parser. Convenção fixada na sprint 25. Texto de
  tela com acento vai como `\uXXXX` (contrato C-tela), nunca cru.
- **`PATH` fixo, com `/system/bin` antes.** O init sobe o serviço de boot com o `PATH` do `/vendor`, e `cmd`,
  `pm`, `am`, `settings`, `input`, `dumpsys` e `logcat` moram em `/system/bin` (visto no aparelho em 2026-10-31:
  `exec cmd: No such file or directory`).
- **`LC_ALL=C`.** O `awk` segue `LC_NUMERIC`; em pt_BR imprime `3,50`, que outro `awk` lê como 3.
- **Ganchos de teste só com `PFL_TESTE=1`.** Fora disso todas as variáveis `PFL_*` saem do ambiente, para nenhuma
  virar porta de entrada em produção; o gancho de boot gerado pelo `cor.sh` também as apaga antes de tudo.
- **Pasta de trabalho só do root (E3b).** Tudo roda como root a partir de `/data/vendor/pfl7560-kit` ou
  `/data/vendor/pfl7560-suite`. Se alguém que não é root escrevesse lá (ou trocasse a pasta por um link),
  executaria código como root. Por isso `dir_seguro` exige diretório real, dono root e nada para grupo e outros (o
  `ls` pode pôr `.` ou `+` no fim do modo, por SELinux/ACL), e `arq_seguro` exige arquivo regular do root. Uma
  pasta errada que já existe **nunca** é consertada nem apagada: recusa. As subpastas (`kit/`, `fontes/`) também
  são conferidas, senão um arquivo "regular" dentro de uma subpasta que é link passaria.
- **md5 conferido na hora de cada execução**, nunca "de antes": `cor.sh`, `lvdsctl`, `nl_camcheck`, `nl_tela`,
  `suite.sh` e `suite-pedido.sh`. Limite honesto: um `newlink_update.sh` adulterado roda como root e não há
  defesa contra ele.
- **Listas de md5 embutidas** (`KIT_LISTA`, `KIT_OVERLAYS`, `SUITE_LISTA`, `SUITE_MD5`) ficam entre as linhas
  `# NOME_INICIO` e `# NOME_FIM`, que o `tests/atualizar-md5-kit.sh` usa como marcador; nunca editar à mão.
- `# shellcheck disable=SC2046/SC2086` nos `set -- $(ls ...)` e nas listas: a divisão em campos é de propósito
  (nomes sem espaço).
- **Nunca `hidebug gtt`** (doc 37): o `gtt` força o mux dos termistores. O kit só lê temperatura por props, e o
  `hidebug` só recebe `gfs`, `gbri`, `gfd`, `gfdr`, `sfd <pos>`, `sbl`, `gbl` e os ajustes do módulo `picture`.
- `printf`, não `echo`, para gravar texto: o `echo` do `sh` do aparelho interpreta barra invertida (um `\c` corta
  a linha).
- O `awk` do Android 9 (BWK) recusa a negação no `exit` ("illegal arithmetic operator"): use `if`/`exit`.

## `newlink_update.sh` (o autorun)

- **Por que existe:** o firmware roda `/vendor/bin/nl_usb_update.sh` a cada boot (`sys.boot_completed=1`); ele varre
  os pendrives e **executa como root** um `newlink_update.sh` que estiver na raiz (via `exec` do init). Por isso
  aqui só roda o que é curto: conferir o kit e a fase térmica.
- **A cor e a suíte rodam destacadas** (`setsid`, ou `nohup`), com log próprio. Premissa não confirmada (doc 41):
  o init processa o `exec` de forma bloqueante (inferido do AOSP), então a pergunta de até ~90 s não pode rodar
  dentro dele. Segunda premissa: ao fim do `exec` o init não mata o grupo do serviço temporário. Se matar, a cor
  morre no início, antes do journal: nada foi escrito.
- **Térmica por seções.** O `.ini` novo nasce do `.ini` **do aparelho**, trocando só `TERM_SECOES` pelas do
  `ZYCustom.ini` do pendrive; o resto (cabeçalho, `CONFIG_MODEL`, demais seções) fica byte a byte. Só
  `grep`/`sed`/`head`/`tail`/`tr` e cortes por número de linha, nada de `awk`: o arquivo mistura ASCII, chinês GBK
  e mojibake. O md5 do resultado é conferido contra o esperado; se o shell do aparelho se comportar diferente, o
  md5 não confere e nada é gravado.
- **md5 conhecidos do `.ini`** (o kit recusa qualquer outro): `*_OK` (corrigido, com USB-C), `*_OK_NOTYPEC`,
  `*_FABRICA` (V1.0.0.9) e `*_FABRICA_NOTYPEC` (V1.0.0.1). Versões anteriores nossas que já foram para aparelho
  (todas do modelo com USB-C): `bbf82dd1` (`artifacts/ZYCustom_390.PREV-211927.ini`), `1ad641ed` (o
  `pendrive-autorun/ZYCustom.ini` de 23169d6 a d10f6da, antes da escada; docs 26 e 34) e `5868d67f` (o de
  cd5a80f, com os espaços de fim de linha cortados). Uma versão anterior nossa difere até fora das seções
  térmicas, então ela troca o arquivo inteiro.
- **Idempotência pelo md5 do `.ini` em uso:** um `.ini` anterior à escada tem o mux mas não a escada, e antes
  passava como aplicado.
- `/atv/ini/ZYCustom*.ini` tem precedência sobre o `/vendor` (doc 06): se existir, o kit avisa em vez de dizer que
  deu certo.
- O `/vendor` só abre rw se algum dos 3 fixes (ou o `.rc` da suíte) estiver pendente, e fecha em **todos** os
  ramos, inclusive no de reboot (antes ficava gravável durante os 8 s de `sleep`). Se só o `.rc` estiver pendente e
  o remount falhar, o kit segue sem ele: o `.rc` nunca impede a cor.
- **Escrita atômica:** `.new` + md5 + `sync` + `mv` + releitura. No `init.bigfish.rc`, boot-crítico, nunca `sed -i`
  no arquivo vivo.
- **Cópia do kit para a pasta do root:** primeiro numa pasta de preparo dentro de `$WORK`, conferida lá, e só então
  cada arquivo vai para o lugar com `mv` (rename atômico; um link no lugar é substituído, nunca seguido). Assim
  `$WORK/cor.sh` nunca tem, nem por um instante, um arquivo não conferido: o pendrive pode ser alterado em uso e um
  `cor.sh` do gancho de boot pode estar rodando ao mesmo tempo.
- **Serviço de boot da suíte:** o `.rc` é montado fora de `/vendor/etc/init` e só entra lá por `mv`, já com 0644,
  root e o rótulo do `init.bigfish.rc` vizinho (ou `vendor_configs_file` se o `ls -Z` não responder; o `ls -Z` é o
  único leitor de rótulo do toybox). Um `.rc` que mesmo assim fique fora do padrão é removido. O brick de julho veio
  de `.rc` 0664 e sem rótulo.
- **O `.rc` da build S5 (bloco 26)** vale como instalado (`rc_s5`): só em `/vendor/etc/init/pfl7560-suite.rc`, só com
  o md5 `RC_S5_MD5` (gerado pelo `atualizar-md5-kit.sh`) e só se a semente `/vendor/etc/pfl7560-suite/suite-semente.sh`
  existir; modo, dono e rótulo são conferidos como os do `.rc` do kit. Sem a semente, o `.rc` da S5 rodaria um
  script que não existe, e o kit põe o dele ([doc 47 §12](../research/47-build-completa.md)).
- **Apps e sobreposições em `/vendor/app` e `/vendor/overlay`:** o `pm install` deste firmware recusa qualquer app
  de fora (`INSTALL_FAILED_INVALID_INSTALL_LOCATION`, 2026-10-30). O PackageManager varre `/vendor/app` no boot,
  como faz com o `KeymasterProvisionDemo` de fábrica. Vale no boot seguinte. O APK vem de `$WORK` (conferido),
  nunca do pendrive. Falha só avisa: o resto do kit segue. A sobreposição do `android` vai sempre por último (entra
  em todo processo).
- **Home pela prop `vendor.newlink.launcher.package`:** o HOME do sistema é o assistente `com.newlink.nlprovision`
  (prioridade 29; o `set-home-activity` não vence, 2026-10-31), que repassa a HOME ao pacote da prop (doc 45 §4).
  A linha só entra no `build.prop` com a home instalada e conferida.
- **Marca em `/atv/bootvideo`:** sobrescrita com `cat` (preserva dono e rótulo), depois de guardar uma vez o
  original em `$SUITE/marca-original`. A partição `logo` não vem por aqui: depende dos cantos de cada aparelho
  (`pfl7560-marca.sh`).
- `_trc` tem nome próprio porque o `kit_conferir` já usa `_rc` e `_n`.
- `APP_PKG`/`APP_VERSION_CODE` não são lidos pelo script: o harness os confere contra o `build.sh` e o APK.

## `cor.sh` (a fase de cor)

- **Fluxo:** modo automático pela câmera (calibração, depois escada de 16 cinzas; em ordem = nada se escreve; fora
  de ordem com 2 ou mais inversões = troca o formato ao vivo e mede de novo); qualquer dúvida cai no fluxo manual
  (escada, primeira tecla troca ao vivo com backup e journal, só mantém com a segunda tecla). Sem tecla em 30 s,
  nada é escrito: é a saída do aparelho de fábrica.
- **Só o byte `lvdsctl_fmt` (`0x5c`) do perfil ativo**, nunca `swap`, `bit` ou `map`. O nome do perfil gravado na
  partição tem de bater com o do driver (prova de offset, não de qual painel está no motor).
- **O código de saída do `lvdsctl` não é confiável:** quem confirma é a releitura do byte (`SetLvdsFormat` persiste
  na hora, doc 40 §1).
- **Compara a partição inteira** com o backup, não só o perfil: uma escrita do `lvdsctl` fora do perfil
  (cabeçalho, outro perfil, checksum) tem de aparecer. `cmp` direto entre o dispositivo e o backup, sem temporário.
- **Backup:** `dd` + `cmp` (valida tamanho e conteúdo de uma vez). A cópia principal fica em `/data` (o journal
  depende dela); a do pendrive é melhor esforço. No modo suíte sem pendrive, a cópia vai para a pasta da suíte.
- **Restauração** (journal): primeiro o formato original ao vivo com o journal ainda valendo (o `lvdsctl` também
  grava na partição), depois o byte e a conferência da partição inteira, e só então apaga journal e gancho. Se
  sobrar diferença, restaura os 768 bytes do perfil e, se ainda sobrar, a partição inteira. O backup só serve se
  for arquivo regular do root, do tamanho da partição e com o md5 que o journal gravou.
- **Trava em `/dev`** (tmpfs): some no reboot, nunca fica presa; impede que o autorun e o gancho restaurem juntos.
- **Gancho de recuperação** `/data/local/nlsu/update_after_boot.sh`: o init de fábrica o executa como root no
  `sys.boot_completed` (`init.bigfish.rc:371-373`). Premissa não confirmada (E1-c): a pasta não existe neste
  aparelho. Só se cria se não existir um gancho; um que não é nosso não é tocado. Como `/data/local` é do usuário
  shell, só se instala se `$NLSU` não existir ou for diretório real do root sem escrita de grupo e outros. Um gancho
  nosso de outra versão é sempre reescrito com o md5 do `cor.sh` desta execução.
- **Galeria:** a `NetworkHiGallery` aberta recebe o segundo `am start` como "intent delivered to currently running
  top-most instance" e não troca a imagem (bloco 7). Por isso `force-stop` antes de cada tela; o pacote vem do
  resolvedor de VIEW de PNG.
- **Alertas do sistema** cobrem o meio da tela, onde a câmera lê. Janela focada sem atividade = alerta: o
  "Temperatura anormal" do `nlprovision` só tem OK e recebe `DPAD_CENTER` (o ENTER sozinho não fecha,
  2026-10-31); outro (o "Deseja abrir HDMI1?" do `com.zhiying.settings`, com ABRIR em destaque) recebe BACK.
- **Autofoco de boot:** `sys.newlink.auto` vira 1 no `onCreate` do `AutoFocusService` e 0 no fim do foco e no
  `onDestroy` (doc 43 §2.3). `vendor.focus.camera.is_focused` não serve: vira `true` no início e nada a põe em
  `false`. Tetos `AUTOFOCO_INICIO` e `AUTOFOCO_MAX` encerram mesmo com a prop presa.
- **Premissa não confirmada (E1-d):** `getevent -ql` imprime `EV_KEY ... DOWN` ao vivo, inclusive num pipe. Se a
  saída for bufferizada, nada casa e o resultado é "sem tecla", sempre o lado seguro. Confira com pipe, não no
  terminal (lá a saída sai por linha e esconderia a bufferização).
- **Premissa não confirmada (E1-e):** a galeria abre PNG fora de `/sdcard`. Usa-se `/sdcard/pfl7560-kit` (provado
  no doc 28 §4); sem escrita lá, cai em `$WORK/tela`.
- Sem `lvdsctl`, o byte certo só vale no próximo boot: o script pede reboot (`exit 3`, plano B por `dd`). O journal
  já foi apagado, então o boot seguinte não reinicia de novo. Com journal de pé, nunca reinicia (viraria laço).
- O md5 de si mesmo (`COR_MD5`) vem de quem conferiu o kit e é o que o gancho embute.

## `suite.sh` (a suíte de verificação)

- **Rampa (fato 6 do bloco 9):** injeta 71000 m°C, **fixo**, acima do `WARNING` (70000) e abaixo do `EMERGENCY`;
  no `EMERGENCY` o `DEFAULT_PROTECT=2` desliga na hora. Nunca torne o valor configurável. Só injeta se os
  limiares do `.ini` efetivo, lidos agora, deixam 71000 entre os dois e o LED está frio (`RAMPA_LED_MAX`, porque o
  override mascara o sensor). A marca vem antes da escrita, para um sinal entre as duas ainda limpar. O trap
  desfaz e confere lendo de volta (3 tentativas); um `SIGKILL` pula o trap e o próximo boot desfaz.
- O `timeout` do toybox não repassa o `TERM` ao filho: o `logcat` da rampa é morto primeiro, pelo pid do pai.
- **Proteção contra laço:** conta suítes começadas e não terminadas; o `suite-boot.sh` para de rodar sozinho
  depois de 2 seguidas (a proteção dos 10 min só conta suítes terminadas).
- **Telas:** geradas pelo `nl_tela` numa pasta só do root e copiadas para `/sdcard/pfl7560-suite/<nome>-<epoch>.png`
  (nome único: a galeria guarda cache). Sem `nl_tela`, os PNG estáticos do kit. As fontes só valem com todas
  conferidas (o `nl_tela` as lê como root).
- **Alertas:** com eles a câmera leu 5 a 14 de 16 faixas; sem eles, 16 de 16 (2026-10-30). Mesmo tratamento do
  `cor.sh`, com ENTER de reserva alternado ao `DPAD_CENTER`.
- **Câmera:** o quadro chega espelhado de cima para baixo, não de lado: a coluna c1 é a esquerda na parede. Se a
  câmera não lê nem com `CAM_TENTATIVAS`, a etapa para e chama a pessoa, sem prazo (pedido do dono, 2026-10-30).
- **Bordas medidas** (borda centro/esq/dir, px, quadros reais de 2026-10-30): 1280×720 calibração-hd-f1 (JEIDA,
  boa) 1,77/2,24/1,95; 1280×720 calibração-hd-f0 (VESA) 3,49/3,24/4,02; 640×480 calibração-f1 2,90/2,62/2,84;
  640×480 inclinada-f1 1,63/1,57/1,79.
- **Varredura fina de foco** (desligada por `VARRE_LIGADA=0`, doc 46 §11; doc 46 §2.1 e §7): só `gfd`, `gfdr` e `sfd <pos>` passam por `hb_foco`. Posições
  absolutas na unidade do `gfd` (o sentido do `sfd2 0|1` não é conhecido). Chega a cada posição sempre subindo, um
  passo abaixo antes (folga de direção do motor). Sem melhora, o motor volta à posição inicial.
- **Nitidez 3×3:** o pior canto de cada lado contra o centro dá a causa provável (centro = foco; um lado só =
  ângulo ou 4 pontos; os dois = borda da lente ou da câmera). Com a correção de 4 pontos ligada, a inclinação que a
  câmera vê vem dela (a câmera está presa ao projetor), então o conselho não é nivelar.
- **Temperatura só por `gfs` e `gbri`**: o `gtt` força o mux (doc 35, LSADC-S2).
- O valor de cada item cabe em 18 caracteres (coluna do resumo, Mono 34 px no `nl_tela`); na tela, só modelo e
  variante do painel.
- O log vai para o pendrive antes de pedir para tirá-lo.
- **Desinstalar:** o `ctl.stop` mata o grupo do serviço com `SIGKILL` (sem trap), inclusive uma suíte no meio da
  rampa, por isso o override é limpo aqui também. As sobreposições saem ligadas do sistema antes de as pastas
  sumirem (a do `android` primeiro). A marca de fábrica volta do backup com `cat` e `cmp`; se algum não voltar, a
  pasta da suíte (com o backup) fica. O descanso de tela só volta ao de fábrica se ainda for o nosso. A cópia do
  backup da `panelparam` vai para o pendrive antes de a pasta sumir.

## `suite-boot.sh` (lançador de boot)

- **Critério (m), a marca:** o aparelho não tem RTC (`/sys/class/rtc/rtc0` não existe) e o motivo do boot repete o
  do último desligamento limpo. A cada boot o script grava `pfl7560,ligado` em `persist.sys.boot.reason`; um
  desligamento ou reboot limpo a sobrescreve. Se ela sobrevive, a energia caiu ligado. Provado em 2026-10-30
  (`sysrq b` deu `pfl7560,ligado`; reboot limpo deu `reboot,shell`; `evidencias/boot-tomada/`). Os critérios (a)
  ano do relógio e (b) `sys.boot.reason` sem `shutdown,`/`reboot,` ficam para outro hardware.
- **Luz:** reaplicada em todo boot porque a gravação do `sbl` pelo fabricante é atrasada e não confiável (um reboot
  logo depois perde o valor).
- **Descanso de tela:** só aponta para `.Descanso` se o sistema o enxerga como DreamService; até
  `DESCANSO_TENTATIVAS` consultas em segundo plano (o PackageManager pode estar ocupado no boot). O "não existe"
  visto em 2026-10-31 era o `PATH` sem `/system/bin`.
- **Sobreposições:** o PackageManager só varre `/vendor/overlay` no boot e o `cmd overlay enable` precisa do
  `system_server`, por isso a ligação mora aqui. Só liga as `[ ]`; as `[x]` persistem em `overlays.xml`.
- **Apps desligados:** o PackageManager grava `enabled="3"` com atraso (~10 s); espera até 8 leituras de 2 s, senão
  um reboot logo depois perderia o estado.
- **Vigia do pedido:** o `inotifyd` do toybox ignora a 1ª letra da máscara (2026-10-30: `:wy` vigiava só `y`, `:n`
  dava Invalid argument, `:nwy` entregava `w`). Por isso `:wwy`. Sem `inotifyd`, laço de `VIGIA_INTERVALO`. Um
  pedido que já estava na pasta antes do vigia não gera evento: é tratado uma vez na largada.
- **VLC fora do usuário 0 (2026-11-02, pedido do dono):** `tirar_vlc`, em segundo plano junto com os apps
  desligados e as chaves, roda `pm uninstall --user 0 org.videolan.vlc` **uma vez**: depois de conseguir (ou de ver
  que o pacote já não está no usuário 0) cria a marca `$SUITE/vlc-tirado` e não tenta mais; se o `pm` não responde
  ou o uninstall falha, tenta no boot seguinte. O APK continua no `/vendor/app/VLC` e nada da imagem muda.
  Desfazer: `cmd package install-existing org.videolan.vlc`. O `--desinstalar` apaga a marca com a pasta da suíte,
  mas não devolve o VLC (o desfazer é à mão). Não é chave nem debloat: o `deb_vlc` e o `debloat-aprovados.txt`
  seguem sem o VLC (`test-chaves.sh`, `test-suite.sh`).
- O processo fica vivo enquanto o vigia vive (`wait`): nada depende de como o init trata o fim de um oneshot.
- Log próprio: a saída de um serviço do init vai para `/dev/null`.

## `suite-pedido.sh` (pedidos do app e da home)

- Só aceita `pedir-verificacao` (app Verificar) e `luz` (home), cada um só da pasta privada do app dele, com dono =
  dono da pasta = UID de app (≥ 10000). Em `/sdcard` qualquer app dispararia a suíte (revisão de 2026-10-30). Até
  2026-10-31 o vigia só olhava a pasta do Verificar e o pedido de luz nunca era lido.
- **O root não escreve na pasta do app** (revisão de 2026-10-31: corrida de link). O pedido de luz é **movido**
  (`rename`, que não segue link) para a pasta do root, conferido lá e lido com prazo (um FIFO não trava o vigia). O
  valor volta ao app pela prop `vendor.pfl7560.luz`.
- Luz: só dígitos, até 3, de 10 a 100. Com a trava ocupada (rampa no meio), só guarda.
- O pedido de verificação é do dono: roda mesmo logo depois de outra suíte. A proteção dos 10 min é contra laço no
  boot, não contra quem pede (2026-10-31). Um pedido que não se apaga não vira laço de suítes.
- Descanso de tela: luz a 10 % enquanto ele estiver na tela (pedido do dono, 2026-10-31); não mexe no nível
  guardado e não age com a suíte rodando.

## `suite-curvas.sh` (bloco 23: curvas, standby, debloat)

- Um só despachante: `ini-ok`, `ini-base`, `ini-norm` (variantes do `.ini`), `pedido vent|led`, `laco`, `boot`,
  `parar`, `standby-inicio|cancelar|vigia|escolha`, `debloat-lista|reverter`. O `suite-pedido.sh` chama `pedido` quando
  encontra `curva-vent`/`curva-led` (até 200 bytes, dono = UID de app, movido para a pasta do root antes de ler).
- Respostas por prop: `vent`/`led` = `perfil:modo` (`vivo`, `gravada`, `ambos`, `desistiu`); `vent_aviso`/`led_aviso`
  em `firmware`, `temperatura`, `pedido`, `hidebug`, `ini`, `suite`, e `gravar` (só ventiladores: a curva não se
  grava no `.ini`); `standby` em `aviso`/`agora`.
- Por que os ventiladores não se gravam: `FW_SPEED_CURVE` é a tabela velocidade → duty por onde passa todo `sfs`
  (doc 49 §4.3), não uma curva por temperatura; mexer nela distorce o laço ao vivo. Por isso as seções
  `CoolingFan_*` entram inteiras no md5 normalizado, e só a `BacklightPolicy` pode variar.
- Por que soltar o LED não é `sbri 1000`: o `sbri` não entra no estado da política e a rampa só escreve quando o
  alvo muda (doc 49 §4.2). Acima de 70 °C a escada é plana em 850, e um `sbri 1000` ficaria. `escada_em` interpola
  as duas `POLICY` instaladas e a canônica e devolve o menor; o laço mira em `min(curva, escada)` e solta na escada.
- Por que o standby confere `dumpsys power`: o `descanso-fim` pode não chegar (app morto, pedido perdido). Só com
  `mWakefulness=Dreaming` o vigia avisa e manda o `KEYCODE_POWER`, que desliga o aparelho (doc 49 §4.4).
- Por que `solta_pid` (conferente F3): o vigia do standby e o laço só apagam o arquivo de pid se ele ainda tiver o
  próprio `$$`. Um vigia velho morto pelo `standby-inicio` seguinte só roda o `trap` depois do `sleep 5`, e a essa
  altura o pid já é do vigia novo; apagar sem conferir deixava o novo sem dono, e o `descanso-fim` seguinte não o
  achava para cancelar (o `KEYCODE_POWER` saía fora de hora). O mesmo vale para o laço e o `laco_ligar`.
- "Desligar no descanso" (tarefa 2026-11-02): a home grava o pedido `standby` (até 32 bytes, lista fechada
  `v1 ligado|desligado 10|20|30|60` ou `v1 ler`); o `suite-pedido.sh` passa a `standby-escolha`, que grava
  `standby-escolha` na pasta da suite (umask 077) e publica `standby_conf` = `<1|0>:<min>` (também no `boot`).
  O vigia lê a escolha ao começar: aviso = min × 60 s, standby 60 s depois; desligado, o `standby-inicio` não liga
  o vigia e a escolha de desligar cancela o que estiver em curso. Sem escolha, insegura ou fora da lista: ligado,
  10 min (as constantes 600/660 de antes).
- Só `sfs`/`gfs` e `sbri`/`gbri` no `hidebug`; nunca `sbl`, `gtt` ou `stp`. A temperatura é a prop `zysys.env_temp`.
- Entra na `SUITE_LISTA` e no `KIT_LISTA`/`KIT_EXEC`; o md5 vai embutido no `suite-pedido.sh` e no `suite-boot.sh`
  (`bash tests/atualizar-md5-kit.sh`). Ganchos de teste só com `PFL_TESTE=1`: `PFL_CURVAS_VOLTAS`,
  `PFL_STANDBY_AVISO`, `PFL_STANDBY_TOTAL` (fixam os tempos, acima da escolha), `PFL_STANDBY_MINUTO`.
- `newlink_update.sh`: `term_ok` aceita o `.ini` do kit ou uma variante só nos degraus da `BacklightPolicy`
  (`ini_variante_ok`); `debloat_pendrive` lê `REVERTER-DEBLOAT.txt`/`REAPLICAR-DEBLOAT.txt`.
- Detalhes, formatos e o PROVISÓRIO: [44 §17](../research/44-suite-de-boot.md).

## `suite-chaves.sh` (chaves de ajuste do sistema, bloco 24)

- Onze chaves, ids na ordem fixa `deb_seg deb_ota deb_hisi deb_lnch deb_vlc log_vplug eth0 wifi_pwr web_cmd keystone
  pop_disp` (o `pop_disp` entrou no bloco 27, no fim, para não mexer na posição das outras).
  "Ligada" = a medida está aplicada (app desligado, porta caída...). Desde o bloco 27 a home mostra o contrário, o
  **serviço** (ligado = funciona), e esconde o `wifi_pwr`; a inversão é só dela, o protocolo e a prop não mudam. Cada chave **lê o estado real** do aparelho e volta
  pela mesma chave; nada se desliga sem o dono ligar a chave (ou sem o padrão da instalação, abaixo).
- Comandos: `boot` (reaplica o que o dono escolheu), `pedido` (chamado pelo `suite-pedido.sh`), `aplicar <id>
  ligar|desligar`, `resgate` (desliga todas), `pacotes-fora` (lista que o `desligar_apps` do boot respeita).
- Estado posicional em `vendor.pfl7560.chaves` (um caractere por chave: `1` ligada, `0` desligada, `p` parcial, `-` não
  existe, `?` não li). O aviso da última ação em `vendor.pfl7560.chaves_aviso` = `id:codigo:epoch`. Escolhas do dono em
  `$SUITE/chaves.escolhas`; a escolha só é gravada se o estado relido confirmou (ou se a chave não existe aqui). Se a
  coisa existia e **sumiu** com a mudança (o chip Wi-Fi que cai do barramento), o aviso é `sumiu` e a escolha vira 0,
  para o boot não repetir: reiniciar devolve o aparelho.
- Padrões ao instalar (sem escolha explícita): os cinco grupos de debloat, o log do vplugin e o `pop_disp` ligados; eth0, chip Wi-Fi,
  web/cmdsrv e keystone desligados. `debloat-revertido` segura só `deb_vlc`. `deb_lnch` só liga com a home instalada
  e ativa. O protetor de tela não entra no debloat.
- Grupos: `deb_seg` (autotest, factorymenu, tvtestingtools, hikeymasterprovision, ijkplayerdemo, location.fused),
  `deb_ota` (`com.newlink.service`, `service2`), `deb_hisi` (music, videoplayer, tvui, tv.menu; **nunca** `higallery`:
  é o visor de fotos, lista de negação com teste de lista contaminada), `deb_lnch`, `deb_vlc` (só o Office desde o bloco 27; o
  id ficou `deb_vlc` para não mudar a prop. As chaves e o debloat não mexem no VLC; quem o tira do usuário 0, uma
  vez, é o `suite-boot.sh`, acima).
- Outras: `log_vplug` = `setprop log.tag.HI_VPLUGIN S`; `eth0` = `ip link set eth0 down|up`; `wifi_pwr` acha o USB
  `a69c:8d80/8d81` e escreve `auto`/`on` em `power/control` (pode derrubar Wi-Fi e adb); `web_cmd` = `stop|start boa`
  e `cmdsrv`; `keystone` = `persist.hisi.keystone.enable` (vale no próximo boot); `pop_disp` = `setprop
  vendor.newlink.hisi.hdmiisdialog 0` (o pop-up "Dispositivo conectado" é do `com.zhiying.settings`, que só abre a
  janela com a prop != 0; de fábrica 1). Não é persist: o boot reaplica, e desligar devolve o valor do
  `/vendor/build.prop` (1 se faltar). Firmware sem a prop = `-`, sem `setprop`.
- **Resgate:** o arquivo `DESLIGAR-CHAVES.txt` no pendrive desliga todas a cada plugada e grava escolha 0 em todas
  (sem marca de "feito"). A escolha 0 é gravada **antes** da trava, e o boot só toma a trava depois de esperar o
  `pm`: o `newlink_update.sh` e o `suite-boot.sh` sobem juntos no `boot_completed`, e o resgate não pode perder a
  vez (espera a trava até 180 s; sem ela, as escolhas já ficaram 0 e o boot seguinte desliga). Pedido da home: `v1 ler` ou `v1 <id> ligar|desligar`; id e ação fora da lista são recusados.
- As ações de cada chave vão para `$SUITE/diario.fila` (`<uptime> <id> <acao> <resultado>`, máx. 60), de onde o diário
  as lê quando existir.

## `suite-diario.sh` (diário do projetor, bloco 24)

- Um laço (processo `sh suite-diario.sh laco`, pid em `/dev/pfl7560-diario.pid`, conferido pelo `/proc/<pid>/cmdline`)
  grava **1 linha por minuto** em `$SUITE/diario/diario-0.txt` e `diario-1.txt` (pasta 700, arquivos 600). Cada arquivo
  tem no máximo 256 KB; ao encher, passa para o outro e **apaga** o que lá havia (ponteiro em `$SUITE/diario.atual`).
- A linha é ASCII, `chave=valor` sem espaço dentro do valor, `-` para o que faltou:
  `up dt boot env placa luz load vent led wifi eth mem ch ev` (uptime, data do aparelho, id do boot, temperaturas,
  luz, carga, ventilador, LED, Wi-Fi, eth0, memória, chaves, eventos). Só lê `getprop` (`zysys.env_temp`,
  `zysys.light_temp`, `vendor.pfl7560.luz|vent|led|chaves`), `/proc` e `/sys`. Nunca `hidebug`, `gtt` nem `logcat`.
- `ev` traz as linhas novas de `$SUITE/diario.fila` (as chaves da `suite-chaves.sh`): até 5 (`id:acao:resultado`),
  depois `,+N`. Ao ligar, a fila é marcada como vista (o passado não é despejado).
- Comandos: `iniciar` (boot: sobe o laço se não está desligado), `laco`, `uma-linha`, `ligar`, `desligar`, `enviar`,
  `enviado <AAAA-MM-DDTHH:MM:SS>`, `ler`, `parar`, `pedido "v1 ligar|desligar|enviar|ler"`.
- **Chave do dono:** `desligar` cria a marca `$SUITE/diario.desligado` e para o laço; o boot não sobe o laço com a
  marca. `ligar` apaga a marca e sobe o laço. O resgate `DESLIGAR-CHAVES.txt` não mexe no diário (não é medida
  de sistema) e a desinstalação da suíte para o laço.
- **Enviar agora** só cria `$SUITE/diario.envio`; quem busca é o PC (`pfl7560-diario.sh`), que ao terminar chama
  `enviado <data>`: isso apaga o pedido e grava a data em `$SUITE/diario.ultimo-envio`.
- Props: `vendor.pfl7560.diario` = `<1|0>:<bytes>:<pedido 0|1>`; `vendor.pfl7560.diario_envio` = data do último envio.
- Pedido da home: arquivo `diario` (`v1 ligar|desligar|enviar|ler`, até 32 bytes), tratado pelo `suite-pedido.sh`
  como os outros (dono da pasta da home, `mv` para a pasta do root). O `suite-pedido.sh` e o `suite-boot.sh`
  guardam o md5 do `suite-diario.sh`; ele próprio não guarda md5 de ninguém.
- Ganchos de teste (só com `PFL_TESTE=1`): `PFL_DIARIO_MAX`, `PFL_DIARIO_INTERVALO`, `PFL_DIARIO_VOLTAS`.

## `suite-logo.sh` (bloco 25: logo automático do boot)

- Três modos: `boot` (do `suite-boot.sh`, em segundo plano, depois do lançamento da suíte), `chave ligado|desligado`
  (do `suite-pedido.sh`, pedido `logo-auto` da home, até 16 bytes) e `estado` (só publica as props).
- **Estado numa pasta só do root fora da suíte** (`/data/vendor/pfl7560-logo`, 0700): sobrevive ao
  `--desinstalar` da suíte, porque os backups da partição moram lá. `desligado` (marca; sem ela = ligado),
  `cantos`, `jpeg-md5`, `gravado-em`, `motivo`, `primeiro.img`, `ultimo.img`, `logo.log`.
- **O que se compara é o JPEG da partição, não o registro.** Os cantos registrados só valem se o md5 registrado é o
  do JPEG que está na partição; a arte reta é reconhecida pelo md5 da arte. Registro perdido ou adulterado = gera
  de novo e, se o JPEG gerado é o que já está lá, só adota.
- **As conferências do `pfl7560-marca.sh`, na mesma ordem:** modelo, md5 do `nl_logo` e da arte (bloco
  `LOGO_MD5`), tamanho da partição, `LOGO_TABLE`; backup inteiro conferido por tamanho e md5 contra a partição;
  `LOGO_TABLE` do backup; imagem montada com `LOGO_KEY_LEN` = tamanho do JPEG; a partição ainda igual ao backup;
  só então os dois `dd` (JPEG com `bs=4096 seek=2`, `keylen.bin` com `bs=1 seek=120`, sem `conv`), `sync` e o md5
  da partição inteira igual ao da imagem montada. Errado: `dd` do backup inteiro de volta, conferido, e a chave
  desliga.
- **Uma vez por boot:** `mkdir /dev/pfl7560-logo.boot` (o `/dev` é tmpfs). Espera 60 s e depois a trava da suíte
  (até 40 x 30 s); com a suíte rodando ainda, desiste neste boot (`suite_rodando`).
- **Props para a home:** `vendor.pfl7560.logo` (`ligado`, `desligado`, `erro`), `logo_cantos`, `logo_hora`,
  `logo_motivo`. Motivos: os do `nl_logo cantos` mais `programa`, `arte`, `modelo`, `particao`, `cabecalho`,
  `trabalho`, `gerar`, `backup`, `primeiro`, `montar`, `mudou`, `suite_rodando`, `pendrive`, `releitura_devolvido`,
  `releitura_sem_volta`.
- `newlink_update.sh`: `nl_logo` e `suite-logo.sh` no `KIT_EXEC`; a arte `marca/logo.jpg` agora também vai para a
  suíte (o `suite_nomes` só tira a `bootanimation.zip`); `logo_pendrive` roda sempre (com ou sem suíte) e,
  com `DESLIGAR-LOGO-AUTO.txt`, cria a pasta do logo se faltar, põe a marca `desligado` e o motivo `pendrive`.
- O md5 do `suite-logo.sh` vai no `suite-boot.sh` e no `suite-pedido.sh` (`LOGO_MD5`); os do `nl_logo` e da arte no
  próprio `suite-logo.sh`. Gancho de teste só com `PFL_TESTE=1`: `PFL_NLLOGO`, `PFL_NLLOGO_MD5`.

## Provisório (o aparelho confirma)

| Arquivo | Constante ou função | O que falta | Doc |
|---|---|---|---|
| `cor.sh` | `AUTOFOCO_FOLGA=5` | folga depois do fim do autofoco de boot | 44 §11 |
| `suite.sh` | `AUTOFOCO_FOLGA=5` | idem, na suíte | 44 §11 |
| `suite-boot.sh` | `ESPERA_MONTAGEM=20` | espera um pendrive do kit montar antes de decidir | 44 §11 |
| `suite.sh` | `LIMIAR_BORDA_PX_1280=3.5` | limiar proporcional à largura (2× a borda boa); a 640 dá 1,75 px e o 640×480 real (2,6 a 2,9 px) passaria | 44 §11 |
| `suite.sh` | `SINAL_INCLINACAO=1` | graus > 0 = faixas descem para a direita no quadro; como o quadro vem espelhado de cima para baixo, na parede o lado direito está mais alto; −1 inverte | 44 §11 |
| `suite.sh` | `VARRE_PASSO`, `VARRE_LADO`, `VARRE_PAUSA`, `VARRE_CHEGADA`, `VARRE_TOLERANCIA`, `VARRE_GANHO` | unidade do `gfd`/`sfd` e o critério do "Motor is too hot!" | 44 §16 |
| `suite.sh` | `foco_pos`, `foco_faixa` | formato da saída do `gfd` e do `gfdr`; sem número, a varredura não mexe no motor | 44 §16 |
| `suite.sh` | `ler_modo_projecao` | o rótulo do menu de cada valor de `persist.sys.mountingmode` (doc 43 §5) | 44 §11 |
| `suite.sh` | leitura do `fan speed` | unidade não medida; 0 = parada | 44 §11 |
| `cor.sh` | `preparar_tela` | E1-e: a galeria abre PNG fora de `/sdcard` | 41 |
| `cor.sh` | `esperar_tecla` | E1-d: `getevent -ql` sem bufferização num pipe | 41 |
| `cor.sh` | gancho `nlsu` | E1-c: o init executa o `update_after_boot.sh` | 41 |
| `suite-curvas.sh` | piso 700 (70 %, bloco 25), `LED_MIN=850`, standby 600/660 s, `KEYCODE_POWER` = tecla do IR, `mWakefulness=Dreaming`, Luz (`picture`) x `sbri` | 44 §17 |
| `newlink_update.sh` | lançamento destacado | o `exec` do init é bloqueante e não mata o grupo no fim | 41 |
| `suite-logo.sh` | `dd` na partição sem `conv`, espera 60 s + trava da suíte | o bootloader lê o JPEG do `stb_image_write`; o `dd` do toybox no bloco como no PC | 44 §18 |
| `nl_logo.c` | `MAX_JPEG` 256 KiB, `AREA_MIN_PCT` 25, regra do quadrante | limite do bootloader; o que é canto "absurdo" | 44 §18 |
