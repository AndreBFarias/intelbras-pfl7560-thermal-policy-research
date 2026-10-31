# 47 — Build completa: o que a nova build leva por padrão, e o que não cabe nela (2026-10-31)

**Estado: gerador parametrizado pronto e provado só no PC. Nada foi gravado no aparelho.** Gravar o `.bin` é o
gate BIN-S4a: só com a palavra do dono naquele momento, com o pendrive de resgate na mão, e **nunca** no modelo
sem USB-C com esta base. Spec: [bloco 12](../sprints/2026-10-31-bloco-12-build-completa.md).

> **Bloco 21 (2026-10-31): leia a §10 primeiro.** A folga de 65312 bytes das seções 2 e 6 vinha toda de chunks
> FILL que o re-pack criava, forma que o loader nunca gravou; as builds `eae3a83d` e `397698b9` saíram de uso. O
> gate BIN-S4a passa a gravar `PFL7560-S4a-NAO-GRADUADO.bin` (os 3 fixes nos mesmos blocos do stock, md5
> `a6e5da14…`), e a build completa vira o BIN-S4b, realocada, com o `.rc`, o app, a home e as 20 sobreposições
> (`PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin`, md5 `e6b41856…`).

Pedido do dono: "nossa nova build vai conferir isso tudo né? por default? [...] ter essas correções e o sistema
operacional todo prontinho."

---

## 1. Resposta curta

- **Por padrão, a build nova leva:** a correção térmica com a escada de brilho (`ZYCustom.ini`), o Wi-Fi que
  reconecta sozinho (`build.prop`), o `xiriservice` desligado (`init.bigfish.rc`) e o **serviço de boot da
  suíte** (`/vendor/etc/init/pfl7560-suite.rc`), todos com modo, dono e rótulo SELinux carimbados e conferidos.
- **Não leva o app nem a suíte.** O motivo é medido, não escolhido: o vendor viaja no `.bin` dentro de um slot
  de tamanho fixo, e esse slot tem só **65312 bytes de folga** (seção 2). O app sozinho pede cerca de 110 KB; a
  suíte, cerca de 1,4 MB.
- **Mesmo que coubessem, o pendrive do kit seria obrigatório depois da gravação.** Gravar o `.bin` formata o
  `/data` (visto em julho, [guia 16](../guide/16-recuperacao-brick.md) §1; o `misc` do container pede
  `--wipe_data`, [doc 42](42-firmware-2026-10-modelo-sem-usbc.md)), e a suíte mora em `/data/vendor`. Além disso,
  a `panelparam` provavelmente vem no container ([doc 41](41-auto-pareamento-camera-e-kit-universal.md) §3) e a
  gravação devolve o formato de cor ao de fábrica: um painel JEIDA precisa do kit para voltar a ter cor certa. O
  JEIDA não entra no `.bin`, porque depende do painel de cada aparelho.
- **Bloco 21:** com `--realocar` (opção c, §10) o app, a home e as 20 sobreposições cabem; a suíte segue pelo
  pendrive, porque mora no `/data`.
- **Recomendação (bloco 12):** opção (a) da spec, do tamanho que cabe: `.bin` com os 3 fixes e o `.rc`; app e suíte pelo
  pendrive do kit, uma vez, logo depois da gravação. Nenhum script do kit precisa mudar (seção 4).

## 2. A medida que manda: a folga do slot do vendor

Medido no stock V1.0.0.9 (`28a2f280…`, extraído do zip LFS conferido pelo sha256 `08d37bbb…`):

