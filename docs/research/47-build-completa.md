# 47 — Build completa: o que a nova build leva por padrão, e o que não cabe nela (2026-10-31)

**Estado (2026-11-02): a S5 `3f3023b0…` foi GRAVADA no aparelho e subiu funcionando (§13).** As S4a e S4b seguem
só provadas no PC. Gravar um `.bin` é o gate BIN-S4a: só com a palavra do dono naquele momento, com o pendrive de
resgate na mão, e **nunca** no modelo sem USB-C com esta base. Spec: [bloco 12](../sprints/2026-10-31-bloco-12-build-completa.md).

> **Bloco 21 (2026-10-31): leia a §10 primeiro.** A folga de 65312 bytes das seções 2 e 6 vinha toda de chunks
> FILL que o re-pack criava, forma que o loader nunca gravou; as builds `eae3a83d` e `397698b9` saíram de uso. O
> gate BIN-S4a passa a gravar `PFL7560-S4a-NAO-GRADUADO.bin` (os 3 fixes nos mesmos blocos do stock, md5
> `a6e5da14…`), e a build completa vira o BIN-S4b, realocada, com o `.rc`, o app, a home e as 20 sobreposições
> (`PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin`, md5 `2b1836b8…` com o app versionCode 8 e a home 9, refeita em
> 2026-11-02; no fim do bloco 21 era `31702b64…`).

