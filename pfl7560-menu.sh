#!/usr/bin/env bash
# ============================================================================
#  Menu amigável da correção PFL7560 (feito para duplo-clique).
#  Chama o pfl7560-fix.sh que está na mesma pasta.
# ============================================================================
HERE="$(cd "$(dirname "$0")" && pwd)"
FIX="$HERE/pfl7560-fix.sh"
[ -x "$FIX" ] || { echo "ERRO: não achei o pfl7560-fix.sh ao lado deste menu."; read -p "Enter..."; exit 1; }

clear
cat <<'BANNER'
 ============================================================
      CORREÇÃO PFL7560 - Intelbras
      (ventilação + brilho + wi-fi + xiri)
 ============================================================
  Este menu fala com o projetor pela rede (Wi-Fi / adb).
  Deixe o projetor LIGADO e no mesmo Wi-Fi do PC.

  Obs: seu projetor JÁ está corrigido (a correção vive na
  memória dele e se auto-aplica em todo boot). Este menu
  serve para CONFERIR, REAPLICAR ou REVERTER quando quiser.
 ============================================================
BANNER
echo
echo "   1) VER o estado do projetor   (não muda nada)"
echo "   2) APLICAR / reaplicar a correção"
echo "   3) REVERTER para o firmware de fábrica"
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
  *) echo " opção inválida." ;;
esac
echo "------------------------------------------------------------"
echo
read -p " Pronto. Pressione Enter para fechar..."
