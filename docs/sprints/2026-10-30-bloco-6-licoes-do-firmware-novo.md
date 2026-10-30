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
