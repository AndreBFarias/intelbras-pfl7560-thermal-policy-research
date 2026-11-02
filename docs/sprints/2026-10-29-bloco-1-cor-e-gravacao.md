# Bloco 1 - código que grava cor/partição (2026-10-29)

Origem: auditoria de código da sessão do [doc 40](../research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §4.
Arquivos do bloco (disjuntos dos blocos 2 e 3): `pendrive-autorun/newlink_update.sh`,
`pendrive-autorun/LEIA-ME.txt`, `pfl7560-lcd-color.sh`, `pfl7560-menu.sh`, `install.bat`,
`artifacts/bin-build/build_fix_bin.py`.

Regras do bloco:
- `newlink_update.sh` e `LEIA-ME.txt` são **ASCII puro, byte-exatos** (`.gitattributes`): sem acento, sem
  CRLF, e o hook de pre-commit não pode reformatar.
- `artifacts/lcd-color-fix/lvdsctl.c` fica **fora**: sem NDK nesta máquina, o binário não seria
  recompilado. Anotar, não editar.
- Nenhum teste fala com o aparelho. Prova = `bash -n`, `shellcheck` se houver, e simulação com stubs
  de `adb`/`dd`.

## T1.1 - FIX 4 do pendrive com formato alvo

> **EM ABERTO (2026-10-29):** o dono exige solução **automática, idempotente, universal e fácil para
> leigo**, para cor e térmica. A sentinela `fmt=` abaixo exige que a pessoa saiba o formato, então não
> atende. O desenho final depende da pesquisa de auto-pareamento (câmera interna, LCD-S3 do doc 29; ID
> elétrico do painel). Não implementar T1.1 antes dessa decisão; T1.2 a T1.5 seguem valendo.
>
> **SUBSTITUÍDA (2026-10-29):** a pesquisa decidiu o desenho. A T1.1 vira o
> [bloco 5](2026-10-29-bloco-5-kit-universal.md) (kit universal, critério "duas metades",
> [doc 41](../research/41-auto-pareamento-camera-e-kit-universal.md)).

- **Medido:** `newlink_update.sh:93-113,274-305` só grava `1` (JEIDA) e trata qualquer valor diferente
  de 1 como pendente; a autorização casa o serial com `grep -q` (substring, linha 96).
- **Causa:** premissa "painel trocado = -0600 = JEIDA para sempre".
- **Cura:** a sentinela declara o alvo (linha `SERIAL fmt=0|1`); grava só se o byte atual difere do alvo;
  `grep -qxF` (ou casamento exato do campo) no serial. Manter compatibilidade: sentinela antiga sem
  `fmt=` = alvo 1 (comportamento de hoje), com aviso no log.
- **Prova:** stub de `getprop`/`dd` com byte 0 e 1 e sentinela com e sem `fmt=`; serial `ABC12` não
  autoriza sentinela `ABC123`.

## T1.2 - `term_ok` do pendrive aceita `.ini` antigo

- **Medido:** `newlink_update.sh:123` só procura `HW_VIRTUAL_CHANNEL = 1`; o `.ini` anterior à escada
  passa como aplicado.
- **Cura:** comparar com `INI_MD5_OK` quando houver `md5sum`; sem ele, exigir o mux **e** a escada
  (`POLICY_0_THRESHOLD = 66000`).
- **Prova:** stub com `artifacts/ZYCustom_390.PREV-211927.ini` deve sair "pendente".

## T1.3 - Backup obrigatório antes de gravar na `panelparam`

- **Medido:** `pfl7560-lcd-color.sh:96-99` (`jeida`/`vesa`/`swap`/`bit`), `pfl7560-menu.sh:53-54` e
  `install.bat:~288-296` chamam o `lvdsctl`, que **grava** o byte na partição (provado 2026-10-29); só o
  `wizard` faz backup.
- **Cura:** todo caminho que chama `lvds` faz `do_backup` antes (um backup por dia basta, nome com data)
  e aborta se o backup falhar; `swap`/`bit` pedem confirmação explícita. No `install.bat`, a mesma
  regra (ou recusar e mandar para o `wizard`).
- **Corrige junto:** cabeçalho de `pfl7560-lcd-color.sh:7` ("ao vivo") e os rótulos que ligam número de
  peça a formato (`lcd-color.sh:16-17,152`, `menu.sh:44-48`, `install.bat:274-275`): "VESA (painel de
  fábrica e o da 2ª troca)", "JEIDA (o -0600 da 1ª troca)". A linha 159 do wizard não deve forçar base
  JEIDA nos eixos avançados: usar o formato que o usuário aceitou ou o atual.
- **Prova:** stub de `adb` registrando a ordem das chamadas: backup sempre antes de `lvdsctl`.

## T1.4 - `install.bat`: IP com porta, root e "JEIDA = certo"

- **Medido:** `install.bat:125` acrescenta `:5555` sempre; `:connect` imprime "(root)" sem conferir;
  `install.bat:108` só aceita JEIDA.
- **Cura:** aceitar `IP` e `IP:porta`; conferir `id` depois do `adb root`; checagem de cor passa quando o
  formato em uso bate com o byte gravado.
- **Prova:** revisão linha a linha (não há cmd.exe aqui); fim de linha do arquivo preservado como está.

## T1.5 - Builder do `.bin`

- **Medido:** `build_fix_bin.py` ignora o código de saída do `e2fsck` (`check=False`) e não confere se as
  trocas do wifi e do xiri aconteceram.
- **Cura:** falhar com `e2fsck` >= 4; conferir no fim que os dois arquivos trocados têm o conteúdo novo.
- **Prova:** `python3 -m py_compile`; leitura do diff.

## Estado (2026-10-30)

- **T1.1:** substituída pelo [bloco 5](2026-10-29-bloco-5-kit-universal.md) (kit universal). O FIX 4 por
  serial não existe mais no `newlink_update.sh`.
- **T1.2 a T1.5:** feitas e integradas (merge `1447328`): `term_ok` por md5 (`8fbe1bf`), backup obrigatório
  antes de gravar na `panelparam` com rótulos VESA/JEIDA corrigidos (`c7a0bbb`, `10df356`), `install.bat`
  com IP:porta, root conferido e cor pelo byte gravado (`aabd2f4`, `e207ccd`), builder falhando com
  `e2fsck` >= 4 e conferindo as trocas (`3c34df5`). Só em software; nada foi para o aparelho.
