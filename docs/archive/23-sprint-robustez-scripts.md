# 23 - Sprint: atomicidade e robustez dos scripts de instalação (M4 + M5)

Status: **PRONTA PARA EXECUÇÃO**. Prioridade **MÉDIA** (janela pequena, mas o pior caso do pendrive é RC
corrompido → só resgate destrutivo). Origem: auditoria [doc 20](20-auditoria-integral-2026-07-06.md).

## Objetivo

Estender o padrão de escrita atômica (`.new` + confere md5 + `mv`) e a checagem de erro do `pfl7560-fix.sh`
para todos os caminhos de escrita, nos dois instaladores, sem mudar o comportamento observável no caso feliz.

## Tasks

### T1 (M4) — autorun do pendrive: escrita atômica no arquivo boot-crítico
- Em `pendrive-autorun/newlink_update.sh`:
  - `ZYCustom.ini`: trocar o `cp "$MP/ZYCustom.ini" "$INI"` direto por `cp ... "$INI.new" && grep/md5 ok && mv
    "$INI.new" "$INI"` (rename atômico no mesmo FS).
  - `init.bigfish.rc` (BOOT-CRÍTICO): editar uma cópia — `cp "$RC" "$RC.new"; sed -i '...disabled...' "$RC.new";
    xiri_ok em "$RC.new"; mv "$RC.new" "$RC"` — nunca `sed -i` in-place no arquivo vivo.
  - Checar o exit code dos `cp` de backup (`cp "$X" "$X.STOCK"`).

### T2 (M5) — `pfl7560-fix.sh`: FIX 2 (wifi) atômico + backup à prova de falha silenciosa
- FIX 2: puxar o `build.prop` → `sed` local → `grep` de confirmação → push `.new` → confere md5 → `mv`
  (mesmo padrão dos FIX 1/3), em vez de `sed -i` direto no device sem verificação.
- `backup_stock`: trocar `mv ... && ok` / `cp ... && ok` por `mv ... || { err; exit 1; }` (idem `cp`) e
  `mkdir -p "$BK" || exit 1`; opcionalmente re-testar `[ -s "$BK/$nome.STOCK" ]` como pós-condição.
- Adicionar remontagem `mount -o ro,remount /vendor` nos caminhos de abort (hoje o device fica rw até reboot;
  o pendrive já remonta ro em falha).

### T3 (unificar semântica de "wifi ok")
- Alinhar os dois scripts para o predicado mais forte `grep -q wifi_disconnect_on_boot=0` (estado-alvo
  presente). No `wifi_ok` do pendrive, tratar `$BP` ausente/ilegível como NÃO-ok (hoje a negação vira sucesso).

## Proof-of-work esperado (runtime-real)

```bash
bash -n pfl7560-fix.sh && bash -n pendrive-autorun/newlink_update.sh   # sintaxe ok
# revisao do diff: nenhum caminho de escrita sem .new+md5+mv; nenhum cp/mv/mkdir de backup sem '|| exit 1'
# teste seguro com o projetor (leitura), depois um apply real supervisionado (com o dono ciente):
PFL_IP=<IP-do-projetor> ./pfl7560-fix.sh status
```

## Riscos e recuperação

- Mudança nos scripts. **Testar o `apply` real só com o dono ciente e com o pendrive de resgate à mão** — é o
  único item desta leva que grava no aparelho.
- A atomicidade REDUZ o risco de brick (fecha a janela de corrupção do `init.bigfish.rc`), não aumenta.
