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
6. **Configurações** fica na tela inicial (decidido).
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

- [ ] H1
- [ ] H2
- [ ] prévias aprovadas pelo dono
- [ ] instalar pelo pendrive (sim do dono)