| Grandeza | Valor |
|---|---|
| Record 14 (vendor) | prefixo em `0x4b0b1d54`, payload sparse de **80593044** bytes |
| ext4 do vendor | 76800 blocos de 4 KiB (300 MiB): 22074 usados, **54726 livres** (213 MiB); 722 de 76800 inodes |
| Tamanho do inode | **128 bytes**: o `security.selinux` não cabe no inode e vai num bloco de xattr próprio, um por arquivo (o stock também é assim) |
| Blocos livres com dado | 0 (todo bloco livre do stock é zero: não há o que recuperar zerando) |
| Re-pack do stock sem mudança nenhuma | 80527732 bytes: **folga de 65312 bytes** (15,9 blocos) |
| Depois dos 3 fixes (build `eae3a83d`) | 80540020 bytes: folga de **53024** (12,9 blocos) |
| Depois dos 3 fixes e do `.rc` (`conteudo.txt`) | 80548212 bytes: folga de **44832** (10,9 blocos) |

**Correção do bloco 21:** essa folga é 100 % dos 8 chunks FILL do re-pack (16 blocos de libs como
`/lib/libhi_msp.so`: 16 x 4096 - (8 x 16 + 8 x 12) = 65312). O stock só tem RAW e DONTCARE e ocupa o slot exato;
sem FILL, nada novo cabe no slot (§10).

O limite não é o ext4, que tem 213 MiB livres: é o transporte. O sparse do vendor ocupa um slot fixo dentro do
container LOAD, e crescer além dele exige mexer na tabela, no `checksum1` e na posição dos records 15 a 18
(opção c).

Custo de cada coisa, medido com o `debugfs` no vendor real: um arquivo novo gasta os blocos de dados mais **1
bloco de xattr**; uma pasta nova gasta 2 blocos (o da pasta e o de xattr).

| O que entraria | Blocos de 4 KiB | Cabe nos 12,9 que sobram? |
|---|---|---|
| `pfl7560-suite.rc` (398 B) | 2 | sim |
| app: `PFL7560.apk` (95577 B no bloco 12; 189941 B no bloco 21) e a pasta `/vendor/app/PFL7560` | 24 + 1 + 2 = **27** | não |
| suíte: 21 arquivos (1247378 B: scripts, `nl_tela`, `nl_camcheck`, `lvdsctl`, `kit/*.png`, `fontes/*`) e 3 pastas | 316 + 21 + 6 = **343** | não |

A rodada real com o app no manifesto confirma: o gerador recusa com `maior que o slot stock`, e nenhum `.bin` é
gerado (seção 6).

## 3. As opções

| | (a) `.rc` + app + fixes; suíte pelo pendrive | (b) suíte também no `/vendor`, copiada para o `/data` no 1º boot | (c) aumentar o slot do vendor no container |
|---|---|---|---|
| Cabe hoje | só o `.rc` e os fixes (o app não) | não (343 blocos contra 12,9) | cabe tudo, se o slot crescer |
| `newlink_update.sh` | nada obrigatório | o `.rc` do kit teria de ser o mesmo da build; a cópia para `/data` ganharia a regra de versão (ver abaixo) | nada |
| `suite-boot.sh` | nada | ganha a cópia conferida por md5 e a regra de versão; o `.rc` passa a chamar um script do `/vendor` | nada |
| Risco no boot | o `.rc` é o mesmo que o init do aparelho já lê desde o teste de 2026-10-30, com os mesmos metadados | o mesmo `.rc` mais uma cópia de 1,2 MB no 1º boot; uma falha dela não trava o boot (serviço `oneshot`, `disabled`, depois do `sys.boot_completed`), mas deixa a suíte meio copiada | **classe nova de risco:** um container com a tabela e o `checksum1` reescritos nunca passou pelo loader; o resgate continua (o loader não é tocado), mas o 1º teste seria de outra natureza que o BIN-S4a |
| Idempotência com o kit | total: o kit acha térmico, Wi-Fi, xiri e `.rc` em dia e não regrava; só o app entra | conflito de versões: a cópia do `/vendor` fica velha quando o kit atualiza a do `/data` | igual à (a) |
| Valor depois da gravação | o pendrive é obrigatório de qualquer jeito (`/data` formatado, cor) | economiza o pendrive só para a suíte, não para a cor | idem |

