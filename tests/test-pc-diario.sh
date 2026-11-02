#!/usr/bin/env bash
# Teste do diario do projetor, lado do PC (bloco 24): pfl7560-diario.sh, as unidades systemd --user e o
# ./install.sh --diario. Um "adb" de mentira num BIN temporario; nenhum teste fala com o projetor, nada
# e ligado no systemd (HOME aponta para uma pasta temporaria e um systemctl de mentira prova que nao e chamado).
# shellcheck disable=SC2016,SC2034
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export LC_ALL=C
SCRIPT="$ROOT/pfl7560-diario.sh"
FALHAS=0; TESTES=0; CASO="-"
ok(){ TESTES=$((TESTES+1)); }
falha(){ TESTES=$((TESTES+1)); FALHAS=$((FALHAS+1)); echo "  FALHA $CASO: $*"; }
afirma(){ if eval "$1"; then ok; else falha "$2  (cond: $1)"; fi; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"; mkdir -p "$BIN"

cat > "$BIN/adb" <<'EOA'
#!/bin/sh
printf '%s\n' "adb $*" >> "$T/adb.log"
if [ "$1" = "connect" ]; then [ -f "$T/fora" ] && { echo "failed to connect"; exit 1; }; echo "connected to $2"; exit 0; fi
[ "$1" = "-s" ] && shift 2
case "$1" in
  root) [ -f "$T/sem-root" ] || : > "$T/root-ok"; exit 0 ;;
  pull) [ -f "$T/aparelho/${2##*/}" ] || { echo "remote object '$2' does not exist"; exit 1; }
        cp "$T/aparelho/${2##*/}" "$3"; exit 0 ;;
  shell) shift; cmd="$*" ;;
  *) exit 1 ;;
esac
[ -f "$T/fora" ] && exit 1
case "$cmd" in
  id) if [ -f "$T/root-ok" ] || [ -f "$T/ja-root" ]; then echo "uid=0(root) gid=0(root)"; else echo "uid=2000(shell) gid=2000(shell)"; fi ;;
  "getprop ro.product.model") echo "${MODELO:-PFL7560}" ;;
  *"/proc/uptime"*) printf '%s\r\n%s\r\n' "$(cat "$T/up")" "$(cat "$T/boot_id")" ;;
  "sh /data/vendor/pfl7560-suite/suite-diario.sh enviado "*) printf '%s\n' "${cmd##* }" >> "$T/enviado.log"; [ -f "$T/enviado-falha" ] && exit 1 ;;
  *) exit 1 ;;
esac
exit 0
EOA
chmod +x "$BIN/adb"
printf '#!/bin/sh\necho "systemctl $*" >> "$T/systemctl.log"\n' > "$BIN/systemctl"; chmod +x "$BIN/systemctl"

# o aparelho no instante AGORA: boot_id, uptime e os dois arquivos
AGORA=1793600000       # 2026-11-02T06:13:20Z
cenario(){
  CASO="$1"; T="$TMP/c$((TESTES))-$RANDOM"; rm -rf "$T"; mkdir -p "$T/aparelho" "$T/dest"
  export T; : > "$T/adb.log"
  echo 600 > "$T/up"; echo "a1b2c3d4-0000-4000-8000-000000000001" > "$T/boot_id"
  : > "$T/ja-root"
}
# linha do aparelho: boot, up, dt (o relogio do aparelho, de proposito errado), extras
lin(){ printf 'up=%s dt=%s boot=%s env=45 placa=41 luz=80 load=0.5 vent=padrao led=padrao wifi=up eth=down mem=300000 ch=1101101111 ev=%s\n' "$2" "$3" "$1" "${4:--}"; }
roda(){
  env T="$T" PATH="$BIN:$PATH" TZ=UTC PFL_TESTE=1 PFL_AGORA="$AGORA" PFL_IP="${IP_TESTE-10.0.0.9}" PFL_DIARIO_DESTINO="$T/dest" \
      ${MODELO:+MODELO="$MODELO"} bash "$SCRIPT" "$@" > "$T/out" 2> "$T/err"; RC=$?
}
tudo(){ cat "$T"/dest/diario-????-??.txt 2>/dev/null; }
n_linhas(){ tudo | grep -c .; }

