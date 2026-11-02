package com.pfl7560.home;

/**
 * Tela "Ajustes do sistema" (bloco 24): as chaves de ajuste do projetor. Modelo puro, sem Android.
 * "Ligada" quer dizer "a medida esta aplicada" (o app desligado, a porta de cabo caida...). O estado vem
 * do projetor numa propriedade posicional, um caractere por chave, na ordem de IDS:
 * 1 ligada, 0 desligada, p parcial, - nao existe neste projetor, ? nao consegui ler.
 */
public final class Ajustes {
    public static final int ZONA_ABA = 0;
    public static final int ZONA_LINHAS = 1;

    public static final int NADA = 0;
    public static final int PEDIR = 1;
    public static final int CONFIRMAR = 2;

    public static final int ABA_CHAVES = 0;
    public static final int ABA_DIARIO = 1;
    public static final String[] ABAS = {"Chaves", "Diário"};

    public static final String[] IDS = {
        "deb_seg", "deb_ota", "deb_hisi", "deb_lnch", "deb_vlc", "log_vplug", "eth0", "wifi_pwr", "web_cmd", "keystone",
    };
    public static final String[] ROTULOS = {
        "Apps de teste e de fábrica",
        "Telemetria e atualização do fabricante",
        "Players e menus da HiSilicon",
        "Tela inicial de fábrica",
        "VLC e Office embutidos",
        "Silenciar o log do vplugin",
        "Porta de cabo de rede (eth0)",
        "Chip Wi-Fi dorme (AIC8800)",
        "Servidor web (porta 80) e cmdsrv",
        "Mecanismo do keystone",
    };
    public static final String[] FAZ = {
        "Desliga apps de teste e de fábrica que não servem no dia a dia (autoteste, menu de fábrica, ferramentas de teste).",
        "Desliga os serviços de telemetria e de atualização pela internet do fabricante.",
        "Desliga os players de música e de vídeo e os menus de TV da HiSilicon. O visor de fotos fica ligado.",
        "Desliga a tela inicial de fábrica. Só liga com a home nova instalada.",
        "Desliga o VLC e o Office que vêm no projetor.",
        "Cala as mensagens do vplugin no log do sistema.",
        "Derruba a porta de cabo de rede (eth0). O Wi-Fi não muda.",
        "Deixa o chip de Wi-Fi e Bluetooth dormir quando está parado (suspensão automática).",
        "Para o servidor web da porta 80 e o serviço cmdsrv de fábrica.",
        "Desliga a correção automática do trapézio (keystone). Só vale no próximo reinício.",
    };
    public static final String[] RISCO = {
        "Desligando a chave, os apps voltam.",
        "O projetor deixa de receber avisos do fabricante e o descanso de tela pode se comportar diferente.",
        "O menu de imagem pode mudar: teste logo depois. Se algo faltar, desligue a chave.",
        "Se esta home travar, não há tela de reserva. Desligando a chave, a tela de fábrica volta.",
        "Desligando a chave, os dois voltam.",
        "Só silencia mensagens; volta ao desligar a chave ou ao reiniciar.",
        "Se o projetor usa só o cabo, perde a rede e o adb por cabo. Pelo Wi-Fi nada muda.",
        "Pode derrubar o Wi-Fi e o adb, e a rede não volta sozinha. Resgate: arquivo DESLIGAR-CHAVES.txt no pendrive.",
        "O painel web e o controle por rede deixam de responder até desligar a chave.",
        "Se a imagem ficar torta, desligue a chave e reinicie o projetor.",
    };
    public static final String[] NIVEIS = {"Risco baixo: ", "Risco médio: ", "Risco alto: "};
    // 0 baixo, 1 medio, 2 alto
    public static final int[] NIVEL_RISCO = {0, 1, 1, 1, 0, 0, 2, 2, 1, 1};
    // quem derruba rede pede OK duas vezes para LIGAR
    public static final boolean[] CONFIRMA = {false, false, false, false, false, false, true, true, false, false};