**O que a (b) mudaria nos scripts, se um dia o slot permitir** (não mudei nada; é o que mudaria):

1. `pfl7560-suite.rc`: `service pfl7560_suite /vendor/bin/sh /vendor/etc/pfl7560-suite/suite-boot.sh`, porque o
   `/data` chega vazio depois da gravação e o script atual (`/data/vendor/pfl7560-suite/suite-boot.sh`) não existe.
2. `suite-boot.sh`: antes do `dir_seguro "$SUITE"`, criar `/data/vendor/pfl7560-suite` (0700, root) se faltar e
   copiar de `/vendor/etc/pfl7560-suite/` os arquivos da lista com md5 embutido (a `KIT_LISTA` do kit),
   por uma pasta de preparo, conferindo antes de cada `mv`, como o `instalar_suite_arquivos` do kit faz.
3. Regra de versão nos dois scripts: copiar só o que **falta** no `/data`, nunca por cima de um arquivo que o
   kit já atualizou (senão um `.bin` velho rebaixaria uma suíte nova a cada boot). O `newlink_update.sh` não
   precisaria mudar na cópia, mas o `.rc` dele teria de ser byte a byte o da build, ou o `rc_conforme` trocaria
   o serviço pelo dele.
4. O `newlink_update.sh` ganharia na `KIT_LISTA` o `.rc` novo, e o `tests/atualizar-md5-kit.sh` passaria a gerar
   também a lista que o `suite-boot.sh` usa para a cópia.

**O que a (c) exigiria:** no gerador, deslocar os records 15 a 18 pelo crescimento do vendor (alinhado como os
outros), reescrever os offsets e tamanhos deles e o do vendor na tabela, o tamanho total em `0x10` e o
`checksum1`; e provar, no PC, que o container novo é coerente. A dúvida que só o aparelho tira é se o loader
aceita um record maior que a partição de origem do container de fábrica (a partição na eMMC tem 300 MiB, então o
dado expandido continua cabendo). É uma decisão do dono, para outro bloco. **Bloco 21:** o risco estava
superestimado, porque esses são os mesmos campos que a HiSilicon muda entre o V1.0.0.1 e o V1.0.0.9 (os records
são contíguos e sem alinhamento); implementado como `--realocar` (§10).

## 4. Recomendação, e o que mudaria no kit

**(a), do tamanho que cabe.** O `.bin` leva os 3 fixes e o `.rc`; app e suíte entram pelo pendrive do kit, uma
vez, logo depois da gravação. Por quê:

- o pendrive é obrigatório depois de qualquer gravação: `/data` formatado e cor de fábrica;
- não há espaço para mais, sem a (c);
- o `.rc` é o único arquivo novo e já foi lido pelo init do aparelho com esses mesmos metadados (teste de
  2026-10-30, doc 44); no `.bin` ele é carimbado e conferido três vezes (antes, depois do `e2fsck`, depois do
  re-pack) e de novo por fora, no teste;
- enquanto a suíte não chega, o serviço só falha em silêncio: o `sh` não acha o `suite-boot.sh` no `/data` vazio e
  sai. É um `oneshot` `disabled`, disparado depois do `sys.boot_completed=1`, então não segura o boot.

**No `newlink_update.sh`: nada obrigatório.** Conferido no código, contra o que o `.bin` grava:

| Conferência do kit | O que acha num aparelho recém-gravado | Resultado |
|---|---|---|
| `term_ok` (md5 do `ZYCustom.ini`) | `252ab7a7…` = `INI_MD5_OK` | `termico ja estava ok`, sem `.STOCK` |
| `wifi_ok`, `xiri_ok` | `wifi_disconnect_on_boot=0`; `disabled` logo abaixo do `xiriservice` | `wi-fi ja estava ok`, `xiri ja estava desabilitado` |
| `suite_rc_ok` → `rc_conforme` | `.rc` byte a byte o do kit (`cmp`), `-rw-r--r--`, dono 0, rótulo `vendor_configs_file` = o do `init.bigfish.rc` vizinho (`rotulo_alvo`) | `suite: servico de boot ja estava instalado` |
| `app_conforme` | falta o `/vendor/app/PFL7560` | abre o `/vendor` só para o app (`APP_PEND=1`) e o instala |
| suíte em `/data/vendor/pfl7560-suite` | ausente (`/data` formatado) | `instalar_suite_arquivos` cria e copia |

