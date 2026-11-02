# Tarefa - O logo do boot se refaz sozinho quando o keystone muda (2026-11-01, bloco futuro)

**Pedido do dono (2026-11-01):** "Reto agora + auto de verdade". O logo do boot tem que acompanhar os cantos do
keystone sem o PC.

**Medido.** O carregador mostra a partição `logo` antes do Android: um JPEG fixo (`LOGO_TABLE`, JPEG no byte 8192,
`LOGO_KEY_LEN` em 0x78), sem SVG e sem keystone. Hoje quem distorce e grava é o PC (`pfl7560-marca.sh` +
`gerar-marca.py`, Pillow). Em 2026-11-01 o keystone foi zerado (doc 46 §13) e o logo regravado reto (backups em
`backups-projetor/logo/`).

**Cura na origem.** Um programa nativo (NDK r27c, já no `install.sh --dev`) no kit que, no fim da suíte, compara
os cantos `persist.sys.keystone.*` com os cantos com que o logo gravado foi feito (guardados numa pasta do root).
Se diferirem, ele refaz o JPEG pela mesma conta do `gerar-marca.py` (perspectiva, bicúbico, qualidade 95, 4:4:4) e
grava só as duas regiões, com os mesmos cuidados do `pfl7560-marca.sh`: backup da partição, conferência do
`LOGO_TABLE`, md5 antes e depois, e desistência sem gravar a qualquer falha.

**Riscos a decidir antes.** O aparelho passa a gravar a partição do carregador sem o dono ver. Limite de
gravações por dia, cantos absurdos recusados, e um arquivo no pendrive que desliga a função.

**Como provar.** Teste no PC: a saída do programa nativo bate com a do `gerar-marca.py` (diferença de pixel
pequena) para cantos retos e tortos. No aparelho: mudar o keystone, ligar, reler a `logo` e conferir.