    // aba Diario: duas linhas
    public static final String[] DIARIO_ROTULOS = {"Gravar o diário", "Enviar agora ao PC"};
    public static final String[] DIARIO_FAZ = {
        "Grava uma linha por minuto no projetor: temperaturas, ventilador, luz, rede e memória. Guarda no máximo 512 KB.",
        "Só marca o pedido de envio. Quem busca o diário é o PC, a cada 2 minutos, quando o projetor está na rede.",
    };
    public static final String[] DIARIO_RISCO = {
        "Desligado, o diário para de gravar e o que já foi gravado fica.",
        "Se o PC não estiver ligado e na rede, o pedido espera.",
    };
    public static final long DIARIO_MAX_BYTES = 512L * 1024L;
    public static final String PEDIDO_DIARIO_LER = "v1 ler";
    public static final String PEDIDO_DIARIO_ENVIAR = "v1 enviar";

    public int aba = ABA_CHAVES;
    public int zona = ZONA_LINHAS;
    public int linha = 0;
    public String estado = "";
    /** vendor.pfl7560.diario: "<1|0>:<bytes>:<pedido 0|1>"; "" se nao li. */
    public String diario = "";
    /** vendor.pfl7560.diario_envio: "AAAA-MM-DDTHH:MM:SS" do ultimo envio, "" se nunca. */
    public String diarioEnvio = "";
    public String aviso = "";
    public String pedindo;
    public int confirmando = -1;

    public void abrir() {
        aba = ABA_CHAVES;
        zona = ZONA_LINHAS;
        linha = 0;
        pedindo = null;
        confirmando = -1;
    }

    public int abas() {
        return ABAS.length;
    }

    public int linhas() {
        return aba == ABA_DIARIO ? DIARIO_ROTULOS.length : IDS.length;
    }

    public boolean mover(int dx, int dy) {
        confirmando = -1;
        if (zona == ZONA_ABA) {
            if (dy > 0) {
                zona = ZONA_LINHAS;
                return true;
            }
            int n = aba + dx;
            if (dx == 0 || n < 0 || n >= abas()) return false;
            aba = n;
            linha = 0;
            return true;
        }
        if (dx != 0) return false;
        if (dy < 0) {
            if (linha > 0) {
                linha--;
                return true;
            }
            if (abas() > 1) {
                zona = ZONA_ABA;
                return true;
            }
            return false;
        }
        if (dy > 0 && linha < linhas() - 1) {
            linha++;
            return true;
        }
        return false;
    }

    public char estadoDe(int i) {
        if (estado == null || i < 0 || i >= estado.length()) return '?';
        char c = estado.charAt(i);
        return c == '0' || c == '1' || c == 'p' || c == '-' ? c : '?';
    }

    public boolean ligada(int i) {
        return estadoDe(i) == '1';
    }

    public static String rotuloEstado(char c) {
        switch (c) {
            case '1':
                return "Ligada";
            case '0':
                return "Desligada";
            case 'p':
                return "Parcial";
            case '-':
                return "Não existe neste projetor";
            default:
                return "Não consegui ler";
        }
    }

    /** OK na linha em foco: o que a tela deve fazer. */
    public int ok() {
        if (zona != ZONA_LINHAS || pedindo != null) return NADA;
        if (aba == ABA_DIARIO) {
            if (!diarioLido()) return NADA;
            if (linha == 1 && diarioPedido()) return NADA;
            return PEDIR;
        }
        char c = estadoDe(linha);
        if (c == '-' || c == '?') return NADA;
        if (c != '1' && CONFIRMA[linha] && confirmando != linha) {
            confirmando = linha;
            return CONFIRMAR;
        }
        confirmando = -1;
        return PEDIR;
    }

    public String idEmFoco() {
        return aba == ABA_DIARIO ? "diario" : IDS[linha];
    }

