# Tarefa - "Desligar no descanso" na home (2026-11-02)

Pedido do dono: "E a flag de desligar [...] a partir de x minutos no modo de tela de descanso?" Decisão pelo
AskUserQuestion: **linha em Serviços com switch + tempo**, tempos **10, 20, 30, 60 min** (padrão 10, o de hoje).

## O que existe (bloco 23)

- `suite-curvas.sh`: `STANDBY_AVISO=600`, `STANDBY_TOTAL=660` fixos; o vigia começa com `descanso-inicio`, mostra o
  aviso de 60 s (`vendor.pfl7560.standby`) e manda `KEYCODE_POWER` só com `mWakefulness=Dreaming`; `descanso-fim`
  cancela.
- O app `com.pfl7560.verificar/.Descanso` lê `vendor.pfl7560.standby` para o aviso.

## Cura

- Uma escolha persistente no `/data/vendor` (como as outras da home): ligado/desligado + minutos ∈ {10,20,30,60};
  padrão ligado, 10. O vigia lê a escolha ao começar (`STANDBY_AVISO = min*60`, total = aviso + 60); desligado, não
  começa.
- Pedido novo da home pelo canal que já existe (`suite-pedido.sh`), validado (lista fechada de valores), com teste.
- Home: linha "Desligar no descanso" na aba Serviços (switch = ligado funciona), com o tempo mostrado à direita;
  OK alterna, esquerda/direita na linha em foco troca o tempo (a troca de aba com a seta vale nas outras linhas;
  resolver o conflito de forma previsível e documentar no rodapé de teclas). Lida de volta como as outras.

## Prova

- Testes do kit (escolha, validação, vigia com tempos de teste) e de modelo da home; todos os `tests/test-*.sh`,
  `make check`, `shellcheck`.

Entra no workflow final (antes da regressão), para ir na S5.
