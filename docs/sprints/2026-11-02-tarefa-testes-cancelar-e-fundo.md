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

## Feito (T1, bloco 29)

**Visor no app** (`com.pfl7560.verificar`, versionCode 9): `Visor.java`, não exportado, `singleTask` em tarefa própria
(`taskAffinity` `com.pfl7560.verificar.visor`), tema `TemaVisor` com o logo MeowCast da abertura como fundo da janela
(`res/drawable-nodpi/visor_fundo.jpg`, byte a byte o `artifacts/tema/marca/logo.jpg`). A suíte abre com
`am start -n com.pfl7560.verificar/.Visor --es tela NOME.png`; cada tela seguinte chega por `onNewIntent`: a imagem velha
some (aparece o fundo MeowCast), a nova acende. No fim, `--ez fechar true` fecha antes do `HOME`. Regras em
`VisorModelo.java` (Java puro), testadas pelo `tests/test-kit-pendrive.sh` (`teste/TesteVisorModelo.java`).

**Onde ficam as telas e por que o app lê com SELinux enforcing:** `/data/data/com.pfl7560.verificar/visor/NOME.png`
(pasta do root `0755`, arquivo `0644`; a suíte copia para `.n-NOME` e faz `mv`). É a pasta do canal que o app já usa
(`pedir-verificacao`, `descanso-*`): o arquivo que o root cria ali herda o tipo da pasta (`app_data_file`, não há
`type_transition` do `vendor_shell` para lá) e nasce no nível `s0` do processo que cria; o `untrusted_app` (o app está
em `/vendor/app` sem ser privilegiado) tem `allow appdomain app_data_file:file` de leitura, e no MLS o nível do app
(`s0:c512,c768`) domina `s0`. DAC: o app é dono da pasta pai e lê a `visor/` `0755` e os `0644`. Hoje o aparelho está
`Permissive` (doc 49), então nada nega de qualquer jeito; a conta acima é para quando estiver `Enforcing`.
`/sdcard` foi descartado: o app precisaria de `READ_EXTERNAL_STORAGE` (permissão de tempo de execução no targetSdk 28).
A suíte recria a `visor/` se ela for link ou não for do root `0755` (o alvo do link fica intocado).

**Fallback:** sem a pasta do app (ou com UID abaixo de 10000), sem o `.Visor` no app instalado (app v8: o
`cmd package resolve-activity --brief -n` não devolve o componente) ou com o `am start` do visor dando `Error`, a
suíte volta à galeria como antes, com `[AVISO] visor: ...` no `ultimo.log`.

**Voltar/Sair = cancelar:** o visor grava `cancelar-suite` (dono = UID do app, `fsync`) no `onKeyDown` de Voltar (4) ou
Esc (111) e fecha. A suíte (`cancelou`: arquivo comum, não link, dono = dono da pasta do app >= 10000) confere antes de
cada tela, entre as etapas, a cada segundo das esperas fixas (`dormir`: abertura, tela, folga do autofoco, as três da
rampa), a cada volta das esperas do autofoco, e na espera da câmera sem prazo (agora em janelas de 5 s do
`getevent -qlc 3`, para conferir entre elas; depois de uma tecla, 1 s e confere de novo, porque a tecla pode ter sido
o Voltar). Ao cancelar: loga "cancelado pelo controle", `exit 0`; o `sair` limpa o override da rampa e o foco como
antes, grava `ultimo-fim` e zera `incompletas` (cancelar não é suíte interrompida), **apaga o `resultados.txt.new`** (o
`resultados.txt` anterior fica), no pendrive copia só o log, e vai à home (galeria fechada, `HOME`). Depois que o resumo
aparece, Voltar só fecha a tela: o resultado fica gravado e, no modo pendrive, a tela final é pulada. Pedido velho
(de antes da suíte) é apagado no início. O `suite-pedido.sh` ignora `cancelar-suite` (cai no `*) exit 0`).
`--desinstalar` apaga `cancelar-suite` e a `visor/`.

**Provas no PC:** `tests/test-suite.sh` caso `c_visor_cancelar` (visor nas telas sem galeria entre elas, fechar antes do
HOME, pasta do root `0755` limpa no fim; app velho; `am start` com erro; `visor/` link; UID baixo; cancelar na etapa 3
nos modos tomada, pedido e pendrive; na espera da câmera com e sem tecla; nos 40 s da rampa com o override limpo;
pedido link ignorado; pedido velho apagado; Voltar no resumo só fecha, tomada e pendrive; o `suite-pedido.sh` não
apaga o pedido; estático: nenhum `sleep` longo fora do `dormir`) e `--desinstalar` no `c_desinstalar`.

