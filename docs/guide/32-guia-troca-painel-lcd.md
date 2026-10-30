# 32 - Guia leigo: trocar o painel LCD e corrigir a cor

Passo a passo para quem precisa **substituir o micro-painel LCD** do PFL7560 (queimou, manchou, morreu)
e quer a imagem **com cor certa** no fim. Escrito para leigo; sem jargão. Base técnica completa em
[`../research/28-troca-painel-rx058b-diagnostico-cor.md`](../research/28-troca-painel-rx058b-diagnostico-cor.md);
matriz de painéis testados em [`../research/33-matriz-paineis.md`](../research/33-matriz-paineis.md).

> **Aviso.** Abrir o aparelho e trocar o painel é reparo físico, por sua conta e risco. A parte de
> **software** (correção de cor) é reversível e não toca no bootloader.

---

## 0. Entenda o problema em uma frase

O PFL7560 é um projetor de **painel LCD único**. O SoC manda a imagem ao painel em LVDS, num de dois
formatos, **VESA** ou **JEIDA**. Se o formato não casa com o painel instalado, a imagem sai **nítida e com
as cores puras certas**, mas o **preto e os cinzas saem tingidos** (verde num padrão, laranja noutro: a
cor muda com a imagem). Isso tem conserto **por software** (não precisa trocar nada de volta).