Duas observações, sem mudança de código:

- o kit só salva `ZYCustom.ini.STOCK`, `build.prop.STOCK` e `init.bigfish.rc.STOCK` quando acha o arquivo de
  fábrica. Num aparelho que veio do `.bin` esses backups não existem; o `pfl7560-fix.sh revert` já cai nos
  artefatos de fábrica versionados no repo, e a volta completa é regravar o stock (seção 8);
- se o `.rc` do kit mudar um dia, o `rc_conforme` vê a diferença e instala o novo por cima do da build: a build
  não trava a evolução do kit. Basta rodar o gerador de novo quando for gerar outra build.

**No `suite-boot.sh`: nada.**

## 5. O gerador

`artifacts/bin-build/build_fix_bin.py` ganhou `--conteudo <manifesto>`. Sem ele, a saída é a de sempre
(`eae3a83d…`, reconferido nesta rodada). O manifesto [`artifacts/bin-build/conteudo.txt`](../../artifacts/bin-build/conteudo.txt)
tem `origem destino modo uid gid rotulo` por linha; as linhas do app estão lá, comentadas, com o motivo. Regras e
recusas no [README do builder](../../artifacts/bin-build/README.md). O que importa para a segurança:

- `verify_meta` agora confere pastas (tipo `directory`) e qualquer arquivo do manifesto, além dos 3 fixes;
  continua abortando se algum arquivo ficar com escrita para grupo ou outros;
- cada arquivo do manifesto é lido de volta da imagem e comparado byte a byte com uma cópia congelada da origem,
  depois do `e2fsck` e depois do re-pack (pega também um `write` do `debugfs` que falhou por falta de espaço);
- blocos e inodes livres são conferidos antes de gravar; a folga do slot, no re-pack;
- tudo o que já existia continua: tamanho do `.bin`, `checksum1` sem mudar, CRC do record 14 recalculado,
  horários fixos e saída determinística.

## 6. Provas no PC

`make check-bin` (sem os stocks): **124 verificações, 0 falhas**. Os casos novos, em containers sintéticos de
4 MiB com inode de 128 bytes como o vendor real:

- manifesto com o `.rc` do kit, uma pasta nova e um app falso de 20 KB dentro dela, a troca de conteúdo de um
  arquivo do stock (mesmos metadados) e duas pastas aninhadas (uma 0700, uma com gid 2000): tipo, modo, dono,
  rótulo com o NUL e conteúdo de cada entrada conferidos por fora com `debugfs stat`/`cat`; a pasta `/app` e os 3
  arquivos do stock sem mudança; `e2fsck -fn` limpo; duas rodadas com o mesmo md5;
- recusas, todas sem gerar `.bin`: app maior que a folga do slot, arquivo maior que o ext4 livre, `.rc` 0664,
  pasta-mãe não declarada, destino fora do `/vendor` ou com `..`, destino derivado (`/vendor/build.prop`),
  metadado declarado diferente do stock, arquivo por cima de uma pasta do stock, origem ausente, rótulo fora do
  formato, destino repetido e linha sem 6 campos;
- duas mutações do gerador conferidas à mão (rótulo sem o NUL; pasta nova sem os metadados carimbados): o teste
  as pega.

**Rodada real** (`PFL_STOCK_ANTIGO=<stock V1.0.0.9> make check-bin`, 147 verificações, 0 falhas):

