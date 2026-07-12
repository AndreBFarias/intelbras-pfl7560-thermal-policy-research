#!/usr/bin/env bash
# ============================================================================
#  Menu amigavel da correcao PFL7560 (duplo-clique / terminal).
#  Chama o pfl7560-fix.sh que esta na mesma pasta.
# ============================================================================
HERE="$(cd "$(dirname "$0")" && pwd)"
FIX="$HERE/pfl7560-fix.sh"
LCD="$HERE/pfl7560-lcd-color.sh"
[ -x "$FIX" ] || { echo "ERRO: nao achei o pfl7560-fix.sh ao lado deste menu."; read -r -p "Enter..."; exit 1; }

clear
cat <<'BANNER'
 ============================================================
      CORRECAO PFL7560 - Intelbras
      (ventilacao + brilho + wi-fi + xiri)
 ============================================================
  Este menu fala com o projetor pela rede (Wi-Fi / adb).
  Deixe o projetor LIGADO e no mesmo Wi-Fi do PC.

  Se a busca automatica nao achar o aparelho, rode no terminal:
    PFL_IP=<ip-do-projetor> ./pfl7560-menu.sh
  O IP aparece em: Configuracoes -> Wi-Fi -> (rede conectada).
 ============================================================
BANNER
echo
echo "   1) VER o estado do projetor   (nao muda nada)"
echo "   2) APLICAR / reaplicar a correcao termica"
echo "   3) REVERTER para o firmware de fabrica"
echo "   4) CORRIGIR COR (so se voce TROCOU o painel LCD)"
echo "   5) Sair"
echo
read -r -p " Escolha [1-5]: " op
echo "------------------------------------------------------------"
case "$op" in
  1) "$FIX" status ;;
  2) "$FIX" apply ;;
  3) read -r -p " Tem CERTEZA que quer voltar ao stock? [s/N]: " c
     if [ "$c" = "s" ] || [ "$c" = "S" ]; then "$FIX" revert; else echo " cancelado."; fi ;;
  4) if [ ! -x "$LCD" ]; then echo " ERRO: nao achei o pfl7560-lcd-color.sh."; else
       echo " Correcao de cor pos-troca de painel (RX058B -4300 -> -0600)."
       echo "   a) VER o formato LVDS atual (nao muda nada)"
       echo "   b) WIZARD guiado (faz backup + testa VESA/JEIDA na tela)"
       echo "   c) Aplicar JEIDA direto (corrige o -0600)"
       echo "   d) Voltar para VESA (padrao de fabrica -4300)"
       read -r -p " Escolha [a-d]: " lop
       case "$lop" in
         a|A) "$LCD" status ;;
         b|B) "$LCD" wizard ;;
         c|C) "$LCD" jeida ;;
         d|D) "$LCD" vesa ;;
         *)   echo " opcao invalida." ;;
       esac
     fi ;;
  5) exit 0 ;;
  *) echo " opcao invalida." ;;
esac
echo "------------------------------------------------------------"
echo
read -r -p " Pronto. Pressione Enter para fechar..."
