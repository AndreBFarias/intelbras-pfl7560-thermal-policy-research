# Bloco 9B - a suíte: orquestração, serviço de boot, gatilho da tomada e do pendrive (2026-10-30)

Parte do [bloco 9](2026-10-30-bloco-9-suite-de-boot.md) (decisões, fatos 1-10 e contratos C-geo, C-tela, C-res
lá). Usa a pesquisa P (`docs/research/43-pesquisa-autofoco-keystone-teclas.md`) para o autofoco e o modo de
projeção. Branch `bloco-9b/suite`, worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-9b`.

`nl_tela` e `nl_camcheck geometria` são feitos em paralelo pelo 9A: aqui eles entram por stub no harness, com
a interface dos contratos. O coordenador integra os binários reais e as listas de md5 depois.

## Arquivos

- Novos em `pendrive-autorun/` (ASCII puro, byte-exatos, `#!/vendor/bin/sh`, estilo e convenções do `cor.sh`):
  `suite.sh` (orquestra as etapas), `suite-boot.sh` (lançado pelo serviço de boot: decide se roda),
  `suite-pedido.sh` (chamado pelo vigia do pedido do app), `pfl7560-suite.rc` (serviço de boot).
- Mudam: `newlink_update.sh` (instala a suíte e lança a suíte em vez do `cor.sh`), `cor.sh` (modo `suite`,
  mudança mínima), `tests/atualizar-md5-kit.sh` (md5 embutidos novos), `tests/test-kit-pendrive.sh` (o que a
  mudança quebrar), `tests/test-suite.sh` (novo), `Makefile` (roda o novo teste no `check-kit`).

## B1 - Instalação (pelo pendrive, no `newlink_update.sh`)

1. Pasta da suíte `/data/vendor/pfl7560-suite` (root, 0700, mesmas regras `dir_seguro`/`arq_seguro` do E3b).
   Copia para ela: `suite.sh`, `suite-boot.sh`, `suite-pedido.sh`, `cor.sh`, `lvdsctl`, `nl_camcheck`,
   `nl_tela`, `kit/*.png`, `fontes/*`. Idempotente: só regrava o que tem md5 diferente; confere tudo depois.
2. Serviço de boot `/vendor/etc/init/pfl7560-suite.rc` (dentro do bloco que já remonta o `/vendor` em rw):

   ```
   service pfl7560_suite /vendor/bin/sh /data/vendor/pfl7560-suite/suite-boot.sh
       user root
       group root
       seclabel u:r:vendor_shell:s0
       oneshot
       disabled

   on property:sys.boot_completed=1
       start pfl7560_suite
   ```

   Escrita atômica, `chmod 0644`, `chown root:root`, `chcon u:object_r:vendor_configs_file:s0` (copie o rótulo do
   `init.bigfish.rc` vizinho se `ls -Z` responder; registre no log o rótulo final). Idempotente por conteúdo.
   Um `.rc` novo não exige reboot agora: vale no próximo boot.
3. Pasta do pedido do app: `/data/media/0/pfl7560` (vista pelos apps como `/sdcard/pfl7560`), dono
   `media_rw:media_rw`, `0775`. Só o arquivo `pedir-verificacao` importa; o conteúdo é ignorado.
4. Desinstalar: `suite.sh --desinstalar` remove o `.rc` (com remount), a pasta da suíte, a pasta do pedido e
   mata o vigia. O pendrive com um arquivo `DESINSTALAR-SUITE.txt` na raiz faz o `newlink_update.sh` chamar isso
   em vez de instalar (o 9C documenta).

## B2 - Gatilhos (`suite-boot.sh`)

1. Sempre: registra em `historico-boot.txt` (últimos 30) uma linha com data, `sys.boot.reason`,
   `persist.sys.boot.reason`, `ro.boot.bootreason`, a linha do `dmesg` com `setting system clock to` (ano),
   `/sys/class/rtc/rtc0/since_epoch`, o conteúdo resumido de `/proc/msp/pm` e a decisão tomada. É o que o teste
   final usa para calibrar o gatilho.
