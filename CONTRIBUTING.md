# Para quem mexe no código

As regras abaixo valem para qualquer mudança. Cada uma tem o porquê ao lado; se uma regra atrapalhar, mude a regra
aqui primeiro, com o motivo.

## Antes de commitar

1. **As quatro provas verdes:** `make check`, `make check-kit`, `make check-fix` e `make check-bin`
   ([`tests/README.md`](tests/README.md)). E `shellcheck` sem aviso em todo `.sh` que você tocou (`-s sh` nos do
   kit, que rodam no `sh` do Android).
2. **Stage por caminho** (`git add caminho1 caminho2`), nunca `git add -A`, `git add .` ou `--all`: o repositório
   convive com arquivos locais grandes e privados (`firmware/*.bin`, `evidencias/`, `private/`).
3. **Commits pequenos, em pt-BR sem acento**, no formato `tipo(area): o que mudou` (`fix(kit): ...`,
   `docs(bin): ...`). Sem linha de coautoria nem marca de ferramenta: a `main` tem um check que reprova isso.
4. **Zero emojis** em código, docs e commits.

## O kit do pendrive (`pendrive-autorun/`)

- **ASCII puro.** Os scripts rodam no `/vendor/bin/sh` do projetor e vivem em FAT32, onde acento vira mojibake ou
  quebra o parser. Confira com `grep -P '[^\x00-\x7F]' pendrive-autorun/*.sh pendrive-autorun/LEIA-ME.txt`.
- **Byte a byte.** O `newlink_update.sh` confere o md5 de **cada** arquivo do kit antes de escrever qualquer coisa
  e aborta se um divergir. As listas de md5 embutidas (`SUITE_LISTA`, `SUITE_MD5`, `KIT_LISTA`, `KIT_OVERLAYS`) só
  se regravam com `bash tests/atualizar-md5-kit.sh`, nunca à mão: a ordem importa (cada lista depende da anterior).
- Os binários do kit (`lvdsctl`, `nl_camcheck`, `nl_tela`, APKs) têm de ser iguais aos de `artifacts/`; o
  `atualizar-md5-kit.sh --check` reprova se não forem.

## Arquivos de contrato (byte-exatos)

- Os arquivos de fábrica e da correção em `artifacts/` ([mapa](artifacts/README.md)) e a cópia do kit têm md5
  fixo. O `make check` confere os **9** contra as constantes do `pfl7560-fix.sh`.
- O `.gitattributes` marca esses arquivos (e os binários, APKs, PNGs e fontes) como `-text byte-exact`: `-text`
  impede o git de normalizar fim de linha, e `byte-exact` diz ao hook de pre-commit para não "consertar" espaço
  de fim de linha. Os `.ini` de fábrica misturam ASCII, chinês GBK e latin-1, e o espaço de fim de linha é parte
  dos bytes. Em 2026-07-29 o hook tirou o espaço de 88 linhas dos `ZYCustom.ini` e derrubou o md5 (doc 34).
  Arquivo novo de contrato ganha a regra no `.gitattributes` **antes** do `git add`.
- **A correção térmica existe em 3 cópias byte-idênticas:** `artifacts/ZYCustom_390.ini`,
  `pendrive-autorun/ZYCustom.ini` e o `CONFIG_B64` do `pfl7560-fix.sh` (md5 `252ab7a7…`). Mudou o `.ini`:
  regenere as três **e** o `INI_MD5_OK` do `newlink_update.sh` (é um gate: md5 divergente aborta a aplicação) e o
  `MD5_FIX` do `pfl7560-evidencias.sh`. O `make check` cobre as três cópias, não esses dois.

## Segurança do aparelho

- **Nunca tocar bootloader nem recovery.** O aparelho é sempre recuperável porque o loader (ligar segurando o
  power com o `usb_update.bin` de fábrica na raiz de um pendrive) sempre existe ([guia 16](docs/guide/16-recuperacao-brick.md)).
- **Backup antes de escrever em `/vendor` ou na `panelparam`**, e escrita atômica: `.new`, confere o md5, `sync`,
  `mv`.
- **Nunca gravar o firmware de um modelo no outro.** `Software PFL7560.zip` é do modelo com USB-C (V1.0.0.9);
  `Firmware PFL7560.zip`, do sem USB-C (V1.0.0.1). Trocar apaga o mapa térmico certo ([doc 42](docs/research/42-firmware-2026-10-modelo-sem-usbc.md)).
- **Nenhum `.bin` nosso foi gravado no aparelho.** Gravar é o gate BIN-S4a: só com a palavra do dono, no momento,
  e com o pendrive de resgate à mão ([doc 47](docs/research/47-build-completa.md) §8 e §11). Só o gerador
  (`artifacts/bin-build/build_fix_bin.py`) produz candidato; a build de julho sem rótulo SELinux travou o boot.
- **O `0x5c` = JEIDA nunca entra no `.bin`:** depende do painel de cada aparelho; o de fábrica é VESA.
- **Não mexer em `HW_R`, `FW_NTC_B`, `FW_NTC_LNa` nem na escala do ADC:** a conversão de temperatura do firmware
  está certa (erro de 0,04 °C medido); o defeito era só o canal do multiplexador ([doc 08](docs/research/08-por-que-fica-cego.md)).
  Armar o tacômetro dos ventiladores sem o fio cai no canal dos termistores ([doc 34](docs/research/34-escada-brilho-e-fanmonitor.md)).
- **Limiares térmicos são por unidade:** o `EMERGENCY_VALUE` fica 15 a 20 °C acima do normal medido (`gtt1` em
  ~59 a 63 °C), nunca abaixo, senão o aparelho desliga em laço.

## Código e docs

- **Código sem comentário** (shell, Python, C, Java, Makefile, `.bat`, `.ps1`). O porquê vai para as notas do
  código da área ([`docs/codigo/`](docs/codigo/)) e o que é provisório, para a tabela "Provisório" delas. Ficam só os
  funcionais: shebang, diretivas do `shellcheck`, `# noqa` e afins, os marcadores `# NOME_INICIO`/`# NOME_FIM` das
  listas de md5 e o cabeçalho que a opção de ajuda imprime com `sed -n '2,Np' "$0"`.
- **Mapa:** arquivo novo, ponto de entrada novo ou caminho novo no aparelho entra no [`docs/MAPA.md`](docs/MAPA.md).
- **Docs em pt-BR com acento.** Um assunto, um lugar: o estado em [`docs/ESTADO.md`](docs/ESTADO.md), a instalação
  no [`INSTALL.md`](INSTALL.md), o `.bin` no doc 47, os painéis no doc 33; os outros docs apontam com um link.
- Fato que mudou: troque o texto, não empilhe uma "correção" por cima. O histórico fica no git.
- Links relativos válidos: confira depois de mover ou renomear qualquer arquivo.
