# Bloco 23 - Curva dos ventiladores, curva do LED, standby pelo descanso e debloat reversível (2026-11-01)

Pedido do dono (2026-11-01), com as decisões tomadas na conversa:

## 1. Curva dos ventiladores (botão novo na home)

- Tela no estilo dos apps de notebook: gráfico temperatura do LED (°C) × velocidade (%), com **5 bolinhas** que
  o controle remoto move. Perfis: **Silencioso**, **Balanceado**, **Agressivo** (o de hoje: 100 % fixo) e
  **Manual** (as bolinhas do dono).
- Trava (decisão do dono): **100 % obrigatório a partir de 66 °C** e um **piso que nunca deixa parar**
  (PROVISÓRIO: 30 %, até o bloco 22 dizer o mínimo seguro). A tela não deixa arrastar para fora disso, e o
  root recusa pedido fora disso.
- Silencioso: **silêncio primeiro** (decisão do dono): o brilho pode cair mais cedo pela escada de 66 °C.
- **As duas formas de aplicar** (decisão do dono):
  - **ao vivo:** um laço root lê a temperatura do LED pelas props (como a suíte já faz; **nunca `gtt`**,
    doc 37), aplica `sfs` nos dois ventiladores com histerese e relê `gfs`; se o firmware reescrever, o laço
    registra e avisa a home por prop. Nunca `stp`.
  - **gravada no `.ini`:** o mesmo perfil vira `FW_SPEED_CURVE`/`DEFAULT_PWM_DUTY` do `ZYCustom.ini`, para valer
    pelo firmware depois de reiniciar, mesmo sem o laço. Escrita atômica (`.new`, md5, `sync`, `mv`), cópia de
    segurança, e o kit passa a aceitar as variantes do `.ini` que só diferem nessas chaves (hoje ele compara o
    md5 inteiro com `INI_MD5_OK`).
- Rede de segurança: falhou o laço ou o pedido veio inválido → ventiladores em 1000.

## 2. Curva do LED (brilho × temperatura)

- Mesma tela, outro gráfico: temperatura × brilho. Editável **só abaixo de 70 °C**, sempre não crescente.
  WARNING 70000 e EMERGENCY 75000 travados.
- **As duas formas** (decisão do dono): ao vivo por `sbri` (com releitura; se brigar com a escada do firmware,
  o laço desiste e avisa) e gravada nos degraus da `BacklightPolicy` do `.ini`.
- Não mexer no botão Luz (`sbl`); documentar como os dois se combinam.

## 3. Descanso de tela ativo por mais de 10 min → standby

- Decisão do dono: **standby, igual ao botão do controle**, com **aviso de 60 s na tela** que qualquer tecla
  cancela. O descanso já grava `descanso-inicio`/`descanso-fim`; o vigia conta o tempo.

## 4. Debloat reversível

- O kit e a home desativam por `pm disable-user --user 0` (ou o equivalente reversível) **só** os pacotes de uma
  lista aprovada pelo dono, e voltam tudo com um arquivo no pendrive. Lista inicial aprovada: VLC e o pacote
  Office (o dono não usa). O resto vem do doc 49 (bloco 22) depois que o dono aprovar.

## Regras

- Nenhum agente fala com o projetor (nem leitura): tudo em simulação e testes. O coordenador instala com o dono.
- Arquivos deste bloco: `artifacts/home/`, `artifacts/app/`, `pendrive-autorun/` (kit, suíte, vigia, `.ini`),
  `tests/`, `docs/codigo/`, `docs/research/44-suite-de-boot.md` (seções novas), `docs/MAPA.md`. Não tocar em
  `docs/research/49-*` nem `artifacts/re-termico/` (bloco 22).
- Kit em ASCII puro, `sh` do Android (toybox/mksh), `printf`, PATH fixo, pastas só do root; listas de md5 só por
  `bash tests/atualizar-md5-kit.sh`; `versionCode` 6 nos dois apps.
- Provas: `make check`, `make check-fix`, `make check-bin` e cada `tests/test-*.sh` do `check-kit` sem falha nova
  (as falhas por falta de git e Pillow neste PC são conhecidas); `shellcheck -s sh` sem aviso no kit.

## Agentes (3)

| agente | modelo | o quê |
|---|---|---|
| F1 | Sonnet, high | implementa 1 a 4 em sequência, com testes |
| F2 | Opus, high | confere segurança térmica, kit e apps, e corrige |
| F3 | Opus, high | regressão no todo, corrige |

## Estado

- [ ] F1
- [ ] F2
- [ ] F3
- [ ] o coordenador instala no aparelho com o dono
