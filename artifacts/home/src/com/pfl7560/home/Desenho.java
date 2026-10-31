package com.pfl7560.home;

import java.util.ArrayList;
import java.util.List;

public final class Desenho {
    public static final float LARGURA = 1920f;
    public static final float ALTURA = 1080f;

    static final float MX = 112f;
    static final float DIREITA = LARGURA - MX;
    static final float CONTEUDO = DIREITA - MX;
    static final float VAO = 24f;
    static final float RAIO = 18f;

    static final float RELOGIO_BASE = 259f;
    static final float RELOGIO_TAM = 176f;
    static final float DATA_BASE = 325f;
    static final float DATA_TAM = 44f;

    static final float ENT_TITULO = 112f;
    static final float ENT_Y = 136f;
    static final float ENT_W = 296f;
    static final float ENT_H = 200f;
    static final float ENT_X0 = DIREITA - (3 * ENT_W + 2 * VAO);

    static final float ATA_TITULO = 432f;
    static final float ATA_Y = 456f;
    static final float ATA_H = 172f;
    static final float ATA_W = (CONTEUDO - 6 * VAO) / 7f;

    public static final int APPS_VISIVEIS = 7;
    static final float APP_TITULO = 724f;
    static final float APP_Y = 748f;
    static final float APP_H = 190f;
    static final float APP_W = (CONTEUDO - (APPS_VISIVEIS - 1) * VAO) / APPS_VISIVEIS;

    static final float ESTADO_BASE = 1000f;

    static final float TITULO_TAM = 30f;

    private Desenho() {
    }

    public static float centroX(Modelo m, int fileira, int i) {
        if (fileira == Modelo.ENTRADAS) return ENT_X0 + i * (ENT_W + VAO) + ENT_W / 2;
        if (fileira == Modelo.ATALHOS) return MX + i * (ATA_W + VAO) + ATA_W / 2;
        return MX + (i - m.primeiroApp) * (APP_W + VAO) + APP_W / 2;
    }

    public static void desenhar(Pintor p, Modelo m) {
        p.gradiente(0, 0, LARGURA, ALTURA, Tema.FUNDO, Tema.FUNDO_BASE);
        relogio(p, m);
        entradas(p, m);
        atalhos(p, m);
        apps(p, m);
        estado(p, m);
        if (m.luzAberta) painelLuz(p, m);
    }

    private static void relogio(Pintor p, Modelo m) {
        String h = m.hora;
        int dp = h.indexOf(':');
        if (dp < 0) {
            p.texto(h, MX, RELOGIO_BASE, Pintor.MONO_SEMI, RELOGIO_TAM, Tema.TEXTO, Pintor.ESQ);
        } else {
            String a = h.substring(0, dp);
            String b = h.substring(dp + 1);
            float x = MX;
            p.texto(a, x, RELOGIO_BASE, Pintor.MONO_SEMI, RELOGIO_TAM, Tema.TEXTO, Pintor.ESQ);
            x += p.largura(a, Pintor.MONO_SEMI, RELOGIO_TAM);
            p.texto(":", x, RELOGIO_BASE, Pintor.MONO_SEMI, RELOGIO_TAM, Tema.ROXO, Pintor.ESQ);
            x += p.largura(":", Pintor.MONO_SEMI, RELOGIO_TAM);
            p.texto(b, x, RELOGIO_BASE, Pintor.MONO_SEMI, RELOGIO_TAM, Tema.TEXTO, Pintor.ESQ);
        }
        p.texto(m.data, MX + 6, DATA_BASE, Pintor.SANS, DATA_TAM, Tema.TEXTO_2, Pintor.ESQ);
    }

    private static void titulo(Pintor p, String s, float x, float base) {
        p.texto(s, x, base, Pintor.SANS_SEMI, TITULO_TAM, Tema.ROXO, Pintor.ESQ);
    }

    private static void entradas(Pintor p, Modelo m) {
        titulo(p, "Entradas", ENT_X0, ENT_TITULO);
        for (int i = 0; i < m.entradas.length; i++) {
            float x = ENT_X0 + i * (ENT_W + VAO);
            boolean f = m.fileira == Modelo.ENTRADAS && m.coluna == i;
            cartao(p, x, ENT_Y, ENT_W, ENT_H, f);
            int cf = f ? Tema.LINHA : Tema.CARTAO;
            Icones.desenhar(p, m.entradas[i].icone, x + 26, ENT_Y + 22, 76, f ? Tema.ROSA : Tema.TEXTO_2, cf);
            p.texto(m.entradas[i].rotulo, x + 30, ENT_Y + ENT_H - 32, Pintor.SANS_NEGRITO, 44, Tema.TEXTO, Pintor.ESQ);
        }
    }

