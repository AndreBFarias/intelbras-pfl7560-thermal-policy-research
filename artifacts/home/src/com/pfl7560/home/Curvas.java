package com.pfl7560.home;

public final class Curvas {
    public static final int ABA_VENT = 0;
    public static final int ABA_LED = 1;

    public static final int ZONA_ABA = 0;
    public static final int ZONA_PERFIL = 1;
    public static final int ZONA_GRAFICO = 2;
    public static final int ZONA_MODO = 3;
    public static final int ZONA_APLICAR = 4;

    public static final int NADA = 0;
    public static final int APLICAR = 1;

    public static final int VENT_N = 5;
    public static final int LED_N = 3;

    public static final int T_MIN = 25;
    public static final int T_CHEIA = 66;
    public static final int V_MIN = 30;
    public static final int V_MAX = 100;
    public static final int V_PASSO = 5;

    public static final int L_TMIN = 40;
    public static final int L_TMAX = 69;
    public static final int B_MIN = 850;
    public static final int B_MAX = 1000;
    public static final int B_PASSO = 10;

    public static final String[] PERFIS_VENT = {"silencioso", "balanceado", "agressivo", "manual"};
    public static final String[] ROTULOS_VENT = {"Silencioso", "Balanceado", "Agressivo", "Manual"};
    public static final String[] PERFIS_LED = {"padrao", "silencioso", "manual"};
    public static final String[] ROTULOS_LED = {"Padrão do firmware", "Silencioso", "Manual"};
    public static final String[] MODOS = {"vivo", "gravar", "ambos"};
    public static final String[] ROTULOS_MODO = {"Ao vivo", "Gravar no projetor", "Os dois"};

    private static final int[][] PRE_VENT_T = {
        {30, 45, 55, 61, 66}, {30, 45, 55, 60, 66}, {30, 40, 50, 60, 66},
    };
    private static final int[][] PRE_VENT_V = {
        {30, 30, 40, 60, 100}, {40, 45, 60, 80, 100}, {100, 100, 100, 100, 100},
    };
    private static final int[] PRE_LED_T = {45, 55, 62};
    private static final int[] PRE_LED_B = {950, 900, 850};

    public int aba = ABA_VENT;
    public int zona = ZONA_PERFIL;
    public int perfilVent = 0;
    public int perfilLed = 0;
    public int modo = 0;
    public int bola = 0;
    public boolean pegando;

    public final int[] ventT = new int[VENT_N];
    public final int[] ventV = new int[VENT_N];
    public final int[] ledT = new int[LED_N];
    public final int[] ledB = new int[LED_N];
    private final int[] manualVentT = new int[VENT_N];
    private final int[] manualVentV = new int[VENT_N];
    private final int[] manualLedT = new int[LED_N];
    private final int[] manualLedB = new int[LED_N];

    public String ventEstado = "";
    public String ledEstado = "";
    public String ventAviso = "";
    public String ledAviso = "";
    public String pedindo;

    public Curvas() {
        copiar(PRE_VENT_T[1], manualVentT);
        copiar(PRE_VENT_V[1], manualVentV);
        copiar(PRE_LED_T, manualLedT);
        copiar(PRE_LED_B, manualLedB);
        carregarVent(0);
        carregarLed(0);
    }

    private static void copiar(int[] de, int[] para) {
        System.arraycopy(de, 0, para, 0, de.length);
    }

    private void carregarVent(int idx) {
        if (idx == 3) {
            copiar(manualVentT, ventT);
            copiar(manualVentV, ventV);
        } else {
            copiar(PRE_VENT_T[idx], ventT);
            copiar(PRE_VENT_V[idx], ventV);
        }
    }

    private void carregarLed(int idx) {
        if (idx == 2) {
            copiar(manualLedT, ledT);
            copiar(manualLedB, ledB);
        } else {
            copiar(PRE_LED_T, ledT);
            copiar(PRE_LED_B, ledB);
        }
    }

    public void abrir() {
        zona = ZONA_PERFIL;
        pegando = false;
        bola = 0;
        pedindo = null;
    }

    public int pontos() {
        return aba == ABA_VENT ? VENT_N : LED_N;
    }

    public int[] temps() {
        return aba == ABA_VENT ? ventT : ledT;
    }

    public int[] valores() {
        return aba == ABA_VENT ? ventV : ledB;
    }

    public int perfil() {
        return aba == ABA_VENT ? perfilVent : perfilLed;
    }

    public String nomePerfil() {
        return aba == ABA_VENT ? PERFIS_VENT[perfilVent] : PERFIS_LED[perfilLed];
    }

    public String[] rotulosPerfil() {
        return aba == ABA_VENT ? ROTULOS_VENT : ROTULOS_LED;
    }

    public boolean editavel() {
        return !(aba == ABA_VENT && perfilVent == 2) && !(aba == ABA_LED && perfilLed == 0);
    }

    public int tempMin(int i) {
        int[] t = temps();
        if (i == 0) return aba == ABA_VENT ? T_MIN : L_TMIN;
        return t[i - 1] + 1;
    }

    public int tempMax(int i) {
        int[] t = temps();
        if (i == pontos() - 1) return aba == ABA_VENT ? T_CHEIA : L_TMAX;
        return t[i + 1] - 1;
    }

    public int valMin(int i) {
        int[] v = valores();
        if (aba == ABA_VENT) return i == 0 ? V_MIN : v[i - 1];
        return i == LED_N - 1 ? B_MIN : v[i + 1];
    }

    public int valMax(int i) {
        int[] v = valores();
        if (aba == ABA_VENT) return i == VENT_N - 1 ? V_MAX : v[i + 1];
        return i == 0 ? B_MAX : v[i - 1];
    }

