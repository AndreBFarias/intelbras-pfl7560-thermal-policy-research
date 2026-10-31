package com.pfl7560.home;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collections;
import java.util.List;

/**
 * Estado da home e a navegacao com o D-pad. Java puro: o mesmo codigo roda no aparelho e no
 * gerador de previas do PC. Mexer so na thread da interface.
 */
public final class Modelo {
    public static final int ENTRADAS = 0;
    public static final int ATALHOS = 1;
    public static final int APPS = 2;

    public static final int APPS_CARREGANDO = 0;
    public static final int APPS_PRONTOS = 1;

    public final Item[] entradas;
    public final Item[] atalhos;
    public List<Item> apps = Collections.emptyList();
    public int estadoApps = APPS_CARREGANDO;

    public String hora = "";
    public String data = "";
    /** Nome da rede, "Sem rede", ou null enquanto nao se leu. */
    public String wifi;
    /** Temperatura do LED em graus inteiros ("59"; o desenho poe o "°C"), ou null se nao der para ler sem root. */
    public String temperatura;
    /** Aviso curto (ex.: um atalho que nao abriu), ou null. */
    public String aviso;

    /** Os cinco niveis do painel de luz (percentual do hidebug sbl; o ultimo e o "Economico"). */
    public static final int[] LUZ_NIVEIS = {100, 80, 60, 40, 25};
    public static final int LUZ_ECONOMICO = 25;

    /** Luz atual em %, como o root publicou em vendor.pfl7560.luz; 100 enquanto nao houver. */
    public int luz = 100;
    public boolean luzAberta;
    /** Indice em LUZ_NIVEIS do nivel sob o foco no painel. */
    public int luzSel;

    public int fileira = ENTRADAS;
    public int coluna = 0;
    public int primeiroApp = 0;

    public Modelo(Item[] entradas, Item[] atalhos) {
        this.entradas = entradas;
        this.atalhos = atalhos;
    }

    public static Modelo padrao() {
        return new Modelo(new Item[] {
            new Item("HDMI 1", Icones.HDMI, Acoes.HDMI1),
            new Item("HDMI 2", Icones.HDMI, Acoes.HDMI2),
            new Item("USB-C", Icones.USB_C, Acoes.USB_C),
        }, new Item[] {
            new Item("Verificar projetor", Icones.VERIFICAR, Acoes.VERIFICAR),
            new Item("Wi-Fi", Icones.WIFI, Acoes.WIFI),
            new Item("Bluetooth", Icones.BLUETOOTH, Acoes.BLUETOOTH),
            new Item("Imagem", Icones.IMAGEM, Acoes.IMAGEM),
            new Item("Luz", Icones.LUZ, Acoes.LUZ),
            new Item("Configurações", Icones.CONFIG, Acoes.CONFIG),
            new Item("Espelhamento", Icones.ESPELHAR, Acoes.ESPELHAR),
        });
    }

    public int quantos(int f) {
        if (f == ENTRADAS) return entradas.length;
        if (f == ATALHOS) return atalhos.length;
        return apps.size();
    }

    public Item focado() {
        if (fileira == ENTRADAS) return entradas[coluna];
        if (fileira == ATALHOS) return atalhos[coluna];
        return coluna < apps.size() ? apps.get(coluna) : null;
    }

    /** Abre o painel de luz com o foco no nivel mais perto do atual. */
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

    /** Move o foco entre os niveis (-1 esquerda, 1 direita). Devolve true se mudou. */
    public boolean moverLuz(int dx) {
        int n = luzSel + dx;
        if (n < 0 || n >= LUZ_NIVEIS.length) return false;
        luzSel = n;
        return true;
    }

    public int nivelLuz() {
        return LUZ_NIVEIS[luzSel];
    }

    /** Volta ao comeco (HOME apertado com a home ja aberta). */
    public void inicio() {
        luzAberta = false;
        fileira = ENTRADAS;
        coluna = 0;
        primeiroApp = 0;
    }

    public void definirApps(List<Item> lista) {
        apps = lista == null ? Collections.<Item>emptyList() : new ArrayList<Item>(lista);
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

    /** dx/dy em -1, 0, 1. Devolve true se o foco mudou. */
    public boolean mover(int dx, int dy) {
        if (dx != 0) {
            int nc = coluna + dx;
            if (nc < 0 || nc >= quantos(fileira)) return false;
            coluna = nc;
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
        int melhor = ini;
        float dist = Float.MAX_VALUE;
        for (int i = ini; i <= fim; i++) {
            float d = Math.abs(Desenho.centroX(this, f, i) - cx);
            if (d < dist) {
                dist = d;
                melhor = i;
            }
        }
        fileira = f;
        coluna = melhor;
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

    /** Preenche hora ("21:47", 24 h) e data ("Sábado, 31 de outubro") em português, sem depender do idioma do aparelho. */
    public void relogio(Calendar c) {
        int h = c.get(Calendar.HOUR_OF_DAY);
        int m = c.get(Calendar.MINUTE);
        hora = (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
        data = DIAS[c.get(Calendar.DAY_OF_WEEK) - 1] + ", " + c.get(Calendar.DAY_OF_MONTH) + " de "
                + MESES[c.get(Calendar.MONTH)];
    }
}
