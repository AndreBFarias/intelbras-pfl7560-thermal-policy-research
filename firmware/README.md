# firmware/ — material de fabrica (proprietario)

| Arquivo | Tracking | Uso |
|---|---|---|
| `Software PFL7560.zip` | **Git LFS** (backup no repo) | Firmware **oficial** Intelbras V1.0.0.9 — resgate (`usb_update.bin`) e base do `bin-build` |
| `Firmware PFL7560.zip` | **Git LFS** (backup no repo) | Firmware **oficial** publicado em 2026-10-20 "para produtos com data de fabricação a partir de 25/08/2026": é o modelo **sem USB-C** (`KJM_5H039_412_INTELBRAS_NOTYPEC_TP`, V1.0.0.1). zip md5 `0e0ecc6c1bae56bd58b24119c5319b5b`, sha256 `a042d93a10bed36f1ef81786234544a174b4b0a8b14033a7dcfec723272a3762`; `.bin` md5 `89f82720067779fdaae5fc51c1c1ea4e`. **Não aplicar em aparelho com USB-C** ([doc 42](../docs/research/42-firmware-2026-10-modelo-sem-usbc.md)) |
| `PFL7560-FIX-escada-NAO-GRADUADO.bin` | **local only** (`*.bin` no gitignore) | Build com a **escada de brilho** (config md5 `252ab7a7…`) + metadados/SELinux carimbados. md5 `eae3a83db44f790b64b9a5838a27a977`. **Offline APROVADO; boot em hardware NÃO graduado — não flashar (invariante 1).** |
| `PFL7560-FIX-escada-NAO-GRADUADO.bin.md5` | local | md5 do bin acima |
| `PFL7560-S4a-NAO-GRADUADO.bin` | **local only** (md5 em `.md5`, versionado) | Build do gate BIN-S4a (bloco 21): escada + wi-fi + xiri **nos mesmos blocos do stock** (só o `i_size` dos 3 inodes muda; layout de chunks, slot, cabeçalho e `checksum1` do stock). md5 `a6e5da14cb3f53b42a457eb92bd91814`, CRC vendor `0x883b40d6`. **Não graduado em hardware: não flashar sem a palavra do dono e o resgate à mão.** |
| `PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin` | **local only** (md5 em `.md5`, versionado) | Build do BIN-S4b (bloco 21), **só depois de a S4a subir**: o mesmo, mais o `.rc` da suíte, app, home e as 20 sobreposições (`conteudo.txt`), com o record 14 **realocado** (+3407872 B; `file_len`, offsets dos records 15 a 18 e `checksum1` novos). md5 `e6b41856e26add86d0fad8881c0bf145`, CRC vendor `0xdb34914f`. Container realocado nunca passou pelo loader. |
| `PFL7560-COMPLETO-NAO-GRADUADO.bin` | **local only** | Build de 2026-10-31 (bloco 12/19): a escada + wi-fi + xiri + o `.rc` da suíte (`artifacts/bin-build/conteudo.txt`), metadados carimbados e conferidos depois do pack. md5 `397698b97c23b64cfee9e64d55c7f9aa`, CRC vendor `0xc1eee6da`, checksum1 preservado. **Offline válido; não graduado em hardware (gate BIN-S4a): não flashar sem a palavra do dono e o resgate à mão.** App, home, sobreposições e suíte não cabem no slot e entram pelo pendrive depois (doc 47). |

Histórico de builds (nenhuma delas deve ser flashada; todas reproduzíveis pelo builder):

| Build | md5 | Estado |
|---|---|---|
| protótipo sem metadados | `f5ff89c9…` | **BRICOU** o aparelho (mode `0664` + xattr ausente). Apagado; não recriar. |
| `PFL7560-FIX-com-metadados.bin` | `16a4b42a…` | superada em 2026-07-29 — carregava os limiares de `[BacklightPolicy]` **pré-escada** (`27000..36000`). Removida do disco; reproduzível. |
| `PFL7560-FIX-escada-NAO-GRADUADO.bin` | `eae3a83d…` | **aposentada** (bloco 21): só a escada, re-pack com 8 chunks FILL e 53024 B de zeros soltos (doc 47 §10); `--verificar` a reprova. Ainda é o `.bin` que o `install.sh --com-firmware` leva para `firmware-nosso-NAO-GRADUADO/`, até o script passar a levar a S4a. |
| `PFL7560-COMPLETO-NAO-GRADUADO.bin` | `397698b9…` | **aposentada** (bloco 21): escada + wi-fi + xiri + `.rc` da suíte, mas com chunks FILL e 44832 B de zeros soltos no slot, forma que o loader nunca gravou (doc 47 §10); `build_fix_bin.py --verificar` a reprova. Não gravar. |
| `PFL7560-S4a-NAO-GRADUADO.bin` | `a6e5da14…` | **atual, gate BIN-S4a** (bloco 21). Offline válido (`verificar_bin`), HW pendente. |
| `PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin` | `e6b41856…` | **atual, BIN-S4b** (bloco 21), realocada. Offline válida, HW pendente, só depois da S4a. |

**BIN-S3b FECHADO (2026-07-29):** a build é **reprodutível** — duas execuções a partir do mesmo stock
(`28a2f280…`) e do mesmo `artifacts/ZYCustom_390.ini` (`252ab7a7…`) deram md5 idêntico. Verificação
independente: tamanho igual ao stock, `checksum1` preservado (`0x738ebd09`), **todas** as 9 faixas
divergentes contidas no slot da partição vendor (envelope a partir de `0x4b0b1d58`, logo após o prefixo do
record `0x4b0b1d54`), cabeçalho e tabela intactos, escada presente 2× e limiares antigos ausentes, mux
destravado, fans 100% nos 7 degraus. CRC da vendor: `0x832a0731`.

Reproduzir (bloco 21):
```bash
unzip -j "firmware/Software PFL7560.zip" "*/PFL7560.bin" -d /tmp/
python3 artifacts/bin-build/build_fix_bin.py /tmp/PFL7560.bin artifacts/ZYCustom_390.ini firmware/PFL7560-S4a-NAO-GRADUADO.bin
python3 artifacts/bin-build/build_fix_bin.py /tmp/PFL7560.bin artifacts/ZYCustom_390.ini firmware/PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin --realocar --conteudo artifacts/bin-build/conteudo.txt
md5sum -c firmware/PFL7560-S4a-NAO-GRADUADO.bin.md5 firmware/PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin.md5
```
A S4b muda de md5 sempre que um APK do kit ou o `.rc` mudar.

## Avisos

1. O zip e **propriedade da Intelbras**. Fica no repo como **backup pessoal / privado** de reparo. **Nao** redistribua em repositorio publico.
2. Requer **Git LFS** no clone: `git lfs install` antes de `git clone`/`git pull`.
3. Para resgate: extraia o `.bin` do zip **do modelo do aparelho**, renomeie para `usb_update.bin` **na raiz** de um pendrive FAT32 separado do autorun (o loader só procura esse nome na raiz; uma cópia em subpasta só vale depois de copiada para a raiz num PC) (ver `docs/guide/16-recuperacao-brick.md`; o `LEIA-ME.txt` do kit descreve o arranjo pessoal com os dois juntos e o risco dele). O reflash provavelmente devolve o formato de cor do painel ao de fábrica (VESA): quem trocou o LCD refaz o teste de cor.
4. Integridade: LFS oid/sha256 do zip = `08d37bbb83699cfbf7a7cbeb8b1b3a399b3adf953a41e7ba02b900d167fc8b65`.
