# Bloco 9 - suíte de boot: verificação automática ao voltar da tomada e ao inserir o pendrive (2026-10-30)

Pedido do dono (2026-10-30, depois do [bloco 8](2026-10-30-bloco-8-camera-robusta.md)): ao ligar depois de ficar
sem energia, o projetor roda a suíte de correção (câmera, cor, ângulo, foco, imagem, temperatura) e termina
numa tela de resumo em tela cheia, "bonita, agradável, organizada e limpa", estilo MangoHUD. O mesmo ao
inserir o pendrive. "Conclua tudo, deixe tudo pronto; os testes no aparelho ficam para o fim."

Telas propostas (canvas): https://claude.ai/artifact/5Tn6dpqHX2d9kiFVMQDpKT
Escolhas do dono (salvas): https://claude.ai/artifact/YPCCxNyvVYVhKZZo4xvjMz (`escolhas/atual`, 22:40Z)

## Decisões do dono

| Item | Decisão |
|---|---|
| Etapas | as 5: cor (pronta), ângulo e foco (nova), nitidez (nova), temperatura só leitura (nova), teste ativo da rampa (pronto no PC, ~65 s, escurece a imagem) |
| Resumo | tela cheia, 20 s (qualquer tecla fecha antes), os 19 itens (cor: formato, câmera, painel; imagem: resolução, ângulo, foco, nitidez, 4 pontos, modo de projeção; temperatura: LED, placa, brilho, ventoinha, rampa; sistema: firmware, correção térmica, Wi-Fi, motivo do boot, data e hora) |
| Gatilhos | ao voltar da tomada e ao inserir o pendrive |
| Telas por gatilho | na tomada nenhuma tela fala de pendrive; no pendrive a última pede para tirá-lo |
| Ações automáticas | foco ruim refaz o autofoco (até 2 tentativas); imagem torta dá dica de nivelar; nitidez baixa por 4 pontos dá conselho; LED quente avisa da ventilação |
| Chamar quando quiser | ícone na tela inicial; tecla do controle (se a pesquisa achar como); item no menu de configurações (só com firmware provado: fora deste bloco); continua tomada e pendrive |
| Pendrive | kit com autorun + `usb_update.bin` oficial (resgate) + o nosso `.bin` numa pasta, sem ativar |
| Wi-Fi | a tela escondida existe (`android.settings.WIFI_SETTINGS` → `com.zhiying.settings/.network.WifiSettingActivity`, aberta na parede em 2026-10-30); vira atalho no app |
| Imagem do projetor | "melhorar a qualidade de imagem: do projetor e da câmera". Câmera: feito no bloco 8. Projetor: a suíte mede nitidez e aconselha zerar os 4 pontos quando eles borram; ajuste automático dos 4 pontos depende da pesquisa (P2) |

## Fatos que o desenho usa (medidos ou lidos no repositório)

1. Android 9, build `eng`, SELinux **permissivo** (doc 28 tabela, doc 29:324, doc 41:21).
2. Init de fábrica (`artifacts/init.bigfish.rc.STOCK:371-373`): em `sys.boot_completed=1`, `exec u:r:vendor_shell:s0
   root root -- /vendor/bin/sh /data/local/nlsu/update_after_boot.sh` e depois o `nl_usb_update.sh` (que roda o
   `newlink_update.sh` do pendrive). O `exec` bloqueia o init: tudo que demora roda destacado.
3. Um serviço próprio em `/vendor/etc/init/*.rc` já funcionou neste aparelho (`nl_lvds.rc`, doc 35 §6). O kit já
   remonta o `/vendor` em rw para os fixes térmicos (`newlink_update.sh:406`). O brick de julho veio de `.rc`
   com modo `0664` e sem xattr SELinux no **`.bin`**: arquivo novo de `.rc` tem de ser `0644 root:root` e levar o
   rótulo `u:object_r:vendor_configs_file:s0` (conferir com `ls -Z` do vizinho e `chcon`).
4. O `/data/local/nlsu/update_after_boot.sh` é do gancho de recuperação do `cor.sh` (temporário). A suíte **não**
   usa esse caminho, para não disputar com ele.
