# firmware/ — material de fabrica (proprietario)

| Arquivo | Tracking | Uso |
|---|---|---|
| `Software PFL7560.zip` | **Git LFS** (backup no repo) | Firmware **oficial** Intelbras V1.0.0.9 — resgate (`usb_update.bin`) e base do `bin-build` |
| `Firmware PFL7560.zip` | **Git LFS** (backup no repo) | Firmware **oficial** publicado em 2026-10-20 "para produtos com data de fabricação a partir de 25/08/2026": é o modelo **sem USB-C** (`KJM_5H039_412_INTELBRAS_NOTYPEC_TP`, V1.0.0.1). zip md5 `0e0ecc6c1bae56bd58b24119c5319b5b`, sha256 `a042d93a10bed36f1ef81786234544a174b4b0a8b14033a7dcfec723272a3762`; `.bin` md5 `89f82720067779fdaae5fc51c1c1ea4e`. **Não aplicar em aparelho com USB-C** ([doc 42](../docs/research/42-firmware-2026-10-modelo-sem-usbc.md)) |
| `PFL7560-FIX-escada-NAO-GRADUADO.bin` | **local only** (`*.bin` no gitignore) | Build com a **escada de brilho** (config md5 `252ab7a7…`) + metadados/SELinux carimbados. md5 `eae3a83db44f790b64b9a5838a27a977`. **Offline APROVADO; boot em hardware NÃO graduado — não flashar (invariante 1).** |
| `PFL7560-FIX-escada-NAO-GRADUADO.bin.md5` | local | md5 do bin acima |

Histórico de builds (nenhuma delas deve ser flashada; todas reproduzíveis pelo builder):

| Build | md5 | Estado |
|---|---|---|
| protótipo sem metadados | `f5ff89c9…` | **BRICOU** o aparelho (mode `0664` + xattr ausente). Apagado; não recriar. |
| `PFL7560-FIX-com-metadados.bin` | `16a4b42a…` | superada em 2026-07-29 — carregava os limiares de `[BacklightPolicy]` **pré-escada** (`27000..36000`). Removida do disco; reproduzível. |
| `PFL7560-FIX-escada-NAO-GRADUADO.bin` | `eae3a83d…` | **atual.** Offline aprovado, HW pendente (gate BIN-S4a). |

**BIN-S3b FECHADO (2026-07-29):** a build é **reprodutível** — duas execuções a partir do mesmo stock
(`28a2f280…`) e do mesmo `artifacts/ZYCustom_390.ini` (`252ab7a7…`) deram md5 idêntico. Verificação
independente: tamanho igual ao stock, `checksum1` preservado (`0x738ebd09`), **todas** as 9 faixas
divergentes contidas no slot da partição vendor (envelope a partir de `0x4b0b1d58`, logo após o prefixo do
record `0x4b0b1d54`), cabeçalho e tabela intactos, escada presente 2× e limiares antigos ausentes, mux
destravado, fans 100% nos 7 degraus. CRC da vendor: `0x832a0731`.

Reproduzir:
```bash
unzip -j "firmware/Software PFL7560.zip" "*/PFL7560.bin" -d /tmp/
python3 artifacts/bin-build/build_fix_bin.py /tmp/PFL7560.bin artifacts/ZYCustom_390.ini saida.bin
```

## Avisos

1. O zip e **propriedade da Intelbras**. Fica no repo como **backup pessoal / privado** de reparo. **Nao** redistribua em repositorio publico.
2. Requer **Git LFS** no clone: `git lfs install` antes de `git clone`/`git pull`.
3. Para resgate: extraia o `.bin` do zip, renomeie para `usb_update.bin` num pendrive FAT32 separado do autorun (ver `docs/guide/16-recuperacao-brick.md`).
4. Integridade: LFS oid/sha256 do zip = `08d37bbb83699cfbf7a7cbeb8b1b3a399b3adf953a41e7ba02b900d167fc8b65`.