c_recusas(){
  cenario "recusas: sem IP, modelo errado, aparelho fora, sem root"
  IP_TESTE="" roda
  afirma '[ "$RC" = 2 ] && grep -q PFL_IP "$T/err" && [ ! -s "$T/adb.log" ]' "sem PFL_IP: rc=$RC"
  MODELO=OUTRO roda
  afirma '[ "$RC" = 2 ] && [ "$(n_linhas)" = 0 ] && ! grep -q pull "$T/adb.log"' "modelo errado: rc=$RC"
  unset MODELO
  : > "$T/fora"; roda
  afirma '[ "$RC" = 0 ] && grep -q "fora do ar" "$T/out" && [ "$(n_linhas)" = 0 ]' "aparelho fora: rc=$RC $(cat "$T/out")"
  rm -f "$T/fora" "$T/ja-root"; : > "$T/sem-root"; roda
  afirma '[ "$RC" = 1 ] && grep -q "sem root" "$T/err" && ! grep -q pull "$T/adb.log"' "sem root: rc=$RC"
  rm -f "$T/sem-root"
  # o adb root resolve
  roda
  afirma '[ "$RC" = 0 ] && grep -q "root" "$T/adb.log"' "o adb root nao foi tentado"
  roda --lixo
  afirma '[ "$RC" = 2 ]' "argumento solto aceito"
  roda --help
  afirma '[ "$RC" = 0 ] && grep -q "pfl7560-diario.sh" "$T/out"' "ajuda"
  # aparelho sem diario ainda
  cenario "sem arquivos de diario no aparelho"
  roda
  afirma '[ "$RC" = 0 ] && grep -q "ainda nao tem diario" "$T/out" && [ "$(n_linhas)" = 0 ] && [ ! -e "$T/enviado.log" ]' "sem diario: rc=$RC"
}

c_hora(){
  cenario "hora: o relogio do aparelho esta errado e a hora sai do uptime + inicio do boot"
  B=a1b2c3d4
  { lin $B 540 100; lin $B 600 160; } > "$T/aparelho/diario-0.txt"   # dt do aparelho: 1970 (errado)
  roda
  # inicio do boot = AGORA - 600; a linha up=540 e AGORA-60 = 06:12:20 ; up=600 e AGORA = 06:13:20
  afirma '[ "$RC" = 0 ] && [ "$(n_linhas)" = 2 ]' "gravou $(n_linhas) linhas: $(cat "$T/err")"
  afirma 'grep -q "^2026-11-02T06:12:20 pc up=540 " "$T/dest/diario-2026-11.txt" && grep -q "^2026-11-02T06:13:20 pc up=600 " "$T/dest/diario-2026-11.txt"' "hora corrigida errada: $(tudo | cut -c1-60)"
  afirma '[ "$(cat "$T/dest/.boots")" = "a1b2c3d4 $((AGORA - 600))" ]' ".boots: $(cat "$T/dest/.boots")"
  afirma '[ "$(cat "$T/enviado.log")" = "$(date +%Y-%m-%dT%H:%M:%S)" ] || [ "$(wc -l < "$T/enviado.log")" = 1 ]' "o aparelho nao foi avisado do envio"
  afirma 'grep -qE "^sh|suite-diario.sh enviado [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}$" "$T/adb.log"' "formato do aviso de envio"
  # a mesma busca de novo: nada repetido
  roda
  afirma '[ "$(n_linhas)" = 2 ] && grep -q " 0 linha(s) nova(s)" "$T/out"' "repetiu linhas: $(n_linhas) / $(cat "$T/out")"
  # linhas novas: so elas entram, na ordem certa
  echo 700 > "$T/up"
  { lin $B 660 220; lin $B 700 260; } >> "$T/aparelho/diario-0.txt"
  AGORA_ANTES=$AGORA; AGORA=$((AGORA + 100)); roda; AGORA=$AGORA_ANTES
  afirma '[ "$(n_linhas)" = 4 ]' "entraram $(n_linhas) linhas"
  afirma '[ "$(tudo | cut -d" " -f3 | tr "\n" " ")" = "up=540 up=600 up=660 up=700 " ]' "ordem: $(tudo | cut -d" " -f3 | tr "\n" " ")"
  afirma '[ "$(cat "$T/dest/.boots")" = "a1b2c3d4 $((AGORA - 600))" ]' "o inicio do boot mudou com a nova busca: $(cat "$T/dest/.boots")"
  limpa
}