- a build antiga continua `eae3a83db44f790b64b9a5838a27a977`;
- **`.bin` de teste com o `conteudo.txt`: md5 `397698b97c23b64cfee9e64d55c7f9aa`, CRC do vendor `0xc1eee6da`**,
  1393758396 bytes como o stock. Duas rodadas deram o mesmo md5. **O arquivo foi apagado no fim** (1,3 GB);
- fora do intervalo `[0x4b0b1d58, 0x4b0b1d5c + 80593044)` (o CRC e o payload do record 14) o `.bin` é byte a byte
  o stock; o cabeçalho e a tabela (`0x000`–`0x2b4`) estão intactos; o `checksum1` confere (`0x738ebd09`); o CRC
  gravado confere com o payload;
- conferido por fora com `debugfs`, arquivo por arquivo:

| Caminho no aparelho | Tipo | Modo | uid:gid | Rótulo | Conteúdo |
|---|---|---|---|---|---|
| `/vendor/etc/init/pfl7560-suite.rc` | regular | 0644 | 0:0 | `u:object_r:vendor_configs_file:s0\000` | md5 `cb936047…`, o mesmo do `pendrive-autorun/` e da `KIT_LISTA` |
| `/vendor/etc/ZYCustom.ini` | regular | 0644 | 0:0 | `vendor_configs_file` | = `artifacts/ZYCustom_390.ini` (`252ab7a7…`) |
| `/vendor/build.prop` | regular | 0600 | 0:0 | `vendor_file` | `wifi_disconnect_on_boot=0` e nenhum `=1` |
| `/vendor/etc/init/hw/init.bigfish.rc` | regular | 0644 | 0:0 | `vendor_configs_file` | `disabled` logo abaixo do `xiriservice` |

- `e2fsck -fn` do vendor de saída limpo;
- com o app no manifesto, o gerador recusou com
  `sparse empacotado (80658804) maior que o slot stock (80593044) em 65760 bytes` (o app pediu exatamente 27
  blocos, 110592 bytes). Nenhum `.bin` gerado.

Nada no aparelho: nem adb, nem projetor. **Bloco 21:** `make check-bin` tem 324 verificações sem stock e 443 com
os dois stocks; a recusa do app "maior que o slot stock" deixou de existir (§10).

## 7. O que fica PROVISÓRIO até o gate BIN-S4a

A §11 fixa a ordem: o BIN-S4a grava o **delta mínimo** (só os 3
fixes), para que um travamento não tenha variável confusa; a build com arquivo novo em `/vendor/etc/init` vem
numa 2ª gravação (o antigo BIN-S4b). **Bloco 21:** a 1ª é a `PFL7560-S4a` (`a6e5da14`, nos mesmos blocos) e a 2ª
a `PFL7560-S4b-COMPLETO` (`e6b41856`, realocada, com `.rc`, app, home e sobreposições); a `397698b9` saiu de uso.
Só o aparelho confirma:

1. que o loader grava a build e o Android sobe com os 3 fixes (BIN-S4a) e, na 2ª gravação, também com o `.rc`
   (nenhuma build nossa com metadados carimbados foi gravada até hoje; a de julho, sem eles, travou na logo);
2. que o init lê o `pfl7560-suite.rc` vindo do `.bin` como lê o instalado pelo kit, e que o serviço sem o
   `suite-boot.sh` (antes do pendrive) só falha, sem efeito no boot;
3. que a gravação formata o `/data` também com o nosso `.bin` (visto com o de julho; o `misc` é o de fábrica);
4. que a `panelparam` volta ao de fábrica com a gravação (doc 41 §3, inferido) e o kit corrige a cor depois;
5. que o kit, logo depois, acha térmico, Wi-Fi, xiri e `.rc` em dia e só instala app e suíte (o log da seção 8).

## 8. Roteiro de gravação seguro (para o dono, no dia do BIN-S4a)

São duas gravações, na ordem da §11, cada uma com a mesma disciplina. Na 1ª (BIN-S4a) vai a build de 3
fixes; só se ela subir limpa vem a 2ª, com o `.rc`.

