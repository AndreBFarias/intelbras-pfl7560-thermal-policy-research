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

- `stock_PFL7560.bin` — firmware de fábrica V1.0.0.9 (md5 `28a2f280eee313a4b115567926b2ba4f`)
- `../ZYCustom_390.ini` — config da build (md5 `252ab7a7…`, com a escada de brilho)
- `saida.bin` — saída

**Dois modelos (bloco 6).** O firmware V1.0.0.1, do modelo sem USB-C (NOTYPEC, doc 42), tem o
vendor em outro offset (`0x4b0bc954`) e outro `CONFIG_MODEL`. O builder lê offset e tamanho do
record 14 da tabela do container (em `0x40`, big-endian: tamanho em `+0x14`, offset em `+0x18`) e
**recusa** um `.ini` de outro modelo que o do stock (para não rebaixar o `CONFIG_MODEL`):

| stock | `.ini` a usar | md5 da saída |
|---|---|---|
| V1.0.0.9, com USB-C (`28a2f280…`) | `../ZYCustom_390.ini` (`252ab7a7…`) | `eae3a83d…` |
| V1.0.0.1, sem USB-C (`89f82720…`) | `../ZYCustom_390.NOTYPEC.ini` (`bdf5c464…`) | `0d294cb3…` (CRC do vendor `0xe2cad2f5`) |

O `ZYCustom_390.NOTYPEC.ini` é o `.ini` de fábrica do modelo novo (`ed3f314c…`) com só as seções
térmicas trocadas, a mesma conta que o kit de pendrive faz no aparelho. Provado só em software
(`make check-bin`); nenhum `.bin` do modelo novo foi gravado em aparelho.

**Build reprodutível (BIN-S3b, fechado em 2026-07-29):** com esse stock e essa config a saída é
determinística — md5 `eae3a83db44f790b64b9a5838a27a977`, CRC da vendor `0x832a0731`. Rodar 2× dá o mesmo
md5. Se der outro valor, algo mudou no stock, na config ou no builder — investigue antes de usar.

O `build.prop` e o `init.bigfish.rc` são derivados do stock dentro da imagem.

## Manifesto: o que a build leva além dos 3 fixes (bloco 12)

```bash
python3 build_fix_bin.py <stock_PFL7560.bin> ../ZYCustom_390.ini <saida.bin> --conteudo conteudo.txt
```

O [`conteudo.txt`](conteudo.txt) lista, uma entrada por linha, `origem destino modo uid gid rotulo`. A origem
é relativa à raiz do repositório (o conjunto final de arquivos vem do `pendrive-autorun/`); `-` cria uma pasta.
O destino é escrito como o aparelho o vê (`/vendor/...`). Depois que o tema (bloco 10) ou um app novo entrar,
basta rodar de novo. O gerador:

- recusa linha fora do formato, origem ausente, destino fora de `/vendor/` ou repetido, um dos 3 arquivos que
  ele mesmo deriva, modo com escrita para grupo ou outros e rótulo fora de `u:object_r:<tipo>:s0`;
- num destino que já existe no stock, exige exatamente os metadados declarados (troca só o conteúdo);
- exige que a pasta-mãe exista no stock ou esteja no manifesto;
- confere blocos e inodes livres antes de gravar (cada arquivo novo leva um bloco de xattr, porque o inode do
  vendor tem 128 bytes);
- carimba modo, dono, rótulo (com o NUL do stock) e horários fixos, e confere tipo, metadados e conteúdo byte a
  byte depois do `e2fsck` e de novo depois do re-pack;
- aborta se o sparse não couber no slot do record 14 (`maior que o slot stock`).

**A folga do slot é o limite real.** O ext4 do vendor tem 213 MiB livres, mas o sparse dele vai num slot de
tamanho fixo no container: no V1.0.0.9 sobram 65312 bytes (53024 depois dos 3 fixes). Cabe o `.rc` da suíte;
o app (95577 B) não cabe, e a suíte inteira (1,2 MB) muito menos. Ver o
[doc 47](../../docs/research/47-build-completa.md). Sem `--conteudo`, a saída é a de sempre (`eae3a83d…`).

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

1. Extrai vendor (record 14, offset e tamanho lidos da tabela do container)
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

**Ainda é obrigatório testar em hardware** com pendrive de resgate **oficial** (`usb_update.bin` = stock) separado e pronto (`./install.sh --pendrive <pasta> --com-firmware` ou `tests/preparar-pendrive.sh <dispositivo>` preparam um, com o `usb_update.bin` conferido por md5; ver [`INSTALL.md`](../../INSTALL.md)). O protótipo antigo sem metadados foi apagado; não reutilize builds antigas.

Recuperação: [`../../docs/guide/16-recuperacao-brick.md`](../../docs/guide/16-recuperacao-brick.md).