limpa(){ :; }

c_boots(){
  cenario "boots: dois arquivos, reinicio no meio, linha de boot ja visto chega depois"
  A=a1b2c3d4; Bn=b2c3d4e5
  { lin $A 540 5; lin $A 600 65; } > "$T/aparelho/diario-0.txt"
  roda
  afirma '[ "$(n_linhas)" = 2 ]' "primeira busca: $(n_linhas)"
  # o aparelho reiniciou: boot novo, uptime 120; o arquivo 0 ainda tem a linha 610 do boot A que o PC nunca viu
  echo 120 > "$T/up"; echo "b2c3d4e5-0000-4000-8000-000000000002" > "$T/boot_id"
  { lin $A 540 5; lin $A 600 65; lin $A 610 75; } > "$T/aparelho/diario-0.txt"
  { lin $Bn 60 30; lin $Bn 120 90 "eth0:ligar:ok"; } > "$T/aparelho/diario-1.txt"
  AGORA_ANTES=$AGORA; AGORA=$((AGORA + 400)); roda; AGORA=$AGORA_ANTES
  afirma '[ "$(n_linhas)" = 5 ]' "total depois do reinicio: $(n_linhas)"
  afirma 'grep -q "^$(date -u -d @$((AGORA - 600 + 610)) +%Y-%m-%dT%H:%M:%S) pc up=610 " "$T/dest/diario-2026-11.txt"' "a linha 610 do boot A nao foi datada pelo inicio dele: $(tudo | grep up=610 | cut -c1-50)"
  afirma 'grep -q "pc up=120 .*boot=b2c3d4e5.*ev=eth0:ligar:ok$" "$T/dest/diario-2026-11.txt"' "linha do boot novo ou o evento sumiu"
  afirma '[ "$(wc -l < "$T/dest/.boots")" = 2 ]' ".boots: $(tr "\n" ";" < "$T/dest/.boots")"
  afirma '[ "$(tudo | grep -c "boot=a1b2c3d4")" = 3 ]' "o boot A ganhou linhas repetidas"
}

c_sem_hora(){
  cenario "sem hora: boot nunca visto ao vivo usa o relogio do aparelho so se parece certo"
  # boot de agora: z9, o aparelho trouxe tambem linhas do boot c1 (nunca visto) e d2 (nunca visto, relogio zerado)
  echo "e9e9e9e9-0000-4000-8000-000000000003" > "$T/boot_id"
  { lin c1c1c1c1 30 1793500000; lin c1c1c1c1 90 1793500060; lin d2d2d2d2 10 55; lin e9e9e9e9 600 1793600000; } > "$T/aparelho/diario-0.txt"
  roda
  afirma 'grep -q "^2026-11-01T02:26:40 ap up=30 " "$T/dest/diario-2026-11.txt" && grep -q "^2026-11-01T02:27:40 ap up=90 " "$T/dest/diario-2026-11.txt"' "relogio plausivel do aparelho: $(tudo | cut -c1-40 | tr '\n' ';')"
  afirma 'grep -q "^0000-00-00T00:00:00 sem up=10 .*boot=d2d2d2d2" "$T/dest/diario-0000-00.txt"' "linha sem hora: $(cut -c1-50 "$T/dest/diario-0000-00.txt" 2>/dev/null)"
  roda
  afirma '[ "$(wc -l < "$T/dest/diario-0000-00.txt")" = 1 ]' "a linha sem hora se repetiu na segunda busca: $(wc -l < "$T/dest/diario-0000-00.txt")"
  afirma '[ "$(n_linhas)" = 4 ]' "total de linhas: $(n_linhas): $(tudo | cut -c1-45 | tr "\n" ";")"
}

