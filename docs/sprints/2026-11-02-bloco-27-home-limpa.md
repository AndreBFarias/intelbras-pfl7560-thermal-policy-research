# Bloco 27 - Home limpa, rápida e com navegação previsível (2026-11-02)

Pedido do dono (2026-11-02, depois de usar a home versionCode 7 no aparelho): "Tem muitos textos nas novas telas.
Precisam ser removidos e deixarmos o layout mais limpo. Fora que os botões não tão responsivos e a navegação não tá
tão legal." Decisões pelo AskUserQuestion na mesma hora, transcritas abaixo.

## O que se mediu

- Tela Ajustes mostrou "Não consegui ler" em todas as chaves. Causa: o projetor publica `vendor.pfl7560.chaves`
  ~60 s depois do boot (`log_vplug:ok` 59 s após o kernel); a home lê só ao abrir a tela e de novo 2,5 s depois, e
  nunca mais. Aberta antes disso, fica presa. `getprop` no domínio `untrusted_app` funciona (testado com `runcon`).
- `dumpsys gfxinfo` da home: 333 quadros, mediana 13 ms, p95 36 ms, p99 61 ms, 1 quadro de 300 ms,
  **40 "Slow UI thread"**, 49 "Slow issue draw commands". O desenho não explica sozinho a demora: procurar trabalho
  no thread principal (leitura de arquivo/prop, `Process`, montagem de lista) e o vai e volta dos pedidos
  (`pedirChave` → inotifyd → `suite-pedido.sh` → prop) sem resposta visual imediata.
- Visto ao vivo: na tela Curvas, Voltar andou o foco dentro da tela em vez de fechar.

## O que o dono escolheu

1. **Textos:** cada linha mostra só o nome e a chave. Nas Chaves, o texto de baixo (o que a chave faz) **fica**, só
   do item em foco e curto. Riscos longos, parágrafos de explicação e "socorro" saem da tela. Em todas as outras
   telas (Curvas, Logo do boot, Diário): só remover texto e deixar menos confuso.
2. **Navegação nas Ajustes:** seta para a direita na lista vai para a aba da direita (Chaves → Diário); esquerda volta.
3. **Respostas que falharam (todas marcadas):** OK demora a mudar; foco vai para o lugar errado; tecla ignorada;
   Voltar não fecha. Regra nova: **Voltar fecha a tela de uma vez** (a não ser que esteja arrastando uma bola nas
   Curvas, onde Voltar solta a bola); OK muda a chave **na hora** na tela (estado "aplicando"), e o projetor
   confirma depois; nenhuma tecla é engolida.
4. **Tela inicial:**
   - sai o atalho **Imagem** e o app **Gerenciador de arquivos** (já existem dentro de Configurações);
   - o atalho **Configurações** fica;
   - VLC já foi desinstalado: nada a fazer;
   - rodapé ganha o **estado do Bluetooth** (igual ao "Wi-Fi conectado") e a **temperatura da placa** ao lado da do
     LED.
5. **Chaves que somem da tela** (o kit e a prop `chaves` não mudam de posição; a home só esconde o índice):
   - `eth0`: o projetor não tem porta de cabo. Some da tela e o kit não mexe nela (fica desligada).
   - `deb_vlc` ("VLC e Office embutidos"): o dono pediu "Remove vlc e office". Some da tela; o estado atual
     (ligada = os dois desligados) fica como está.
5b. **Revisto pelo dono na mesma hora (vale sobre o item 5):**
   - `eth0` **fica na tela**: "se é uma coisa na placa então faz sentido ela continuar e poder ser desabilitada".
     Nome "Porta de rede por cabo", ligado = funciona.
   - VLC é do dono (instalado por ele, já desinstalado): **o kit deixa de mexer no VLC**. A linha `deb_vlc` vira só
     **"Office do fabricante"** (`com.mobisystems.editor.office_registered`), ligado = funciona; o dono quer
     desativado (estado atual). O id `deb_vlc` e a posição na prop ficam; sai o `org.videolan.vlc` da lista do id e
     do `debloat-aprovados.txt`, e o estado da linha passa a olhar só o Office (sem "parcial" por causa do VLC).
   - **USB-C:** o bloco "USB-C" sai de Entradas (a porta continua funcionando). **Só pesquisar e relatar** (docs,
     dumps e firmware já no repositório, nada no aparelho): existe um jeito seguro e reversível de cortar a energia
     da porta USB-C (chip/regulador, sysfs, gpio)? Quanto economiza? Sem implementar.