> **Blocos 26 a 28 (2026-11-02): a §12 é a build S5**, com a suíte inteira no `/vendor`, uma semente que a copia
> para o `/data` vazio no 1º boot e o logo na partição `logo` (`PFL7560-S5-COMPLETO-NAO-GRADUADO.bin`). **Muda a
> ordem da §11 por decisão do dono:** a S5 é gravada direto, sem gravar antes a S4a e a S4b (§12, "Decisão de
> 2026-11-02").

Pedido do dono: "nossa nova build vai conferir isso tudo né? por default? [...] ter essas correções e o sistema
operacional todo prontinho."

---

## 1. Resposta curta

- **Por padrão (S4a, §10), a build leva:** a correção térmica com a escada de brilho (`ZYCustom.ini`), o Wi-Fi
  que reconecta sozinho (`build.prop`) e o `xiriservice` desligado (`init.bigfish.rc`), nos mesmos blocos do
  stock. **Com `--realocar --conteudo` (S4b)** leva também o **serviço de boot da suíte**
  (`/vendor/etc/init/pfl7560-suite.rc`), o app, a home e as 20 sobreposições, todos com modo, dono e rótulo
  SELinux carimbados e conferidos.
- **Não leva a suíte**, que mora no `/data`. No bloco 12, sem o `--realocar`, nem o app cabia: a folga medida de
  65312 bytes (seção 2) vinha toda dos chunks FILL do re-pack, e sem eles o slot do stock não tem folga (§10).
- **Mesmo que coubessem, o pendrive do kit seria obrigatório depois da gravação.** Gravar o `.bin` formata o
  `/data` (visto em julho, [guia 16](../guide/16-recuperacao-brick.md) §1; o `misc` do container pede
  `--wipe_data`, [doc 42](42-firmware-2026-10-modelo-sem-usbc.md)), e a suíte mora em `/data/vendor`. Além disso,
  a `panelparam` provavelmente vem no container ([doc 41](41-auto-pareamento-camera-e-kit-universal.md) §3) e a
  gravação devolve o formato de cor ao de fábrica: um painel JEIDA precisa do kit para voltar a ter cor certa. O
  JEIDA não entra no `.bin`, porque depende do painel de cada aparelho.
- **Recomendação (bloco 12, trocada pela ordem da §11):** opção (a) da spec, do tamanho que cabe: `.bin` com os 3 fixes e o `.rc`; app e suíte pelo
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
a `PFL7560-S4b-COMPLETO` (`31702b64`, realocada, com `.rc`, app, home e sobreposições); a `397698b9` saiu de uso.
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
   `--realocar --conteudo artifacts/bin-build/conteudo.txt` (2ª gravação: md5 `2b1836b8a86ac1d998e0a06a3000478f`
   com o kit de 2026-11-02; se um APK ou o `.rc` mudar, o md5 muda também). As duas terminam em `VALIDO`, depois do
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
pendrive do kit feito com `--com-firmware` já leva a S4a na raiz como `usb_update.bin`: ligar **segurando o
POWER** com ele plugado também grava a S4a, pelo mesmo motor ([guia 16](../guide/16-recuperacao-brick.md) §3).
Ligar sem segurar o POWER não grava: dos blocos 9 a 20 o kit rodou de um pendrive com o oficial na raiz como
`usb_update.bin`. O
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
| `PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin` | `2b1836b8a86ac1d998e0a06a3000478f` | `0x251ba2e0` | o mesmo, mais o `.rc` da suíte, app, home e as 20 sobreposições (`conteudo.txt`); record 14 com +3432448 B. Refeita em 2026-11-02 (app 8, home 9); a de 2026-10-31 era `31702b64…`, `0xd8e4e78b`, +3407872 B |
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
| 2 | BIN-S4b | `PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin` (`2b1836b8…`) | só depois de a 1ª subir limpa: acrescenta arquivo novo em `/vendor` e o container realocado |

Se a 1ª travar, o resgate é o da §8 e a causa entra neste doc antes de outra tentativa (o antigo BIN-S5).

**2026-11-02: o dono trocou esta ordem.** A próxima gravação é a S5 da §12, direto, sem a S4a e a S4b antes
(decisão e risco na §12).

## 12. Build S5: a suíte nativa no `/vendor` (bloco 26)

Pedido do dono: "então vamos criar o novo firmware, certo? o que vai conter tudo de forma nativa?"

**O que a S5 leva** (`artifacts/bin-build/conteudo-s5.txt`, sobre o V1.0.0.9 `28a2f280…`):

- tudo da S4b: os 3 fixes, app, home e as 20 sobreposições (as mesmas linhas do `conteudo.txt`);
- **a suíte inteira** em `/vendor/etc/pfl7560-suite`: os 28 arquivos que o kit põe em `/data/vendor/pfl7560-suite`
  (scripts, `lvdsctl`, `nl_camcheck`, `nl_tela`, `nl_logo`, telas, fontes, arte do logo, lista do debloat) e a
  semente `suite-semente.sh`. Pastas `0755 0:2000`, arquivos `0644 0:0`, rótulo `vendor_configs_file`: os
  metadados que o `/vendor/etc` do stock já usa;
- o `.rc` da S5 (`artifacts/bin-build/s5/pfl7560-suite.rc`) no lugar do `.rc` do kit: o mesmo serviço
  (`pfl7560_suite`, `sys.boot_completed=1`, `vendor_shell`, root), só que roda a semente do `/vendor`;
- as 2 linhas do `build.prop` que o kit grava (home e gerenciador), pela diretiva nova `prop chave=valor` do
  manifesto. Sem elas, o kit abriria o `/vendor` logo depois da gravação;
- **(bloco 28)** a arte reta com o "Cast" verde (`pendrive-autorun/marca/logo.jpg`, o `ARTE_MD5` do kit) na
  partição `logo` do carregador, pela diretiva `logo <arte.jpg>`: o record 6 (abaixo).

**A semente** (`suite-semente.sh`, roda em todo boot e depois passa a vez ao `suite-boot.sh` do `/data`):

| Estado do `/data` | O que faz | `vendor.pfl7560.semente` |
|---|---|---|
| sem `suite-boot.sh` válido (1º boot depois da gravação, que formata o `/data`; ou cópia interrompida) | confere o `/vendor` contra a lista embutida, copia por uma pasta de preparo, confere de novo e move; o `suite-boot.sh` vai por último | `copiada` |
| a suíte veio inteira da semente (`semente.lista` confere arquivo a arquivo) e o `/vendor` traz a mesma lista | nada | `em_dia` |
| a suíte veio inteira da semente e o `/vendor` traz outra lista (firmware novo gravado sem formatar) | copia de novo | `copiada` |
| a suíte foi instalada ou atualizada pelo kit do pendrive | **nada: o `/data` vence** | `data_vence` |
| `/vendor` adulterado, pasta do `/data` com link ou aberta a outros | nada copiado, nada roda | `erro_copia` / `erro_pasta` |

Os arquivos ficam com os mesmos donos e modos que o kit usa (pastas `0700` root, executáveis `0755`, o resto
`0600`). O registro fica em `/data/vendor/pfl7560-suite/semente.log`. A `SEMENTE_LISTA` é gerada pelo
`tests/atualizar-md5-kit.sh` a partir da `KIT_LISTA`, então a suíte do `/vendor` é sempre a do kit do mesmo
commit.

**O kit do pendrive continua funcionando como hoje.** O `newlink_update.sh` aceita o `.rc` da S5 no lugar do dele
(`rc_s5`: md5 `RC_S5_MD5` e a semente presente no `/vendor`) e registra "servico de boot ja estava instalado (o da
build S5…)", sem abrir o `/vendor`. Sem a semente, ou com o `.rc` mexido, ele põe o dele. Um kit antigo, sem o
`rc_s5`, só troca o `.rc` da S5 pelo dele, o que é inofensivo: a suíte do `/data` continua rodando, só que sem a
semente. O `DESINSTALAR-SUITE.txt` tira o `.rc` da S5 também, e com ele a semente para.

