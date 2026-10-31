# Tema Drácula - o que é nosso, na mesma paleta (bloco 10B)

Pedido do dono (2026-10-31): "um novo tema pra background e layout pra tudo. Gosto da paleta drácula
theme". Contrato em `docs/sprints/2026-10-31-bloco-10-home-e-tema-dracula.md`. A home nova (10A,
`artifacts/home/`) copia os mesmos valores.

| Arquivo | O que é |
| --- | --- |
| `dracula.txt` | a paleta oficial (draculatheme.com/contribute), uma linha `token=#RRGGBB`; fonte única dos geradores |
| `gerar-fundo.py` | gera `fundo-dracula.png` (1920x1080), só biblioteca padrão, reprodutível |
| `fundo-dracula.png` | o plano de fundo: gradiente sutil `fundo` → `linha` com um arco fino em `roxo`, sem texto |
| `gerar-previa.py` | gera `previa/telas.png` (Pillow), a folha de contato das telas da suíte e do fundo |
| `previa/telas.png` | as 9 telas de exemplo da suíte e o fundo, lado a lado, para o dono olhar |

    python3 -I artifacts/tema/gerar-fundo.py
    bash tests/test-tela.sh && python3 -I artifacts/tema/gerar-previa.py

Fontes: IBM Plex Sans Condensed (títulos e rótulos) e IBM Plex Mono (valores), as de
`pendrive-autorun/fontes/` (OFL). Nenhuma fonte nova. Texto com maiúscula no início de frase e de
rótulo, português com acento na tela, zero emoji.

## O que cada token faz em cada tela

| Token | Hex | Telas da suíte (`nl_tela`) | App Verificar/Wi-Fi | Plano de fundo |
| --- | --- | --- | --- | --- |
| `fundo` | `#282A36` | fundo de tudo | fundo das mensagens e dos ícones | início do gradiente |
| `linha` | `#44475A` | cartões (grupos, passos, faixa de dicas) | cartão do ícone | fim do gradiente (canto de baixo, à direita) |
| `texto` | `#F8F8F2` | títulos, nomes dos passos, dicas | título da mensagem, traço do ícone | - |
| `comentario` | `#6272A4` | fio entre os itens do cartão (não é texto: ver abaixo) | contorno do ícone | - |
| `ciano` | `#8BE9FD` | estado info (valor e ponto) | - | - |
| `verde` | `#50FA7B` | estado ok | visto do Verificar | - |
| `laranja` | `#FFB86C` | estado corrigido | - | - |
| `rosa` | `#FF79C6` | o passo em andamento (contorno de 3 px, ponto e "Agora") | - | - |
| `roxo` | `#BD93F9` | marca: "Etapa N de 5" do aviso, título dos grupos do resumo | ponto do Wi-Fi | o arco |
| `vermelho` | `#FF5555` | atenção sobre o fundo: título do alerta, destaque "3 avisos." | título de erro | - |
| `amarelo` | `#F1FA8C` | estado pendente (valor e ponto vazado) | - | - |

Moderação do vermelho: no aviso de alerta só o título e o estado do passo que falhou ficam vermelhos;
o parágrafo segue no secundário e os outros passos não mudam. Um acento por papel: o roxo marca a
etapa e os grupos e nada mais; o rosa marca só o passo em andamento (na home, o foco do controle).

## Dois tons derivados, por contraste (registrado)

Todo texto das telas tem 24 px ou mais (texto grande para a WCAG: piso de 3:1), mas o projetor lava o
contraste, então a meta é 4,5:1 sempre que der. Dois tokens não chegam lá onde são usados, e cada um
ganhou um tom acima, misturado com `texto` em sRGB:

| Tom | Hex | Como | Onde | Por quê |
| --- | --- | --- | --- | --- |
| secundário | `#B4BCCF` | `comentario` + 55% de `texto` | rótulos, canto, rodapé, parágrafo, "Na fila", número do passo; no app, o texto da mensagem | `comentario` puro dá 3,03:1 no fundo e 1,94:1 no cartão |
| atenção no cartão | `#FE7674` | `vermelho` + 20% de `texto` | valor, ponto e palavra de atenção dentro do cartão; marcador das dicas | `vermelho` puro dá 2,91:1 sobre `linha` (abaixo até do piso de 3:1) |