2. Modo em `/data/vendor/pfl7560-suite/gatilho` (`auto` padrão, `sempre`, `nunca`). Em `auto` roda se **algum**:
   (a) ano do relógio no boot < 2020 (relógio zerou = ficou sem energia); (b) `sys.boot.reason` não começa com
   `shutdown,` nem `reboot,` (desligamento não foi limpo). Constantes nomeadas e marcadas PROVISÓRIO.
3. Não roda: se a suíte terminou há menos de 10 min (proteção contra laço); se há um pendrive com
   `newlink_update.sh` montado (o fluxo do pendrive cobre; registra e sai); se outra instância tem a trava.
4. Liga o vigia do pedido: `inotifyd /data/vendor/pfl7560-suite/suite-pedido.sh /data/media/0/pfl7560:wy`
   destacado (se `inotifyd` não existir, laço com `sleep 30` lendo o arquivo; registre qual ficou). Um só
   vigia por boot.
5. Lança `suite.sh tomada` destacado (`setsid`), conferindo o md5 dele contra o embutido no `suite-boot.sh`.

`suite-pedido.sh`: aceita só o evento do arquivo `pedir-verificacao`; apaga o arquivo; respeita os 10 min e a
trava; lança `suite.sh pedido` destacado.

## B3 - A suíte (`suite.sh tomada|pendrive|pedido [mountpoint]`)

Trava em `/dev/pfl7560-suite.lock` (como o `cor.sh`). Log em `ultimo.log` (e no pendrive no modo `pendrive`).
Antes de executar cada binário/script: `arq_seguro` + md5 da lista embutida, na hora. Telas por `nl_tela`
(C-tela) em `/sdcard/pfl7560-suite/<nome>-<epoch>.png`; se o `nl_tela` falhar, usa os PNG estáticos do kit
(`aguarde`, `pronto`, `erro`). Mostrar = `force-stop` do pacote resolvido + `am start` (copie o `mostrar` do
`cor.sh`). Nenhuma tela do modo `tomada` ou `pedido` cita pendrive; no modo `pendrive` a última tela é
"Pode tirar o pendrive." até ele sair (até 60 s) e então volta à tela inicial.

Etapas, na ordem (cada uma grava o resultado em `resultados.txt`, chave=valor):

0. **Abertura** (`aviso`): título por modo — tomada: "Voltou a energia. Conferindo o projetor."; pendrive:
   "Pendrive do kit encontrado. Conferindo o projetor."; pedido: "Verificação pedida. Conferindo o
   projetor." Texto, os 4 passos em `fila`, rodapé "não precisa apertar nada". 5 s. Depois espera o autofoco
   de boot (a função `aguardar_autofoco` do `cor.sh`, uma vez só).
1. **Cor**: prepara `/data/vendor/pfl7560-kit` a partir da pasta da suíte (mesmas conferências do
   `newlink_update.sh`) e roda `cor.sh <mp ou vazio> <aviso> <md5> suite`. No modo `suite` o `cor.sh` **não**
   mostra a tela final e grava `cor_resultado=ordem|corrigido|manual_mantido|manual_trocado|erro`,
   `cor_formato_antes=`, `cor_formato_depois=`, `cor_faixas=` num arquivo que a suíte lê. Sem pendrive (modos
   tomada/pedido) o `cor.sh` precisa continuar seguro: backup e journal na pasta da suíte (persistente), sem a
   cópia no pendrive. Mude o mínimo no `cor.sh`, mantenha todos os casos do `test-kit-pendrive.sh` verdes e
   acrescente os casos do modo `suite`.
2. **Ângulo, foco e nitidez**: `mostrar calibracao`, `nl_camcheck faixas` e `nl_camcheck geometria` (C-geo).
   Foco ruim (borda de um lado > 1,6 x a do centro, ou > `LIMIAR_BORDA_PX`): refaz o autofoco pelo comando da
   pesquisa P, espera `vendor.focus.camera.is_focused=true` (até 60 s) e mede de novo, até 2 vezes. Inclinação
   `|graus| > 1,5`: dica de nivelar (lado pela constante `SINAL_INCLINACAO`, PROVISÓRIO). Trapézio > 3 % ou
   borda central > `LIMIAR_BORDA_PX` com a correção de 4 pontos ligada: conselho de alinhar o projetor de frente
   e zerar os 4 pontos. Limiar em px proporcional à largura do quadro; ponha os valores medidos pelo 9A (no
   relatório dele, ou recalcule com o `nl_camcheck` do host sobre os quadros reais) num comentário ao lado das
   constantes. Câmera falhou: itens `pendente`, a suíte segue.
