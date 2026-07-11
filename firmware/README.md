# firmware/ — material de fabrica (proprietario)

| Arquivo | Tracking | Uso |
|---|---|---|
| `Software PFL7560.zip` | **Git LFS** (backup no repo) | Firmware **oficial** Intelbras V1.0.0.9 — resgate (`usb_update.bin`) e base do `bin-build` |
| `PFL7560-FIX-com-metadados.bin` | **local only** (`*.bin` no gitignore) | Build com conteúdo + metadados (mode/SELinux). **Offline OK; boot em hardware ainda nao graduado.** |
| `PFL7560-FIX-com-metadados.bin.md5` | local | md5 do bin acima |

O protótipo experimental antigo sem metadados (`PFL7560-FIX…brica…`) foi **apagado** — era inseguro (metadados errados) e não deve ser recriado sem o builder atual + teste em hardware.

## Avisos

1. O zip e **propriedade da Intelbras**. Fica no repo como **backup pessoal / privado** de reparo. **Nao** redistribua em repositorio publico.
2. Requer **Git LFS** no clone: `git lfs install` antes de `git clone`/`git pull`.
3. Para resgate: extraia o `.bin` do zip, renomeie para `usb_update.bin` num pendrive FAT32 separado do autorun (ver `docs/guide/16-recuperacao-brick.md`).
4. Integridade: LFS oid/sha256 do zip = `08d37bbb83699cfbf7a7cbeb8b1b3a399b3adf953a41e7ba02b900d167fc8b65`.