**Limites conhecidos:** as telas do `cor.sh` (calibração, escada, corrigida) seguem pela galeria, por cima do visor:
Voltar ali fecha a galeria (aparece o visor) e só o segundo Voltar cancela; durante o `cor.sh` o cancelar vale quando
ele termina. A suíte fecha a galeria do `cor.sh` por trás do visor depois dele, para o Voltar no visor não revelar uma
tela velha. Uma tecla que cair na virada da janela de 5 s da câmera pode se perder (a pessoa aperta de novo).

**Conferir no aparelho:**
1. Qual tecla o "Sair" do controle manda (`getevent -l` como root): se não for `KEY_BACK` nem `KEY_ESC`, o visor não a
   trata e é preciso acrescentar o código no `VisorModelo.cancela`.
2. Suíte pelo ícone "Verificar projetor": entre as telas aparece o fundo MeowCast, nunca a home; o `ultimo.log` diz
   `visor: telas no app`.
3. Voltar na tela da etapa 3: volta à home em até ~2 s, `ultimo.log` termina em "cancelado pelo controle",
   `resultados.txt` com o `inicio=` da suíte anterior, e o `override` limpo (`getprop vendor.zy.power.tm.temp` vazio).
4. Voltar na tela "A câmera não conseguiu ler a tela" (tampar a lente): cancela.
5. `ls -lZ /data/data/com.pfl7560.verificar/visor` durante a suíte: `root root`, `app_data_file`.
6. Voltar na tela de calibração da etapa 1 (lente livre, a leitura da câmera passa): a suíte para antes do `cor.sh`,
   sem nenhuma escada pela galeria por cima da home.

## Conferido (T2, bloco 29)

- **Corrigido (`745e62f`):** o Voltar que chegava durante a leitura da câmera (`nl_camcheck faixas`, até 30 s sem
  conferir) só era visto depois do `cor.sh`, que abria as telas dele pela galeria por cima da home já revelada. A
  suíte agora confere o cancelar logo antes do `cor.sh`; caso novo no `c_visor_cancelar` (falhava sem a correção).
- **SELinux, o que a conta prova e o que não prova.** A *leitura* pelo app vale com `Enforcing`: a tela nasce
  `app_data_file` (tipo da pasta pai, sem `type_transition` do `vendor_shell` para lá) no nível baixo do processo
  que cria (`s0`; para arquivo, sem `range_transition`, o kernel copia o nível baixo de quem cria), o
  `untrusted_app` (targetSdk 28, `levelFrom=all`) tem leitura de `app_data_file` e o nível dele
  (`s0:c512,c768`) domina `s0`; DAC `0755`/`0644`. A *escrita* do root na pasta do app (criar a `visor/`, copiar a
  tela) depende do mesmo acesso do `vendor_shell` a `app_data_file` que o canal antigo já usa (o
  `suite-pedido.sh` faz `mv` do `pedir-verificacao` e dos `descanso-*` dessa pasta): hoje passa porque o aparelho
  está `Permissive`. Se um dia ficar `Enforcing` e a escrita for negada, a suíte não quebra: `visor_dir_ok` ou o
  `cp` falham e as telas voltam pela galeria com `[AVISO] visor: ...` no log (o canal do "Verificar" pararia
  junto, então isso não é regressão deste bloco).
- **Sem defeito achado:** home entre as telas (só o `cor.sh` usa a galeria, por cima do visor); cancelar em toda
  espera da suíte (`dormir`, autofoco, câmera sem prazo, rampa com o override limpo, tela final do pendrive); sem
  resumo e sem `resultados.txt` novo; fallback (app v8, `am start` com erro, pasta link ou de UID baixo); `am start
  -n` de activity não exportada vale porque a suíte roda como root (UID 0 passa no `checkComponentPermission`);
  `wifi_pwr` sem caminho que escreva `auto` (aplicar, pedido, boot, resgate; a semente da S5 só copia o
  `suite-chaves.sh` novo); md5 do kit, `SEMENTE_LISTA` e `RC_S5_MD5` em dia; APK v9 refeito com o mesmo md5.

## Feito (T3, bloco 29): a etapa de cor no visor e Voltar/Esc no cor.sh = cancelar