3. **Temperatura** (tela `aviso` "Etapa 3 de 4 · temperatura"): `zysys.env_temp`, `zysys.light_temp`, ventoinha
   e brilho pelo `hidebug` **sem `gtt`** (fato 5), md5 do `ZYCustom.ini` efetivo (ordem `/atv/ini` → `/vendor`,
   como o `ini_efetivo` do `pfl7560-saude.sh`), escada presente. LED ≥ 66 °C: atenção + dica de ventilação.
4. **Teste ativo da rampa** (tela `aviso` explicando que a imagem escurece por cerca de 1 min): porte fiel do
   `--vivacidade` (fato 6) com trap EXIT/INT/TERM/HUP que limpa e confere; 71000 fixo e nunca configurável;
   só injeta se o `WARNING_VALUE` e o `EMERGENCY_VALUE` lidos agora deixarem 71000 entre os dois.
5. **Resumo** (`resumo`, C-tela): os 19 itens na ordem do dono; título "Tudo certo." / "Tudo certo." +
   destaque "N correção(ões) feita(s)." / "Atenção: …"; até 3 dicas; rodapé com o motivo, data e hora e o
   caminho do relatório. 20 s ou qualquer tecla (`getevent -ql` como no `cor.sh`). Depois `force-stop` da
   galeria e `input keyevent KEYCODE_HOME`.

Itens que dependem de leitura ainda não confirmada no aparelho (modo de projeção, 4 pontos ligada): usar o que a
pesquisa P achar; sem resposta, `pendente` com o valor "[a ler]".

## B4 - Harness `tests/test-suite.sh`

Stubs (no estilo do `test-kit-pendrive.sh`): `am`, `cmd`, `getprop`, `setprop`, `logcat`, `hidebug`,
`nl_camcheck`, `nl_tela`, `lvdsctl`, `getevent`, `input`, `dmesg`, `inotifyd`, `mount`, `chcon`, `setsid`.
Casos mínimos:
- gatilho: matriz (relógio zerado, motivo limpo/sujo, `gatilho=sempre|nunca`), proteção de 10 min, pendrive
  presente no boot, trava ocupada, histórico com 30 linhas no máximo;
- instalação: `.rc` com o conteúdo exato, modo 0644 e `chcon`; idempotência (2ª vez não regrava); md5 de um
  arquivo adulterado na pasta da suíte aborta antes de executar; link simbólico recusado; desinstalar;
- etapas: cor nos 4 resultados; geometria boa, inclinada, foco ruim que melhora no 2º autofoco, câmera falhou;
  temperatura normal e LED quente; rampa que reage, que não reage, e morte no meio (o trap limpa o override);
- `hidebug` nunca recebe `gtt`; nenhum arquivo do kit tem byte não-ASCII; nenhuma tela dos modos tomada/pedido
  tem a palavra "pendrive" nos campos; o resumo tem os 19 itens; no modo pendrive a tela final existe;
- o `newlink_update.sh` passa a lançar a suíte (e não o `cor.sh` direto) e continua com todos os casos antigos.

## Restrições

- Nenhum agente fala com o projetor. ASCII puro e byte-exato no kit; md5 só pelo script. Nada de
  `git add -A`, `.` ou `--all`; commits pequenos sem linha de atribuição; push do branch no fim.
- `shellcheck` sem aviso novo; `bash -n` e `dash -n` em tudo; `make check`, `check-kit`, `check-fix` verdes.

## Prova

1. Os testes acima verdes, com a contagem no relatório.
2. Relatório final: o que ficou PROVISÓRIO (constantes e premissas) e o que o teste no aparelho precisa
   confirmar, em lista.