5. Temperatura sem tocar o mux: `getprop zysys.env_temp` (sensor quente, bloco do LED, gtt1) e
   `zysys.light_temp` (placa, gtt0), em °C com sufixo "℃". O `hidebug gtt` força o mux e é suspeito de causar o
   "LSADC Error" (doc 35, LSADC-S2): **proibido** na suíte. Ventoinha e brilho: `printf 'custom\ngfs 0\ngfs 1\ngbri 0\nquit\n' | /vendor/bin/hidebug`
   (linhas `fan speed` e `backlight brightness`; ver `pfl7560-monitor-termico.sh:50-61`).
6. Teste ativo da rampa (`pfl7560-saude.sh:200-300`, provado em 2026-10-30): `setprop vendor.zy.power.tm.temp 71000`
   (fixo; 75000 desliga na hora), `logcat -v time -s ZYThermalManager`, sinal = `Overheat Warning` e
   `Level Change X => 850!` (excluindo `850 => 850!`), limpar com `setprop vendor.zy.power.tm.temp ''` e
   confirmar lendo de volta; limpeza em trap. Volta: `Level Change X => 1000!` (excluindo `1000 => 1000!`).
7. Motivo do boot: `sys.boot.reason` = `shutdown,userrequested` (botão), `shutdown,shell` (adb `reboot -p`).
   **Não medido:** o valor depois de faltar energia com o projetor ligado, e se o relógio (RTC) zera ao tirar
   da tomada. A detecção da tomada fica configurável e registra todos os sinais a cada boot (ver 9B).
8. Câmera: `nl_camcheck` (bloco 8) com janela 47 a 53 % e 1280x720; o quadro é espelhado de cima para baixo.
   A câmera vê ~1100 px de largura para 1920 px projetados: listras de 1 a 2 px **não** são resolvidas por ela,
   então "nitidez" e "foco" se medem pela largura da borda das faixas brancas da tela de calibração.
9. Galeria: `am force-stop` do pacote resolvido antes de cada `am start` (bloco 7). Um PNG gerado na hora deve
   ter nome único por execução (cache).
10. Ferramentas no PC: NDK r27c (`~/Android/android-ndk-r27c`), Android SDK (`~/Android/sdk`: build-tools
    35.0.0 e 36.0.0 com `aapt2`, `d8`, `zipalign`, `apksigner`; `platforms/android-34`), `apktool`, Java 17.
    Fonte IBM Plex (OFL) em `https://raw.githubusercontent.com/IBM/plex/master/packages/plex-sans-condensed/fonts/complete/ttf/`
    e `.../plex-mono/...`; `stb_truetype.h` e `stb_image_write.h` (domínio público) em
    `https://raw.githubusercontent.com/nothings/stb/master/`.

## Contratos entre as partes (fixos; quem muda avisa o coordenador)

### C-geo: `nl_camcheck geometria <dev> <faixas.txt> [descarte]` (9A faz, 9B usa)

Captura um quadro (mesmas regras do `niveis`), com a tela de calibração projetada e o `faixas.txt` do `faixas`.
Imprime linhas `chave=valor`, números com ponto decimal, nesta ordem, e sai 0; sai 1 se não conseguiu ler, 3
se as faixas não aparecem nas três colunas:

```
inclinacao_graus=-1.84     # inclinação média das faixas no quadro (sinal: ver nota)
trapezio_pct=4.2           # (altura da pilha de faixas à direita / à esquerda - 1) * 100
borda_centro_px=2.10       # largura média 10-90 % das bordas das faixas, coluna central, px do quadro
borda_esq_px=3.05          # idem, coluna da esquerda (15 a 21 % da largura)
borda_dir_px=2.80          # idem, coluna da direita (79 a 85 %)
contraste_centro=0.93      # (claro - vão) / claro na coluna central
quadro=1280x720
```

Nota: o quadro é espelhado na vertical; o sinal de `inclinacao_graus` é o do quadro como chega, e o mapeamento
para "abaixe o lado X" fica numa constante do `suite.sh`, marcada para confirmar no teste com uma inclinação
proposital.

