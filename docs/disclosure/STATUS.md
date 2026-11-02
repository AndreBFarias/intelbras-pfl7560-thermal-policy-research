# Divulgação e publicação: o estado

Tudo o que é divulgação à fabricante e publicação do repositório mora aqui. O texto do envio é o
[`relatorio-csirt.md`](relatorio-csirt.md); o roteiro das provas, o [`roteiro-evidencias.md`](roteiro-evidencias.md).

## Divulgação responsável

| Campo | Valor |
|---|---|
| **Estado** | Relatório preparado; **ainda não enviado** |
| **Canal** | CSIRT Intelbras — https://www.intelbras.com/pt-br/CSIRT-Intelbras |
| **Fallback** | suporte@intelbras.com.br / SAC (mesmo relatório) |
| **Data de envio** | _preencher após o envio_ |
| **Protocolo / nº** | _preencher após o envio_ |
| **Resposta** | — |
| **Repo público** | Somente após 7–10 dias úteis do envio (ou resposta da fabricante) e depois dos pré-requisitos abaixo |
| **Defeito no firmware mais novo** | Persiste no V1.0.0.1 publicado em 2026-10-20 (modelo sem USB-C; [doc 42](../research/42-firmware-2026-10-modelo-sem-usbc.md)). Nota datada no relatório e no rascunho antigo de e-mail ([doc 11](../archive/11-email-intelbras.md), arquivado) |

**Follow-up:**

- D+7–10 úteis sem resposta → follow-up educado no mesmo canal.
- D+30–45 sem retorno sério → divulgação pública completa (atualizar o README).

## Impacto no consumidor

Em condições normais de uso, o defeito de configuração térmica favorece **superaquecimento da óptica** e a
troca recorrente de polarizador e LCD (no aparelho desta pesquisa: **duas trocas em 18 meses**).

Sob o **Código de Defesa do Consumidor** (Lei 8.078/1990):

- **Art. 18** — o fornecedor responde por **vícios de qualidade** que tornem o produto **impróprio ou
  inadequado ao consumo** a que se destina, ou lhe diminuam o valor.
- **Art. 25** — é vedada a exoneração contratual do fornecedor pela reparação dos danos causados por defeitos
  relativos a produtos (incluindo a cadeia de fornecimento, nos termos da lei).

Quando o vício decorre de **configuração sistemática de firmware** (e não de mau uso isolado), há base para
discutir **inadequação ao uso ordinário** e, em escala, eventual **responsabilidade coletiva**. Este repositório
não substitui assessoria jurídica; documenta fatos técnicos e medições para o consumidor, a assistência e a
fabricante.

## Antes de tornar o repositório público (REPO-S2)

Vindo do [doc 30](../archive/30-sprint-validacao-repositorio.md) (arquivado). Nenhum destes foi feito ainda.

1. **Firmware proprietário.** Os zips de `firmware/` são da Intelbras e estão no LFS; o ponteiro fica no
   histórico e o objeto iria junto para um remote público. Decidir entre expurgar do LFS e do histórico ou
   publicar um repositório separado, sem os zips.
2. **E-mail pessoal no histórico de commits.** Decidir entre aceitar, reescrever o histórico ou usar o e-mail
   `noreply` daqui em diante.
3. **Fotos.** 6 das 8 fotos de `media/` precisam de recorte ou desfoque antes (número de série e código de
   barras, data-matrix de placa, reflexo de pessoa). O checklist por foto está no
   [`media/README.md`](../../media/README.md); guarde as cópias sem redação fora do git.
4. **Binários ARM versionados** (`lvdsctl`, `nl_camcheck`, `nl_tela`, APKs): confirmar que cada um tem md5
   fixado e o modo de compilar no README da pasta, para ser auditável.