c_lixo(){
  cenario "lixo: linha cortada, torta ou estranha fica de fora"
  B=a1b2c3d4
  {
    lin $B 540 1
    printf 'up=570 dt=2 boot=%s env=45 placa=41 luz=80 load=0.5 vent=padrao led=padrao wifi=up eth=down mem=300000 ch=1101101111 ev=\n' $B | head -c 60   # cortada, sem \n
    echo
    echo 'isto nao e uma linha do diario'
    echo 'up=1 dt=2 boot=a1b2c3d4 ev=$(rm -rf /)'
    echo 'up=3 dt=4 boot=ZZZZ ev=-'
    lin $B 600 2
  } > "$T/aparelho/diario-0.txt"
  printf 'up=630 dt=3 boot=%s env=45 placa=41 luz=80 load=0.5 vent=padrao led=padrao wifi=up eth=down mem=300000 ch=1101101111 ev=-' $B > "$T/aparelho/diario-1.txt"   # sem \n final
  roda
  afirma '[ "$RC" = 0 ] && [ "$(n_linhas)" = 3 ]' "linhas aceitas: $(n_linhas): $(tudo | cut -c1-40 | tr '\n' ';')"
  afirma '! tudo | grep -q "rm -rf"' "linha com comando entrou"
  # tudo torto: sem nenhuma linha boa
  cenario "lixo: arquivo so com lixo"
  echo "lixo" > "$T/aparelho/diario-0.txt"
  roda
  afirma '[ "$RC" = 1 ] && [ "$(n_linhas)" = 0 ] && [ ! -e "$T/enviado.log" ]' "so lixo: rc=$RC"
}

c_envio_falha(){
  cenario "envio: nao conseguir avisar o aparelho nao perde as linhas"
  lin a1b2c3d4 600 1 > "$T/aparelho/diario-0.txt"
  : > "$T/enviado-falha"
  roda
  afirma '[ "$RC" = 0 ] && [ "$(n_linhas)" = 1 ] && grep -q "nao consegui avisar" "$T/err"' "falha do aviso: rc=$RC"
}

