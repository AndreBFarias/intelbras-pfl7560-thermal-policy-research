#!/usr/bin/env bash
# ============================================================================
#  Menu amigavel da correcao PFL7560 (feito para duplo-clique).
#  Chama o pfl7560-fix.sh que esta na mesma pasta.
# ============================================================================
HERE="$(cd "$(dirname "$0")" && pwd)"
FIX="$HERE/pfl7560-fix.sh"
[ -x "$FIX" ] || { echo "ERRO: nao achei o pfl7560-fix.sh ao lado deste menu."; read -p "Enter..."; exit 1; }

clear
cat <<'BANNER'
 ============================================================
      CORRECAO PFL7560 - Intelbras
      (ventilacao + brilho + wi-fi + xiri)
 ============================================================
  Este menu fala com o projetor pela rede (Wi-Fi / adb).
  Deixe o projetor LIGADO e no mesmo Wi-Fi do PC.

  Obs: seu projetor JA esta corrigido (a correcao vive na
  memoria dele e se auto-aplica em todo boot). Este menu
  serve para CONFERIR, REAPLICAR ou REVERTER quando quiser.
 ============================================================
BANNER
echo
echo "   1) VER o estado do projetor   (nao muda nada)"
echo "   2) APLICAR / reaplicar a correcao"
echo "   3) REVERTER para o firmware de fabrica"
echo "   4) Sair"
echo
read -p " Escolha [1-4]: " op
echo "------------------------------------------------------------"
case "$op" in
  1) "$FIX" status ;;
  2) "$FIX" apply ;;
  3) read -p " Tem CERTEZA que quer voltar ao stock? [s/N]: " c
     if [ "$c" = "s" ] || [ "$c" = "S" ]; then "$FIX" revert; else echo " cancelado."; fi ;;
  4) exit 0 ;;
  *) echo " opcao invalida." ;;
esac
echo "------------------------------------------------------------"
echo
read -p " Pronto. Pressione Enter para fechar..."