> **O formato não se deduz do nome do painel.** Neste aparelho, o `RX058B-0600` da 1ª troca (2026-07-10)
> pediu **JEIDA**; o `FPX-RX058B-4300-V0` `20241101 HT` da 2ª troca (2026-10-29), o mesmo modelo e data
> do painel de fábrica, pediu **VESA**, e o aparelho está hoje em VESA
> ([doc 40](../research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §1). Quem decide é o teste
> de cinza da seção 3.

---

## 1. Identifique o painel que você tem (e o que vai comprar)

1. Com o aparelho aberto, olhe o **flat** (a fita) do painel: há um código serigrafado, tipo
   `FPX-RX058B-4300-V0`. A ordem das peças do motor óptico está no
   [doc 38](../research/38-motor-optico-e-troca-do-polarizador.md) §1.
2. O painel de **fábrica** é o `RX058B-4300`. A peça de reposição mais vendida (para o projetor Thundeal
   TD96, entre outros) é anunciada como `RX058B-0600` — **drop-in mecânico** (mesmo conector, encaixe
   pino a pino). Confira o código no flat da peça que chegou: o anúncio não garante o formato.
3. Antes de comprar, confira a **matriz de painéis** ([doc 33](../research/33-matriz-paineis.md)): ela diz
   quais painéis já foram testados neste aparelho, que formato cada um pediu e o "grau de plug-and-play".

---

## 2. Troque o painel (físico)

O acesso ao motor óptico está no [doc 38](../research/38-motor-optico-e-troca-do-polarizador.md) §5.1 (o
teardown do [doc 27](../research/27-teardown-cabo-gnd-ntc.md) para no gabinete e não chega ao motor
óptico). Cuidados:
- **Estática:** aterre-se; o painel é sensível.
- **Poeira:** qualquer partícula no caminho óptico aparece gigante na projeção. Trabalhe limpo.
- **Flat:** encaixe firme e reto no conector; um flat torto dá tela preta ou linhas.

Ligue o aparelho. Você deve ter **imagem** (mesmo que com cor estranha). Se a tela ficar **preta**, o
problema é físico (flat mal encaixado ou painel incompatível de timing) — reveja o encaixe antes de mexer
em software.

---

## 3. Corrija a cor (software — reversível)

Antes de qualquer ajuste, projete **barras de cor puras** e um **padrão de cinza**:

- **primárias certas + preto/cinzas tingidos** = formato (VESA/JEIDA). É o caso comum; siga abaixo.
- **uma primária no lugar da outra** (vermelho saindo azul, por exemplo) = troca de canal. Só nesse caso
  faz sentido o `swap` do modo avançado.

Não use `swap` para "consertar" cinza tingido: com primárias certas, o problema não é troca de canal.

### Sem PC (recomendado para leigo): kit de pendrive

O kit do Método 1 do [`../../INSTALL.md`](../../INSTALL.md) (ver `pendrive-autorun/LEIA-ME.txt`) aplica a
correção térmica e faz o teste de cor das **"duas metades"**: uma tela com duas metades de cinza quase
iguais (63 e 64), que só ficam **visivelmente diferentes** quando o formato está errado
([doc 41](../research/41-auto-pareamento-camera-e-kit-universal.md) §4).

1. Metades **iguais**: não aperte nada. Em 30 s ele segue e a cor não é mexida.
2. Metades **diferentes**: aperte qualquer tecla do controle. O kit troca o formato e mostra de novo.
3. Agora iguais? Aperte de novo para **manter**. Continuam diferentes? Não aperte: em 30 s ele volta ao
   formato de antes.

Antes de trocar, o kit faz backup da `panelparam` (conferido com `cmp`) e grava um journal: se faltar
energia no meio do teste, o formato original volta no boot seguinte. Rodar de novo é inofensivo.
**Limite:** o kit v2 foi provado só em simulação; a bancada no aparelho (etapa E4 do
[bloco 5](../sprints/2026-10-29-bloco-5-kit-universal.md)) ainda não foi feita.

### Com PC: wizard guiado

Precisa de um PC com `adb` e o projetor no **mesmo Wi-Fi** (ver [`../../INSTALL.md`](../../INSTALL.md),
"Preparar o PC"). O IP aparece em *Configurações → Wi-Fi*.

```bash
PFL_IP=<ip> ./pfl7560-lcd-color.sh wizard
```
O wizard:
1. **Faz um backup** do painel antes de mexer (arquivo `panelparam.wizard.img` + `.md5`, conferido pelo
   tamanho da partição). Se o backup falhar, ele **não grava nada**. **Guarde o arquivo.**
2. Projeta um padrão de cinzas e **aplica JEIDA**, depois **VESA**, perguntando a cada um: "os cinzas
   estão neutros (sem verde/rosa)? [s/N]". Responda `s` no que ficar **cinza neutro**.
3. Se nenhum dos dois servir, testa os eixos avançados (`swap 0..5`) sobre o formato que estava em uso.
   Se você não responder em ~25 s (ex.: tela preta), ele **reverte sozinho**.
4. Ao acertar, a correção **já fica gravada** (persiste no boot). Se nada resolver, ele **restaura o
   backup** e avisa.

Ou pelo menu: `./pfl7560-menu.sh` → opção **4**. No Windows: `install.bat` → opção **6** (aplica JEIDA
ou VESA com backup antes; o wizard completo usa WSL).

### Com PC: jeito direto (se você já viu qual formato deixa o cinza neutro)
```bash
PFL_IP=<ip> ./pfl7560-lcd-color.sh status   # mostra o formato em uso
PFL_IP=<ip> ./pfl7560-lcd-color.sh jeida    # aplica JEIDA (foi o caso do -0600 da 1ª troca)
PFL_IP=<ip> ./pfl7560-lcd-color.sh vesa     # aplica VESA (painel de fábrica e o da 2ª troca)
```
`jeida` e `vesa` **gravam** na `panelparam`: antes, fazem o backup do dia
(`panelparam.backup-<serial>-<data>.img` + `.md5`) e abortam se ele falhar. `swap` e `bit` pedem
confirmação explícita.

---

## 4. Troubleshooting

| Sintoma | O que fazer |
|---|---|
| Primárias certas, preto/cinza tingido (a cor muda com a imagem) | Formato errado. Rode o kit de pendrive ou o `wizard`. |
| Uma primária no lugar da outra | Troca de canal: só aqui o `wizard` avançado (`swap`) faz sentido. |
| Ficou **tela preta** depois de um ajuste avançado (`swap`/`bit`) | Restaure o backup: `./pfl7560-lcd-color.sh restore <arquivo .img>` e reinicie. |
| Cor ainda errada depois de VESA **e** JEIDA | Pode ser outro eixo — o wizard testa `swap 0..5` no fim. Se nada funcionar, o painel pode não ser compatível (ver abaixo). |
| Nenhuma imagem (preto desde o começo) | Problema **físico** (flat/timing), não software. Reveja o encaixe; confira na matriz se o painel é de timing compatível. |
| Perdi o backup e quero o padrão de fábrica | `./pfl7560-lcd-color.sh vesa` volta ao formato de fábrica (VESA). |
| A cor errou de novo depois de **regravar o firmware de fábrica** | O reflash provavelmente devolveu o byte ao de fábrica (VESA): a `panelparam` parece estar no `.bin` ([doc 42](../research/42-firmware-2026-10-modelo-sem-usbc.md) §5). Refaça o teste de cor. |

---

## 5. Quando NÃO tem conserto por software

A correção de cor só resolve **formato de dados** (VESA/JEIDA, ordem de bits). **Não** resolve:
- **Timing/resolução física incompatível:** se o painel novo tem outro clock/resolução nativa, dá tela
  preta ou imagem cortada — nenhum ajuste de formato conserta. Solução: comprar um painel de timing
  compatível (ver matriz) ou voltar ao `-4300` original.
- **Defeito físico do painel** (mancha, pixel morto, área apagada): é hardware.

Regra de ouro: **mantenha o backup do `panelparam`** e **nunca** grave um painel sem backup — as
ferramentas do repositório já se recusam a gravar sem ele, e assim qualquer tentativa é reversível.
