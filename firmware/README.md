# firmware/ — firmwares de fábrica e as nossas builds

Os `.zip` de fábrica ficam no git por **Git LFS**; os `.bin` são locais (`*.bin` no `.gitignore`), e só o md5
deles é versionado (`*.bin.md5`). O estado da build, o que ela leva e o roteiro de gravação estão no
[doc 47](../docs/research/47-build-completa.md); o formato do container, no [doc 15](../docs/research/15-bin-definitivo.md).

## Firmwares de fábrica

| Arquivo | Modelo | Integridade |
|---|---|---|
| `Software PFL7560.zip` | **com USB-C**, V1.0.0.9: o resgate e a base das nossas builds | sha256 do zip `08d37bbb83699cfbf7a7cbeb8b1b3a399b3adf953a41e7ba02b900d167fc8b65` (`Software-PFL7560.zip.sha256`); `PFL7560.bin` dentro dele md5 `28a2f280eee313a4b115567926b2ba4f` |
| `Firmware PFL7560.zip` | **sem USB-C**, V1.0.0.1 (`KJM_5H039_412_INTELBRAS_NOTYPEC_TP`), publicado em 2026-10-20 para aparelhos fabricados a partir de 25/08/2026 | zip md5 `0e0ecc6c1bae56bd58b24119c5319b5b`, sha256 `a042d93a10bed36f1ef81786234544a174b4b0a8b14033a7dcfec723272a3762`; `.bin` md5 `89f82720067779fdaae5fc51c1c1ea4e`. **Nunca no aparelho com USB-C** ([doc 42](../docs/research/42-firmware-2026-10-modelo-sem-usbc.md)) |

## As nossas builds (locais; a S5 foi gravada e funciona)

A **S5 `3f3023b0…` foi gravada no aparelho em 2026-11-02 e subiu funcionando** (sem travar na logo, sem panic, suíte
rodando; o relato, o que se leu por adb e o roteiro para a próxima estão no [doc 47 §13](../docs/research/47-build-completa.md)).
O dono a gravou direto (AskUserQuestion, "S5 com o bloco 27" em vez de "Provar a S4a antes"), sem gravar a S4a e a
S4b. A S4a e a S4b nunca foram gravadas. A próxima gravação será a **S6**, com o bloco 30; o resgate segue sendo o
stock pelo POWER (aviso 3 abaixo, [doc 47 §12](../docs/research/47-build-completa.md)).

| Build | md5 | Estado |
|---|---|---|
| `PFL7560-S4a-NAO-GRADUADO.bin` | `a6e5da14cb3f53b42a457eb92bd91814` | **gate BIN-S4a (pulado na decisão de 2026-11-02).** Escada, Wi-Fi e xiri **nos mesmos blocos do stock** (só o `i_size` dos 3 inodes muda; chunks, slot, cabeçalho e `checksum1` do stock). CRC do vendor `0x883b40d6`. Fica para diagnóstico: se a S5 travar, é a build de delta mínimo |
| `PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin` | `2b1836b8a86ac1d998e0a06a3000478f` | **BIN-S4b.** O mesmo, mais o `.rc` da suíte, o app, a home e as 20 sobreposições (`artifacts/bin-build/conteudo.txt`), com o record 14 realocado (+3432448 B), 1397190844 B. CRC do vendor `0x251ba2e0`. Refeita em 2026-11-02 com o app versionCode 8 e a home 9 (duas gerações, o mesmo md5, `--verificar` APROVADO); a do bloco 21 era `31702b64…`. Muda de md5 sempre que um APK do kit ou o `.rc` mudar |
| `PFL7560-S5-COMPLETO-NAO-GRADUADO.bin` | `3f3023b06e500e354fa6d4ca4e236f5f` | **GRAVADA e funcionando em 2026-11-02 ([doc 47 §13](../docs/research/47-build-completa.md)).** A S4b mais a suíte inteira em `/vendor/etc/pfl7560-suite`, com uma semente que a copia para o `/data` vazio no 1º boot, as 2 linhas do `build.prop` da home e do gerenciador e a arte reta com o "Cast" verde na partição `logo` (record 6, mesmo tamanho, CRC `0x9c066411`), tudo em `artifacts/bin-build/conteudo-s5.txt`. Não traz a marca do `/atv` nem o JEIDA ([doc 47 §12](../docs/research/47-build-completa.md)): no 1º boot, com o pendrive plugado, o kit os repôs. **A que foi gravada (2026-11-02, blocos 26 a 29, app 9 e home 9, visor dos testes, `wifi_pwr` fora das escolhas):** 1399009468 B, record 14 com 85844116 B (+5251072 B), CRC do vendor `0x7ccdb8eb`; duas gerações com o mesmo md5, `--verificar` APROVADO, `test-semente-s5` 66/0. A `253b01c9` (bloco 28: record 14 com +5136384 B, CRC do vendor `0xe0263cf7`, 1398894780 B) foi superada pelo kit do conferente final (app 8, home 9, "Desligar no descanso", VLC no boot): A do bloco 26 (`81bb9885…`, sem o record 6) também foi superada |
| `PFL7560-COMPLETO-NAO-GRADUADO.bin` | `397698b9…` | aposentada (bloco 21): chunks FILL e 44832 B de zeros soltos no slot, forma que o loader nunca gravou; `build_fix_bin.py --verificar` a reprova |
| `PFL7560-FIX-escada-NAO-GRADUADO.bin` | `eae3a83d…` | aposentada (bloco 21): só a escada, com 8 chunks FILL e 53024 B de zeros soltos; `--verificar` a reprova |
| `PFL7560-FIX-com-metadados.bin` | `16a4b42a…` | superada em 2026-07-29 (limiares de brilho de antes da escada); removida do disco |
| protótipo sem metadados | `f5ff89c9…` | **travou o boot** (modo `0664` e sem rótulo SELinux, [guia 16](../docs/guide/16-recuperacao-brick.md)); apagado, não recriar |

