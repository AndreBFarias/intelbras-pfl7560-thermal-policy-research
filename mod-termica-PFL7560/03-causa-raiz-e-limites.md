# 03 - Causa raiz do superaquecimento e o teto do software

Contexto do usuário: polarizador + LCD trocados 2x em 18 meses; base ventilada de notebook;
ambiente da sala bem ventilado; "10 minutos e está ultra quente"; crítica comum ao modelo.

## Por que a óptica queima (mecanismo)

Num projetor **LCD**, a luz da fonte (LED de alta potência) atravessa os polarizadores e o painel LCD.
Os polarizadores **absorvem** parte da luz e a convertem em **calor concentrado** exatamente no filme polarizador
e no vidro do LCD. Se esse calor não for removido rápido, o polarizador degrada (mancha, escurece, "queima").

Ou seja: a fonte do calor que mata a óptica é a **própria luz**, proporcional ao **brilho**. Um aparelho classe
"8000 lúmens" empurra muita luz -> muito calor no polarizador. Esse é o ponto central.

## Por que a proteção de firmware não está salvando a óptica

1. **Sensor no lugar errado.** Os 2 NTC medem **ar/placa**, não a junção do polarizador. `WARNING=43 C` / `EMERGENCY=45 C`
   são números baixos, típicos de temperatura de ar. O polarizador pode estar a 80-90 C enquanto o NTC lê < 43 C ->
   a proteção **nunca dispara** para a óptica. É indireta e atrasada.
2. **Fan sem headroom.** Os fans saturam em 100% já a 36 C sensados. Acima disso, o firmware só pode escurecer
   (até 75%) ou desligar. Se o **duto/soprador** não move ar suficiente, 100% não basta.
3. **Brilho alto por padrão.** Quando "frio", roda a 100% de brilho -> calor máximo na óptica justamente enquanto o
   NTC ainda está baixo e a proteção dormindo.

## O que o software PODE fazer (e o que não pode)

| Alavanca | Ajuda a óptica? | Observação |
|---|---|---|
| **Reduzir/limitar o brilho** | **SIM, muito** | corta o calor na FONTE; maior alavanca de software. Num home theater de sala, cair p/ ~80% é quase imperceptível e derruba muito o calor no polarizador. |
| **Fans a 100% mais cedo + piso alto** | Sim, marginal | os fans já vão a 100%; só antecipamos. Ganho real limitado pelo hardware do soprador. |
| **Dimming mais cedo/agressivo** | Sim | é a mesma alavanca do brilho, atada à temperatura. |
| **Desligar antes (WARNING/EMERGENCY menores)** | Rede de segurança | evita dano catastrófico; troca autonomia por vida útil. Só calibrar com dados reais do NTC. |
| **Undervolt de CPU/SoC** | **Praticamente NAO** | ver abaixo. |
| **Trocar hardware (soprador/duto/heatsink no polarizador)** | Sim (cura) | fora de escopo de software; mencionado por completude. |

## O mito do undervolt (por que NAO resolve aqui)

Undervolt reduz o calor da **CPU/SoC**. Mas:
- O calor que queima o polarizador vem do **LED/óptica**, não do SoC. Baixar a tensão do Hi3751 não esfria a lente.
- O throttling térmico da CPU já existe no driver `hi3751-cpufreq` (boost/buck de tensão + corte de clock por temperatura),
  mas os limiares são **valores de registrador em runtime**, não um `.ini` editável -> mexer exigiria recompilar o kernel/driver.
- Custo alto (rebuild de kernel), payoff ~nulo para o problema real.

**Conclusão:** o "undervolt que importa" neste aparelho é **subvoltar a fonte de luz** — ou seja, **reduzir o brilho
(PWM do LED)**, que é exatamente o que fazemos via `[Backlight]`/`[BacklightPolicy]` no `ZYCustom.ini`. Isso entrega o
"mais agressivo" que você quer, mirando a fonte de calor certa.

## Sinceridade sobre o teto

Se, com brilho reduzido, fans a 100% desde cedo e airflow externo bom, o aparelho **ainda** cozinha em 10 min,
o gargalo é **hardware** (CFM do soprador, duto, ausência de dissipação no bloco óptico). Nesse cenário, o software
protege (desligando antes de destruir a óptica) e reduz a carga (menos brilho), mas a cura seria hardware.

Por isso o **passo 1 é diagnóstico**: ler os NTCs ao vivo (`gtt`) durante um aquecimento de 10 min, com e sem fans
forçados a 100% e com brilho reduzido, para medir quanto cada alavanca realmente move a temperatura. Só então
fixamos os números da build (especialmente o limiar de desligamento) com base em dados, não em chute.
