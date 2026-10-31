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
| `newlink_update.sh` | lançamento destacado | o `exec` do init é bloqueante e não mata o grupo no fim | 41 |