**O que ainda precisa do pendrive do kit depois da S5:**

- a marca do `/atv/bootvideo` (`logo.jpg` e `bootanimation.zip`), que mora em outra partição (o logo do
  carregador, na partição `logo`, já vem da S5 desde o bloco 28);
- a cor do painel trocado (JEIDA): a suíte tem o `cor.sh`, mas a verificação no boot só roda por queda de energia,
  relógio zerado, desligamento não limpo ou pedido da home. Se o 1º boot depois da gravação dispara a
  verificação sozinho, só o aparelho mostra. Pela home ("verificar"), a cor volta sem pendrive.

O resto, que antes vinha do kit no 1º boot, agora sai do `suite-boot.sh` copiado pela semente: sobreposições
ligadas, debloat, descanso de tela, curvas, chaves, diário, "Desligar no descanso" (padrão ligado, 10 min), o VLC
fora do usuário 0 (uma vez, se o pacote existir na imagem) e o logo automático do carregador (a partição `logo`,
abaixo).

**Build e provas (no PC, 2026-11-02):**

| Build | md5 | Tamanho | CRC do vendor | Record 14 | Record 6 |
|---|---|---|---|---|---|
| **S5 final, gravada em 2026-11-02** (blocos 26 a 29: app 9, home 9, visor dos testes, `wifi_pwr` fora das escolhas; §13) | **`3f3023b06e500e354fa6d4ca4e236f5f`** | 1399009468 B | `0x7ccdb8eb` | 85844116 B (+5251072 B contra o stock) | 106496 B (= stock), arte `78b23ece…` (o `ARTE_MD5` não mudou) |
| a do bloco 28 (superada pelo conferente final; o `.md5` ainda a traz até a montagem final) | `253b01c95b2dd121408fc3c0817bf219` | 1398894780 B | `0xe0263cf7` | 85729428 B (+5136384 B contra o stock) | 106496 B (= stock), CRC `0x9c066411` |
| a do bloco 26 (superada) | `81bb9885581356d5e46a5f612a29ae8a` | 1398890684 B | `0xa9f3457a` | 85725332 B (+5132288 B) | = stock |

