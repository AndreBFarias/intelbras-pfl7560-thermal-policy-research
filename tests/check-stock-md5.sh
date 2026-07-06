#!/usr/bin/env bash
# tests/check-stock-md5.sh - sprint 21 (T3)
# Valida a integridade byte-exata dos artefatos stock/fix versionados contra as
# constantes do proprio pfl7560-fix.sh (lidas via grep, NUNCA redigitadas aqui,
# para o teste nao envelhecer se as constantes mudarem). Roda da raiz do repo:
#   make check   ou   bash tests/check-stock-md5.sh
# Sai !=0 se qualquer md5 divergir. Nao toca no aparelho.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX="$ROOT/pfl7560-fix.sh"
ART="$ROOT/mod-termica-PFL7560/artefatos"

[ -f "$FIX" ] || { echo "FALHA: nao encontrei $FIX"; exit 1; }

# le uma constante do fix.sh (aspas simples ou duplas), sem redigitar o valor.
# strip do prefixo NOME= e do primeiro quote; corta a partir do quote de fechamento.
# extrator robusto tambem para CONFIG_B64, cujo base64 termina em '=' (padding)
# imediatamente antes da aspa - onde um sed greedy s/.*='// comeria o valor todo.
const(){ grep -m1 "^$1=" "$FIX" | sed -E "s/^[A-Za-z0-9_]+=[\"']//; s/[\"'].*\$//"; }

md5f(){ md5sum "$1" | awk '{print $1}'; }

INI_STOCK_MD5="$(const INI_STOCK_MD5)"
INI_FIX_MD5="$(const INI_FIX_MD5)"
BP_STOCK_MD5="$(const BP_STOCK_MD5)"
RC_STOCK_MD5="$(const RC_STOCK_MD5)"

rc=0
check(){ # $1 rotulo  $2 obtido  $3 esperado
  if [ -n "$3" ] && [ "$2" = "$3" ]; then
    printf 'OK    %-50s %s\n' "$1" "$2"
  else
    printf 'FALHA %-50s obtido=%s esperado=%s\n' "$1" "$2" "$3"
    rc=1
  fi
}

check "ZYCustom.ini.ORIGINAL == INI_STOCK_MD5" "$(md5f "$ART/ZYCustom.ini.ORIGINAL")" "$INI_STOCK_MD5"
check "build.prop.STOCK == BP_STOCK_MD5"        "$(md5f "$ART/build.prop.STOCK")"       "$BP_STOCK_MD5"
check "init.bigfish.rc.STOCK == RC_STOCK_MD5"   "$(md5f "$ART/init.bigfish.rc.STOCK")"  "$RC_STOCK_MD5"
check "ZYCustom_390.ini == INI_FIX_MD5"         "$(md5f "$ART/ZYCustom_390.ini")"       "$INI_FIX_MD5"
check "pendrive-autorun/ZYCustom.ini == INI_FIX_MD5" "$(md5f "$ROOT/pendrive-autorun/ZYCustom.ini")" "$INI_FIX_MD5"

# base64 embutido no fix.sh, decodificado, deve bater INI_FIX_MD5 (as 3 copias)
b64md5="$(grep -m1 '^CONFIG_B64=' "$FIX" | sed -E "s/^[A-Za-z0-9_]+=[\"']//; s/[\"'].*\$//" | base64 -d | md5sum | awk '{print $1}')"
check "CONFIG_B64 base64 -d (fix.sh) == INI_FIX_MD5" "$b64md5" "$INI_FIX_MD5"

if [ "$rc" -eq 0 ]; then
  echo "integridade OK: todos os artefatos byte-exatos"
else
  echo "integridade COMPROMETIDA: ver linhas FALHA acima"
fi
exit "$rc"
