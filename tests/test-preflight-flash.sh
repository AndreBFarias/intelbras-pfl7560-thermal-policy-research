#!/usr/bin/env bash
# firmware/preflight-flash.sh (bloco 28) sob dash, num pendrive de mentira (kit real copiado pelo install.sh,
# usb_update.bin e stock pequenos, verificador de mentira): aprova so com os 5 itens certos e recusa cada um.
# shellcheck disable=SC2016,SC2034
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export LC_ALL=C
PRE="$ROOT/firmware/preflight-flash.sh"
FALHAS=0; TESTES=0; CASO="-"
ok(){ TESTES=$((TESTES+1)); }
falha(){ TESTES=$((TESTES+1)); FALHAS=$((FALHAS+1)); echo "  FALHA $CASO: $*"; }
afirma(){ if eval "$1"; then ok; else falha "$2  (cond: $1)"; fi; }
md5(){ md5sum "$1" | cut -d' ' -f1; }
SH="dash"; command -v dash >/dev/null 2>&1 || SH="sh"

TMP="$(mktemp -d)"
trap 'chmod -R u+rwx "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT

# o kit real, uma vez; cada cenario copia
KIT="$TMP/kit"; mkdir -p "$KIT"
if ! env PFL_TESTE=1 bash "$ROOT/install.sh" --pendrive "$KIT" > "$TMP/kit.log" 2>&1; then
  echo "install.sh --pendrive falhou: $(tail -3 "$TMP/kit.log")"; exit 1
fi

cat > "$TMP/verif.sh" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$VERIF_LOG"
if [ -f "$VERIF_FLAG.reprova" ]; then echo "  record 6: payload difere do logo de fabrica com o JPEG do manifesto"; echo "[verificar] $1  FALHOU"; exit 1; fi
if [ -f "$VERIF_FLAG.mudo" ]; then exit 0; fi
if [ -f "$VERIF_FLAG.rc1" ]; then echo "[verificar] $1  APROVADO"; exit 1; fi
echo "  nenhum problema"; echo "[verificar] $1  APROVADO"
EOF
chmod +x "$TMP/verif.sh"

novo_cenario(){
  CASO="$1"
  T="$(mktemp -d "$TMP/c.XXXXXX")"
  PEN="$T/pen"; PC="$T/pc"
  cp -a "$KIT" "$PEN"
  mkdir -p "$PC/backup/x"
  head -c 70000 /dev/urandom > "$PEN/usb_update.bin"
  printf '%s  PFL7560-S5-COMPLETO-NAO-GRADUADO.bin\n' "$(md5 "$PEN/usb_update.bin")" > "$T/s5.md5"
  head -c 50000 /dev/urandom > "$PC/stock.bin"
  STOCK_MD5="$(md5 "$PC/stock.bin")"
  ( cd "$PC/backup/x" && mkdir -p data/vendor/pfl7560-suite data/vendor/pfl7560-logo data/data/com.pfl7560.home/shared_prefs \
    && echo diario > data/vendor/pfl7560-suite/diario-0.txt && echo 7 > data/vendor/pfl7560-logo/cantos \
    && tar cf ../pfl-backup.tar data ) && rm -rf "$PC/backup/x"
  BK="$PC/backup"; RES="$PC/stock.bin"
}
roda(){
  env PFL_TESTE=1 PFL_STOCK_MD5="$STOCK_MD5" PFL_S5_MD5_ARQ="$T/s5.md5" PFL_VERIFICAR="${VERIFICADOR-$TMP/verif.sh}" \
      VERIF_LOG="$T/verif.log" VERIF_FLAG="$T/flag" PATH="${PATH_EXTRA:+$PATH_EXTRA:}$PATH" \
      "$SH" "$PRE" "$@" > "$T/saida.log" 2>&1
  RC=$?
}
padrao(){ roda "$PEN" --backup "$BK" --resgate "$RES"; }
arvore(){ ( cd "$1" && find . -printf '%p %s %m\n' | sort && find . -type f -exec md5sum {} + | sort ); }
recusa(){ # recusa <trecho esperado na saida>
  ESPERA="$1"
  afirma '[ "$RC" = 1 ]' "deveria recusar (rc=$RC): $(tail -2 "$T/saida.log" | tr '\n' ' ')"
  afirma 'grep -q "PRE-VOO RECUSADO" "$T/saida.log" && ! grep -q "PRE-VOO APROVADO" "$T/saida.log"' "sem a linha de recusa"
  afirma 'grep -F "[FALHA]" "$T/saida.log" | grep -qF -- "$ESPERA"' "sem a falha '$ESPERA': $(grep -F '[FALHA]' "$T/saida.log" | tr '\n' ' ')"
}

