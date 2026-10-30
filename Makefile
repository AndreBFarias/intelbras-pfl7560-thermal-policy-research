.PHONY: check check-kit

check:
	bash tests/check-stock-md5.sh

# kit universal de pendrive (bloco 5): padroes, md5 embutido e harness com stubs
check-kit:
	python3 -I tests/simula-padroes-kit.py
	bash tests/atualizar-md5-kit.sh --check
	bash tests/test-kit-pendrive.sh
