# Tarefa - Testes automáticos: Voltar cancela, fundo MeowCast entre as telas (2026-11-02)

Pedido do dono (2026-11-02): "durante os testes automatizados, caso eu tenha clicado sem querer [e] iniciar eles. O
botão sair ou voltar deveria finalizar ele sem dar o resultado e voltar pra tela home. [...] Na transição entre eles
ele sempre mostra o background da home. Coloca entre as transições de telas o background do MeowCast".

## O que se mediu (código da árvore `integracao`)

- A home pede a suíte pelo `suite-pedido.sh`, que lança `suite.sh pedido` destacado (`setsid`, linha 266).
- Cada tela de teste é uma imagem aberta na galeria do sistema: `mostrar_arq` (`suite.sh:276`) faz `am force-stop`
  da galeria e `am start -a VIEW ... -t image/png` de novo. Entre o `force-stop` e a imagem nova aparece o que está
  atrás: a home.
- Voltar no controle fecha a galeria, mas a suíte não sabe: segue as etapas (cor, geometria, temperatura, rampa,
  resumo) e abre a próxima imagem por cima, até o resumo. Não existe pedido de cancelar.

## Cura na origem

1. **Visor próprio no app** (`com.pfl7560.verificar`): uma activity que mostra a imagem de teste sobre o fundo
   MeowCast e fica aberta durante a suíte inteira; a imagem seguinte troca dentro dela (sem fechar e abrir), então a
   home não aparece entre as telas. A suíte deixa de usar a galeria.
2. **Voltar/Sair no visor = cancelar:** o visor grava um pedido de cancelar que a suíte lê entre etapas e dentro das
   esperas; a suíte para sem gerar resumo nem gravar resultado no diário (registra só "cancelado pelo controle" no
   log) e volta à home.
3. Se o visor não abrir (app ausente), a suíte cai na galeria como hoje (fallback), com aviso no log.

## Como se prova (no PC)

- Teste do kit: suíte simulada recebe o pedido de cancelar no meio e termina sem resumo, sem linha no diário, com
  `ir_para_inicio`.
- Teste do app (modelo puro): Voltar no visor grava o pedido; trocar a imagem não fecha a activity.
- `tests/test-*.sh`, `make check`, `shellcheck -s sh` sem falha nova; md5 do kit atualizados.

## Decisões do dono (AskUserQuestion, 2026-11-02)

- **Entra antes do flash**, vai na S5 (um flash só). Começa depois que o workflow final terminar (mesmos arquivos).
- **Fundo:** a arte do logo MeowCast no centro ("Meow" `#9D7AD0`, "Cast" `#50FA7B`, fundo `#120B1A`), a mesma da
  abertura (`artifacts/tema/marca/logo.jpg` ou gerada pelo `gerar-marca.py`).

## Agentes (2)

| agente | modelo | o quê |
|---|---|---|
| T1 | Opus, high | visor + cancelar (app e kit), com testes |
| T2 | Opus, high | confere, corrige e regressão |