**Antes (no PC):**

1. Gere a build: `unzip -j "firmware/Software PFL7560.zip" "*/PFL7560.bin" -d <pasta>` e
   `python3 artifacts/bin-build/build_fix_bin.py <pasta>/PFL7560.bin artifacts/ZYCustom_390.ini <saída.bin>`
   (1ª gravação: md5 `a6e5da14cb3f53b42a457eb92bd91814`), ou o mesmo comando com
   `--realocar --conteudo artifacts/bin-build/conteudo.txt` (2ª gravação: md5 `e6b41856e26add86d0fad8881c0bf145`
   com o kit de hoje; se um APK ou o `.rc` mudar, o md5 muda também). As duas terminam em `VALIDO`, depois do
   `verificar_bin`; `build_fix_bin.py --verificar <saída.bin> <stock.bin>` repete a conferência.
2. **Pendrive de resgate pronto e separado:** um pendrive só com o firmware de **fábrica do modelo com USB-C**
   (md5 `28a2f280eee313a4b115567926b2ba4f`) **na raiz**, como `usb_update.bin`: o loader só procura esse nome na
   raiz. O `./install.sh --pendrive <ponto> --com-firmware` põe na raiz o **nosso** `.bin` (a S4a) e guarda o
   oficial em `resgate-oficial/PFL7560.bin`: para o resgate, copie esse arquivo num PC para a raiz de outro
   pendrive, com o nome `usb_update.bin`. Confira o md5 de novo no pendrive. Nunca o `Firmware PFL7560.zip`.
3. **Pendrive do kit pronto** (`./install.sh --pendrive <ponto>`), para logo depois da gravação.
4. Confirme que o aparelho é o **modelo com USB-C** (V1.0.0.9). No sem USB-C, esta build não serve.
5. Anote o formato de cor atual (JEIDA hoje) e, se quiser, guarde um backup da `panelparam` pelo kit.

