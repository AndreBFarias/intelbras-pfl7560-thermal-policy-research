package com.pfl7560.home;

/**
 * Tela "Ajustes do sistema": a aba Servicos (bloco 27) e a aba Diario. Modelo puro, sem Android.
 *
 * O projetor publica o estado numa propriedade posicional, um caractere por id, na ordem de IDS, e fala da
 * MEDIDA: 1 aplicada (o servico desativado), 0 nao aplicada (o servico funciona), p parcial, - nao existe
 * neste projetor, ? nao li. A tela mostra o SERVICO, como no Android: ligado = o servico funciona. A inversao
 * fica so aqui; o pedido continua "v1 <id> ligar|desligar" no sentido da medida.
 */
public final class Ajustes {
    public static final int ZONA_ABA = 0;
    public static final int ZONA_LINHAS = 1;

    public static final int NADA = 0;
    public static final int PEDIR = 1;
    public static final int CONFIRMAR = 2;

    public static final int ABA_SERVICOS = 0;
    public static final int ABA_DIARIO = 1;
    public static final String[] ABAS = {"Serviços", "Diário"};

    /** A ordem do projetor: nao muda, so cresce no fim. */
    public static final String[] IDS = {
        "deb_seg", "deb_ota", "deb_hisi", "deb_lnch", "deb_vlc", "log_vplug", "eth0", "wifi_pwr", "web_cmd", "keystone",
        "pop_disp",
    };
    /** O que aparece na tela, na ordem da tela. O chip Wi-Fi (wifi_pwr) nao e um servico: fica fora. */
    public static final int[] VISIVEIS = {0, 1, 2, 3, 4, 5, 6, 8, 9, 10};
    public static final String[] ROTULOS = {
        "Apps de teste e de fábrica",
        "Telemetria do fabricante",
        "Players da HiSilicon",
        "Tela inicial de fábrica",
        "Office do fabricante",
        "Log do vplugin",
        "Porta de rede por cabo",
        "Chip Wi-Fi",
        "Servidor web e cmdsrv",
        "Keystone automático",
        "Aviso de dispositivo conectado",
    };
    /** O texto de baixo do item em foco: curto, sobre o servico. */
    public static final String[] FAZ = {
        "Autoteste, menu de fábrica e ferramentas de teste.",
        "Telemetria e atualização pela internet do fabricante.",
        "Players de música e vídeo e menus de TV da HiSilicon.",
        "A tela inicial que veio no projetor.",
        "O Office que veio no projetor.",
        "Mensagens do vplugin no log do sistema.",
        "A porta de cabo de rede. O Wi-Fi não muda.",
        "Chip de Wi-Fi e Bluetooth sempre acordado.",
        "Painel web da porta 80 e controle por rede de fábrica.",
        "Correção automática do trapézio. Muda no próximo reinício.",
        "Janela que oferece abrir a entrada quando um aparelho é ligado.",
    };
    /** Desativar o que derruba rede pede OK duas vezes. */
    public static final boolean[] CONFIRMA = {false, false, false, false, false, false, true, true, false, false, false};

    // aba Diario: duas linhas
    public static final String[] DIARIO_ROTULOS = {"Gravar o diário", "Enviar agora ao PC"};
    public static final String[] DIARIO_FAZ = {
        "Uma linha por minuto, até 512 KB.",
        "O PC busca o diário a cada 2 minutos.",
    };
    public static final long DIARIO_MAX_BYTES = 512L * 1024L;

    /*
     * "Desligar no descanso" (tarefa 2026-11-02): a ultima linha da aba Servicos. Nao e uma medida do
     * suite-chaves.sh (fora dos IDS): o vigia do standby (suite-curvas.sh) le a escolha. O projetor publica
     * vendor.pfl7560.standby_conf = "<1|0>:<minutos>"; a home pede "v1 ligado|desligado <minutos>" ou "v1 ler".
     * OK liga/desliga; esquerda/direita NESTA linha trocam o tempo (nas outras, a aba).
     */
    public static final String DESCANSO_ROTULO = "Desligar no descanso";
    public static final String DESCANSO_FAZ = "Desliga o projetor depois desse tempo no descanso de tela.";
    public static final String DESCANSO_TECLAS = "Esquerda e direita: tempo    OK: liga ou desliga";
    public static final int[] DESCANSO_MINUTOS = {10, 20, 30, 60};
    public static final String PEDIDO_DESCANSO_LER = "v1 ler";
    public static final String PEDIDO_DIARIO_LER = "v1 ler";
    public static final String PEDIDO_DIARIO_ENVIAR = "v1 enviar";

