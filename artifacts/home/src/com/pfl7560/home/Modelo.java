package com.pfl7560.home;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Calendar;
import java.util.Collections;
import java.util.List;

public final class Modelo {
    public static final int ENTRADAS = 0;
    public static final int ATALHOS = 1;
    public static final int APPS = 2;

    public static final int APPS_CARREGANDO = 0;
    public static final int APPS_PRONTOS = 1;

    public static final List<String> OCULTOS = Collections.unmodifiableList(Arrays.asList(
            "com.mobisystems.editor.office_registered", "com.newlink.cast", "com.hisilicon.miracast",
            "com.newlink.filemanager"));

    /**
     * So as entradas com cabo (bloco 30), na ordem HDMI 1, HDMI 2, USB-C; vazia ate a primeira leitura e sem cabo
     * nenhum. Quem muda e definirEntradas, que cuida do foco.
     */
    public Item[] entradas;
    /** A primeira leitura das entradas ja chegou. */
    public boolean entradasLidas;
    /** O dono mexeu no foco desde a abertura ou o ultimo HOME. */
    private boolean tocado;
    public final Item[] atalhos;
    public List<Item> apps = Collections.emptyList();
    public int estadoApps = APPS_CARREGANDO;

    public String hora = "";
    public String data = "";
    public String wifi;
    /** "Bluetooth ligado/desligado/conectado"; null se nao li. */
    public String bluetooth;
    /** Temperatura do LED (zysys.env_temp), em graus inteiros; null se nao li. */
    public String temperatura;
    /** Temperatura da placa (zysys.light_temp, termistor 0 do POLICY_0); null se nao li. */
    public String temperaturaPlaca;
    public String aviso;

    public static final int[] LUZ_NIVEIS = {100, 80, 60, 40, 25};
    public static final int LUZ_ECONOMICO = 25;

    public int luz = 100;
    public boolean luzAberta;
    public int luzSel;

    public final Curvas curvas = new Curvas();
    public boolean curvasAberta;

    public final Ajustes ajustes = new Ajustes();
    public boolean ajustesAberta;

    public int fileira = ENTRADAS;
    public int coluna = 0;
    public int primeiroApp = 0;

    public Modelo(Item[] entradas, Item[] atalhos) {
        this.entradas = entradas == null ? new Item[0] : entradas;
        this.atalhos = atalhos;
        posicaoInicial();
    }

    /** A tela de sempre: seis atalhos; as entradas chegam depois, so as com cabo (definirEntradas). */
    public static Modelo padrao() {
        return new Modelo(new Item[0], new Item[] {
            new Item("Verificar projetor", Icones.VERIFICAR, Acoes.VERIFICAR),
            new Item("Wi-Fi", Icones.WIFI, Acoes.WIFI),
            new Item("Bluetooth", Icones.BLUETOOTH, Acoes.BLUETOOTH),
            new Item("Luz", Icones.LUZ, Acoes.LUZ),
            new Item("Curvas", Icones.CURVAS, Acoes.CURVAS),
            new Item("Configurações", Icones.CONFIG, Acoes.CONFIG),
        });
    }

    public int quantos(int f) {
        if (f == ENTRADAS) return entradas.length;
        if (f == ATALHOS) return atalhos.length;
        return apps.size();
    }

    public Item focado() {
        if (fileira == ENTRADAS) return coluna < entradas.length ? entradas[coluna] : null;
        if (fileira == ATALHOS) return coluna < atalhos.length ? atalhos[coluna] : null;
        return coluna < apps.size() ? apps.get(coluna) : null;
    }

    public void abrirLuz() {
        luzAberta = true;
        luzSel = 0;
        int dist = Integer.MAX_VALUE;
        for (int i = 0; i < LUZ_NIVEIS.length; i++) {
            int d = Math.abs(LUZ_NIVEIS[i] - luz);
            if (d < dist) {
                dist = d;
                luzSel = i;
            }
        }
    }

    public void fecharLuz() {
        luzAberta = false;
    }

    public boolean moverLuz(int dx) {
        int n = luzSel + dx;
        if (n < 0 || n >= LUZ_NIVEIS.length) return false;
        luzSel = n;
        return true;
    }

    /**
     * Setas no painel Luz (bloco 28): nenhuma e engolida. Esquerda/direita andam nos niveis; cima vai para mais luz
     * (o nivel a esquerda) e baixo para menos luz (a direita), como promete o rodape "Setas: escolher". Na ponta,
     * nada muda, igual as setas do lado.
     */
    public boolean moverLuz(int dx, int dy) {
        if (dx != 0) return moverLuz(dx);
        if (dy != 0) return moverLuz(dy);
        return false;
    }

    public int nivelLuz() {
        return LUZ_NIVEIS[luzSel];
    }

    public void abrirCurvas() {
        curvasAberta = true;
        curvas.abrir();
    }

    public void fecharCurvas() {
        curvasAberta = false;
        curvas.pegando = false;
    }

    public void abrirAjustes() {
        ajustesAberta = true;
        ajustes.abrir();
    }

    public void fecharAjustes() {
        ajustesAberta = false;
        ajustes.confirmando = -1;
    }

    /**
     * Voltar: fecha a tela aberta com um aperto. Unica excecao: arrastando uma bola nas Curvas, Voltar solta a bola.
     * Devolve false na tela principal (nada a fechar).
     */
    public boolean voltar() {
        if (curvasAberta) {
            if (!curvas.voltar()) fecharCurvas();
        } else if (ajustesAberta) {
            fecharAjustes();
        } else if (luzAberta) {
            fecharLuz();
        } else {
            return false;
        }
        aviso = null;
        return true;
    }

