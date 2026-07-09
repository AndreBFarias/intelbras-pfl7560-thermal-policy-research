# firmware/ — material de fabrica (proprietario)

| Arquivo | Tracking | Uso |
|---|---|---|
| `Software PFL7560.zip` | **Git LFS** (backup no repo) | Firmware **oficial** Intelbras V1.0.0.9 — resgate (`usb_update.bin`) e base do `bin-build` |
| `PFL7560-FIX.NAO-USAR-brica-SELinux.bin` | **ignorado** (nao versionar) | Protótipo antigo sem metadados — **nao flashe** |

## Avisos

1. O zip e **propriedade da Intelbras**. Fica no repo como **backup pessoal / privado** de reparo. **Nao** redistribua em repositorio publico.
2. Requer **Git LFS** no clone: `git lfs install` antes de `git clone`/`git pull`.
3. Para resgate: extraia o `.bin` do zip, renomeie para `usb_update.bin` num pendrive FAT32 separado do autorun (ver `docs/guide/16-recuperacao-brick.md`).
4. Integridade de referencia (arquivo local): confira com `ls -lh` e, se quiser, `sha256sum Software\ PFL7560.zip` apos o clone.