    public int aba = ABA_SERVICOS;
    public int zona = ZONA_LINHAS;
    public int linha = 0;
    /** vendor.pfl7560.chaves como veio; "" enquanto nao li. */
    public String estado = "";
    /** vendor.pfl7560.diario: "<1|0>:<bytes>:<pedido 0|1>"; "" se nao li. */
    public String diario = "";
    /** vendor.pfl7560.diario_envio: "AAAA-MM-DDTHH:MM:SS" do ultimo envio, "" se nunca. */
    public String diarioEnvio = "";
    public int confirmando = -1;
    /** Por id: a medida pedida e ainda nao confirmada ('1' ou '0'), ou 0. A tela ja mostra o alvo. */
    public final char[] aplicando = new char[IDS.length];
    /** Diario: '1'/'0' gravar pedido, 'e' envio pedido, 0 nada em curso. */
    public char diarioAplicando;
    /** vendor.pfl7560.standby_conf: "<1|0>:<minutos>"; "" enquanto nao li. */
    public String descanso = "";
    /** Desligar no descanso: o alvo pedido e ainda nao confirmado ("1:20"), ou null. A tela ja mostra o alvo. */
    public String descansoAplicando;
    /** Conta os pedidos do descanso: so a resposta do ultimo tira o "Aplicando…" (as setas podem mandar varios). */
    public int descansoPedidos;

    public void abrir() {
        aba = ABA_SERVICOS;
        zona = ZONA_LINHAS;
        linha = 0;
        confirmando = -1;
    }

    public int abas() {
        return ABAS.length;
    }

    public int linhas() {
        return aba == ABA_DIARIO ? DIARIO_ROTULOS.length : VISIVEIS.length + 1;
    }

    /** O foco esta na linha "Desligar no descanso" (a ultima da aba Servicos)? */
    public boolean naLinhaDescanso() {
        return aba == ABA_SERVICOS && zona == ZONA_LINHAS && linha == VISIVEIS.length;
    }

    /** O indice em IDS da linha em foco (so na aba Servicos). */
    public int indice() {
        return VISIVEIS[Math.max(0, Math.min(linha, VISIVEIS.length - 1))];
    }

    /**
     * Setas. Esquerda/direita trocam a aba, menos na linha "Desligar no descanso", onde trocam o tempo: ai o
     * retorno diz se o tempo mudou, e a home manda o pedido ({@link #pedidoDescanso}).
     */
    public boolean mover(int dx, int dy) {
        confirmando = -1;
        if (dx != 0 && dy == 0 && naLinhaDescanso()) return trocarMinutos(dx);
        if (dx != 0 && dy == 0) return trocarAba(aba + dx);
        if (zona == ZONA_ABA) {
            if (dy > 0) {
                zona = ZONA_LINHAS;
                return true;
            }
            return false;
        }
        if (dy < 0) {
            if (linha > 0) {
                linha--;
                return true;
            }
            zona = ZONA_ABA;
            return true;
        }
        if (dy > 0 && linha < linhas() - 1) {
            linha++;
            return true;
        }
        return false;
    }

    private boolean trocarAba(int nova) {
        if (nova < 0 || nova >= abas() || nova == aba) return false;
        aba = nova;
        linha = 0;
        return true;
    }

    /** Ja li o estado do projetor alguma vez? Antes disso a tela diz "Lendo…". */
    public boolean lido() {
        return estado != null && !estado.isEmpty();
    }

    /** O caractere da MEDIDA para o id i, como o projetor publicou. Id alem da prop (kit antigo) = nao existe. */
    public char estadoDe(int i) {
        if (!lido() || i < 0) return '?';
        if (i >= estado.length()) return '-';
        char c = estado.charAt(i);
        return c == '0' || c == '1' || c == 'p' || c == '-' ? c : '?';
    }

    /** A medida esta aplicada (o servico desativado)? */
    public boolean ligada(int i) {
        return estadoDe(i) == '1';
    }

    /** Medida -> servico: '1' o servico funciona, '0' desativado; p, - e ? passam iguais. */
    public static char servicoDaMedida(char medida) {
        return medida == '1' ? '0' : medida == '0' ? '1' : medida;
    }

    /** Servico -> medida (o caminho de volta, para o pedido). */
    public static char medidaDoServico(char servico) {
        return servicoDaMedida(servico);
    }

    /** O que a tela mostra para o id i: o servico, ja no alvo se o pedido esta em curso. */
    public char servico(int i) {
        if (i >= 0 && i < IDS.length && aplicando[i] != 0) return servicoDaMedida(aplicando[i]);
        return servicoDaMedida(estadoDe(i));
    }

