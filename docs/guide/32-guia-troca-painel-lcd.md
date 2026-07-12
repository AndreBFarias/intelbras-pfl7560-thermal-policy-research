# 32 - Guia leigo: trocar o painel LCD e corrigir a cor

Passo a passo para quem precisa **substituir o micro-painel LCD** do PFL7560 (queimou, manchou, morreu)
e quer a imagem **com cor certa** no fim. Escrito para leigo; sem jargão. Base técnica completa em
[`../research/28-troca-painel-rx058b-diagnostico-cor.md`](../research/28-troca-painel-rx058b-diagnostico-cor.md);
matriz de painéis testados em [`../research/33-matriz-paineis.md`](../research/33-matriz-paineis.md).

> **Aviso.** Abrir o aparelho e trocar o painel é reparo físico, por sua conta e risco. A parte de
> **software** (correção de cor) é reversível e não toca no bootloader.

---

## 0. Entenda o problema em uma frase

O PFL7560 é um projetor de **painel LCD único**. Se você troca esse painel por um de **sufixo diferente**
(ex.: o de fábrica é `RX058B-4300`; a peça de reposição comum é `RX058B-0600`), a imagem sai **nítida e
com as cores puras certas**, mas os **meios-tons ficam embaralhados** (cinza vira esverdeado/rosa). Isso
tem conserto **por software** (não precisa trocar nada de volta).

---

## 1. Identifique o painel que você tem (e o que vai comprar)

1. Com o aparelho aberto (ver teardown fotografado em
   [`../research/27-teardown-cabo-gnd-ntc.md`](../research/27-teardown-cabo-gnd-ntc.md)), olhe o **flat**
   (a fita) do painel: há um código serigrafado, tipo `FPX-RX058B-4300-V0`.
2. O painel de **fábrica** é o `RX058B-4300`. A peça de reposição mais vendida (para o projetor Thundeal
   TD96, entre outros) é o `RX058B-0600` — **drop-in mecânico** (mesmo conector, encaixe pino a pino).
3. Antes de comprar, confira a **matriz de painéis** ([doc 33](../research/33-matriz-paineis.md)): ela diz
   quais painéis já foram testados, qual o **formato LVDS** que cada um precisa (VESA ou JEIDA) e o "grau
   de plug-and-play".

---

## 2. Troque o painel (físico)

Siga o teardown ([doc 27](../research/27-teardown-cabo-gnd-ntc.md)) na ordem inversa para chegar no motor
óptico. Cuidados:
- **Estática:** aterre-se; o painel é sensível.
- **Poeira:** qualquer partícula no caminho óptico aparece gigante na projeção. Trabalhe limpo.
- **Flat:** encaixe firme e reto no conector; um flat torto dá tela preta ou linhas.

Ligue o aparelho. Você deve ter **imagem** (mesmo que com cor estranha). Se a tela ficar **preta**, o
problema é físico (flat mal encaixado ou painel incompatível de timing) — reveja o encaixe antes de mexer
em software.

---

## 3. Corrija a cor (software — reversível)

Precisa de um PC com `adb` e o projetor no **mesmo Wi-Fi** (ver [`../../INSTALL.md`](../../INSTALL.md),
"Preparar o PC"). O IP aparece em *Configurações → Wi-Fi*.

### Jeito guiado (recomendado)
```bash
PFL_IP=<ip> ./pfl7560-lcd-color.sh wizard
```
O wizard:
1. **Faz um backup** do painel automaticamente (arquivo `panelparam.wizard.img` + `.md5`). **Guarde-o.**
2. Projeta um padrão de cinzas e **aplica JEIDA**, depois **VESA**, perguntando a cada um: "os cinzas
   estão neutros (sem verde/rosa)? [s/N]". Responda `s` no que ficar **cinza neutro**.
3. Se você não responder em ~25 s (ex.: tela preta num teste avançado), ele **reverte sozinho**.
4. Ao acertar, a correção **já fica gravada** (persiste no boot). Se nada resolver, ele **restaura o
   backup** e avisa.

Ou pelo menu: `./pfl7560-menu.sh` → opção **4**. No Windows: `install.bat` → opção **6**.

### Jeito direto (se você já sabe o formato)
```bash
PFL_IP=<ip> ./pfl7560-lcd-color.sh jeida    # corrige o RX058B-0600 (o caso comum)
PFL_IP=<ip> ./pfl7560-lcd-color.sh vesa     # volta ao padrão do RX058B-4300
PFL_IP=<ip> ./pfl7560-lcd-color.sh status   # mostra o formato atual
```

---

## 4. Troubleshooting

| Sintoma | O que fazer |
|---|---|
| Meios-tons embaralhados (cinza colorido) | Rode o `wizard` ou aplique `jeida`. É o caso clássico do `-0600`. |
| Ficou **tela preta** depois de um ajuste avançado (`swap`/`bit`) | Restaure o backup: `./pfl7560-lcd-color.sh restore panelparam.wizard.img` e reinicie. |
| Cor ainda errada depois de VESA **e** JEIDA | Pode ser outro eixo — o wizard testa `swap 0..5` no fim. Se nada funcionar, o painel pode não ser compatível (ver abaixo). |
| Nenhuma imagem (preto desde o começo) | Problema **físico** (flat/timing), não software. Reveja o encaixe; confira na matriz se o painel é de timing compatível. |
| Perdi o backup e quero o padrão de fábrica | `./pfl7560-lcd-color.sh vesa` volta ao formato de fábrica (VESA). |

---

## 5. Quando NÃO tem conserto por software

A correção de cor só resolve **formato de dados** (VESA/JEIDA, ordem de bits). **Não** resolve:
- **Timing/resolução física incompatível:** se o painel novo tem outro clock/resolução nativa, dá tela
  preta ou imagem cortada — nenhum ajuste de formato conserta. Solução: comprar um painel de timing
  compatível (ver matriz) ou voltar ao `-4300` original.
- **Defeito físico do painel** (mancha, pixel morto, área apagada): é hardware.

Regra de ouro: **mantenha o backup do `panelparam`** (o wizard faz um) e **nunca** grave um painel sem
backup — assim qualquer tentativa é reversível.