- **Visor no `cor.sh`:** com o visor aberto, a suíte chama `cor.sh ... suite visor`; o `mostrar()` do `cor.sh` usa a
  mesma pasta (`/data/data/com.pfl7560.verificar/visor/NOME.png`, root `0755`, `.n-NOME` + `mv`, `0644`) e o mesmo
  `am start -n com.pfl7560.verificar/.Visor --es tela NOME.png` da suíte. Se a pasta não confere ou o `am start` dá
  `Error`, aquela tela e as seguintes vão pela galeria, com `[AVISO] visor: ...` no `cor.log` (igual à suíte). Fora da
  suíte (kit de pendrive sozinho) segue a galeria.
- **Voltar/Esc = cancelar:** o `esperar_tecla` lê o nome da tecla no `getevent -qlc 3`: `KEY_BACK` ou `KEY_ESC` (e,
  só no modo suíte, o `cancelar-suite` gravado pelo visor, conferido antes de cada tela, antes de escrever e em cada
  espera de tecla) cancelam; outra tecla é resposta como antes. Ao cancelar: sem journal desta execução, sai sem
  escrever ("nada foi escrito na panelparam"); com journal (lvds_fmt trocado ao vivo), `reverter` (o mesmo caminho:
  `lvdsctl fmt` original, byte da partição, confere com o backup, apaga journal e gancho) e loga "revertido no
  cancelar". O resultado da cor fica `cancelado`; o `cor.sh` não apaga o pedido (quem apaga é a suíte). Na suíte,
  `checar_cancelar` logo depois do `cor.sh` (pedido do visor) e, sem pedido (Voltar na galeria de reserva),
  `cor_resultado=cancelado` também para a suíte sem resumo e sem resultado. No kit sozinho: sem tela de resultado,
  galeria fechada e `HOME`.
- **Sair do controle:** não há prova no repositório de outro código (o `Vendor_0001_Product_0001.kl` foi lido no doc 43
  mas não está guardado, e nenhum dump de `getevent` traz o Sair). Ficaram só `KEY_BACK`/`KEY_ESC`, os mesmos do
  `VisorModelo.cancela`. Se o Sair mandar outro código, ele conta como "outra tecla" (resposta) no `cor.sh` e não cancela
  no visor: acrescentar nos dois lugares.
- **Limites:** se a reversão de um cancelar não conferir, o journal fica e o gancho restaura no próximo boot (como em
  todo outro caminho de reversão), com `[ERRO]` no log; a suíte para do mesmo jeito. Na galeria de reserva, um Voltar
  fora de uma espera de tecla (durante a leitura da câmera) só fecha a galeria; o cancelar vale na próxima espera.
- **Provas:** `tests/test-suite.sh` caso novo `c_cor_cancelar` (telas do cor.sh no visor sem galeria; galeria de
  reserva com aviso; Voltar no visor antes de escrever; Voltar e Esc na galeria antes de escrever; Voltar depois da
  troca ao vivo, revertido e conferido; Voltar na tela corrigida; pedido do visor durante a medição; outra tecla na
  corrigida desfaz como antes) e `tests/test-kit-pendrive.sh` caso `c_tecla_voltar` (kit sozinho: Voltar antes de
  escrever e depois da troca). Todos falham sem a correção. As expectativas de `telas_visor` do `c_visor_cancelar`
  passaram a incluir as telas do cor.sh.

**Conferir no aparelho (T3):**
1. Suíte pelo ícone, lente livre, painel já em ordem: entre a calibração e a escada aparece o fundo MeowCast, nunca a
   home; `cor.log` sem `[AVISO] visor`.
2. Etapa 1 com a escada na tela (fluxo manual: tampar a lente para cair nele ou rodar com o modo automático
   desligado): Voltar uma vez volta à home, `cor.log` termina em "cancelado pelo controle (tecla Voltar/Esc)" e
   "nada foi escrito", `ultimo.log` em "cancelado pelo controle", `resultados.txt` da suíte anterior.
3. Fluxo manual com OK na escada (troca ao vivo) e Voltar na escada-2: a imagem volta ao formato de antes,
   `cor.log` com "revertido no cancelar: ... confere com o backup", sem `journal` em `/data/vendor/pfl7560-kit`.
4. Qual código o Sair manda (`getevent -l` como root): se não for `KEY_BACK`/`KEY_ESC`, acrescentar no `cor.sh` e no
   `VisorModelo.cancela`.
