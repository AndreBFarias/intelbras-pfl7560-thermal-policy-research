# 11 - Rascunho de email para a Intelbras

Pronto para enviar (ajuste nome/dados). Canais: suporte@intelbras.com.br · forum.intelbras.com.br · SAC 0800 7042767.

> **NOTA (2026-10-30) — o texto abaixo não foi alterado; vale acrescentar ao envio:**
> 1. **O defeito persiste em outubro de 2026.** O firmware publicado pela Intelbras em 2026-10-20 ("para
>    produtos com data de fabricação a partir de 25/08/2026") é o modelo sem USB-C, `V1.0.0.1` (build de
>    2026-08-08). A térmica é idêntica: os dois termistores seguem com `HW_VIRTUAL_CHANNEL = 0` e a
>    `libhitvservice.so` é byte-idêntica ([doc 42](../research/42-firmware-2026-10-modelo-sem-usbc.md) §3 e "Lições").
> 2. **Onde fica o 2º sensor:** é um NTC encapsulado num olhal no topo do **bloco dissipador do LED**
>    (light engine), não junto do polarizador/LCD; nenhum sensor do aparelho mede o polarizador
>    ([doc 40](../research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3). "Próximo à óptica" abaixo deve
>    ser lido assim.

---

**Assunto:** PFL7560 — defeito de firmware desliga a proteção térmica e queima o polarizador/LCD (com causa-raiz e correção)

Prezados,

Sou proprietário de um projetor **PFL7560** e quero reportar um **defeito de firmware** que, na minha avaliação
técnica, é a causa de um problema recorrente de superaquecimento — no meu caso, **troquei o polarizador e o LCD
duas vezes em 18 meses**.

**Resumo do defeito:** o produto tem **dois sensores de temperatura (NTC)**, mas o firmware (versão
**V1.0.0.9:2026-06-17**) está configurado de forma que **o segundo sensor — justamente o que fica próximo do bloco
óptico/light-engine — nunca é lido**. O sistema só lê o primeiro NTC, que mede a temperatura do ar da placa
(~26 °C), e por isso **acredita que o aparelho está frio mesmo quando ele está superaquecido**. Consequência: os
ventiladores ficam em rotação baixa e a proteção térmica **nunca dispara**, enquanto a óptica cozinha.

**Evidência técnica (medida no próprio aparelho):**
- Com o aparelho em uso, a **saída de ar mediu acima de 43 °C** (termômetro saturou), enquanto a leitura interna
  de temperatura do sistema permanecia travada em **~26 °C**.
- No arquivo de configuração do firmware (`/vendor/etc/ZYCustom.ini`), as duas seções de termistor
  (`[Thermistor_0]` e `[Thermistor_1]`) estão **ambas** com `HW_VIRTUAL_CHANNEL = 0`. Como o multiplexador
  (BL1551B, GPIO4_4) só comuta quando o canal difere, ele **fica preso no canal 0 e nunca seleciona o 2º NTC**.
- Ao corrigir para `HW_VIRTUAL_CHANNEL = 1` no segundo termistor, o 2º sensor passou a ler a temperatura real:
  **59 °C** (com os ventiladores no máximo), e o firmware finalmente emitiu o alerta de superaquecimento —
  algo que **nunca acontecia** na configuração de fábrica.
- Também constatei que forçar os ventiladores a 100% reduziu a saída de ar de **46,7 °C para 37,2 °C**, ou seja,
  há folga de refrigeração que o firmware não usa por causa do sensor cego.

**Impacto:** sem a proteção térmica funcionando, o polarizador e o painel LCD superaquecem e degradam
(manchas, perda de brilho, "queima"), gerando custo recorrente de reparo para o consumidor.

**Correção sugerida (firmware):**
1. Ativar o segundo NTC: `HW_VIRTUAL_CHANNEL = 1` em `[Thermistor_1]` (ou revisar o mapeamento do mux).
2. Fazer a curva de ventilador e o desligamento de emergência **usarem a leitura do sensor próximo à óptica**.
3. Revisar os limiares de `[Thermal]` (WARNING/EMERGENCY) para valores coerentes com a temperatura real da óptica.

**Observações adicionais de qualidade do firmware V1.0.0.9:**
- Após reinicialização, o aparelho **não reconecta ao Wi-Fi automaticamente** (vários erros de `WifiVendorHal`).
- A imagem é uma build de engenharia (`userdebug` / `dev-keys`) com SELinux em modo permissivo e diversas
  negações de política (`avc denied`) — indícios de uma release sem o hardening de produção.

Coloco-me à disposição para fornecer os detalhes técnicos completos (logs, medições e a análise do binário).
Peço que encaminhem ao time de engenharia/P&D responsável pelo firmware, pois trata-se de um problema de
**segurança do produto e de proteção ao consumidor**, não de um caso isolado.

Atenciosamente,
[Seu nome]
[Modelo: PFL7560 — Nº de série / nota fiscal, se quiser anexar]

---

**Dica:** anexe 2-3 fotos (o termômetro marcando >43 °C na saída de ar e a tela de "Informações do sistema" com a
versão V1.0.0.9). Fortalece muito o report.