echo "== aprovado =="
novo_cenario "tudo certo"
ANTES="$(arvore "$PEN")"
padrao
afirma '[ "$RC" = 0 ]' "rc=$RC: $(cat "$T/saida.log")"
afirma 'grep -q "^PRE-VOO APROVADO" "$T/saida.log" && [ "$(grep -c "^\[OK\] [1-5]\. " "$T/saida.log")" = 6 ] && ! grep -q FALHA "$T/saida.log"' "saida: $(cat "$T/saida.log")"
for i in 1 2 3 4 5; do afirma 'grep -q "^\[OK\] $i\. " "$T/saida.log"' "item $i sem [OK]"; done
afirma '[ "$(sed -n 1p "$T/verif.log")" = "$PEN/usb_update.bin" ] && [ "$(sed -n 2p "$T/verif.log")" = "$PC/stock.bin" ] && [ "$(sed -n 3p "$T/verif.log")" = "$ROOT/artifacts/bin-build/conteudo-s5.txt" ]' "o verificador nao recebeu bin, stock e conteudo-s5.txt: $(tr '\n' ' ' < "$T/verif.log")"
afirma '[ "$(arvore "$PEN")" = "$ANTES" ]' "o pre-voo mexeu no pendrive"
afirma 'grep -qF "(2 arquivos de /data/vendor/pfl7560-*," "$T/saida.log"' "nao contou os 2 arquivos do vendor no tar"

novo_cenario "pendrive so de leitura, backup solto (sem tar), caminhos com espaco"
mkdir -p "$T/com espaco"; mv "$PC" "$T/com espaco/pc"; PC="$T/com espaco/pc"; RES="$PC/stock.bin"
rm -f "$PC/backup/pfl-backup.tar"; BK="$PC/backup"
mkdir -p "$BK/data/vendor/pfl7560-suite" "$BK/data/data/com.pfl7560.home/shared_prefs"; echo x > "$BK/data/vendor/pfl7560-suite/escolhas"
chmod -R a-w "$PEN"
padrao
afirma '[ "$RC" = 0 ]' "rc=$RC: $(grep FALHA "$T/saida.log")"
chmod -R u+w "$PEN"

novo_cenario "resgate tambem no pendrive (resgate-oficial do install.sh) mas guardado fora"
mkdir -p "$PEN/resgate-oficial"; cp "$PC/stock.bin" "$PEN/resgate-oficial/PFL7560.bin"
padrao
afirma '[ "$RC" = 0 ]' "uma copia extra no pendrive nao e motivo de recusa: rc=$RC"

novo_cenario "chamada do verificador de verdade (python3 de mentira)"
mkdir -p "$T/bin"
cat > "$T/bin/python3" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$VERIF_LOG"
echo "[verificar] $3  APROVADO"
EOF
chmod +x "$T/bin/python3"
VERIFICADOR="" PATH_EXTRA="$T/bin" padrao
afirma '[ "$RC" = 0 ]' "rc=$RC: $(grep FALHA "$T/saida.log")"
afirma '[ "$(tr "\n" " " < "$T/verif.log")" = "$ROOT/artifacts/bin-build/build_fix_bin.py --verificar $PEN/usb_update.bin $PC/stock.bin --conteudo $ROOT/artifacts/bin-build/conteudo-s5.txt " ]' "linha do verificador: $(tr '\n' ' ' < "$T/verif.log")"

echo "== item 1: usb_update.bin =="
novo_cenario "sem usb_update.bin"; rm "$PEN/usb_update.bin"; padrao; recusa "1. usb_update.bin ausente"
afirma 'grep -qF "2. verificar_bin nao rodou" "$T/saida.log" && [ ! -e "$T/verif.log" ]' "o verificador rodou sem o .bin"
novo_cenario "usb_update.bin de outra build (S4a)"; echo outro >> "$PEN/usb_update.bin"; padrao; recusa "1. usb_update.bin tem md5"
afirma '[ ! -e "$T/verif.log" ]' "o verificador rodou com o .bin errado"
novo_cenario "usb_update.bin e um link"; mv "$PEN/usb_update.bin" "$PC/s5.bin"; ln -s "$PC/s5.bin" "$PEN/usb_update.bin"; padrao; recusa "ou e um link"
novo_cenario "usb_update.bin com outro nome (Usb_Update.bin)"; mv "$PEN/usb_update.bin" "$PEN/Usb_Update.bin"; padrao; recusa "1. usb_update.bin ausente"
novo_cenario "sem o .md5 da S5"; rm "$T/s5.md5"; padrao; recusa "1. sem o md5 da S5"
novo_cenario ".md5 da S5 de outro arquivo"; sed -i 's/S5-COMPLETO/S4b-COMPLETO/' "$T/s5.md5"; padrao; recusa "1. sem o md5 da S5"

