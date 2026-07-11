# bin-build — reconstruir o PFL7560.bin com a correção embutida

Gera um firmware `.bin` com os fixes no default, editando **apenas a partição vendor** e
mantendo o tamanho do payload no container LOAD — o `checksum1` permanece válido; só o CRC da
partição é recalculado. Fundamentação: [`../../docs/research/15-bin-definitivo.md`](../../docs/research/15-bin-definitivo.md).

## Requisitos

- `python3`, `debugfs`, `e2fsck` (pacote `e2fsprogs`)
- `sparse.py` neste diretório

```bash
sudo apt install e2fsprogs   # Debian/Ubuntu/Pop
```

## Uso

```bash
# extrair o stock do zip oficial, se ainda nao tiver o .bin solto:
#   unzip -j "firmware/Software PFL7560.zip" "*.bin" -d /tmp/
python3 build_fix_bin.py  <stock_PFL7560.bin>  ../ZYCustom_390.ini  <saida.bin>
```

- `stock_PFL7560.bin` — firmware de fábrica V1.0.0.9
- `../ZYCustom_390.ini` — config da build (md5 `1ad641ed…`)
- `saida.bin` — saída

O `build.prop` e o `init.bigfish.rc` são derivados do stock dentro da imagem.

## Metadados (obrigatório — causa do brick antigo)

Após cada `debugfs write`, o script **lê e reaplica** do stock:

| Arquivo | mode (perm) | sif mode (com S_IFREG) | security.selinux |
|---|---|---|---|
| `/etc/ZYCustom.ini` | 0644 | **0100644** | `u:object_r:vendor_configs_file:s0` |
| `/build.prop` | 0600 | **0100600** | `u:object_r:vendor_file:s0` |
| `/etc/init/hw/init.bigfish.rc` | 0644 | **0100644** | `u:object_r:vendor_configs_file:s0` |

Notas críticas:

1. `sif mode 0644` **sem** o bit `S_IFREG` vira `Type: bad type` — o script usa `0100xxx`.
2. `init.bigfish.rc` **não pode** ser group/world-writable (`0664`) — o init do Android recusa o parse.
3. Label SELinux com NUL terminal (`\000`), como no stock (34 bytes no configs).
4. Gate fatal: após o edit e após o re-pack, `stat`/`ea_get` devem bater com o stock; aborta se falhar.

## O que o script faz

1. Extrai vendor (record 14 @ `0x4b0b1d54`)
2. Expande sparse → ext4 raw
3. Lê metadados stock dos 3 arquivos
4. Substitui conteúdo (`ZYCustom` / wifi / xiri disabled) + carimba mode/uid/gid/xattr
5. `e2fsck` + reaplica metadados + fixa superbloco (determinismo de timestamps)
6. **Re-pack sparse** (`sparse.pack`) + pad com zeros até o size stock (slot do container)
7. Recalcula CRC-32/MPEG-2 da partição; `checksum1` do LOAD permanece
8. Revalida metadados no sparse empacotado

## Verificação / flash

```bash
# o script ja aborta se metadados divergirem; saida tipica:
#   [done] saida.bin  VALIDO (conteudo + metadados stock nos 3 arquivos)
```

**Ainda é obrigatório testar em hardware** com pendrive de resgate **oficial** (`usb_update.bin` = stock) separado e pronto. O protótipo antigo sem metadados foi apagado; não reutilize builds antigas.

Recuperação: [`../../docs/guide/16-recuperacao-brick.md`](../../docs/guide/16-recuperacao-brick.md).