A S5 do bloco 28 sai com o kit do Cast verde (o vendor cresce 4096 B com a arte nova) e com o record 6. Depois
dela, o conferente final mudou APKs e scripts da suíte (app versionCode 8, home 9, `suite-boot.sh`,
`suite-curvas.sh`, `suite-pedido.sh`), então o vendor da S5 muda e o md5 de `253b01c9` não vale mais para o kit de
hoje. As provas abaixo são do bloco 26 e foram repetidas no bloco 28, com os números da linha do bloco 28; na S5
final elas se repetem na montagem (roteiro, passo 2): duas gerações com o mesmo
md5, `--verificar` com o `conteudo-s5.txt` APROVADO (e REPROVADO com o `conteudo.txt`: "record 6: difere do
stock"), `e2fsck -fn` limpo (53477 blocos livres de 76800), `test-semente-s5.sh` com o vendor real 66/0.

- duas gerações, o mesmo md5; `verificar_bin` com o `conteudo-s5.txt` APROVADO (78 entradas e 2 linhas no
  `build.prop`); sem o manifesto, ele REPROVA (arquivos novos fora do manifesto), como deve;
- `e2fsck -fn` do vendor extraído limpo; 53478 blocos livres de 76800 (o stock tem 54726);
- conferência independente (S2): uma 3ª geração deu o mesmo md5; os 18 records fora do 14, o cabeçalho (fora do
  `checksum1`, do tamanho total e da tabela) e a cauda iguais ao stock byte a byte; dos 714 inodes do stock nenhum
  sumiu nem mudou de modo, dono ou xattr, e só os 3 fixes mudaram de conteúdo; os 78 novos são exatamente os do
  manifesto, sem escrita para grupo ou outros e com o rótulo do vizinho no stock (as pastas de app e de tema saem
  `0:0`, como o kit as cria no aparelho, e as do stock são `0:2000`: o modo `0755` é o mesmo);
- `tests/test-semente-s5.sh`: 66 verificações, 0 falhas (o `EXEC_LISTA` da semente conferido contra o `KIT_EXEC`), com o vendor montado do manifesto e com
  `PFL_S5_BIN=<.bin>` (o vendor tirado do record 14 do `.bin` de verdade): 1º boot com o `/data` vazio, kit mais
  novo já no `/data`, `/vendor` mais novo, cópia interrompida, `/vendor` adulterado e pastas inseguras;
- `test-kit-pendrive.sh` (`c_bloco26`): o `.rc` da S5 com a semente vale como "já instalado" e não abre o `/vendor`;
  sem a semente, ou mexido, o kit põe o dele; o desinstalar o tira;
- `test-builder-bin.py`: a diretiva `prop` (deriva o `build.prop` como o kit, recusa a do Wi-Fi e chave repetida,
  o `--verificar` acusa prop que falta) e, com `PFL_STOCK_ANTIGO`, o md5 da S5 contra o `firmware/*.md5`.

**PROVISÓRIO até o aparelho** (somado aos da §7 e §10):

1. que o init roda um script de `/vendor/etc` pelo `/vendor/bin/sh` no domínio `vendor_shell` e que a cópia para
   `/data/vendor` passa (o aparelho está em SELinux Permissive, então hoje nada nega);
2. que o `/data/vendor` existe no `sys.boot_completed` do 1º boot depois da gravação (o init do Android o cria cedo);
3. quanto o 1º boot demora a mais para copiar 1477484 B (1,4 MB; no PC é instantâneo);
4. que um kit antigo, plugado depois da S5, se comporta como o teste mostra (só troca o `.rc`).

**A partição `logo` no container: o record 6 (bloco 28, implementado).** O **record 6** (`flash_begin`
0x3e00000, 40 MiB na eMMC) é a `/dev/block/by-name/logo`: o `blkdevparts` do próprio stock (records 0 e 1) põe a
`logo` em 8+1+1+2+40+8+2 = 62 MiB = 0x3e00000, com 40M. O payload do stock tem 106496 B: a `LOGO_TABLE` (os 0x78 B
de `###\0`/`LOGO_KEY_FLAG`), o `LOGO_KEY_LEN` (u32 LE no 0x78, 95226), zeros até 8192, o JPEG de fábrica
(1920x1080, baseline, 4:2:0) no 8192 e 3078 B de zeros no fim. Os backups da partição tirados do aparelho
(`backups-projetor/logo/`) têm os mesmos 0x78 B e, depois do JPEG, restos de gravações antigas: o carregador lê só
`LOGO_KEY_LEN` bytes a partir do 8192 (o aparelho mostrou o logo de 44491 B com lixo atrás).

O que o gerador faz (`build_fix_bin.py`, diretiva `logo <arte.jpg>` do manifesto): confere o payload do stock
(tabela, zeros, `LOGO_KEY_LEN` e o JPEG dele), confere a arte (JPEG baseline 1920x1080, 3 componentes, cabe no
record), troca só o `LOGO_KEY_LEN` e o JPEG (zeros até o fim), recalcula o CRC do prefixo do record 6 e não mexe
em mais nada: o tamanho do record, a tabela, o cabeçalho e o `checksum1` ficam os do stock. O `verificar_bin`
aceita **só os records 6 e 14** diferentes do stock, e o 6 só se for exatamente o payload que o gerador monta com
a arte do manifesto e o CRC certo (sem a diretiva, ele tem de ser igual ao stock).

Provas no PC: o record 6 tirado da S5 tem a entrada da tabela do stock, 106496 B, CRC `0x9c066411` conferido bit a
bit, a `LOGO_TABLE` do stock, `LOGO_KEY_LEN` 91378 e a arte (md5 `78b23ece…` = `ARTE_MD5`) seguida de zeros. A
partição depois da gravação foi simulada pondo o record sobre o backup de 40 MiB do aparelho: o `nl_logo` do PC
(o mesmo `.c` do ARM) lê o cabeçalho (91378) e extrai a arte com o md5 do `ARTE_MD5`, então o logo automático da
suíte a reconhece como a reta. `test-builder-bin.py` (`caso_logo`, `caso_recusa_logo`) cobre o layout, o gate, as
mutações (CRC, byte do JPEG, cauda, `LOGO_KEY_LEN`, outro record) e as recusas (stock sem tabela, arte que não
cabe, progressiva, de outro tamanho, que não é JPEG, diretiva repetida ou sem arte).

**PROVISÓRIO até o aparelho:** a arte do `gerar-marca.py` é JPEG **4:4:4** (o do stock é 4:2:0). O aparelho já
deu 4 boots, em 2026-11-02, com uma arte 4:4:4 do Pillow gravada na partição pelo logo automático, mas que o
carregador a desenha certa só o olho do dono confirma. No 1º boot, o logo automático da suíte (ligado por padrão)
continua trocando a arte reta pela distorcida no keystone do aparelho, como antes.

**Pré-voo (bloco 28):** `firmware/preflight-flash.sh <pendrive> --backup <pasta> --resgate <PFL7560.bin>` só lê
e recusa (sai 1) se qualquer item falhar: o `usb_update.bin` da raiz não é a S5 do
`firmware/PFL7560-S5-COMPLETO-NAO-GRADUADO.bin.md5`; o `--verificar` dele contra o stock, com o `conteudo-s5.txt`,
não sai APROVADO; o kit do pendrive não está inteiro (a `KIT_LISTA` do `newlink_update.sh` dele), não traz o
`RC_S5_MD5` do `.rc` desta S5 ou há um `DESINSTALAR-SUITE.txt`; o backup do aparelho (arquivos de
`/data/vendor/pfl7560-*` e a pasta `/data/data/com.pfl7560.home/shared_prefs`, soltos ou no `pfl-backup.tar`) não
está no PC; ou o stock de resgate não tem o md5 `28a2f280…` ou está no pendrive do flash. Teste:
`tests/test-preflight-flash.sh` (135 verificações sob `dash`, com o cenário inteiro "`install.sh
--com-firmware`, depois o pré-voo"). Ensaio do bloco 28: uma cópia do pendrive com o kit do
`install.sh --pendrive`, a S5 real como `usb_update.bin`, o backup `antes-s5-20261102-0201` e o stock: APROVADO
em 8 s. Desde o conferente final, o `install.sh --pendrive <ponto> --com-firmware` (e o `.ps1` do Windows) põe a
**S5** no pendrive, conferida pelo md5 do `firmware/PFL7560-S5-COMPLETO-NAO-GRADUADO.bin.md5`, com a mesma regra
do pré-voo: o pendrive que ele monta passa no pré-voo.

**Decisão de 2026-11-02: a S5 direto.** O §11 e a versão anterior deste roteiro mandavam gravar a S5 só depois de
a S4a e a S4b subirem limpas. Em 2026-11-02 o dono escolheu, pelo AskUserQuestion, a opção "S5 com o bloco 27"
(remontar a S5 com a home nova e o logo verde e gravar num flash só) em vez de "Provar a S4a antes", e deu o sim
para gravar depois do conferente final, do pré-voo verde e do backup. **O risco que fica:** nenhuma build
modificada nossa foi gravada no aparelho até hoje (a de julho, sem metadados, travou na logo); a S5 junta de uma vez
tudo o que a S4a, a S4b e a S5 provariam em separado (os 3 fixes, o container realocado, o record 6, o `.rc` e a
semente), então um travamento não aponta a causa. O resgate é o stock V1.0.0.9 (`28a2f280…`) como `usb_update.bin`
na raiz de **outro** pendrive, ligando segurando o POWER (§8, [guia 16](../guide/16-recuperacao-brick.md)).

**Roteiro de gravação da S5 (com o sim do dono):**

1. Confirme que o aparelho é o **modelo com USB-C** (V1.0.0.9). Nada de S4a nem S4b antes (decisão acima).
2. No PC, monte a S5 final. Builds grandes vão numa pasta ignorada da árvore (`build-s5/`), não no `/tmp` (tmpfs
   pequeno; o stock aberto tem 1,3 GB e cada build 1,4 GB). Confira o sha256 do zip (`08d37bbb…`), extraia o stock
   (`unzip -j "firmware/Software PFL7560.zip" "*/PFL7560.bin" -d build-s5/`, md5 `28a2f280…`) e gere
   (`python3 artifacts/bin-build/build_fix_bin.py build-s5/PFL7560.bin artifacts/ZYCustom_390.ini
   firmware/PFL7560-S5-COMPLETO-NAO-GRADUADO.bin --realocar --conteudo artifacts/bin-build/conteudo-s5.txt`).
   Gere uma 2ª vez em outro caminho: o md5 tem de ser o mesmo. Depois `build_fix_bin.py --verificar <S5> <stock>
   --conteudo artifacts/bin-build/conteudo-s5.txt` (APROVADO) e `PFL_S5_BIN=<S5> bash tests/test-semente-s5.sh`
   (0 falhas). Grave o md5 novo em `firmware/PFL7560-S5-COMPLETO-NAO-GRADUADO.bin.md5`, no formato
   `<md5>  PFL7560-S5-COMPLETO-NAO-GRADUADO.bin` (dois espaços), e no mesmo commit os números da tabela acima e da
   linha da S5 no `firmware/README.md`. O `.bin` não entra no git.
3. Backup do aparelho no PC (`/data/vendor/pfl7560-*` e o `shared_prefs` da home). Pendrive de resgate pronto e
   separado (oficial V1.0.0.9, `28a2f280…`, na raiz como `usb_update.bin`). Monte o pendrive do flash com
   `./install.sh --pendrive <ponto> --com-firmware` (a S5 como `usb_update.bin` e o kit) e rode o pré-voo
   (`sh firmware/preflight-flash.sh <pendrive> --backup <pasta> --resgate <PFL7560.bin>`): só grave com
   `PRE-VOO APROVADO`.
4. Grave pela "Atualização local do sistema" (§8). Não desligue durante a gravação.
5. No 1º boot: espere o launcher (demora mais, porque o `/data` foi formatado) e reconfigure o Wi-Fi. Por adb, se
   der: `getprop vendor.pfl7560.semente` deve ser `copiada`, e o
   `/data/vendor/pfl7560-suite/semente.log` deve trazer `[OK] suite copiada do /vendor e conferida: 28 arquivos`.
   Num boot seguinte, deve dar `em_dia`.
6. Só então, se quiser a marca do `/atv` ou a cor do painel trocado sem esperar a verificação, plugue o pendrive do
   kit. O log deve trazer `servico de boot ja estava instalado (o da build S5…)`, e os apps e as sobreposições
   como "ja estava".
7. Se travar na logo, o resgate é o da §8.

O que aconteceu de verdade na primeira vez que este roteiro foi seguido, com os desvios e o que se mediu depois,
está na §13.

---

## 13. Gravação real da S5 (2026-11-02)

**Veredito: a S5 `3f3023b06e500e354fa6d4ca4e236f5f` foi gravada no aparelho com USB-C e subiu inteira**, sem
travar na logo (o que a de julho fez), sem panic e com a suíte rodando. É a primeira build nossa a ser gravada;
resolve de uma vez o que a §12 deixava como risco (container realocado, record 6, `.rc` e semente juntos). O que
segue é o roteiro como foi provado, na ordem em que o dono o viu, para repetir na próxima gravação (a S6, que
leva o bloco 30).

### 13.1 Antes, no PC

- **Montagem.** A S5 foi gerada **duas vezes** em `build-s5/` da árvore `integracao`, com `TMPDIR` apontado para
  dentro dela (`build-s5/tmp`): o `/tmp` é um tmpfs de 4 GB e não comporta o stock aberto (1,3 GB) mais uma build
  (1,4 GB). As duas deram o mesmo md5, `3f3023b06e500e354fa6d4ca4e236f5f`, 1399009468 B, record 14 com
  +5251072 B contra o stock e CRC do vendor `0x7ccdb8eb`. `build_fix_bin.py --verificar` com o `conteudo-s5.txt`
  APROVADO; `test-semente-s5.sh` com o vendor real, 66 verificações, 0 falhas.
- **Regressão inteira verde, com uma exceção que não é defeito.** O `test-preparar-pendrive.sh` **precisa do
  `/tmp` de verdade**: o snapshot que o teste faz só é feito sob `/tmp`. Com o `TMPDIR` fora dele, o teste falha
  de mentira. Rode a regressão com o `TMPDIR` padrão, e só a montagem da build com o `TMPDIR` em `build-s5/tmp`.
- **O pendrive** (FAT32, rótulo `PFL7560`) saiu de `./install.sh --pendrive <ponto> --com-firmware`: a S5 na raiz
  como `usb_update.bin`, o stock `28a2f280…` em `resgate-oficial/`, o kit com 55 arquivos.
- **Pré-voo:** `sh firmware/preflight-flash.sh <ponto> --backup <pasta> --resgate <stock .bin fora do pendrive>`:
  os 5 itens OK, `PRE-VOO APROVADO`.
- **Backup no PC, logo antes** (`backups-projetor/antes-s5-20261102-1100`, um tar com 76 entradas, md5 igual no
  aparelho e no PC). **Armadilha:** o `adb` sobe como uid 2000 e só vira root cerca de 2 minutos depois do boot.
  Um backup feito antes disso sai **incompleto** (`permission denied` nos arquivos de `/data/vendor`). Confira
  `adb shell id -u` = `0` antes de tirar o backup, e o md5 do tar nos dois lados depois.
- **Contexto do dia:** o kit tinha a escolha `wifi_pwr=1` (autosuspend do chip AIC8800), que causava kernel panic
  (NULL em `aicwf_usb_bus_start`) e fazia a suíte rodar a cada boot depois de um panic. O bloco 29 a tirou das
  escolhas (doc 49); a S5 gravada já é a que não a tem.

### 13.2 Gravar

Projetor desligado normal, pendrive plugado, **ligar segurando o POWER**. A ordem dos eventos que o dono viu:

1. **Tela azul do gravador da placa:** "Do not power off the device during the upgrade", "UPGRADING", "download
   progress" e "burn progress". É o loader: não muda de build para build.
2. **Animação de boot da Intelbras, de cabeça para baixo e com a cor esverdeada.** É esperado no 1º boot: a
   gravação repõe o `/atv/bootvideo` de fábrica e apaga o formato de cor e o espelhamento (o guia 16, passo 7, já
   avisava). O kit repõe a marca MeowCast depois.
3. **Tela do kit "Pendrive do kit encontrado. Conferindo o projetor."** com as 4 etapas: cor do painel,
   ângulo/foco/nitidez, temperatura e teste da proteção térmica. O pendrive ficou plugado, então **o kit rodou
   já no 1º boot**.
4. **Assistente "Pareamento do Controle Remoto" da Intelbras** (`com.newlink.nlprovision`), que só aparece na
   primeira configuração depois do reset. Depois disso a cor voltou ao normal sozinha, e o dono reconfigurou o
   Wi-Fi (o `/data` foi formatado).

### 13.3 O que se leu depois, por adb

| O que | Valor | Lê-se como |
|---|---|---|
| `sys.boot.reason` | `reboot,factory_reset` | a gravação formatou o `/data`, como previsto |
| pstore | sem panic | o `wifi_pwr` fora das escolhas resolveu |
| home e app | versionCode 9 | os APKs da S5 |
| `/vendor/etc/ZYCustom.ini` | md5 `252ab7a7…` | a escada de brilho está no `/vendor` |
| `vendor.newlink.wifi_disconnect_on_boot` | `0` | o fix do Wi-Fi do `build.prop` |
| `/vendor/etc/init/pfl7560-suite.rc` | `root root`, rótulo `vendor_configs_file` | o `.rc` da S5 com os metadados que o init exige (a lição do guia 16) |
| chip Wi-Fi `power/control` | `on` | sem autosuspend |
| VLC | ausente | como o `suite-boot.sh` deixa |
| `vendor.pfl7560.semente` | `data_vence` | ver abaixo |
| `/atv/bootvideo` | o `bootanimation` e o logo do kit | o kit repôs a marca |

**A semente do `/vendor` ainda não está provada no aparelho.** Com o pendrive plugado, o kit instalou a suíte no
`/data` primeiro, e a semente fez o que a tabela da §12 manda nesse caso: `data_vence`, sem copiar nada. A cópia
`copiada` (1º boot de `/data` vazio, sem pendrive) e depois `em_dia` só se provam num boot **sem pendrive**.

**A suíte no modo pendrive** terminou com o resumo de 19 itens, 0 correções e 0 atenções: o visor no app com o
fundo MeowCast; a cor VESA para JEIDA corrigida (a escada de cor em ordem; a partição só mudou o byte `0x5c`); a
câmera ok; temperatura do LED 63,4 °C e da placa 31,9 °C; a rampa térmica reagiu (alerta em 39, desceu a 20, voltou
a 17 e a limpeza fechou). Os dois avisos "o alerta do sistema nao fechou depois de 4 teclas" são o assistente de
pareamento do `nlprovision` na frente da tela: esperados no 1º boot depois do reset, não defeito.

### 13.4 O que isto prova, e o que não

Provado no aparelho: o container realocado da S5 é aceito pelo loader e grava (inclusive o record 14 com +5 MB);
os metadados do `/vendor` (modo, dono e rótulo) deixam o init subir e o `.rc` da S5 ser lido; a escada de brilho e o
fix do Wi-Fi estão no aparelho; o record 6 não atrapalhou o boot; o kit do pendrive roda por cima da S5 no 1º boot.

**Continua provisório:** a cópia da semente para um `/data` vazio sem pendrive (`copiada`, depois `em_dia`); que o
carregador desenha certa a arte 4:4:4 do record 6 (só o olho do dono confirma, §12); e o tempo do 1º boot sem o
kit.

### 13.5 Para a próxima gravação (a S6, com o bloco 30)

1. Siga o roteiro da §12 como está; a §13.1 só acrescenta o `TMPDIR` em `build-s5/tmp` **só na montagem**, a
   regressão no `/tmp` normal e o `id -u` = 0 antes do backup.
2. **Decida antes se o pendrive fica plugado no 1º boot.** Plugado é o prático: o kit corrige a cor e repõe a marca
   na hora, e o assistente de pareamento da Intelbras aparece de qualquer jeito. Sem pendrive prova a semente do
   `/vendor` (`copiada`, depois `em_dia`), mas a cor fica errada e a marca é a de fábrica até a verificação ou o
   pedido pela home. Se a S6 for a que deve provar a semente, **tire o pendrive** quando o gravador terminar
   (o passo 6 do guia 16 vale: com ele plugado, um novo power-hold regrava).
3. Resgate, se travar: o mesmo da §8, com o stock `28a2f280…` como `usb_update.bin` na raiz de **outro** pendrive.
   Desta vez ele não foi preciso.