    public boolean emCurso(int i) {
        return i >= 0 && i < IDS.length && aplicando[i] != 0;
    }

    public String rotuloServico(int i) {
        if (!lido()) return "Lendo…";
        if (emCurso(i)) return "Aplicando…";
        return rotuloEstado(servico(i));
    }

    /** Rotulo de um caractere do SERVICO. */
    public static String rotuloEstado(char c) {
        switch (c) {
            case '1':
                return "Ligado";
            case '0':
                return "Desligado";
            case 'p':
                return "Parcial";
            case '-':
                return "Não existe aqui";
            default:
                return "Não consegui ler";
        }
    }

    /** OK na linha em foco: o que a tela deve fazer. */
    public int ok() {
        if (zona != ZONA_LINHAS) return NADA;
        if (naLinhaDescanso()) {
            confirmando = -1;
            return descansoLido() ? PEDIR : NADA;
        }
        if (aba == ABA_DIARIO) {
            if (!diarioLido() || diarioAplicando != 0) return NADA;
            if (linha == 1 && diarioPedido()) return NADA;
            return PEDIR;
        }
        int i = indice();
        if (emCurso(i)) return NADA;
        char c = estadoDe(i);
        if (c == '-' || c == '?') return NADA;
        // desativar o servico (aplicar a medida) da porta de rede pede confirmacao
        if (c != '1' && CONFIRMA[i] && confirmando != linha) {
            confirmando = linha;
            return CONFIRMAR;
        }
        confirmando = -1;
        return PEDIR;
    }

    public String idEmFoco() {
        if (naLinhaDescanso()) return "descanso";
        return aba == ABA_DIARIO ? "diario" : IDS[indice()];
    }

    /** O pedido que a linha em foco manda: inverte o servico, no sentido da medida do projetor. */
    public String pedido() {
        if (aba == ABA_DIARIO) {
            if (linha == 1) return PEDIDO_DIARIO_ENVIAR;
            return diarioLigado() ? "v1 desligar" : "v1 ligar";
        }
        if (naLinhaDescanso()) return pedidoDescanso(alvoDescanso(!descansoLigado(), minutosDescanso()));
        int i = indice();
        return "v1 " + IDS[i] + (ligada(i) ? " desligar" : " ligar");
    }

    /**
     * OK aceito: a tela muda na hora para o alvo ("Aplicando…") e devolve o pedido a mandar. O projetor confirma
     * depois em {@link #confirmar}.
     */
    public String marcarAplicando() {
        String p = pedido();
        if (naLinhaDescanso()) {
            descansoAplicando = alvoDescanso(!descansoLigado(), minutosDescanso());
            descansoPedidos++;
            return p;
        }
        if (aba == ABA_DIARIO) {
            diarioAplicando = linha == 1 ? 'e' : diarioLigado() ? '0' : '1';
        } else {
            aplicando[indice()] = p.endsWith(" desligar") ? '0' : '1';
        }
        return p;
    }

    /** A resposta do projetor para o id: o estado relido manda, o "aplicando" sai. */
    public void confirmar(String id, String lidoAgora) {
        for (int i = 0; i < IDS.length; i++) if (IDS[i].equals(id)) aplicando[i] = 0;
        if (lidoAgora != null && !lidoAgora.isEmpty()) estado = lidoAgora;
    }

    public void confirmarDiario(String lidoAgora, String envio) {
        diarioAplicando = 0;
        if (lidoAgora != null && !lidoAgora.isEmpty()) diario = lidoAgora;
        if (envio != null) diarioEnvio = envio;
    }

    /** Algum pedido desta tela ainda espera a resposta do projetor? */
    public boolean algumEmCurso() {
        if (diarioAplicando != 0 || descansoAplicando != null) return true;
        for (char c : aplicando) if (c != 0) return true;
        return false;
    }