### C-tela: `nl_tela aviso|resumo <campos.txt> <saida.png> <dir_fontes>` (9A faz, 9B usa)

PNG 1920x1080 RGB. Sai 0 ok, 1 erro (fonte, arquivo, gravação), 2 uso errado. `campos.txt` é **ASCII puro**
(o kit é ASCII): texto não-ASCII vai como `\uXXXX` (BMP) e quebra de linha como `\n`; chaves desconhecidas
são ignoradas; linhas longas são truncadas com reticências, nunca transbordam. Fontes procuradas em
`<dir_fontes>` (`IBMPlexSansCondensed-Regular.ttf`, `-SemiBold.ttf`, `-Bold.ttf`, `IBMPlexMono-Regular.ttf`,
`IBMPlexMono-SemiBold.ttf`) e, se faltar, em `/system/fonts/Roboto-Regular.ttf`, `Roboto-Bold.ttf`,
`DroidSansMono.ttf`. Glifo ausente vira o da fonte reserva ou `?`.

`aviso` (abertura, etapas sem câmera, final):
```
etapa=Etapa 3 de 4                   # canto superior esquerdo, opcional
canto=só leitura                # canto superior direito, opcional
titulo=Voltou a energia.\nConferindo o projetor.
texto=O projetor ficou sem energia. Antes de você usar, ...
passo=Cor do painel|feito|ok         # nome|fila,agora,feito|ok,corrigido,atencao,pendente (resultado opcional)
passo=...                            # até 6
rodape=não precisa apertar nada
tom=normal|alerta
```

`resumo`:
```
titulo=Tudo certo.
destaque=1 correção feita.
destaque_estado=ok|corrigido|atencao
canto=fecha sozinho em 20 s · qualquer tecla fecha
grupo=COR
item=Formato do painel|VESA → JEIDA|corrigido     # rótulo|valor|ok,corrigido,atencao,info,pendente
...                                                    # até 4 grupos, até 6 itens por grupo
dica=Imagem inclinada 2°: abaixe o pé esquerdo.   # até 3 linhas de dica/conselho, opcional
rodape=queda de energia · 30/10/2026 19:40 · relatório em /data/vendor/pfl7560-suite/ultimo.log
```

Visual (o do canvas, mais limpo): fundo `#0E1116`, cartões `#171B21`, texto `#F2F3F5`, secundário `#A9AFB8`,
fio `#2A3038`; estados: ok `#6FD6A6`, corrigido `#F2B451`, atenção `#F07560`, info = texto, pendente =
secundário. Margens 110 px, título 72 px Bold, rótulo de grupo 30 px SemiBold com espaçamento, rótulo de item
26 px Regular secundário, valor 34 px Mono SemiBold na cor do estado com um ponto de estado de 12 px, rodapé 24
px Mono. Quatro colunas de grupos com a mesma altura de linha entre colunas; sem barra lateral colorida, sem
gradiente, sem emoji. A dica, se houver, numa faixa própria acima do rodapé, cor de atenção no marcador.

### C-res: arquivo de resultados da suíte (9B escreve, 9C documenta)

`/data/vendor/pfl7560-suite/ultimo.log` (texto) e `/data/vendor/pfl7560-suite/resultados.txt` (`chave=valor`
ASCII, uma por linha, com todas as medidas brutas e os estados), mais `historico-boot.txt` (os sinais do
gatilho de cada boot, últimos 30).

## Partes

- **P (pesquisa, só leitura):** no firmware extraído (método do doc 42), achar: (1) como disparar o autofoco
  (`com.zhiying.autofocus`, `AutoFocus3.apk`; serviço, broadcast ou propriedade); (2) onde a correção de 4
  pontos é guardada e se dá para ler e escrever (`com.newlink.hisetting/.FourPointActivity`); (3) se o
  `com.newlink.hotkeysservices` permite ligar uma tecla do controle a uma ação nossa; (4) a propriedade do modo
  de projeção (mesa, teto, traseira); (5) se o launcher `com.newlink.hisilauncher` lista apps por
  `LAUNCHER` ou `LEANBACK_LAUNCHER`. Saída: `docs/research/43-pesquisa-autofoco-keystone-teclas.md` com o
  comando exato de cada item, o nível de confiança e o arquivo/linha de onde saiu.