## Estado (implementação, 2026-10-30)

Feito no branch `bloco-9b/suite`. Nada rodou no aparelho: tudo abaixo é harness com stubs.

- **B1:** o `newlink_update.sh` instala a suíte em `/data/vendor/pfl7560-suite`, só os arquivos com md5 diferente,
  por uma pasta de preparo dentro dela. Grava também o `.rc` dentro da janela rw do `/vendor`: é montado em
  `/vendor/etc/pfl7560-suite.rc.new`, fora da pasta que o init lê, e só entra nela por `mv`, com `chmod 0644`,
  `chown root:root` e `chcon` com o rótulo do `init.bigfish.rc` vizinho. Cria a pasta do pedido e lança
  `suite.sh pendrive` no lugar do `cor.sh`. O `DESINSTALAR-SUITE.txt` remove a suíte e roda só o `cor.sh`.
  Se a suíte não instalar, o kit roda só o `cor.sh`, como antes.
- **B2:** o `suite-boot.sh` cuida do histórico (30 linhas), do gatilho `auto|sempre|nunca`, dos 10 min, do
  pendrive, da trava e do vigia (`inotifyd`, ou um laço de 30 s). O processo do serviço fica vivo com `wait`
  enquanto o vigia vive. O `suite-pedido.sh` trata o pedido do app.
- **B3:** o `suite.sh` faz as 5 etapas e o resumo de 19 itens. O `cor.sh` ganhou o modo `suite`: sem as telas
  dele, sem a espera do autofoco, com o resultado em `cor-resultado.txt` e, sem pendrive, a cópia do backup
  na pasta da suíte. O autofoco agora é lido por `sys.newlink.auto` (doc 43 §2.3), no `cor.sh` e na suíte.
- **B4:** `tests/test-suite.sh` (novo) e `tests/test-kit-pendrive.sh` (adaptado ao fluxo da suíte), os dois no
  `make check-kit`. O `tests/atualizar-md5-kit.sh` gera em cadeia `SUITE_LISTA` → `SUITE_MD5` → `KIT_LISTA` e
  inclui `nl_tela` e `fontes/` quando existirem.

Desvios do texto do spec:

1. A etapa 2 espera `sys.newlink.auto` (1 e depois 0, teto de 70 s), não `is_focused=true` (doc 43 §8).
2. Com os 4 pontos ligados, a inclinação vira o conselho de zerar os 4 pontos, e não a dica de nivelar.
   Motivo: a câmera é presa ao projetor e não vê o projetor girado; o que ela vê inclinado vem da correção.
3. Nos modos tomada e pedido, as telas estáticas de reserva são só `aguarde` e `calibracao`: `pronto` e
   `erro` falam de pendrive. Sem o `nl_tela`, o resumo não aparece; o resultado fica no `resultados.txt`.
4. Travas da rampa além das do spec: o `.ini` efetivo tem de ter o md5 de um corrigido, e o LED tem de estar
   abaixo de 66 °C (o override mascara o sensor por 40 s).
5. No modo pendrive, com a trava ocupada por outra suíte, a suíte espera até 10 min, para que a última tela
   ainda peça para tirar o pendrive.

PROVISÓRIO (o teste no aparelho confirma):

- os critérios do gatilho `auto` (`ANO_MIN=2020`, prefixos `shutdown,`/`reboot,`) e o `ESPERA_MONTAGEM=20`;
- `SINAL_INCLINACAO=1` e se a câmera vê alguma inclinação real (teste 4 do bloco 9);
- `LIMIAR_BORDA_PX_1280=3.5`, proporcional à largura (o 640x480 real passaria dele);
- `AUTOFOCO_FOLGA=5` (antes 30 s, com o sinal errado);
- a leitura de `persist.sys.mountingmode` (rótulo do menu não provado) e a unidade do `fan speed` (0 = parada);
- o `inotifyd` no toybox do Android 9 e a escrita do app vista pelo inotify no `/data/media`;
- `logcat -T 1` no Android 9 (sem ele, "não reagiu" falso, nunca injeção sem limpeza).
