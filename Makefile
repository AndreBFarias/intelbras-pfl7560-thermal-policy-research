.PHONY: check check-kit check-bin check-fix

check:
	bash tests/check-stock-md5.sh

# kit universal de pendrive (blocos 5 e 7): padroes, nl_camcheck do host sobre quadros reais,
# md5 embutido e harness com stubs
check-kit:
	python3 -I tests/simula-padroes-kit.py
	bash tests/test-camcheck.sh
	bash tests/atualizar-md5-kit.sh --check
	bash tests/test-kit-pendrive.sh

# builder do .bin (bloco 6): offset do vendor lido da tabela, em containers sinteticos.
# Com PFL_STOCK_ANTIGO=<PFL7560.bin V1.0.0.9> e PFL_STOCK_NOVO=<PFL7560.bin V1.0.0.1> roda
# tambem com os stocks de verdade (so leitura; 1,3 GB cada, leva alguns minutos).
check-bin:
	python3 tests/test-builder-bin.py

# pfl7560-fix.sh apply/revert por modelo (bloco 6, T6.3): adb de mentira, nada fala com o aparelho
check-fix:
	bash tests/test-fix-modelo.sh