    private static void atalhos(Pintor p, Modelo m) {
        titulo(p, "Atalhos", MX, ATA_TITULO);
        for (int i = 0; i < m.atalhos.length; i++) {
            float x = MX + i * (ATA_W + VAO);
            boolean f = m.fileira == Modelo.ATALHOS && m.coluna == i;
            cartao(p, x, ATA_Y, ATA_W, ATA_H, f);
            int cf = f ? Tema.LINHA : Tema.CARTAO;
            Icones.desenhar(p, m.atalhos[i].icone, x + 22, ATA_Y + 20, 56, f ? Tema.ROSA : Tema.TEXTO_2, cf);
            if (Acoes.LUZ.equals(m.atalhos[i].acao)) {
                p.texto(m.atalhos[i].rotulo, x + 20, ATA_Y + ATA_H - 24 - 34, Pintor.SANS_SEMI, 30, Tema.TEXTO, Pintor.ESQ);
                p.texto(m.luz + "%", x + 20, ATA_Y + ATA_H - 24, Pintor.MONO, 28, Tema.TEXTO_2, Pintor.ESQ);
            } else {
                rotulo(p, m.atalhos[i].rotulo, x + 20, ATA_Y + ATA_H - 24, ATA_W - 40, Pintor.SANS_SEMI, 30, 34, Pintor.ESQ);
            }
        }
    }

    private static void apps(Pintor p, Modelo m) {
        titulo(p, "Apps", MX, APP_TITULO);
        int n = m.apps.size();
        if (m.estadoApps == Modelo.APPS_CARREGANDO || n == 0) {
            String s = m.estadoApps == Modelo.APPS_CARREGANDO ? "Carregando a lista de apps" : "Nenhum app para mostrar";
            p.contorno(MX, APP_Y, CONTEUDO, APP_H, RAIO, 2, Tema.CARTAO);
            p.texto(s, MX + CONTEUDO / 2, APP_Y + APP_H / 2 + 11, Pintor.SANS, 32, Tema.TEXTO_2, Pintor.CENTRO);
            return;
        }
        String cont;
        if (n <= APPS_VISIVEIS) {
            cont = n == 1 ? "1 app" : n + " apps";
        } else {
            int fim = Math.min(n, m.primeiroApp + APPS_VISIVEIS);
            cont = (m.primeiroApp + 1) + "–" + fim + " de " + n;
        }
        p.texto(cont, DIREITA, APP_TITULO, Pintor.SANS, 28, Tema.TEXTO_2, Pintor.DIR);
        int fim = Math.min(n, m.primeiroApp + APPS_VISIVEIS);
        for (int i = m.primeiroApp; i < fim; i++) {
            Item a = m.apps.get(i);
            float x = MX + (i - m.primeiroApp) * (APP_W + VAO);
            boolean f = m.fileira == Modelo.APPS && m.coluna == i;
            cartao(p, x, APP_Y, APP_W, APP_H, f);
            float lado = 88;
            float ix = x + (APP_W - lado) / 2;
            float iy = APP_Y + 22;
            if (a.icone == Icones.MONOGRAMA) {
                Icones.monograma(p, a.rotulo, a.pacote, ix, iy, lado, f);
            } else {
                Icones.desenhar(p, a.icone, ix, iy, lado, f ? Tema.ROSA : Tema.TEXTO_2, f ? Tema.LINHA : Tema.CARTAO);
            }
            rotulo(p, a.rotulo, x + APP_W / 2, APP_Y + APP_H - 20, APP_W - 28, Pintor.SANS_SEMI, 26, 30, Pintor.CENTRO);
        }
    }

    private static void estado(Pintor p, Modelo m) {
        float x = MX;
        float t = 28;
        if (m.wifi != null) {
            Icones.desenhar(p, Icones.WIFI, x, ESTADO_BASE - 28, 34, Tema.TEXTO_2, Tema.FUNDO_BASE);
            x += 46;
            p.texto(m.wifi, x, ESTADO_BASE, Pintor.SANS, t, Tema.TEXTO_2, Pintor.ESQ);
            x += p.largura(m.wifi, Pintor.SANS, t) + 48;
        }
        if (m.temperatura != null) {
            Icones.desenhar(p, Icones.TERMOMETRO, x, ESTADO_BASE - 28, 34, Tema.TEXTO_2, Tema.FUNDO_BASE);
            x += 42;
            p.texto("LED", x, ESTADO_BASE, Pintor.SANS, t, Tema.TEXTO_2, Pintor.ESQ);
            x += p.largura("LED ", Pintor.SANS, t);
            p.texto(m.temperatura, x, ESTADO_BASE, Pintor.MONO, 27, Tema.TEXTO_2, Pintor.ESQ);
            x += p.largura(m.temperatura, Pintor.MONO, 27) + 5;
            p.texto("°C", x, ESTADO_BASE, Pintor.SANS, t, Tema.TEXTO_2, Pintor.ESQ);
        }
        if (m.aviso != null) {
            p.texto(m.aviso, DIREITA, ESTADO_BASE, Pintor.SANS_SEMI, t, Tema.AMARELO, Pintor.DIR);
        }
    }

