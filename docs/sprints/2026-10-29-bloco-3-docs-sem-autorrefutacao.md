# Bloco 3 - documentação sem autorrefutação (2026-10-29)

Pedido do dono: **"quero saber tudo e atualizar tudo. Nada se autorrefuta em termos de documentação."**
Roda **depois** dos blocos 1 e 2, para descrever o comportamento novo dos scripts.

Arquivos do bloco: todo `.md` e `.html` fora de `docs/archive/` (o archive é histórico: só recebe
ressalva no topo quando um doc vivo o cita como válido), `README.md`, `INSTALL.md`, `REQUIREMENTS.md`,
`media/README.md`, `artifacts/**/README.md`. Fora: `pendrive-autorun/LEIA-ME.txt` (bloco 1).

## Regra de saída

Para cada afirmação factual que um registro mais novo derrubou ou atualizou:
- no doc antigo, corrigir o texto **ou** pôr ressalva datada na linha, apontando para o doc que manda
  (estilo já usado no repo: `> **CORREÇÃO (AAAA-MM-DD)** ...`);
- nenhum par de docs vivos pode afirmar valores diferentes para o mesmo fato sem que um aponte para o
  outro como superado;
- todo ID de pendência (OPT-S*, LCD-S*, BIN-S*, FAN-S*, LSADC-S*, POL-S* ...) tem **um** status atual,
  igual em todos os docs que o citam;
- links internos continuam íntegros (arquivo e âncora).

## Itens já conhecidos (ponto de partida, não teto)

1. Docs que mandam esperar `jeida`: `39:664`, `38:204,320-321`, `guide/36:112-113`, `31:98`,
   `guide/32:15-17,70,81,83`, `33:16-21` (falta a linha do painel da 2ª troca, VESA), `INSTALL.md:168-173`,
   `docs/README.md:51`, `artifacts/lcd-color-fix/README.md:7-8`, e a ilustração
   `media/guia-ordem-pecas-opticas.jpg` (ressalva já no `media/README.md`).
2. Doc 28: §12.1 sem marca de refutada pela §13; "só o bit 4" contradiz a tabela VESA/JEIDA do kernel
   (desloca 2 bits em todos os canais, fonte no doc 40 §5); `28:23-24` "correção ainda não fechada".
   Acrescentar ao guia 32 o diagnóstico "primárias certas + preto/cinza tingido = formato, não troca
   de canal; barras puras antes de qualquer `swap`".
3. `README.md:26-32` e resumo de `34:19-22`: FanMonitor como bug de config; o veredito FAN-S1 (34:276,459)
   é inarmável por software.
4. `39:291-292`, `34:98`: "vive em 61-63 °C, a escada não atua" ficou desatualizado (doc 40 §2). `34:3-4,12-13`
   vs `34:462` e `39:197,293` sobre o alarme real de 70 °C.
5. Ventiladores: `27:12,45-47,74`, `38:39`, `disclosure/roteiro-evidencias.md:65`, título de `39:82`
   vs `39:116`; fonte Amazon errada no doc 07 (é Skywalking 8025S). Estado: 2 blowers DFH8030S 12 V 0,45 A
   controlados + 1 fan axial do LED; contagem final OPT-S6.
6. Status divergentes: OPT-S3/S4 (38 vs 39), BIN-S3b (31 vs archive/18 e `artifacts/bin-build/README.md`),
   LCD-S1/S2 (29, 31 vs commit a9d3fa2), OPT-S13 vs etapa 3 do 31.
7. "`gtt1` = óptica" é rótulo, não medição (`39:221-222`, `34:29`, coluna `optica_C`): chamar de
   "sensor quente (`gtt1`), posição não verificada (OPT-S7)" até fechar; doc 27 separar o olhal solto
   do terminal parafusado no bloco do LED.
8. Doc 39 §4.1: conclusão "a peça velha era o gargalo" e a previsão por ambiente ganham a ressalva do
   doc 40 §2 (`gtt0` abaixo da sala; âncora de ambiente suspeita).
9. Doc 07: números de vazão do DFH8025S sem fonte (doc 40 §5).
10. Os scripts mudados nos blocos 1 e 2: cada doc que descreve o comportamento antigo é atualizado.

## Prova

Um conferente independente relê o diff e faz busca dirigida por cada fato do doc 40 e por cada ID de
pendência, listando qualquer par de docs ainda em conflito. Zero pares = bloco fechado.
