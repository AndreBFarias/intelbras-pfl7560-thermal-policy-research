# Bloco 25 - Logo automático, piso de 70 % e o sensor da [ThermalPolicy] (2026-11-01, em paralelo ao 24)

Decisões do dono (rodada do bloco 23, 2026-11-01):
- **Instalação:** o 23 vai para o aparelho junto com o 24 (e este, se estiver pronto).
- **Piso da curva dos ventiladores: 70 %** (era 30 % provisório). Pelo binário, abaixo de 50 % de velocidade o
  firmware usa o mesmo duty mínimo (doc 49 §4.3).
- **Curva gravada dos ventiladores:** pesquisar qual sensor a `[ThermalPolicy]` lê, antes de ligar.
- **Logo automático:** chave na home, **ligada** ao instalar; no máximo 1 gravação por boot; recusa cantos absurdos;
  backup antes. Tarefa de origem: `2026-11-01-tarefa-logo-automatico.md`.
- Regra que vale para tudo (dono, 2026-11-01): **tudo criado na interface**.

## 1. Piso de 70 %

Na tela Curvas (bolinhas presas em ≥ 70 %, texto "piso 70 %"), no root (`suite-curvas.sh` recusa < 70 %), nos
perfis Silencioso e Balanceado (refeitos para começar em 70 %, com 100 % obrigatório a partir de 66 °C), nos testes
e nos docs (doc 44 §17, `docs/codigo/`).

## 2. Logo automático

- O kit leva a arte **reta** do logo (`artifacts/tema/marca/logo.jpg`, 1920x1080) e um programa nativo (NDK r27c,
  já no `install.sh --dev`, como o `nl_tela`/`nl_camcheck`) que faz a mesma conta do `gerar-marca.py`: perspectiva
  pelos 4 cantos `persist.sys.keystone.*`, bicúbico, fundo preto, JPEG qualidade 95 e 4:4:4.
- No boot (`suite-boot.sh`), com a chave ligada: se os cantos atuais diferem dos cantos do logo gravado (guardados
  numa pasta do root), gera, confere o `LOGO_TABLE` (JPEG no byte 8192, `LOGO_KEY_LEN` em 0x78) e grava só essas
  duas regiões, como o `pfl7560-marca.sh`: backup da partição antes (guardar o primeiro e o último), md5 do que
  foi escrito relido, desistência sem gravar a qualquer falha. No máximo 1 gravação por boot. Cantos fora da tela
  ou que não formam quadrilátero convexo: recusa e registra.
- Home: chave liga/desliga (padrão ligada), cantos do logo atual, hora da última gravação, último motivo de recusa.
- Resgate: arquivo no pendrive que desliga a chave.
- Teste no PC: a saída do programa nativo (rodando no PC, compilado para x86 ou pela mesma conta em teste) bate com a
  do `gerar-marca.py` (diferença média de pixel pequena) para cantos retos, os de hoje e tortos.

## 3. Pesquisa: o sensor da `[ThermalPolicy]` (só leitura)

Qual sensor o firmware lê para a `[ThermalPolicy]` (`libhitvservice.so`, doc 34, doc 49 §4.1-4.3), em que unidade,
de quanto em quanto tempo, e se uma curva por temperatura gravada ali vale para os dois ventiladores (o P2 achou
que o ventilador 1 segue só a política 1). Saída: `docs/research/50-sensor-da-thermalpolicy.md`, com endereços e
INFERIDO marcado, e a proposta de como gravar a curva do dono ali. No aparelho, só leitura; nunca `gtt`.

## Regras

- Branch `bloco-25`, árvore `~/Apate/Desenvolvimento/.arvores/bloco25/` (git worktree). Um commit por tarefa.
- O bloco 24 roda em paralelo nos mesmos arquivos (home, kit): o coordenador junta no `main`; APKs, `versionCode`
  e listas md5 são refeitos na integração.
- Kit em ASCII puro, `sh` do Android, PATH fixo; md5 por `bash tests/atualizar-md5-kit.sh`.
- Nenhum agente grava no projetor.

## Agentes (3)

| agente | modelo | o quê |
|---|---|---|
| R1 | Opus, high | pesquisa §3 (só leitura), em paralelo ao I1 |
| I1 | Opus, high | implementa §1 e §2, com testes |
| C1 | Opus, high | confere e corrige o I1 e o R1 |

## Estado

- [ ] R1
- [ ] I1
- [ ] C1
- [ ] o coordenador instala no aparelho com o dono