echo "== item 2: verificar_bin =="
novo_cenario "verificador reprova"; : > "$T/flag.reprova"; padrao; recusa "2. verificar_bin reprovou"
afirma 'grep -F "[FALHA] 2." "$T/saida.log" | grep -qF "record 6: payload difere"' "a falha nao mostra o problema do verificador"
novo_cenario "verificador sai 0 sem dizer APROVADO"; : > "$T/flag.mudo"; padrao; recusa "2. verificar_bin reprovou"
novo_cenario "verificador diz APROVADO mas sai 1"; : > "$T/flag.rc1"; padrao; recusa "2. verificar_bin reprovou"
novo_cenario "verificador ausente"; VERIFICADOR="$T/nao-existe" padrao; recusa "2. verificar_bin reprovou"

echo "== item 3: kit do pendrive =="
novo_cenario "sem o kit"; rm "$PEN/newlink_update.sh"; padrao; recusa "3. sem newlink_update.sh"
novo_cenario "kit anterior ao bloco 26 (sem RC_S5_MD5)"; sed -i '/^RC_S5_MD5=/d' "$PEN/newlink_update.sh"; padrao; recusa "3. o kit do pendrive e anterior ao bloco 26"
novo_cenario "kit que aceita outro .rc"; sed -i 's/^RC_S5_MD5="[0-9a-f]*"$/RC_S5_MD5="0123456789abcdef0123456789abcdef"/' "$PEN/newlink_update.sh"; padrao; recusa "3. o kit do pendrive aceita outro .rc"
novo_cenario "arquivo do kit faltando"; N1="$(sed -n '/^# KIT_LISTA_INICIO/,/^# KIT_LISTA_FIM/p' "$PEN/newlink_update.sh" | sed -n 's/^\(KIT_LISTA="\)\{0,1\}[0-9a-f]\{32\}  \(.*\)$/\2/p' | tail -1)"
afirma '[ -n "$N1" ] && [ -f "$PEN/$N1" ]' "nao achei a KIT_LISTA no kit copiado"
rm -f "$PEN/$N1"; padrao; recusa "3. arquivos do kit ausentes"
afirma 'grep -F "[FALHA] 3." "$T/saida.log" | grep -qF "$N1"' "a falha nao nomeia $N1"
novo_cenario "arquivo do kit adulterado"; echo x >> "$PEN/cor.sh"; padrao; recusa "3. arquivos do kit ausentes ou com md5 diferente"
novo_cenario "arquivo do kit trocado por link"; mv "$PEN/cor.sh" "$PC/cor.sh"; ln -s "$PC/cor.sh" "$PEN/cor.sh"; padrao; recusa "3. arquivos do kit ausentes ou com md5 diferente"
novo_cenario "KIT_LISTA apagada"; sed -i '/^# KIT_LISTA_INICIO/,/^# KIT_LISTA_FIM/d' "$PEN/newlink_update.sh"; padrao; recusa "3. sem a KIT_LISTA"
novo_cenario "DESINSTALAR-SUITE.txt no pendrive"; : > "$PEN/DESINSTALAR-SUITE.txt"; padrao; recusa "3. o pendrive tem DESINSTALAR-SUITE.txt"

echo "== item 4: backup =="
novo_cenario "sem a pasta de backup"; BK="$PC/nao-existe"; padrao; recusa "4. pasta de backup"
novo_cenario "pasta de backup vazia"; rm -f "$BK/pfl-backup.tar"; padrao; recusa "4. backup incompleto"
novo_cenario "tar sem o shared_prefs"
( cd "$T" && rm -f "$BK/pfl-backup.tar" && mkdir -p x/data/vendor/pfl7560-suite && echo a > x/data/vendor/pfl7560-suite/a && cd x && tar cf "$BK/pfl-backup.tar" data )
padrao; recusa "4. backup incompleto"
novo_cenario "tar so com arquivos vazios do vendor"
( cd "$T" && rm -f "$BK/pfl-backup.tar" && mkdir -p x/data/vendor/pfl7560-suite x/data/data/com.pfl7560.home/shared_prefs && : > x/data/vendor/pfl7560-suite/a && cd x && tar cf "$BK/pfl-backup.tar" data )
padrao; recusa "4. backup incompleto"
novo_cenario "tar de outro pacote (shared_prefs de outra home)"
( cd "$T" && rm -f "$BK/pfl-backup.tar" && mkdir -p x/data/vendor/pfl7560-suite x/data/data/com.pfl7560.homex/shared_prefs && echo a > x/data/vendor/pfl7560-suite/a && cd x && tar cf "$BK/pfl-backup.tar" data )
padrao; recusa "4. backup incompleto"
novo_cenario "tar ilegivel"; head -c 3000 /dev/urandom > "$BK/pfl-backup.tar"; padrao; recusa "4. tar de backup ilegivel"
novo_cenario "tar cortado ao meio"; head -c 1500 "$BK/pfl-backup.tar" > "$T/c.tar"; mv "$T/c.tar" "$BK/pfl-backup.tar"; padrao
afirma '[ "$RC" = 1 ] && grep -qF "[FALHA] 4." "$T/saida.log"' "tar cortado aprovado: $(grep '4\.' "$T/saida.log")"
novo_cenario "backup dentro do pendrive"; mv "$BK" "$PEN/backup"; BK="$PEN/backup"; padrao; recusa "4. o backup esta no pendrive"
novo_cenario "backup por um link que leva ao pendrive"; mv "$BK" "$PEN/backup"; ln -s "$PEN/backup" "$PC/bk"; BK="$PC/bk"; padrao; recusa "4. o backup esta no pendrive"

