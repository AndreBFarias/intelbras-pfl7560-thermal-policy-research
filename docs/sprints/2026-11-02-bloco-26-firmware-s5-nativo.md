# Bloco 26 - Firmware S5: tudo nativo no vendor (2026-11-02)

Pedido do dono (2026-11-02): "vamos criar o novo firmware [...] que vai conter tudo de forma nativa". Decisão na
mesma hora: o kit dos blocos 23 a 25 vai para o aparelho pelo pendrive hoje, e a S5 é montada **no PC, em paralelo,
sem gravar nada no aparelho**. A gravação é outra decisão do dono, depois da S4a provada (doc 47 §11).

## O que já existe (medido)

- `artifacts/bin-build/build_fix_bin.py` com `--realocar --conteudo` (doc 47 §10): grava no vendor pelo `debugfs`
  com modo, dono e rótulo SELinux carimbados, refaz o record 14 e passa pelo `verificar_bin`.
- `artifacts/bin-build/conteudo.txt` (S4b): `.rc` da suíte, app, home e as 20 sobreposições.
- Doc 47 §3, opção (b): a suíte também no `/vendor`, copiada para o `/data` no 1º boot. Na época ela perdeu para a
  (a) por causa da folga do slot; o `--realocar` (bloco 21) tirou esse limite.
- Stock: `firmware/Software PFL7560.zip` (sha256 `08d37bbb…`, restaurado em 2026-11-02 na árvore principal;
  `PFL7560.bin` dentro, md5 `28a2f280…`). **Só o V1.0.0.9 com USB-C**; nunca o `Firmware PFL7560.zip`.

## O que a S5 leva a mais que a S4b

1. A suíte inteira, como o kit instala hoje: `suite.sh`, `suite-boot.sh`, `suite-pedido.sh`, `suite-curvas.sh`,
   `suite-chaves.sh`, `suite-diario.sh`, `suite-logo.sh`, `cor.sh`, `lvdsctl`, `nl_camcheck`, `nl_tela`, `nl_logo`,
   `debloat-aprovados.txt`, `kit/*.png` e o que mais a `SUITE_LISTA`/`KIT_LISTA` pedir, numa pasta do `/vendor`
   (ex.: `/vendor/etc/pfl7560-suite/`), com os mesmos md5.
2. O `.rc` que funciona com o `/data` vazio depois da gravação: no 1º boot copia a suíte do `/vendor` para
   `/data/vendor/pfl7560-suite/` (conferida por md5, pasta só do root) e segue o boot normal; a regra de versão
   resolve o conflito "a cópia do `/vendor` é mais velha que a que o kit pelo pendrive instalou depois" (doc 47 §3).
3. A marca (bootanimation) e as fontes, se o kit as põe no `/vendor`/`/system` e couberem no mesmo slot.
4. Os padrões de instalação das chaves (bloco 24) e o logo automático ligado valem no 1º boot sem pendrive.

**Fica fora:** o estado em `/data` (escolhas, diário, backups do logo), o JEIDA de cada painel, o debloat
(continua pelas chaves, reversível). **Só pesquisar e relatar, sem fazer:** se o container tem um record da
partição `logo` e se a arte reta poderia ir nele.

## Como se prova (tudo no PC)

- `build_fix_bin.py` gera `firmware/PFL7560-S5-COMPLETO-NAO-GRADUADO.bin` reprodutível (duas gerações, mesmo
  md5), passa no `verificar_bin` e no `--verificar` com o manifesto novo; `e2fsck -fn` limpo; o md5 vai em
  `firmware/PFL7560-S5-COMPLETO-NAO-GRADUADO.bin.md5`.
- Teste novo (ou estendido) que monta o vendor da S5 em simulação e roda o 1º boot com o `/data` vazio: a suíte é
  copiada, conferida e sobe; com um kit mais novo no `/data`, a do `/vendor` não sobrescreve.
- Todo o `tests/test-*.sh` e `make check` sem falha nova; `shellcheck -s sh` limpo no kit.
- Doc 47 ganha a seção da S5; `firmware/README.md` ganha a linha da S5.

## Regras

- **Nada no aparelho**, nem leitura (o dono usa o projetor e o kit está sendo instalado agora). Nunca `gtt`/`stp`.
- Nenhum `.bin` sai do PC; nada de `--com-firmware` no pendrive.
- Temporários na árvore do bloco (pasta ignorada) ou no scratchpad, nunca soltos no `/tmp`.
- Um commit por tarefa, sem `--no-verify`. `.bin` e zips não entram no git (só o `.md5`).

## Agentes (2)

| agente | modelo | o quê |
|---|---|---|
| S1 | Opus, high | implementa e gera a S5 |
| S2 | Opus, high | confere imagem, metadados, SELinux, 1º boot simulado e regressão; corrige |

## Estado

- [x] S1
- [x] S2 (conferiu a imagem e o 1º boot simulado; corrigiu o teste do `EXEC_LISTA`)
- [ ] o dono decide quando gravar (depois da S4a provada)