c_unidades(){
  CASO="unidades: copia sem ligar nada"
  local H="$TMP/home-u" saida
  mkdir -p "$H"; : > "$TMP/systemctl.log"
  saida=$(env HOME="$H" XDG_CONFIG_HOME="" T="$TMP" PATH="$BIN:$PATH" bash "$ROOT/install.sh" --diario 2>&1); local rc=$?
  afirma '[ "$rc" = 0 ]' "install.sh --diario saiu com $rc: $saida"
  local sv="$H/.config/systemd/user/pfl7560-diario.service" tm="$H/.config/systemd/user/pfl7560-diario.timer"
  afirma '[ -f "$sv" ] && [ -f "$tm" ]' "unidades nao copiadas"
  afirma '! grep -q "@AQUI@" "$sv" "$tm"' "sobrou @AQUI@"
  afirma 'grep -q "^ExecStart=$ROOT/pfl7560-diario.sh$" "$sv" && grep -q "^WorkingDirectory=$ROOT$" "$sv"' "caminho do repositorio nao entrou"
  afirma 'grep -q "^Type=oneshot$" "$sv" && grep -q "^EnvironmentFile=-%h/.config/pfl7560/diario.env$" "$sv"' "service sem oneshot ou sem EnvironmentFile opcional"
  afirma 'grep -q "^OnBootSec=2min$" "$tm" && grep -q "^OnUnitActiveSec=2min$" "$tm" && grep -q "^WantedBy=timers.target$" "$tm"' "timer fora do contrato de 2 min"
  afirma '[ ! -s "$TMP/systemctl.log" ] && ! printf "%s" "$saida" | grep -q "^systemctl" ' "o instalador chamou o systemctl"
  afirma 'printf "%s" "$saida" | grep -q "Nada foi ligado" && printf "%s" "$saida" | grep -q "systemctl --user enable --now pfl7560-diario.timer"' "faltou a instrucao para ligar"
  afirma '[ -z "$(find "$H" -name "*.novo")" ] && [ ! -e "$H/.config/pfl7560" ]' "o instalador deixou sobra ou criou o diario.env"
  afirma '! grep -vE "^[[:space:]]*#|^[[:space:]]*(echo|printf|cat)|DIARIOFIM|^  [0-9]\.|^Para |^Os arquivos|^Nada" "$ROOT/install.sh" | grep -qE "systemctl[^|]*(enable|start|daemon-reload)"' "install.sh executa systemctl enable/start"
  # de novo: mesmo resultado, sem erro
  saida=$(env HOME="$H" XDG_CONFIG_HOME="" PATH="$BIN:$PATH" bash "$ROOT/install.sh" --diario 2>&1)
  afirma '[ "$?" = 0 ]' "segunda copia falhou"
  # o XDG_CONFIG_HOME manda
  local X="$TMP/xdg"
  env HOME="$H" XDG_CONFIG_HOME="$X" PATH="$BIN:$PATH" bash "$ROOT/install.sh" --diario >/dev/null 2>&1
  afirma '[ -f "$X/systemd/user/pfl7560-diario.timer" ]' "XDG_CONFIG_HOME ignorado"
  # nao mistura com os outros modos
  env HOME="$H" PATH="$BIN:$PATH" bash "$ROOT/install.sh" --diario --check >/dev/null 2>&1
  afirma '[ "$?" != 0 ]' "--diario --check aceito"
  env HOME="$H" PATH="$BIN:$PATH" bash "$ROOT/install.sh" --diario --pendrive "$TMP" >/dev/null 2>&1
  afirma '[ "$?" != 0 ]' "--diario --pendrive aceito"
}

c_estaticos(){
  CASO="estaticos"
  afirma 'bash -n "$SCRIPT" && bash -n "$ROOT/install.sh"' "sintaxe"
  if command -v shellcheck >/dev/null 2>&1; then
    afirma 'shellcheck "$SCRIPT" "$ROOT/tests/test-pc-diario.sh"' "shellcheck"
  else echo "  (shellcheck ausente: etapa pulada)"; fi
  afirma '[ -x "$SCRIPT" ]' "pfl7560-diario.sh nao e executavel"
  afirma '! grep -vE "^[[:space:]]*#" "$SCRIPT" | grep -qwE "gtt|stp|logcat|hidebug"' "o script do PC cita gtt/stp/logcat/hidebug"
  afirma '! grep -vE "^[[:space:]]*#" "$SCRIPT" | grep -qE "adb[^|]* (reboot|install|uninstall|push|remount)"' "o script do PC escreve no aparelho alem do aviso de envio"
  afirma 'grep -q "^logs-projetor/$" "$ROOT/.gitignore"' "logs-projetor/ fora do .gitignore"
  afirma 'grep -q "timeout 60 \"\$ADB\" -s \"\$DEV\" pull" "$SCRIPT" && grep -q "ro.product.model" "$SCRIPT"' "sem timeout no pull ou sem a trava de modelo"
  afirma '[ -z "$(LC_ALL=C grep -nP "[^\x00-\x7F]" "$SCRIPT" "$ROOT/systemd/pfl7560-diario.service" "$ROOT/systemd/pfl7560-diario.timer")" ]' "byte fora de ASCII"
}

echo "== estaticos =="; c_estaticos
echo "== cenarios =="
for c in c_recusas c_hora c_boots c_sem_hora c_lixo c_envio_falha c_unidades; do echo "  $c"; "$c"; done
echo "----"
echo "$TESTES verificacoes, $FALHAS falha(s)"
[ "$FALHAS" = 0 ]
