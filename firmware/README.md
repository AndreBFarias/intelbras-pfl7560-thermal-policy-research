# firmware/ — firmwares de fábrica e as nossas builds

Os `.zip` de fábrica ficam no git por **Git LFS**; os `.bin` são locais (`*.bin` no `.gitignore`), e só o md5
deles é versionado (`*.bin.md5`). O estado da build, o que ela leva e o roteiro de gravação estão no
[doc 47](../docs/research/47-build-completa.md); o formato do container, no [doc 15](../docs/research/15-bin-definitivo.md).

## Firmwares de fábrica

| Arquivo | Modelo | Integridade |
|---|---|---|
| `Software PFL7560.zip` | **com USB-C**, V1.0.0.9: o resgate e a base das nossas builds | sha256 do zip `08d37bbb83699cfbf7a7cbeb8b1b3a399b3adf953a41e7ba02b900d167fc8b65` (`Software-PFL7560.zip.sha256`); `PFL7560.bin` dentro dele md5 `28a2f280eee313a4b115567926b2ba4f` |
| `Firmware PFL7560.zip` | **sem USB-C**, V1.0.0.1 (`KJM_5H039_412_INTELBRAS_NOTYPEC_TP`), publicado em 2026-10-20 para aparelhos fabricados a partir de 25/08/2026 | zip md5 `0e0ecc6c1bae56bd58b24119c5319b5b`, sha256 `a042d93a10bed36f1ef81786234544a174b4b0a8b14033a7dcfec723272a3762`; `.bin` md5 `89f82720067779fdaae5fc51c1c1ea4e`. **Nunca no aparelho com USB-C** ([doc 42](../docs/research/42-firmware-2026-10-modelo-sem-usbc.md)) |

## As nossas builds (locais; nenhuma gravada no aparelho)

| Build | md5 | Estado |
|---|---|---|
| `PFL7560-S4a-NAO-GRADUADO.bin` | `a6e5da14cb3f53b42a457eb92bd91814` | **atual, gate BIN-S4a.** Escada, Wi-Fi e xiri **nos mesmos blocos do stock** (só o `i_size` dos 3 inodes muda; chunks, slot, cabeçalho e `checksum1` do stock). CRC do vendor `0x883b40d6`. É a que o `install.sh --com-firmware` põe na raiz do pendrive como `usb_update.bin` |
| `PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin` | `31702b647ba9b2bca98e6da625231e69` | **atual, BIN-S4b, só depois de a S4a subir.** O mesmo, mais o `.rc` da suíte, o app, a home e as 20 sobreposições (`artifacts/bin-build/conteudo.txt`), com o record 14 realocado (+3407872 B). CRC do vendor `0xd8e4e78b`. Muda de md5 sempre que um APK do kit ou o `.rc` mudar |
| `PFL7560-COMPLETO-NAO-GRADUADO.bin` | `397698b9…` | aposentada (bloco 21): chunks FILL e 44832 B de zeros soltos no slot, forma que o loader nunca gravou; `build_fix_bin.py --verificar` a reprova |
| `PFL7560-FIX-escada-NAO-GRADUADO.bin` | `eae3a83d…` | aposentada (bloco 21): só a escada, com 8 chunks FILL e 53024 B de zeros soltos; `--verificar` a reprova |
| `PFL7560-FIX-com-metadados.bin` | `16a4b42a…` | superada em 2026-07-29 (limiares de brilho de antes da escada); removida do disco |
| protótipo sem metadados | `f5ff89c9…` | **travou o boot** (modo `0664` e sem rótulo SELinux, [guia 16](../docs/guide/16-recuperacao-brick.md)); apagado, não recriar |

Gerar e conferir (o stock é o `PFL7560.bin` de dentro do `Software PFL7560.zip`):

```bash
unzip -j "firmware/Software PFL7560.zip" "*/PFL7560.bin" -d /tmp/
python3 artifacts/bin-build/build_fix_bin.py /tmp/PFL7560.bin artifacts/ZYCustom_390.ini firmware/PFL7560-S4a-NAO-GRADUADO.bin
python3 artifacts/bin-build/build_fix_bin.py /tmp/PFL7560.bin artifacts/ZYCustom_390.ini firmware/PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin --realocar --conteudo artifacts/bin-build/conteudo.txt
md5sum -c firmware/PFL7560-S4a-NAO-GRADUADO.bin.md5 firmware/PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin.md5
```

As duas saem reprodutíveis (o mesmo stock e o mesmo `.ini` dão o mesmo md5) e só ganham o nome final depois do
`verificar_bin` (doc 47 §10). `build_fix_bin.py --verificar <bin> <stock>` repete a conferência.

## Avisos

1. Os zips são **propriedade da Intelbras** e ficam aqui como backup privado de reparo. Não redistribua.
2. O clone precisa de **Git LFS**: `git lfs install` antes do `git clone` ou do `git pull`.
3. **O pendrive.** O `./install.sh --pendrive <ponto> --com-firmware` põe o **nosso** `.bin` (a S4a) na raiz como
   `usb_update.bin` e o oficial V1.0.0.9 em `resgate-oficial/PFL7560.bin`, com um `LEIA-ME.txt` que ele mesmo
   gera. Ligar **segurando o power** com esse pendrive plugado grava o nosso firmware, que não foi provado no
   hardware. Para o **resgate**, o loader só lê o `usb_update.bin` da raiz: copie o `resgate-oficial/PFL7560.bin`,
   num PC, para a raiz de outro pendrive FAT32 com o nome `usb_update.bin` ([guia 16](../docs/guide/16-recuperacao-brick.md)).
4. Gravar qualquer `.bin` apaga o `/data` e provavelmente devolve o formato de cor do painel ao de fábrica (VESA):
   quem trocou o LCD roda o kit de novo para a cor.