O `comentario` puro ficou para o que não é texto: o fio entre itens e o contorno do ícone. O vermelho
no cartão não foi além de 20% de mistura porque, mais claro, ele vira salmão e se confunde com o rosa
e com o laranja.

Contraste medido (WCAG 2, luminância relativa), sobre `fundo` / sobre `linha`:

| Cor | fundo | linha |
| --- | --- | --- |
| texto `#F8F8F2` | 13,36 | 8,59 |
| secundário `#B4BCCF` | 7,48 | 4,81 |
| verde `#50FA7B` | 10,38 | 6,67 |
| ciano `#8BE9FD` | 10,29 | 6,61 |
| amarelo `#F1FA8C` | 12,74 | 8,19 |
| laranja `#FFB86C` | 8,36 | 5,37 |
| roxo `#BD93F9` | 5,90 | 3,79 (título de grupo, SemiBold 30) |
| rosa `#FF79C6` | 5,97 | 3,84 ("Agora", Mono 24) |
| vermelho `#FF5555` | 4,53 | (não usado sobre `linha`) |
| atenção no cartão `#FE7674` | - | 3,51 (valor Mono SemiBold 34, palavra Mono 24) |
| comentario `#6272A4` | 3,03 | 1,94 (só no fio, que não é texto) |

Os abaixo de 4,5:1 (roxo, rosa e atenção sobre o cartão) estão todos em texto de 24 px ou mais e
passam o piso de 3:1; ficam como pendência de olhar no aparelho (ver o fim).

## Plano de fundo do sistema: como pôr (não aplicado)

Nada foi aplicado no aparelho. O que existe no Android 9 deste firmware:

1. **Pelo app (o caminho limpo).** `WallpaperManager.getInstance(ctx).setStream(in, null, true,
   WallpaperManager.FLAG_SYSTEM)` com a permissão `android.permission.SET_WALLPAPER`, que é de nível
   *normal* (concedida na instalação, não é perigosa). O app Verificar hoje não tem permissão nenhuma;
   quem fizer isso (a home 10A ou um bloco seguinte) declara a permissão e leva o PNG em `res/drawable-nodpi/`.
2. **Pela linha de comando.** Conferir no aparelho se há o serviço com comando de shell:
   `adb shell cmd -l | grep -i wallpaper` e, se houver, `adb shell cmd wallpaper` para ver os
   subcomandos. Não há confirmação de que o Android 9 tenha esse comando; sem ele, use o item 1.
3. **Por intent.** `am start -a android.intent.action.ATTACH_DATA -t image/png -d file:///sdcard/fundo-dracula.png`
   abre o "Definir como" de quem trata a imagem. A lista de pacotes do firmware (pesquisa P) não tem
   seletor de papel de parede, só `com.android.wallpaperbackup`, então é provável que nada responda.
4. **Como root, copiando o arquivo** para `/data/system/users/0/wallpaper` (dono `system`, 0600):
   frágil (o serviço recorta a partir de `wallpaper_orig` e só relê no boot). Não recomendado.

Duas ressalvas: o launcher de fábrica (`com.newlink.hisilauncher`) pode desenhar o próprio fundo e
nem mostrar o papel de parede do sistema; e para a home 10A o mais simples é usar o PNG como fundo da
própria janela, sem depender do papel de parede.

## O que ficou de fora, de propósito

- **`pendrive-autorun/kit/*.png`** (aguarde, calibração, corrigida, erro, escada-1, escada-2, pronto,
  reiniciando). Têm gerador (`tests/gerar-padroes-kit.py`), mas não são telas de interface: são os
  padrões de diagnóstico do formato do painel (VESA x JEIDA). O texto delas fica só em preto e branco
  puros (0 e 255) e a escada em cinzas, porque só esses valores sobrevivem iguais à rotação de bits do
  formato errado; o `tests/simula-padroes-kit.py` confere isso. Pintá-las de Drácula quebraria a
  função delas. Não foram tocadas.

## Pendente (aparelho)

- Ver as telas da suíte no projetor: o contraste do roxo, do rosa e do vermelho sobre o cartão
  (3,5 a 3,8:1) com a luz da sala; se algum sumir, subir o tom como na tabela acima.
- Ver os ícones novos na lista de apps (o APK subiu para `versionCode` 2: o kit reinstala por cima).
- Se o plano de fundo for aplicado (pela home ou pelo app), conferir se o arco roxo de 3 px aparece
  e se o gradiente não faz faixas no projetor.