echo "== item 5: stock de resgate =="
novo_cenario "sem o stock"; rm "$RES"; padrao; recusa "5. stock de resgate"
afirma '[ ! -e "$T/verif.log" ]' "o verificador rodou sem o stock"
novo_cenario "stock com outro md5 (V1.0.0.1 sem USB-C)"; echo x >> "$RES"; padrao; recusa "5. stock de resgate com md5"
novo_cenario "stock so no pendrive"; mkdir -p "$PEN/resgate-oficial"; mv "$RES" "$PEN/resgate-oficial/PFL7560.bin"; RES="$PEN/resgate-oficial/PFL7560.bin"; padrao; recusa "5. o stock de resgate esta no pendrive"
novo_cenario "stock no pendrive por um caminho com .."; mkdir -p "$PEN/r"; mv "$RES" "$PEN/r/s.bin"; RES="$PC/../pen/r/s.bin"; padrao; recusa "5. o stock de resgate esta no pendrive"
novo_cenario "stock por link"; mv "$RES" "$PC/s.bin"; ln -s "$PC/s.bin" "$RES"; padrao; recusa "5. stock de resgate"
novo_cenario "stock e uma pasta"; rm "$RES"; mkdir "$RES"; padrao; recusa "5. stock de resgate"

echo "== uso e pendrive =="
novo_cenario "pendrive nao e pasta"; roda "$T/nao-existe" --backup "$BK" --resgate "$RES"
afirma '[ "$RC" = 1 ] && grep -q "PRE-VOO RECUSADO" "$T/saida.log"' "rc=$RC"
novo_cenario "tudo errado de uma vez conta as 5 falhas"
rm "$PEN/usb_update.bin" "$PEN/newlink_update.sh" "$BK/pfl-backup.tar" "$RES"; padrao
afirma '[ "$RC" = 1 ] && grep -q "PRE-VOO RECUSADO: 5 item" "$T/saida.log"' "$(tail -1 "$T/saida.log")"
for args in "" "--backup x --resgate y" "p --resgate y" "p --backup x" "p q --backup x --resgate y" "p --backup x --resgate y --forca" "p --backup"; do
  CASO="uso: '$args'"
  # shellcheck disable=SC2086
  roda $args
  afirma '[ "$RC" = 2 ] && grep -q "^uso:" "$T/saida.log"' "rc=$RC"
done

echo "== estaticos =="
CASO="estaticos"
afirma 'dash -n "$PRE"' "dash -n"
afirma '[ -x "$PRE" ] && head -1 "$PRE" | grep -qx "#!/bin/sh"' "sem +x ou shebang"
afirma '[ -z "$(LC_ALL=C grep -nP "[^\x00-\x7F]" "$PRE")" ]' "byte fora de ASCII"
afirma '! grep -vE "^[[:space:]]*#" "$PRE" | grep -qE "\b(adb|rm|mv|cp|dd|mkfs|mount|chmod|tee)\b|>[^&]*\$PEN|PFL_FALLBACK"' "o pre-voo grava, apaga ou fala com o aparelho"
afirma 'grep -q "28a2f280eee313a4b115567926b2ba4f" "$PRE"' "sem o md5 do stock V1.0.0.9"
if command -v shellcheck >/dev/null 2>&1; then
  afirma 'shellcheck -s sh "$PRE"' "shellcheck -s sh"
  afirma 'shellcheck "$ROOT/tests/test-preflight-flash.sh"' "shellcheck do harness"
else echo "  (shellcheck ausente: etapa pulada)"; fi

echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ "$FALHAS" = 0 ]
