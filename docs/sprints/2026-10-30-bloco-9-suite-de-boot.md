# Bloco 9 - suíte de boot: verificação automática ao voltar da tomada e ao inserir o pendrive (2026-10-30)

Pedido do dono (2026-10-30, depois do [bloco 8](2026-10-30-bloco-8-camera-robusta.md)): ao ligar depois de ficar
sem energia, o projetor roda a suíte de correção (câmera, cor, ângulo, foco, imagem, temperatura) e termina
numa tela de resumo em tela cheia, "bonita, agradável, organizada e limpa", estilo MangoHUD. O mesmo ao
inserir o pendrive. Quer pronto hoje.

Telas propostas (canvas): https://claude.ai/artifact/5Tn6dpqHX2d9kiFVMQDpKT
Escolhas do dono (salvas): https://claude.ai/artifact/YPCCxNyvVYVhKZZo4xvjMz (`escolhas/atual`, 22:40Z)

## Decisões do dono

| Item | Decisão |
|---|---|
| Etapas | as 5: cor (pronta), ângulo e foco (nova), nitidez (nova), temperatura só leitura (nova), teste ativo da rampa (pronto, ~65 s, escurece a imagem) |
| Resumo | tela cheia, 20 s, os 19 itens (cor: formato, câmera, painel; imagem: resolução, ângulo, foco, nitidez, 4 pontos, modo de projeção; temperatura: LED, placa, brilho, ventoinha, rampa; sistema: firmware, correção térmica, Wi-Fi, motivo do boot, data e hora) |
| Gatilhos | ao voltar da tomada e ao inserir o pendrive |
| Telas por gatilho | na tomada nenhuma tela fala de pendrive; no pendrive a última pede para tirá-lo |
| Ações automáticas | foco ruim refaz o autofoco (até 2 tentativas); imagem torta dá dica de nivelar; nitidez baixa por 4 pontos dá conselho; LED quente no boot avisa da ventilação |
| Chamar quando quiser | ícone na tela inicial; tecla do controle; item no menu de configurações (só com firmware provado); e continua tomada e pendrive |
| Pendrive | kit com autorun + `usb_update.bin` oficial (resgate) + o nosso `.bin` numa pasta, sem ativar |

## Perguntas do dono e respostas iniciais

1. **Compensar a mesa torta em software?** Em parte. A correção de quatro pontos já é isso: deforma a imagem
   para ela sair retangular. A câmera pode medir a forma e ajustar os 4 pontos sozinha, se acharmos onde o
   sistema guarda esses valores (`com.newlink.hisetting/.FourPointActivity`; a investigar). O custo é nitidez:
   a imagem Full HD é reamostrada numa área menor (foi o que borrou as faixas no bloco 8).
2. **Wi-Fi sem tela para trocar a rede:** a tela existe e está escondida: `android.settings.WIFI_SETTINGS`
   resolve para `com.zhiying.settings/.network.WifiSettingActivity` (medido 2026-10-30, aberta na parede pelo
   adb). Também existe `com.android.tv.settings`. Falta: o dono testar trocar a rede por ela; depois, atalho.

## Medido no aparelho

- `sys.boot.reason` registra o desligamento anterior: `shutdown,userrequested` (botão) e `shutdown,shell`
  (`reboot -p` pelo adb). Falta medir o valor depois de tirar da tomada (teste em andamento).

## Fatiamento proposto

- **Hoje:** gatilho da tomada (depende da medida acima), cor, temperatura só leitura, teste ativo da rampa e
  o resumo em tela cheia. O resumo precisa de um gerador de imagem no aparelho (sem Python lá): programa C
  pequeno que escreve PNG com fonte embutida, como o `nl_camcheck`.
- **Bloco seguinte:** ângulo, foco e nitidez pela câmera; autofoco de novo; ajuste automático dos 4 pontos;
  ícone na tela inicial e atalho de Wi-Fi; tecla do controle (investigar `com.newlink.hotkeysservices`).
- **Só depois do `.bin` provado:** item no menu de configurações.

## Pergunta aberta: processo em segundo plano esquentando?

O dono pergunta se processos desnecessários em segundo plano ajudam a esquentar. Indício: a carga média
fica em ~7 com o projetor parado (`uptime` em 2026-10-30: 7,15 / 7,29). No Android a carga conta também
threads esperando disco, então não é só CPU. O sensor quente (`gtt1`) mede o bloco do LED, não o
processador ([memória: gtt1 mede o bloco do LED]), e a placa fica em ~30 °C: CPU dificilmente explica o
LED quente, mas o calor do SoC soma na caixa. A medir: `top` por processo em repouso, e a temperatura do LED
com e sem os processos suspeitos parados.