    public void inicio() {
        luzAberta = false;
        fecharCurvas();
        fecharAjustes();
        posicaoInicial();
        primeiroApp = 0;
        tocado = false;
    }

    /** O comeco: a primeira entrada com cabo; sem nenhuma, o primeiro atalho. */
    private void posicaoInicial() {
        fileira = entradas.length > 0 ? ENTRADAS : ATALHOS;
        coluna = 0;
    }

    /**
     * Cabo ligado ou tirado (bloco 30). Devolve true se a tela mudou. O foco nunca some nem e roubado:
     * <ul>
     * <li>na primeira leitura, sem o dono ter mexido, vai para o comeco (HDMI 1 se tiver cabo, como sempre);</li>
     * <li>depois, uma entrada nova nunca puxa o foco;</li>
     * <li>o botao em foco que continua leva o foco junto, mesmo mudando de lugar;</li>
     * <li>o botao em foco que some passa o foco ao que ocupa o lugar dele na fileira (ou ao ultimo); sem entrada
     * nenhuma, ao atalho logo abaixo, como a seta para baixo.</li>
     * </ul>
     */
    public boolean definirEntradas(Item[] novas) {
        if (novas == null) novas = new Item[0];
        boolean primeira = !entradasLidas;
        entradasLidas = true;
        if (mesmas(entradas, novas)) {
            if (primeira && !tocado && fileira != APPS) {
                int f = fileira;
                int c = coluna;
                posicaoInicial();
                return f != fileira || c != coluna;
            }
            return false;
        }
        boolean naFileira = fileira == ENTRADAS && coluna < entradas.length;
        String antes = naFileira ? entradas[coluna].acao : null;
        float cx = naFileira ? Desenho.centroX(this, ENTRADAS, coluna) : 0f;
        entradas = novas;
        if (primeira && !tocado && fileira != APPS) {
            posicaoInicial();
            return true;
        }
        if (fileira != ENTRADAS) return true;
        for (int i = 0; i < novas.length; i++) {
            if (antes != null && antes.equals(novas[i].acao)) {
                coluna = i;
                return true;
            }
        }
        if (novas.length > 0) {
            coluna = Math.max(0, Math.min(coluna, novas.length - 1));
            return true;
        }
        fileira = ATALHOS;
        coluna = maisPerto(ATALHOS, 0, atalhos.length - 1, cx);
        return true;
    }

    private static boolean mesmas(Item[] a, Item[] b) {
        if (a.length != b.length) return false;
        for (int i = 0; i < a.length; i++) {
            if (a[i].acao == null ? b[i].acao != null : !a[i].acao.equals(b[i].acao)) return false;
        }
        return true;
    }

    private int maisPerto(int f, int ini, int fim, float cx) {
        int melhor = ini;
        float dist = Float.MAX_VALUE;
        for (int i = ini; i <= fim; i++) {
            float d = Math.abs(Desenho.centroX(this, f, i) - cx);
            if (d < dist) {
                dist = d;
                melhor = i;
            }
        }
        return melhor;
    }

    public void definirApps(List<Item> lista) {
        apps = new ArrayList<Item>();
        if (lista != null) {
            for (Item it : lista) {
                if (it.pacote == null || !OCULTOS.contains(it.pacote)) apps.add(it);
            }
        }
        estadoApps = APPS_PRONTOS;
        if (apps.isEmpty()) {
            primeiroApp = 0;
            if (fileira == APPS) {
                fileira = ATALHOS;
                coluna = 0;
            }
            return;
        }
        if (primeiroApp > Math.max(0, apps.size() - Desenho.APPS_VISIVEIS)) {
            primeiroApp = Math.max(0, apps.size() - Desenho.APPS_VISIVEIS);
        }
        if (fileira == APPS && coluna >= apps.size()) coluna = apps.size() - 1;
        rolarAteFoco();
    }

    public boolean mover(int dx, int dy) {
        if (dx != 0) {
            int nc = coluna + dx;
            if (nc < 0 || nc >= quantos(fileira)) return false;
            coluna = nc;
            tocado = true;
            rolarAteFoco();
            return true;
        }
        if (dy == 0) return false;
        int f = fileira + dy;
        while (f >= ENTRADAS && f <= APPS && quantos(f) == 0) f += dy;
        if (f < ENTRADAS || f > APPS) return false;
        float cx = Desenho.centroX(this, fileira, coluna);
        int ini = 0;
        int fim = quantos(f) - 1;
        if (f == APPS) {
            ini = primeiroApp;
            fim = Math.min(fim, primeiroApp + Desenho.APPS_VISIVEIS - 1);
        }
        int melhor = maisPerto(f, ini, fim, cx);
        fileira = f;
        coluna = melhor;
        tocado = true;
        return true;
    }

    private void rolarAteFoco() {
        if (fileira != APPS) return;
        if (coluna < primeiroApp) primeiroApp = coluna;
        if (coluna >= primeiroApp + Desenho.APPS_VISIVEIS) primeiroApp = coluna - Desenho.APPS_VISIVEIS + 1;
    }

    private static final String[] DIAS = {
        "Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado",
    };
    private static final String[] MESES = {
        "janeiro", "fevereiro", "março", "abril", "maio", "junho",
        "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
    };

    public void relogio(Calendar c) {
        int h = c.get(Calendar.HOUR_OF_DAY);
        int m = c.get(Calendar.MINUTE);
        hora = (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
        data = DIAS[c.get(Calendar.DAY_OF_WEEK) - 1] + ", " + c.get(Calendar.DAY_OF_MONTH) + " de "
                + MESES[c.get(Calendar.MONTH)];
    }
}