Gerar e conferir (o stock é o `PFL7560.bin` de dentro do `Software PFL7560.zip`). Na pasta ignorada `build-s5/`, não
no `/tmp`: o stock e cada build têm ~1,4 GB e o `/tmp` é tmpfs pequeno (o gerador usa o `TMPDIR`):

```bash
mkdir -p build-s5/tmp && export TMPDIR="$PWD/build-s5/tmp"
unzip -j "firmware/Software PFL7560.zip" "*/PFL7560.bin" -d build-s5/
python3 artifacts/bin-build/build_fix_bin.py build-s5/PFL7560.bin artifacts/ZYCustom_390.ini firmware/PFL7560-S4a-NAO-GRADUADO.bin
python3 artifacts/bin-build/build_fix_bin.py build-s5/PFL7560.bin artifacts/ZYCustom_390.ini firmware/PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin --realocar --conteudo artifacts/bin-build/conteudo.txt
python3 artifacts/bin-build/build_fix_bin.py build-s5/PFL7560.bin artifacts/ZYCustom_390.ini firmware/PFL7560-S5-COMPLETO-NAO-GRADUADO.bin --realocar --conteudo artifacts/bin-build/conteudo-s5.txt
md5sum -c firmware/PFL7560-S4a-NAO-GRADUADO.bin.md5 firmware/PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin.md5
(cd firmware && md5sum -c PFL7560-S5-COMPLETO-NAO-GRADUADO.bin.md5)
```

Os `.md5` da S4a e da S4b trazem o caminho `firmware/...` (conferir da raiz do repositório); o da S5 traz só o nome
(conferir de dentro de `firmware/`), o formato que o `install.sh` e o `preflight-flash.sh` leem.

As três saem reprodutíveis (o mesmo stock e o mesmo `.ini` dão o mesmo md5; a S4b foi refeita duas vezes em
2026-11-02 com o mesmo `2b1836b8…`) e só ganham o nome final depois do
`verificar_bin` (doc 47 §10). `build_fix_bin.py --verificar <bin> <stock>` repete a conferência. Ele aceita só os
records 6 (com a diretiva `logo` do manifesto) e 14 diferentes do stock.

## Pré-voo do flash da S5

```bash
sh firmware/preflight-flash.sh <pendrive> --backup <pasta do backup no PC> --resgate <PFL7560.bin do stock>
```

Só lê. Sai 0 com `PRE-VOO APROVADO` e 1 se qualquer item falhar:

1. o `usb_update.bin` da raiz do pendrive é a S5 do `PFL7560-S5-COMPLETO-NAO-GRADUADO.bin.md5`;
2. o `--verificar` dele contra o stock, com o `conteudo-s5.txt`, sai APROVADO;
3. o kit do pendrive está inteiro (a `KIT_LISTA` do `newlink_update.sh` dele), aceita o `.rc` desta S5
   (`RC_S5_MD5`) e não há `DESINSTALAR-SUITE.txt`;
4. o backup do aparelho está no PC, fora do pendrive: arquivos de `/data/vendor/pfl7560-*` e a pasta
   `/data/data/com.pfl7560.home/shared_prefs`, soltos ou no `pfl-backup.tar`;
5. o stock de resgate (md5 `28a2f280…`) está fora do pendrive do flash.

O `install.sh --com-firmware` põe a S5 no pendrive, conferida pelo md5 deste mesmo `.md5` (o `.ps1` do Windows
também): o pendrive que ele faz passa no pré-voo. Teste: `tests/test-preflight-flash.sh`.

## Avisos

1. Os zips são **propriedade da Intelbras** e ficam aqui como backup privado de reparo. Não redistribua.
2. O clone precisa de **Git LFS**: `git lfs install` antes do `git clone` ou do `git pull`.
3. **O pendrive.** O `./install.sh --pendrive <ponto> --com-firmware` põe o **nosso** `.bin` (a S5) na raiz como
   `usb_update.bin` e o oficial V1.0.0.9 em `resgate-oficial/PFL7560.bin`, com um `LEIA-ME.txt` que ele mesmo
   gera. Ligar **segurando o power** com esse pendrive plugado grava o nosso firmware (a S5, gravada e
   funcionando desde 2026-11-02; as builds seguintes só são provadas no PC até a gravação). Para o **resgate**, o loader só lê o `usb_update.bin` da raiz: copie o `resgate-oficial/PFL7560.bin`,
   num PC, para a raiz de outro pendrive FAT32 com o nome `usb_update.bin` ([guia 16](../docs/guide/16-recuperacao-brick.md)).
4. Gravar qualquer `.bin` apaga o `/data` e provavelmente devolve o formato de cor do painel ao de fábrica (VESA):
   quem trocou o LCD roda o kit de novo para a cor. Na gravação da S5 a cor voltou ao normal sozinha porque o pendrive do kit ficou plugado no 1º boot ([doc 47 §13](../docs/research/47-build-completa.md)).