**Gravar:** pela "Atualização local do sistema" do menu, como em julho ([guia 16](../guide/16-recuperacao-brick.md)
§1), a partir de um terceiro pendrive (nem o de resgate, nem o do kit). Não desligue durante a gravação. O
checklist completo de pré-condições é o do [doc 18](../archive/18-sprint-bin-futuro.md) ("Pré-requisito absoluto —
kit de resgate").

**No 1º boot, o que olhar:**

- passa da logo do Android (o 1º boot depois de formatar o `/data` demora mais que o normal; em julho, travado,
  ficou mais de 10 minutos na logo);
- ventoinhas em 100 % desde o início: a térmica nova subiu (em julho isso apareceu até com o boot travado, então
  sozinho não prova o boot);
- a cor pode estar errada (JEIDA perdido): é esperado, o kit corrige;
- o `/data` foi formatado: reconfigure o Wi-Fi no launcher antes de tentar o adb (o adb por Wi-Fi só responde
  com o launcher);
- por adb, se der: `ls -lZ /vendor/etc/init/pfl7560-suite.rc` (`-rw-r--r-- root root` e
  `vendor_configs_file`; só na 2ª gravação), `md5sum /vendor/etc/ZYCustom.ini` (`252ab7a7…`) e
  `grep wifi_disconnect /vendor/build.prop` (`=0`);
- gravar qualquer `.bin` (o nosso ou o oficial) regrava 19 partições, inclusive a `logo` e o `/atv`: o
  carregador volta à marca Intelbras (só o `pfl7560-marca.sh` pelo PC repõe a MeowCast, porque depende do
  keystone de cada aparelho) e o `/atv/bootvideo` volta ao de fábrica (o kit repõe);
- depois, plugue o pendrive do kit e ligue: o `newlink_update.log` (em ASCII, como o script) deve trazer
  `termico ja estava ok`, `wi-fi ja estava ok`, `xiri ja estava desabilitado`,
  `suite: servico de boot ja estava instalado` (na 1ª gravação, `[OK] suite: servico de boot instalado`),
  `[OK] app` e `[OK] suite: arquivos atualizados`. A suíte roda e corrige a cor. Reinicie uma vez para o ícone valer.

**Se travar na logo (mais de 10 minutos) ou algo sair errado, como voltar:**

1. tire o cabo de energia;
2. plugue **só** o pendrive de resgate;
3. segure o botão de power e ligue o cabo, segurando por 10 a 15 s ([guia 16](../guide/16-recuperacao-brick.md)
   §3): o loader regrava o stock;
4. tire o pendrive quando terminar, ligue, e rode o pendrive do kit (térmico, Wi-Fi, xiri, suíte, app e cor
   voltam pelo caminho do `/vendor`, que nunca bricou);
5. traga o `newlink_update.log` e, se houver, uma foto da tela travada: a causa entra no doc antes de outra
   tentativa.

## 9. Decisões que ficam com o dono

- **Aumentar o slot do vendor (opção c)**: feito no bloco 21 (`--realocar`); falta o 1º teste no aparelho, o
  BIN-S4b, só depois de a S4a subir.
- Gravar em duas etapas (§11) ou ir direto à build com o `.rc`: a recomendação é a de duas etapas.

## 10. A forma do sparse e os dois modos do gerador (bloco 21)

**Medido.** O sparse do vendor no stock V1.0.0.9 tem 10 chunks (5 RAW, 5 DONTCARE) e ocupa o slot exato (sobra
0 B); o V1.0.0.1 também. As builds `eae3a83d` e `397698b9` usavam chunks FILL (`0xCAC2`, 8 deles, nos dados de
libs como `/lib/libhi_msp.so` e `/lib/mediadrm/libwvdrmengine.so`) e deixavam 53024 e 44832 B de zeros soltos
depois do último chunk. O loader tem código para FILL, mas a única build já gravada (julho) tinha a forma do
stock, e o CRC que ele confere é o do container, não o do que foi escrito na eMMC: um erro no caminho FILL
estragaria essas libs sem aviso, e zeros lidos como cabeçalho de chunk parariam a gravação no record 14.

**O que o gerador faz agora** (`artifacts/bin-build/build_fix_bin.py`, README do builder):

- `sparse.pack` só emite RAW e DONTCARE, e nunca há zeros soltos: o sparse ocupa exatamente o `img_length`.
- **Padrão, nos mesmos blocos (gate BIN-S4a):** os 3 fixes vão nos blocos de dados que os arquivos já ocupam
  (ZYCustom 3 blocos, `build.prop` 2, `init.bigfish.rc` 4), direto nos chunks RAW do sparse original, e só o
  `i_size` do inode muda. Layout de chunks, slot, cabeçalho e `checksum1` iguais aos do stock; modo, dono e rótulo
  de todos os inodes intactos por construção. Recusa se um arquivo pedir outro número de blocos.
- **`--realocar` (BIN-S4b):** grava pelo `debugfs` com os metadados carimbados, re-empacota e muda o tamanho do
  record 14 no container: `img_length` dele, `offset` dos records 15 a 18 (+ delta), `file_len` e `checksum1`;
  os records 15 a 18 vão byte a byte. É o único modo que aceita `--conteudo`.
- **`verificar_bin`**, antes de a saída ganhar o nome final (ela é escrita em `<saída>.tmp`): `header_len`,
  `file_len` e `checksum1`; cabeçalho igual ao do stock fora dos campos do tamanho; blob e os 19 records
  contíguos, os outros byte a byte iguais aos do stock, CRC do 14; forma do sparse (só RAW e DONTCARE,
  `total_sz` coerente, soma = `total_blks`, consumido = `img_length`); e a árvore inteira do vendor contra a do
  stock (`e2fsck -fn` limpo, só os 3 fixes e o manifesto mudam, metadados de todos os inodes iguais). Também
  pela linha de comando: `build_fix_bin.py --verificar <bin> <stock> [--conteudo <manifesto>]`.

**Builds de 2026-10-31** (locais em `firmware/`, md5 em `firmware/*.md5`):

| Build | md5 | CRC do vendor | O que leva |
|---|---|---|---|
| `PFL7560-S4a-NAO-GRADUADO.bin` | `a6e5da14cb3f53b42a457eb92bd91814` | `0x883b40d6` | escada, Wi-Fi e xiri, nos mesmos blocos; 1393758396 B, como o stock |
| `PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin` | `e6b41856e26add86d0fad8881c0bf145` | `0xdb34914f` | o mesmo, mais o `.rc` da suíte, app, home e as 20 sobreposições (`conteudo.txt`); record 14 com +3407872 B |
| V1.0.0.1 (sem USB-C), nos mesmos blocos, só em software | `e3e3e87ce08a625c83c3824eafd26d9b` | `0xe5b1294a` | a mesma conta com o `ZYCustom_390.NOTYPEC.ini` |

**O que o `.bin` não leva de jeito nenhum:** o JEIDA (cada painel), a partição `logo` (cada keystone) e o estado
em `/data` (apps desligados, sobreposições ligadas, home pela prop, descanso de tela), que a suíte refaz no 1º
boot com o pendrive do kit. Office, iOSCast e Espelhamento ficam no `/system` (outro slot): tirá-los não libera
espaço no vendor, e o `--realocar` dispensa esse espaço; eles seguem só desligados.

**PROVISÓRIO até o aparelho:** que o loader grava a S4a como gravou a de julho (forma do stock) e o Android sobe
com os 3 fixes; e, só depois disso, que o loader aceita o container realocado da S4b (`file_len`, offsets e
`checksum1` novos) e que o kit, logo depois, acha app, home e sobreposições "já estava ... (igual ao do kit)".

## 11. Definição de pronto e ordem das gravações (vinda do doc 31)

O plano de julho ([doc 31](../archive/31-plano-mestre-bin-final.md), arquivado) fixou o que continua valendo:

**O `.bin` está pronto quando**, gravado pela "Atualização local do sistema" num PFL7560 com USB-C:

1. sobe até o launcher (não trava na logo, o defeito da build de julho sem metadados);
2. traz os fixes térmicos ativos por padrão: 2º sensor lido (`HW_VIRTUAL_CHANNEL = 1`), ventiladores a 100 %,
   escada de brilho, `WARNING` 70 °C e `EMERGENCY` 75 °C, Wi-Fi que reconecta e `xiriservice` desligado;
3. foi gerado de forma reprodutível (duas builds, o mesmo md5) e passou no `verificar_bin`;
4. foi testado no aparelho com o pendrive de resgate ao lado.

O serviço de boot da suíte (`.rc`), o app, a home e as sobreposições vêm na S4b; a suíte e o estado em `/data`
chegam pelo pendrive do kit depois da gravação (§1 e §10).

**O `.bin` não corrige a cor de painel trocado.** O `0x5c` = JEIDA não entra no `.bin` (quebraria a cor de todo
aparelho com o painel de fábrica, que é VESA). A `panelparam` provavelmente vem no container e volta ao de fábrica
na gravação (doc 41 §3, inferido): quem tem painel JEIDA refaz a cor pelo kit.

**Ordem das gravações:**

| # | Gate | Build | Por quê |
|---|---|---|---|
| 1 | BIN-S4a | `PFL7560-S4a-NAO-GRADUADO.bin` (`a6e5da14…`) | **delta mínimo** (só os 3 fixes, nos mesmos blocos do stock): se travar, não há variável confusa |
| 2 | BIN-S4b | `PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin` (`e6b41856…`) | só depois de a 1ª subir limpa: acrescenta arquivo novo em `/vendor` e o container realocado |

Se a 1ª travar, o resgate é o da §8 e a causa entra neste doc antes de outra tentativa (o antigo BIN-S5).
