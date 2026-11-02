package com.pfl7560.home;

/**
 * Quais entradas tem cabo (bloco 30). Java puro: o mesmo codigo no aparelho e nas previas.
 *
 * O sinal e o estado das entradas de TV do hardware HDMI no TvInputManager (API publica, sem permissao). O
 * system_server ouve o hotplug HDMI de cada porta (HdmiControlService, o mesmo que o HiTvService usa para o aviso
 * "Dispositivo conectado") e marca a entrada da porta: 0 (INPUT_STATE_CONNECTED) com cabo, 1 sem. A entrada do
 * hardware se chama "<servico>/HDMI0000C<porta>" (HiHdmiTvInputService, HdmiDeviceInfo(0, porta)) e a porta e a
 * fonte menos 8 (zysys.source.hdmi1=11 -> 3, hdmi2=10 -> 2, typec1=9 -> 1), a mesma conta do HDMIService e do
 * teste de fabrica (NLAutoTest). Doc 45 §14.
 */
public final class Entradas {
    /** TvInputManager.INPUT_STATE_CONNECTED. */
    public static final int LIGADO = 0;
    /** A porta nao aparece entre as entradas de TV: nao da para saber. */
    public static final int DESCONHECIDO = -1;
    /** Portas HDMI do HiSilicon: 1..15. */
    public static final int PORTAS = 16;

    public static final int PADRAO_HDMI1 = 11;
    public static final int PADRAO_HDMI2 = 10;
    public static final int PADRAO_USBC = 9;

    public static final Item HDMI1 = new Item("HDMI 1", Icones.HDMI, Acoes.HDMI1);
    public static final Item HDMI2 = new Item("HDMI 2", Icones.HDMI, Acoes.HDMI2);
    public static final Item USBC = new Item("USB-C", Icones.USB_C, Acoes.USBC);

    private static final String PREFIXO = "/HDMI";
    private static final int ID_HARDWARE = 0xC0;

    private Entradas() {
    }

    /** A porta HDMI de uma fonte (valor de zysys.source.*): fonte - 8; vazio ou lixo usa o padrao; -1 se nao da. */
    public static int porta(String fonte, int padrao) {
        int f = padrao;
        if (fonte != null && !fonte.trim().isEmpty()) {
            try {
                f = Integer.parseInt(fonte.trim());
            } catch (NumberFormatException e) {
                f = padrao;
            }
        }
        int p = f - 8;
        return p >= 1 && p < PORTAS ? p : -1;
    }

    /** O firmware tem USB-C: zysys.typec_count > 0 ou zysys.source.typec1 definida (o sem USB-C nao tem nenhuma). */
    public static boolean temUsbC(String contagem, String fonte) {
        try {
            if (contagem != null && Integer.parseInt(contagem.trim()) > 0) return true;
        } catch (NumberFormatException e) {
            // segue para a fonte
        }
        return fonte != null && !fonte.trim().isEmpty();
    }

    /**
     * A porta da entrada de TV do hardware HDMI: ".../HDMI0000C3" -> 3. Qualquer outra (aparelho CEC dentro de uma
     * porta, componente, VGA, id torto) -> -1.
     */
    public static int portaDoId(String id) {
        if (id == null) return -1;
        int i = id.lastIndexOf(PREFIXO);
        if (i < 0) return -1;
        String s = id.substring(i + PREFIXO.length());
        if (s.length() != 6) return -1;
        int disp;
        try {
            Integer.parseInt(s.substring(0, 4), 16);
            disp = Integer.parseInt(s.substring(4), 16);
        } catch (NumberFormatException e) {
            return -1;
        }
        int p = disp - ID_HARDWARE;
        return p >= 1 && p < PORTAS ? p : -1;
    }

    /**
     * O botao aparece com o cabo ligado (estado 0). Porta que nao aparece entre as entradas de TV fica visivel: sem o
     * sinal, esconder tiraria o unico caminho para a entrada. portaUsbc = -1 quando o firmware nao tem USB-C.
     *
     * @param estado estado por porta (indice = porta), DESCONHECIDO onde nao ha entrada de TV
     */
    public static Item[] comCabo(int portaHdmi1, int portaHdmi2, int portaUsbc, int[] estado) {
        boolean h1 = mostra(portaHdmi1, estado);
        boolean h2 = mostra(portaHdmi2, estado);
        boolean uc = mostra(portaUsbc, estado);
        return lista(h1, h2, uc);
    }

    /** Sem leitura nenhuma (servico de TV fora do ar): todas as entradas do firmware, como antes do bloco 30. */
    public static Item[] semLeitura(boolean usbc) {
        return lista(true, true, usbc);
    }

    /** Na ordem de sempre: HDMI 1, HDMI 2, USB-C. */
    public static Item[] lista(boolean hdmi1, boolean hdmi2, boolean usbc) {
        int n = (hdmi1 ? 1 : 0) + (hdmi2 ? 1 : 0) + (usbc ? 1 : 0);
        Item[] r = new Item[n];
        int i = 0;
        if (hdmi1) r[i++] = HDMI1;
        if (hdmi2) r[i++] = HDMI2;
        if (usbc) r[i] = USBC;
        return r;
    }

    public static int[] estadosVazios() {
        int[] e = new int[PORTAS];
        for (int i = 0; i < PORTAS; i++) e[i] = DESCONHECIDO;
        return e;
    }

    private static boolean mostra(int porta, int[] estado) {
        if (porta < 1 || porta >= PORTAS) return false;
        int s = estado == null || porta >= estado.length ? DESCONHECIDO : estado[porta];
        return s == LIGADO || s == DESCONHECIDO;
    }
}
