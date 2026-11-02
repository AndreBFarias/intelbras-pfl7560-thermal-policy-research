# Bloco 6 - adotar as lições do firmware de 2026-10-20 (2026-10-30)

Origem: [doc 42](../research/42-firmware-2026-10-modelo-sem-usbc.md), seção "Lições para o nosso fix".
Objetivo: o kit e o builder servirem aos dois modelos (V1.0.0.9 com USB-C e V1.0.0.1 sem USB-C), sem
regressão para quem já usa. Roda depois da integração do bloco 5.

## T6.1 - Térmica por seções, preservando o modelo

- **Medido:** o stock novo (`ed3f314c…`) difere do antigo só no `CONFIG_MODEL`; o kit compara o `.ini`
  inteiro por md5 e recusaria o modelo novo.
- **Cura:** o kit reconhece os dois md5 de fábrica (e as versões nossas anteriores) e gera o `.ini`
  corrigido a partir do `.ini` do aparelho, trocando só as seções térmicas (`[Thermistor_*]`,
  `[BacklightPolicy]`, `[ThermalPolicy]`, `[CoolingFan_*]`) e mantendo o resto byte a byte. Estado-alvo
  continua idempotente: segunda execução não escreve.
- **Prova:** harness com os dois stocks; o resultado do antigo tem o md5 `252ab7a7…` de hoje; o do novo
  difere dele só no `CONFIG_MODEL`.

## T6.2 - Builder lê o offset do vendor da tabela

- **Medido:** `build_fix_bin.py` usa `0x4b0b1d54` fixo; no stock novo o vendor está em `0x4b0bc954` e o
  builder para num assert.
- **Cura:** ler offset e tamanho do record 14 da tabela em `0x40`.
- **Prova:** com o stock V1.0.0.9 o md5 de saída continua `eae3a83d…`; com o stock novo sai um `.bin`
  com checksum1 e CRC do vendor conferidos.

## T6.3 - Revert do `build.prop` por modelo

- **Medido:** o `build.prop.STOCK` é do V1.0.0.9 (com `zysys.typec*` e o canal de OTA antigo).
- **Cura:** o revert usa o `build.prop` do mesmo modelo do aparelho (detectado pelo `CONFIG_MODEL` ou
  pelo `ro.build.fingerprint`), ou se recusa a reverter com mensagem clara.

## T6.4 - Higiene e docs

- `artifacts/init.bigfish.rc.STOCK`: decidir com o dono se alinha com o stock real (quebra de linha
  final) — muda um md5 do contrato de `make check`.
- Doc 33: perfis 83 a 86. Docs 11 e disclosure: o defeito persiste no firmware de outubro.

## Estado (2026-10-30, bloco 6 implementado)

T6.1, T6.2 e T6.3 feitos; a T6.4 segue fora (decisão do dono). Só em software: nada disto foi para
aparelho nem para boot real do `.bin`.

> **Atualização (2026-10-30):** a **T6.4 foi feita**. O `artifacts/init.bigfish.rc.STOCK` ficou byte-exato
> ao de fábrica (sem a quebra de linha final) e o `RC_STOCK_MD5` passou de `0fe1b8fb` a `8f7e02b2`
> (`5bf7e80`; `make check` 9 OK). A parte de docs (doc 33 com os perfis 83-86; docs 11 e disclosure com o
> defeito persistindo em outubro) entrou no [bloco 3](2026-10-29-bloco-3-docs-sem-autorrefutacao.md).

- **T6.1:** `newlink_update.sh` reconhece os dois md5 de fábrica e monta o `.ini` por seções sobre o do
  aparelho. Acrescentou `[Thermal]` à lista de seções (os limites de 70/75 C moram nela). As versões
  anteriores nossas seguem trocadas pelo arquivo inteiro, porque uma delas (`5868d67f`) difere do atual até
  fora das seções térmicas. O md5 do resultado é conferido contra o esperado antes de gravar. Novos:
  `artifacts/ZYCustom.ini.NOTYPEC.STOCK` (`ed3f314c`), `build.prop.NOTYPEC.STOCK` (`f5b24c1d`),
  `ZYCustom_390.NOTYPEC.ini` (`bdf5c464`). Prova: `make check-kit`.
- **T6.2:** `build_fix_bin.py` lê offset/tamanho do record 14; stock V1.0.0.9 segue em `eae3a83d`, o
  V1.0.0.1 com o `.ini` NOTYPEC sai em `0d294cb3` (CRC do vendor `0xe2cad2f5`). Também recusa `.ini` de
  outro modelo que o do stock. Prova: `make check-bin` (containers sintéticos; com `PFL_STOCK_ANTIGO` e
  `PFL_STOCK_NOVO` roda nos stocks de verdade).
- **T6.3:** `pfl7560-fix.sh` detecta o modelo; backup do modelo sem USB-C em `backups-projetor/notypec/`;
  revert recusa backup de outro modelo; `apply` do modelo novo usa o `.ini` NOTYPEC (senão rebaixaria o
  `CONFIG_MODEL`). `install.bat` recusa apply/revert fora do modelo com USB-C. Prova: `make check-fix`.