- **9A (C):** `nl_tela` (C-tela) e `nl_camcheck geometria` (C-geo). Spec: `2026-10-30-bloco-9a-tela-e-geometria.md`.
- **9B (shell):** a suíte (`suite.sh`), o serviço de boot e o gatilho, a integração com o `newlink_update.sh` e o
  `cor.sh`, o harness. Spec: `2026-10-30-bloco-9b-suite.md`.
- **9C (app, pendrive, processos, documentos):** depois de 9A e 9B. Spec: `2026-10-30-bloco-9c-app-pendrive-docs.md`.

## Pergunta aberta: processo em segundo plano esquentando?

O dono pergunta se processos desnecessários em segundo plano ajudam a esquentar. Indício: a carga média
fica em ~7 com o projetor parado (`uptime` em 2026-10-30: 7,15 / 7,29). No Android a carga conta também
threads esperando disco, então não é só CPU. O sensor quente (`gtt1`) mede o bloco do LED, não o
processador, e a placa fica em ~30 °C: CPU dificilmente explica o LED quente, mas o calor do SoC soma na
caixa. 9C entrega a ferramenta de medida; a medida é do teste final.

## Testes no aparelho (no fim de tudo, pelo coordenador)

1. Instalar pelo pendrive real (FAT32): kit + suíte + app; idempotência numa 2ª inserção.
2. Tirar da tomada **com o projetor ligado**, religar: a suíte roda, o resumo aparece; `historico-boot.txt`
   mostra os sinais. Repetir desligando pelo controle e religando: a suíte **não** roda (se os sinais
   permitirem distinguir; senão, decidir com o dono).
3. VESA à mão + tirar da tomada: a suíte corrige para JEIDA.
4. Inclinar o projetor de propósito: confirmar o sinal de `inclinacao_graus` e a dica.
5. Ícone "Verificar projetor" e "Wi-Fi" na tela inicial.
6. Ferramenta de processos em repouso; 7. `pfl7560-saude.sh --vivacidade` verde depois de tudo.

## Estado (fechamento do bloco, 9C, 2026-10-30)

Tudo o que o bloco pedia está **em código e provado só em simulação**. Nada rodou no aparelho: os testes dele
são o roteiro único da seção 12 de [`docs/research/44-suite-de-boot.md`](../research/44-suite-de-boot.md), que
é também a documentação final da suíte.

| Parte | Estado | Onde |
|---|---|---|
| P, pesquisa | feita ([doc 43](../research/43-pesquisa-autofoco-keystone-teclas.md)) | autofoco e `sys.newlink.auto`, 4 pontos, tecla (não há caminho), modo de projeção, launcher |
| 9A, `nl_tela` e `nl_camcheck geometria` | feita, integrada | [9A](2026-10-30-bloco-9a-tela-e-geometria.md) |
| 9B, a suíte, o serviço e os gatilhos | feita, integrada (com a revisão de segurança do pedido do app) | [9B](2026-10-30-bloco-9b-suite.md) |
| 9C, app, pendrive, processos e documentos | feita | [9C](2026-10-30-bloco-9c-app-pendrive-docs.md) |

Das decisões do dono, ficaram **fora** (com o porquê no doc 44, seção 10): a tecla do controle (o mapa de teclas
é fixo e a única ação configurável é de teclas que o controle comum provavelmente não tem), o item no menu de
configurações (menu do fabricante, sem ponto de extensão) e o ajuste automático dos 4 pontos (a suíte mede e
aconselha). A pergunta dos processos em segundo plano ganhou a ferramenta de medida (`pfl7560-processos.sh`); a
medida é do teste final (passo 14).

O que falta, tudo no aparelho: a seção 12 do doc 44 inteira, em especial o gatilho da tomada (os sinais de
`sys.boot.reason` e do relógio depois de faltar energia), o sinal da inclinação, o `pm install` do app, o
`inotifyd` e as telas do `nl_tela` na galeria. O que ficou PROVISÓRIO está na seção 11 do doc 44.