    /** O pedido que a linha em foco manda: liga se nao esta ligada, desliga se esta. */
    public String pedido() {
        if (aba == ABA_DIARIO) {
            if (linha == 1) return PEDIDO_DIARIO_ENVIAR;
            return diarioLigado() ? "v1 desligar" : "v1 ligar";
        }
        return "v1 " + IDS[linha] + (ligada(linha) ? " desligar" : " ligar");
    }

    public static final String PEDIDO_LER = "v1 ler";

    public static boolean pedidoValido(String s) {
        if (s == null) return false;
        if (PEDIDO_LER.equals(s)) return true;
        for (String id : IDS) {
            if (s.equals("v1 " + id + " ligar") || s.equals("v1 " + id + " desligar")) return true;
        }
        return false;
    }

    public static boolean pedidoDiarioValido(String s) {
        return "v1 ligar".equals(s) || "v1 desligar".equals(s) || "v1 enviar".equals(s) || PEDIDO_DIARIO_LER.equals(s);
    }

    /** O projetor publicou o estado do diario no formato esperado? */
    public boolean diarioLido() {
        return diario != null && diario.matches("[01]:[0-9]{1,9}:[01]");
    }

    public boolean diarioLigado() {
        return diarioLido() && diario.charAt(0) == '1';
    }

    public boolean diarioPedido() {
        return diarioLido() && diario.endsWith(":1");
    }

    public long diarioBytes() {
        if (!diarioLido()) return 0L;
        return Long.parseLong(diario.substring(2, diario.lastIndexOf(':')));
    }

    /** Estado da chave Gravar o diario no mesmo alfabeto das chaves: 1, 0 ou ? (nao li). */
    public char estadoDiario() {
        return !diarioLido() ? '?' : diarioLigado() ? '1' : '0';
    }

    public static String rotuloTamanho(long b) {
        if (b <= 0) return "vazio";
        if (b < 1024) return b + " bytes";
        long dec = (b * 10L / 1024L) % 10L;
        if (b < 1024L * 1024L) return (b / 1024L) + (b < 10L * 1024L ? "," + dec : "") + " KB";
        return (b / (1024L * 1024L)) + "," + ((b * 10L / (1024L * 1024L)) % 10L) + " MB";
    }

    /** "AAAA-MM-DDTHH:MM:SS" vira "DD/MM/AAAA HH:MM"; vazio ou fora do formato vira "nunca". */
    public static String rotuloEnvio(String iso) {
        if (iso == null || !iso.matches("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}")) return "nunca";
        return iso.substring(8, 10) + "/" + iso.substring(5, 7) + "/" + iso.substring(0, 4) + " " + iso.substring(11, 16);
    }

    public String rotuloEstadoDiario() {
        char c = estadoDiario();
        return c == '1' ? "Gravando" : c == '0' ? "Parado" : "Não consegui ler";
    }

    /** Texto do que o projetor respondeu em chaves_aviso ("id:codigo:hora"); "" se nao e dessa chave. */
    public static String codigoDoAviso(String aviso, String id) {
        if (aviso == null || id == null || !aviso.startsWith(id + ":")) return "";
        String r = aviso.substring(id.length() + 1);
        int d = r.indexOf(':');
        return d < 0 ? r : r.substring(0, d);
    }

    public static String rotuloAviso(String codigo) {
        if (codigo == null || codigo.isEmpty()) return "";
        if ("ok".equals(codigo)) return "Feito";
        if ("sem-home".equals(codigo)) return "Não liguei: a home nova não está instalada";
        if ("ausente".equals(codigo)) return "Este projetor não tem isso";
        if ("sem-ip".equals(codigo)) return "Não liguei: o projetor não tem o comando de rede";
        if ("recusado".equals(codigo)) return "O projetor recusou o pedido";
        if (codigo.startsWith("nao-confere")) return "Pedi, mas o projetor não confirmou a mudança";
        return "Não consegui: " + codigo;
    }
}