    private static void painelLuz(Pintor p, Modelo m) {
        p.gradiente(0, 0, LARGURA, ALTURA, Tema.FUNDO, Tema.FUNDO_BASE);
        titulo(p, "Luz do projetor", MX, ENT_TITULO);
        p.texto(m.luz + "%", MX, RELOGIO_BASE, Pintor.MONO_SEMI, RELOGIO_TAM, Tema.TEXTO, Pintor.ESQ);
        p.texto("Luz atual do LED", MX + 6, DATA_BASE, Pintor.SANS, DATA_TAM, Tema.TEXTO_2, Pintor.ESQ);
        titulo(p, "Escolha o nível", MX, ATA_TITULO);
        int n = Modelo.LUZ_NIVEIS.length;
        float w = (CONTEUDO - (n - 1) * VAO) / n;
        float y = ATA_Y;
        float h = 300;
        for (int i = 0; i < n; i++) {
            int nivel = Modelo.LUZ_NIVEIS[i];
            float x = MX + i * (w + VAO);
            boolean f = m.luzSel == i;
            cartao(p, x, y, w, h, f);
            p.texto(nivel + "%", x + 30, y + 112, Pintor.MONO_SEMI, 64, Tema.TEXTO, Pintor.ESQ);
            float bw = w - 60;
            p.retangulo(x + 30, y + 148, bw, 14, 7, f ? Tema.FUNDO : Tema.LINHA);
            p.retangulo(x + 30, y + 148, bw * nivel / 100f, 14, 7, f ? Tema.ROSA : Tema.TEXTO_2);
            if (nivel == Modelo.LUZ_ECONOMICO) {
                p.texto("Econômico", x + 30, y + 222, Pintor.SANS_SEMI, 28, Tema.TEXTO_2, Pintor.ESQ);
            }
            if (nivel == m.luz) {
                p.texto("Atual", x + 30, y + 264, Pintor.SANS_SEMI, 28, Tema.VERDE, Pintor.ESQ);
            }
        }
        p.texto("Se o LED esquentar demais, a proteção térmica baixa a luz por conta própria.",
                MX, 840, Pintor.SANS, 30, Tema.TEXTO_2, Pintor.ESQ);
        p.texto("O nível escolhido volta sozinho toda vez que o projetor liga.",
                MX, 884, Pintor.SANS, 30, Tema.TEXTO_2, Pintor.ESQ);
        p.texto("Setas: escolher    OK: aplicar    Voltar: fechar", MX, ESTADO_BASE, Pintor.SANS, 28, Tema.TEXTO_2, Pintor.ESQ);
        if (m.aviso != null) {
            p.texto(m.aviso, DIREITA, ESTADO_BASE, Pintor.SANS_SEMI, 28, Tema.AMARELO, Pintor.DIR);
        }
    }

    private static void cartao(Pintor p, float x, float y, float w, float h, boolean foco) {
        if (foco) {
            p.retangulo(x, y, w, h, RAIO, Tema.LINHA);
            p.contorno(x - 8, y - 8, w + 16, h + 16, RAIO + 8, 5, Tema.ROSA);
        } else {
            p.retangulo(x, y, w, h, RAIO, Tema.CARTAO);
        }
    }

    static void rotulo(Pintor p, String s, float x, float base, float maxW, int fonte, float tam, float entre, int alin) {
        List<String> linhas = quebrar(p, s, fonte, tam, maxW, 2);
        float y = base - (linhas.size() - 1) * entre;
        for (String l : linhas) {
            p.texto(l, x, y, fonte, tam, Tema.TEXTO, alin);
            y += entre;
        }
    }

    static List<String> quebrar(Pintor p, String s, int fonte, float tam, float maxW, int maxLinhas) {
        List<String> r = new ArrayList<String>();
        String atual = "";
        for (String w : s.trim().split("\\s+")) {
            String tenta = atual.isEmpty() ? w : atual + " " + w;
            if (p.largura(tenta, fonte, tam) <= maxW || atual.isEmpty()) {
                atual = tenta;
            } else {
                r.add(atual);
                atual = w;
            }
        }
        if (!atual.isEmpty()) r.add(atual);
        while (r.size() > maxLinhas) {
            String ult = r.remove(r.size() - 1);
            r.set(r.size() - 1, r.get(r.size() - 1) + " " + ult);
        }
        for (int i = 0; i < r.size(); i++) r.set(i, reticencias(p, r.get(i), fonte, tam, maxW));
        return r;
    }

    static String reticencias(Pintor p, String s, int fonte, float tam, float maxW) {
        if (p.largura(s, fonte, tam) <= maxW) return s;
        String r = s;
        while (r.length() > 1 && p.largura(r + "…", fonte, tam) > maxW) r = r.substring(0, r.length() - 1);
        return r.trim() + "…";
    }
}
