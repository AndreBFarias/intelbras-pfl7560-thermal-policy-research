.PHONY: check check-kit check-bin check-fix

check:
	bash tests/check-stock-md5.sh

# kit universal de pendrive (blocos 5 e 7): padroes, nl_camcheck do host sobre quadros reais,
# md5 embutido e harness com stubs; a suite de verificacao (bloco 9B) no test-suite.sh;
# pendrive com firmware de resgate e preparar-pendrive.sh (bloco 9C) com lsblk/mkfs de mentira;
# pfl7560-processos.sh (bloco 9C) com uma saida de top gravada e um adb de mentira
# pfl7560-marca.sh e pfl7560-vlc.sh (bloco 14) com um adb de mentira (a particao logo e um arquivo)
# pfl7560-qualidade.sh (bloco 11) com um adb de mentira (os ajustes de imagem num arquivo)
check-kit:
	python3 -I tests/simula-padroes-kit.py
	bash tests/test-camcheck.sh
	bash tests/test-tela.sh
	bash tests/atualizar-md5-kit.sh --check
	bash tests/test-kit-pendrive.sh
	bash tests/test-suite.sh
	bash tests/test-preparar-pendrive.sh
	bash tests/test-processos.sh
	bash tests/test-pc-marca-vlc.sh
	bash tests/test-qualidade.sh

# builder do .bin (bloco 6): offset do vendor lido da tabela, em containers sinteticos; e o
# manifesto --conteudo (bloco 12) com as recusas (espaco, slot, metadados).
# Com PFL_STOCK_ANTIGO=<PFL7560.bin V1.0.0.9> e PFL_STOCK_NOVO=<PFL7560.bin V1.0.0.1> roda
# tambem com os stocks de verdade (so leitura; 1,3 GB cada, leva alguns minutos; o
# PFL_STOCK_ANTIGO roda ainda o conteudo.txt e apaga o .bin de teste).
check-bin:
	python3 tests/test-builder-bin.py

# pfl7560-fix.sh apply/revert por modelo (bloco 6, T6.3): adb de mentira, nada fala com o aparelho
check-fix:
	bash tests/test-fix-modelo.sh
