#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX="$ROOT/pfl7560-fix.sh"
ART="$ROOT/artifacts"

[ -f "$FIX" ] || { echo "FALHA: nao encontrei $FIX"; exit 1; }

const(){ grep -m1 "^$1=" "$FIX" | sed -E "s/^[A-Za-z0-9_]+=[\"']//; s/[\"'].*\$//"; }

md5f(){ md5sum "$1" | awk '{print $1}'; }

INI_STOCK_MD5="$(const INI_STOCK_MD5)"
INI_FIX_MD5="$(const INI_FIX_MD5)"
BP_STOCK_MD5="$(const BP_STOCK_MD5)"
RC_STOCK_MD5="$(const RC_STOCK_MD5)"
INI_STOCK_MD5_NOTYPEC="$(const INI_STOCK_MD5_NOTYPEC)"
INI_FIX_MD5_NOTYPEC="$(const INI_FIX_MD5_NOTYPEC)"
BP_STOCK_MD5_NOTYPEC="$(const BP_STOCK_MD5_NOTYPEC)"

rc=0
check(){
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
check "ZYCustom.ini.NOTYPEC.STOCK == INI_STOCK_MD5_NOTYPEC" "$(md5f "$ART/ZYCustom.ini.NOTYPEC.STOCK")" "$INI_STOCK_MD5_NOTYPEC"
check "build.prop.NOTYPEC.STOCK == BP_STOCK_MD5_NOTYPEC"    "$(md5f "$ART/build.prop.NOTYPEC.STOCK")"    "$BP_STOCK_MD5_NOTYPEC"
check "ZYCustom_390.NOTYPEC.ini == INI_FIX_MD5_NOTYPEC"     "$(md5f "$ART/ZYCustom_390.NOTYPEC.ini")"    "$INI_FIX_MD5_NOTYPEC"
check "pendrive-autorun/ZYCustom.ini == INI_FIX_MD5" "$(md5f "$ROOT/pendrive-autorun/ZYCustom.ini")" "$INI_FIX_MD5"

b64md5="$(grep -m1 '^CONFIG_B64=' "$FIX" | sed -E "s/^[A-Za-z0-9_]+=[\"']//; s/[\"'].*\$//" | base64 -d | md5sum | awk '{print $1}')"
check "CONFIG_B64 base64 -d (fix.sh) == INI_FIX_MD5" "$b64md5" "$INI_FIX_MD5"

if [ "$rc" -eq 0 ]; then
  echo "integridade OK: todos os artefatos byte-exatos"
else
  echo "integridade COMPROMETIDA: ver linhas FALHA acima"
fi
exit "$rc"