    /** Falta ler algo desta tela? Enquanto faltar, a home tenta de novo a cada 2,5 s. */
    public boolean precisaLer() {
        return !lido() || !diarioLido() || !descansoLido();
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

    /** "v1 ligado 10" ... "v1 desligado 60" ou "v1 ler": a lista fechada que o suite-curvas.sh aceita. */
    public static boolean pedidoDescansoValido(String s) {
        if (PEDIDO_DESCANSO_LER.equals(s)) return true;
        for (int m : DESCANSO_MINUTOS) {
            if (("v1 ligado " + m).equals(s) || ("v1 desligado " + m).equals(s)) return true;
        }
        return false;
    }

    private static boolean descansoValido(String v) {
        if (v == null) return false;
        for (int m : DESCANSO_MINUTOS) {
            if (("1:" + m).equals(v) || ("0:" + m).equals(v)) return true;
        }
        return false;
    }

    /** O projetor publicou a escolha do descanso no formato esperado? */
    public boolean descansoLido() {
        return descansoValido(descanso);
    }

    /** O que a tela mostra: o alvo em curso, se houver, senao o lido. */
    private String descansoMostrado() {
        return descansoAplicando != null ? descansoAplicando : descanso;
    }

    public boolean descansoLigado() {
        String v = descansoMostrado();
        return descansoValido(v) && v.charAt(0) == '1';
    }

    /** Os minutos mostrados; 10 (o padrao) enquanto nao li. */
    public int minutosDescanso() {
        String v = descansoMostrado();
        return descansoValido(v) ? Integer.parseInt(v.substring(2)) : DESCANSO_MINUTOS[0];
    }

    /** Estado do servico da linha: '1' ligado, '0' desligado, '?' nao li; ja no alvo se o pedido esta em curso. */
    public char estadoDescanso() {
        if (!descansoValido(descansoMostrado())) return '?';
        return descansoLigado() ? '1' : '0';
    }

    public String rotuloDescanso() {
        if (descansoAplicando != null) return "Aplicando…";
        char c = estadoDescanso();
        return c == '1' ? "Ligado" : c == '0' ? "Desligado" : "Lendo…";
    }

    public static String alvoDescanso(boolean ligado, int minutos) {
        return (ligado ? "1:" : "0:") + minutos;
    }

    /** O pedido que leva ao alvo "<1|0>:<min>". */
    public static String pedidoDescanso(String alvo) {
        return "v1 " + (alvo.charAt(0) == '1' ? "ligado " : "desligado ") + alvo.substring(2);
    }

    /** O pedido do alvo em curso (depois de {@link #marcarAplicando} ou de uma seta na linha). */
    public String pedidoDescanso() {
        return descansoAplicando == null ? null : pedidoDescanso(descansoAplicando);
    }

    /** Esquerda/direita na linha do descanso: o tempo anda na lista, sem dar a volta; a tela ja mostra o alvo. */
    private boolean trocarMinutos(int dx) {
        if (!descansoLido()) return false;
        int atual = minutosDescanso();
        int k = 0;
        for (int i = 0; i < DESCANSO_MINUTOS.length; i++) if (DESCANSO_MINUTOS[i] == atual) k = i;
        int n = k + (dx > 0 ? 1 : -1);
        if (n < 0 || n >= DESCANSO_MINUTOS.length) return false;
        descansoAplicando = alvoDescanso(descansoLigado(), DESCANSO_MINUTOS[n]);
        descansoPedidos++;
        return true;
    }

    /** A resposta do projetor ao pedido numero n: o lido manda; so a do ultimo pedido tira o "Aplicando…". */
    public void confirmarDescanso(int n, String lidoAgora) {
        if (n == descansoPedidos) descansoAplicando = null;
        if (descansoValido(lidoAgora)) descanso = lidoAgora;
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

    /** Estado de Gravar o diario: 1, 0 ou ? (nao li), ja no alvo se o pedido esta em curso. */
    public char estadoDiario() {
        if (diarioAplicando == '1' || diarioAplicando == '0') return diarioAplicando;
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
        if (diarioAplicando == '1' || diarioAplicando == '0') return "Aplicando…";
        char c = estadoDiario();
        return c == '1' ? "Gravando" : c == '0' ? "Parado" : "Lendo…";
    }

    /** Texto do que o projetor respondeu em chaves_aviso ("id:codigo:hora"); "" se nao e desse id. */
    public static String codigoDoAviso(String aviso, String id) {
        if (aviso == null || id == null || !aviso.startsWith(id + ":")) return "";
        String r = aviso.substring(id.length() + 1);
        int d = r.indexOf(':');
        return d < 0 ? r : r.substring(0, d);
    }

    public static String rotuloAviso(String codigo) {
        if (codigo == null || codigo.isEmpty()) return "";
        if ("ok".equals(codigo)) return "Feito";
        if ("sem-home".equals(codigo)) return "Só com a home nova instalada";
        if ("ausente".equals(codigo)) return "Este projetor não tem isso";
        if ("sem-ip".equals(codigo)) return "O projetor não tem o comando de rede";
        if ("recusado".equals(codigo)) return "O projetor recusou o pedido";
        if ("sumiu".equals(codigo)) return "Sumiu com a mudança: reinicie o projetor";
        if (codigo.startsWith("nao-confere")) return "O projetor não confirmou a mudança";
        return "Não consegui: " + codigo;
    }
}