    public int passoValor() {
        return aba == ABA_VENT ? V_PASSO : B_PASSO;
    }

    private boolean valorTravado(int i) {
        return aba == ABA_VENT && i == VENT_N - 1;
    }

    public boolean mover(int dx, int dy) {
        if (zona == ZONA_GRAFICO && pegando) return moverBola(dx, dy);
        if (dy != 0) {
            int z = zona + dy;
            if (z < ZONA_ABA || z > ZONA_APLICAR) return false;
            zona = z;
            return true;
        }
        if (dx == 0) return false;
        switch (zona) {
            case ZONA_ABA:
                return trocarAba(dx > 0 ? ABA_LED : ABA_VENT);
            case ZONA_PERFIL:
                return trocarPerfil(perfil() + dx);
            case ZONA_GRAFICO:
                int n = bola + dx;
                if (n < 0 || n >= pontos()) return false;
                bola = n;
                return true;
            case ZONA_MODO:
                int m = modo + dx;
                if (m < 0 || m >= MODOS.length) return false;
                modo = m;
                return true;
            default:
                return false;
        }
    }

    private boolean trocarAba(int nova) {
        if (nova == aba) return false;
        aba = nova;
        bola = 0;
        pegando = false;
        return true;
    }

    private boolean trocarPerfil(int idx) {
        int max = aba == ABA_VENT ? PERFIS_VENT.length : PERFIS_LED.length;
        if (idx < 0 || idx >= max || idx == perfil()) return false;
        if (aba == ABA_VENT) {
            perfilVent = idx;
            carregarVent(idx);
        } else {
            perfilLed = idx;
            carregarLed(idx);
        }
        bola = 0;
        return true;
    }

    private boolean moverBola(int dx, int dy) {
        if (!editavel()) return false;
        int[] t = temps();
        int[] v = valores();
        boolean mudou = false;
        if (dx != 0) {
            int n = Math.max(tempMin(bola), Math.min(tempMax(bola), t[bola] + dx));
            if (n != t[bola]) {
                t[bola] = n;
                mudou = true;
            }
        }
        if (dy != 0 && !valorTravado(bola)) {
            int n = v[bola] - dy * passoValor();
            n = Math.max(valMin(bola), Math.min(valMax(bola), n));
            if (n != v[bola]) {
                v[bola] = n;
                mudou = true;
            }
        }
        if (mudou) tornarManual();
        return mudou;
    }

    private void tornarManual() {
        if (aba == ABA_VENT) {
            perfilVent = 3;
            copiar(ventT, manualVentT);
            copiar(ventV, manualVentV);
        } else {
            perfilLed = 2;
            copiar(ledT, manualLedT);
            copiar(ledB, manualLedB);
        }
    }

    public int ok() {
        switch (zona) {
            case ZONA_GRAFICO:
                if (editavel()) pegando = !pegando;
                return NADA;
            case ZONA_APLICAR:
                return APLICAR;
            default:
                return NADA;
        }
    }

    public boolean voltar() {
        if (pegando) {
            pegando = false;
            return true;
        }
        return false;
    }

    public String pedido() {
        StringBuilder s = new StringBuilder("v1 ").append(nomePerfil()).append(' ').append(MODOS[modo]);
        if (aba == ABA_LED && perfilLed == 0) return s.toString();
        int[] t = temps();
        int[] v = valores();
        for (int i = 0; i < pontos(); i++) s.append(' ').append(t[i]).append(':').append(v[i]);
        return s.toString();
    }

    public static boolean pedidoValido(String pedido) {
        if (pedido == null) return false;
        String[] p = pedido.trim().split(" ");
        if (p.length < 3 || !"v1".equals(p[0])) return false;
        boolean ok = false;
        for (String m : MODOS) if (m.equals(p[2])) ok = true;
        return ok;
    }

    public static String rotuloEstado(String estado) {
        if (estado == null || estado.isEmpty()) return "Padrão do firmware";
        int d = estado.indexOf(':');
        String perfil = d < 0 ? estado : estado.substring(0, d);
        String modo = d < 0 ? "" : estado.substring(d + 1);
        String nome = perfil;
        for (int i = 0; i < PERFIS_VENT.length; i++) if (PERFIS_VENT[i].equals(perfil)) nome = ROTULOS_VENT[i];
        if ("padrao".equals(perfil)) nome = "Padrão do firmware";
        if ("vivo".equals(modo)) return nome + ", ao vivo";
        if ("gravada".equals(modo) || "gravar".equals(modo)) return nome + ", gravada no projetor";
        if ("ambos".equals(modo)) return nome + ", ao vivo e gravada";
        if ("desistiu".equals(modo)) return nome + ", curva ao vivo desligada";
        return nome;
    }

    public static String rotuloAviso(String aviso, boolean vent) {
        if (aviso == null || aviso.isEmpty()) return "";
        String seguro = vent ? "ventiladores em 100%" : "brilho do firmware";
        if ("firmware".equals(aviso)) return "O firmware brigou com a curva: " + seguro + ".";
        if ("temperatura".equals(aviso)) return "Sem leitura de temperatura: " + seguro + ".";
        if ("pedido".equals(aviso)) return "Pedido recusado: " + seguro + ".";
        if ("hidebug".equals(aviso)) return "O projetor não respondeu: " + seguro + ".";
        if ("ini".equals(aviso)) return "Não consegui gravar no projetor.";
        if ("suite".equals(aviso)) return "A verificação está rodando: peça de novo no fim.";
        return "Aviso: " + aviso;
    }
}
