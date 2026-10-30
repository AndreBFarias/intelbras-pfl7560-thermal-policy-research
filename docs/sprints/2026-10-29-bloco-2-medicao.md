# Bloco 2 - scripts de medição e diagnóstico (2026-10-29)

Origem: auditoria de código da sessão do [doc 40](../research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §4.
Arquivos do bloco (disjuntos dos blocos 1 e 3): `pfl7560-saude.sh`, `pfl7560-monitor-props.sh`,
`pfl7560-evidencias.sh`, `pfl7560-teste-brilho.sh`, `pfl7560-vigia-lsadc.sh`, `pfl7560-fix.sh`,
`pfl7560-monitor-termico.sh`, `pfl7560-autocaptura.sh`.

Regras do bloco: nenhum teste fala com o aparelho. Prova = `bash -n`, `shellcheck` se houver, e os
TSV reais de `evidencias/` (ignorados pelo Git, existem nesta máquina) rodados nos dois locales.
**Nenhuma constante de md5 do `pfl7560-fix.sh` pode mudar** (`make check` tem que continuar verde).

## T2.1 - Locale fixo

- **Medido:** o `awk` daqui é mawk 1.3.4 e segue `LC_NUMERIC=pt_BR`: imprime vírgula, lê "65.8" como 65,
  compara "2,65" como texto. Hoje o `--resumo` deu 7,45 °C em pt_BR e 8,17 °C em C; o vigia trocou o
  veredito do LSADC; o CSV do `evidencias.sh` (`c2`, linhas 65-66) desloca colunas.
- **Cura:** `export LC_ALL=C` no topo de cada script do bloco que formata ou compara número.
- **Prova:** `LC_ALL=pt_BR.UTF-8 ./pfl7560-monitor-props.sh --resumo evidencias/2026-09-03/props-033635.tsv evidencias/2026-10-29/props-221947.tsv`
  dá 8,17 (em C também); o mesmo para `vigia-lsadc.sh --resumo` sobre os logs existentes.

## T2.2 - Monitor separa boots e sai quando o aparelho some

- **Medido:** `monitor-props.sh:127` lê o `boot_id` uma vez; o TSV de hoje mistura dois boots com o
  mesmo id. `:133-136` reconecta para sempre (até `--minutos`), sem marcar a lacuna.
- **Cura:** ler o `boot_id` a cada amostra; ao mudar, zerar a janela de regime e marcar a troca; o
  `--resumo` agrupa por `boot_id`. Depois de N falhas seguidas (ex.: 10), gravar linha de lacuna e sair
  com o resumo. Gravar a marca de override numa coluna (`:140-141,151-155`).
- **Prova:** `--resumo` do TSV de hoje separa os dois boots.

## T2.3 - Root conferido de verdade

- **Medido:** `fix.sh:64-67`, `evidencias.sh:99-102` imprimem "(root)" sem reler `id`; o
  `monitor-termico.sh` nem tenta root; hoje um `hidebug` falhou com `errno = 13` em silêncio.
- **Cura:** reaproveitar o `conecta` do `teste-brilho.sh` (que faz certo) e tratar `errno = 13` na
  saída do `hidebug` como erro visível.

## T2.4 - `saude.sh`: formato de cor e `.ini` efetivo

- **Medido:** `saude.sh:130-140` só aceita JEIDA; `:89,173-174` lê o `.ini` do `/vendor`, mas o
  `/atv/ini/ZYCustom_<projectid>.ini` vence primeiro (docs 04:36, 06:39, 09:55).
- **Cura:** OK quando o `lvds_fmt` em uso bate com o byte `0x5c` gravado; formato esperado opcional por
  `PFL_LVDS_ESPERADO`. Ler o `.ini` efetivo como o `effective_ini` do `evidencias.sh`.

## T2.5 - IP com porta e Ctrl-C

- **Medido:** acrescentam `:5555` sempre: `saude.sh:50`, `monitor-props.sh:102`, `vigia-lsadc.sh:186`,
  `teste-brilho.sh:75`, `fix.sh:61`, `evidencias.sh:96`. O trap de INT/TERM de `saude.sh:206` e
  `teste-brilho.sh:106` não sai: no `--vivacidade` um Ctrl-C ainda injeta 71000.
- **Cura:** o `case *:*` do `monitor-termico.sh:373` em todos; `trap '...; exit 130' INT TERM` como no
  `vigia-lsadc.sh:185`.