6. **Configurações** fica na tela inicial (decidido).
6b. **A chave vira o serviço** (o dono: "até o termo chaves é zuado. Eu não quero nada ali ativado"; "Sério"):
   - o switch mostra **o serviço**, como no Android: **ligado = o serviço funciona**; desligado = desativado. Hoje é o
     contrário ("Ligada" = a medida aplicada = serviço desligado) e confundiu o dono;
   - a aba "Chaves" vira **"Serviços"**; o termo "chave" some de toda a interface (textos, avisos, rodapé);
   - nomes curtos, do serviço, sem verbo: "Apps de teste e de fábrica", "Telemetria do fabricante", "Players da
     HiSilicon", "Tela inicial de fábrica", "Log do vplugin", "Servidor web e cmdsrv", "Keystone automático";
   - **"Chip Wi-Fi dorme" sai da tela** (não é um serviço e o risco é derrubar a rede); o kit não muda;
   - a inversão é **só na home** (visual e pedido): o protocolo `v1 <id> ligar|desligar` e a prop `chaves` do kit
     continuam iguais (ligar = aplicar a medida = desativar o serviço). Testar a tradução nos dois sentidos;
   - o padrão do dono: tudo desativado (o que o kit já instala nas 6 primeiras).
   - o texto de baixo do item em foco fala do serviço ("Telemetria e atualização pela internet do fabricante.").
   - a chave nova do pop-up do `nlprovision` entra no mesmo modelo: "Aviso de dispositivo conectado", ligado =
     aparece.
7. **Junto no bloco:** (a) Ajustes tenta ler de novo a cada 2,5 s até conseguir, mostrando "Lendo…" em vez de
   "Não consegui ler", e lê de novo ao voltar para a tela; (b) chave para desligar o pop-up de "dispositivo
   conectado" (`com.newlink.nlprovision`, visto pela suíte), reversível, no mesmo formato das chaves do bloco 24.

## Cura na origem

- `Ajustes.java`/`Curvas.java`/`Modelo.java`: textos encurtados ou removidos; `mover()` das Ajustes com dx troca
  aba; estado "lendo" e "aplicando".
- `HomeActivity.java`: Voltar fecha; nada de I/O no thread principal; releitura periódica enquanto Ajustes aberta e
  sem estado; resposta visual imediata ao OK.
- `Desenho.java`: layout mais limpo; rodapé com Bluetooth e placa.
- Kit: chave nova do pop-up em `suite-chaves.sh` (ID novo no fim de `IDS`, posição nova na prop `chaves`), com
  teste; descobrir no código/dumps já guardados como o `nlprovision` é desligado (pm disable do componente ou do
  pacote) sem mexer no aparelho.
- Temperatura da placa: mesma fonte que a suíte já usa (`light_temp`/POLICY_0, doc 50), sem `gtt`/`stp`.

## Como se prova (tudo no PC)

- `artifacts/home/gerar-previas.sh` regenera as prévias; prévias novas de Ajustes (lendo, aplicando, aba Diário pela
  seta), Curvas e tela inicial (sem Imagem, rodapé novo) para o dono ver antes de instalar.
- Testes de modelo puro: Voltar fecha em todas as telas; direita/esquerda troca aba; "Lendo…" até ler; OK muda o
  estado na hora.
- Todo o `tests/test-*.sh` e `make check` sem falha nova; `shellcheck -s sh` limpo; APKs refeitos com versionCode 8.

## Regras

- Nada no aparelho (o coordenador faz as leituras e a instalação, com o sim do dono).
- Um commit por tarefa, sem `--no-verify`.

## Agentes (2)

| agente | modelo | o quê |
|---|---|---|
| H1 | Opus, high | implementa (UI + navegação + leitura + chave do pop-up) |
| H2 | Opus, high | confere, corrige, prévias e regressão |

## Estado

- [x] H1
- [x] H2 (prévias regeneradas e tradução conferida em todos os ids, `71566c7`)
- [x] integrado na `integracao` (`a73229d`); home versionCode 8, e 9 depois do conferente final ("Desligar no
  descanso", `6d209c9`)
- [ ] prévias aprovadas pelo dono: **a conferir** (não há registro da aprovação)
- [ ] instalar: vai junto na S5 final (bloco 28), não pelo pendrive à parte
- USB-C (só pesquisar e relatar): **a conferir** se o relato foi feito (nenhum doc nem commit desta árvore o traz)
