.PHONY: check check-kit check-bin check-fix

check:
	bash tests/check-stock-md5.sh

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

check-bin:
	python3 tests/test-builder-bin.py

check-fix:
	bash tests/test-fix-modelo.sh
