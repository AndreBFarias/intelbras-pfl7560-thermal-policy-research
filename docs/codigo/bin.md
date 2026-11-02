# Notas do código: gerador do `.bin` (`artifacts/bin-build/`)

O porquê das decisões no `build_fix_bin.py` e no `sparse.py`. Uso e manifesto:
[`artifacts/bin-build/README.md`](../../artifacts/bin-build/README.md); o `.bin` inteiro (builds, gravação,
definição de pronto): [doc 47](../research/47-build-completa.md); formato do container: [doc 15](../research/15-bin-definitivo.md).
Mapa geral: [`../MAPA.md`](../MAPA.md).

## Formato que o código assume

- **Container LOAD, tudo big-endian** (doc 15 §3): magic, `checksum1` em 0x04 (CRC do cabeçalho com ele zerado),
  `header_len` em 0x08 (0x2b4), `file_len` u64 em 0x0c. As 19 imagens em `0x54 + 32*i`: `img_length`, offset do
  prefixo `[len][crc]`, `flash_begin` e `flash_end` (u64), `flash_type`, `flash_index`. Depois de `header_len` vem o
  prefixo de um blob do loader e, logo depois, os records contíguos (offset = anterior + 8 + len).
- **O vendor é o record 14 e o offset dele não é fixo** (0x4b0b1d54 no V1.0.0.9, 0x4b0bc954 no V1.0.0.1, doc 42):
  é lido da tabela. O fallback do V1.0.0.9 só existe para metadados quando a leitura falha no stock.
- **CRC-32/MPEG-2:** `zlib.crc32` (refletido) sobre os bytes com os bits invertidos, e o registrador invertido de
  volta; igual ao `crc_header`, bit a bit.
- **Sparse do stock só tem chunks RAW e DONTCARE** e ocupa exatamente o `img_length` do record (doc 47 §10); o
  loader nunca gravou FILL. O `sparse.py` reempacota nessa forma, com `mmap` e regiões (não concatena o raw na RAM).

## Modos

- **Padrão (mesmos blocos):** os 3 fixes vão direto nos chunks RAW do sparse original, nos mesmos blocos e inodes do
  stock, e só o `i_size` do inode muda (low 32 bits, inode + 4). Layout de chunks, tamanho do slot, cabeçalho e
  `checksum1` iguais aos do stock; modo, dono e rótulo intactos por construção. Exige o mesmo número de blocos,
  blocos e inode em chunk RAW e ext4 sem `metadata_csum` (o checksum do inode não é refeito).
- **`--realocar`:** grava pelo `debugfs`, com os metadados do stock carimbados e conferidos, reempacota e muda o
  tamanho do record 14 no container (`img_length`, offsets dos records seguintes, `file_len`, `checksum1`). É o
  único que aceita `--conteudo <manifesto>`.
- **Toda saída passa por `verificar_bin`** antes de ganhar o nome final (antes disso fica num nome provisório):
  cabeçalho, os 19 records, a forma do sparse e a árvore inteira do vendor contra o stock (só os 3 fixes e as
  entradas do manifesto mudam; metadados de todos os inodes iguais).

## Armadilhas do `debugfs` e do ext4

- `sif mode 0644` **apaga** `S_IFREG` e o arquivo vira "bad type": o modo vai com o tipo (`0100644`, ou `S_IFDIR`
  numa pasta).
- O rótulo SELinux vai com o NUL terminal (`\000`), como no stock (34 bytes).
- O `debugfs` separa argumentos por espaço: cada origem do manifesto vira uma cópia congelada com nome sem espaço, e
  é ela que vai para a imagem e contra ela que se confere (pega também um `write` que falhou por falta de espaço).
- `e2fsck -fy`: 0 = limpo, 1 ou 2 = corrigiu (esperado depois do `debugfs`); 4 ou mais = a imagem não é confiável.
  Os metadados são reaplicados depois do `e2fsck`, por defesa.
- **Gate fatal:** metadados iguais aos do stock (e do manifesto) e nenhum `.rc` com escrita para grupo: a build de
  julho sem rótulo e com `.rc` 0664 travou o boot.
- Determinismo: o `debugfs`/`e2fsck` carimbam `s_wtime` e `s_lastcheck`; o gerador fixa os dois em 2019-12-31 (a
  era do stock) e fixa `mtime`, `ctime`, `atime` e `crtime` dos arquivos.
- O `.ini` novo tem de ser do mesmo modelo do stock: gravar o de um no outro rebaixaria o `CONFIG_MODEL`. O
  `CONFIG_MODEL` é lido em latin-1 (o arquivo mistura ASCII, GBK e mojibake; só a linha ASCII interessa).

## Manifesto (`conteudo.txt`, bloco 12)

- Uma linha `origem destino modo uid gid rotulo`; `#` comenta; origem `-` = pasta. Origens relativas à raiz do
  repositório; destinos como o aparelho os vê (`/vendor/...`), gravados sem o prefixo `/vendor`.
- Recusa (nada é gravado): linha fora do formato, origem ausente, destino repetido ou derivado do stock, modo com
  escrita para grupo ou outros (a causa do brick de julho). Um destino que já existe tem de ser do mesmo tipo e ter
  exatamente os metadados declarados (troca o conteúdo, nunca o rótulo nem o modo); um destino novo precisa da
  pasta-mãe; e tem de haver blocos e inodes livres (cada arquivo novo leva um bloco de xattr: inode de 128 B).
- Pastas novas entram primeiro (das mais rasas para as mais fundas), depois os arquivos.
