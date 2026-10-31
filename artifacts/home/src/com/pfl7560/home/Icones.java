package com.pfl7560.home;

/**
 * Icones desenhados no codigo, numa grade de 64x64, traco unico de 4/64 com pontas redondas.
 * Nada de imagem baixada: cada icone e uma lista de linhas, arcos e circulos.
 */
public final class Icones {
    public static final int HDMI = 1;
    public static final int USB_C = 2;
    public static final int VERIFICAR = 3;
    public static final int WIFI = 4;
    public static final int BLUETOOTH = 5;
    public static final int IMAGEM = 6;
    public static final int CONFIG = 7;
    public static final int ESPELHAR = 8;
    public static final int TERMOMETRO = 9;
    public static final int MONOGRAMA = 10;   // app sem icone: inicial num disco (desenhado no Desenho)

    private Icones() {
    }

    /** Desenha o icone `tipo` no quadrado (x, y, lado). `fundo` e a cor por baixo (para recortes). */
    public static void desenhar(Pintor p, int tipo, float x, float y, float lado, int cor, int fundo) {
        float s = lado / 64f;
        float e = 4f * s;
        switch (tipo) {
            case HDMI:
                p.polilinha(pts(x, y, s, 6, 22, 58, 22, 58, 34, 50, 44, 14, 44, 6, 34), true, e, cor);
                p.linha(x + 19 * s, y + 31 * s, x + 45 * s, y + 31 * s, e, cor);
                break;
            case USB_C:
                p.contorno(x + 7 * s, y + 23 * s, 50 * s, 18 * s, 9 * s, e, cor);
                p.linha(x + 20 * s, y + 32 * s, x + 44 * s, y + 32 * s, e, cor);
                break;
            case VERIFICAR:
                p.anel(x + 32 * s, y + 32 * s, 23 * s, e, cor);
                p.polilinha(pts(x, y, s, 21, 33, 29, 41, 44, 25), false, e, cor);
                break;
            case WIFI:
                p.arco(x + 32 * s, y + 49 * s, 32 * s, 225, 90, e, cor);
                p.arco(x + 32 * s, y + 49 * s, 21 * s, 225, 90, e, cor);
                p.arco(x + 32 * s, y + 49 * s, 10 * s, 225, 90, e, cor);
                p.circulo(x + 32 * s, y + 49 * s, 3.5f * s, cor);
                break;
            case BLUETOOTH:
                p.polilinha(pts(x, y, s, 19, 22, 44, 43, 32, 54, 32, 10, 44, 21, 19, 42), false, e, cor);
                break;
            case IMAGEM:
                // tela em trapezio (a correcao de 4 pontos) com os quatro cantos marcados
                p.polilinha(pts(x, y, s, 9, 16, 55, 11, 55, 53, 9, 48), true, e, cor);
                p.circulo(x + 9 * s, y + 16 * s, 5 * s, cor);
                p.circulo(x + 55 * s, y + 11 * s, 5 * s, cor);
                p.circulo(x + 55 * s, y + 53 * s, 5 * s, cor);
                p.circulo(x + 9 * s, y + 48 * s, 5 * s, cor);
                break;
            case CONFIG:
                // tres reguladores
                p.linha(x + 9 * s, y + 17 * s, x + 55 * s, y + 17 * s, e, cor);
                p.linha(x + 9 * s, y + 32 * s, x + 55 * s, y + 32 * s, e, cor);
                p.linha(x + 9 * s, y + 47 * s, x + 55 * s, y + 47 * s, e, cor);
                botao(p, x + 40 * s, y + 17 * s, s, cor, fundo);
                botao(p, x + 22 * s, y + 32 * s, s, cor, fundo);
                botao(p, x + 34 * s, y + 47 * s, s, cor, fundo);
                break;
            case ESPELHAR:
                // tela com as ondas de transmissao no canto
                p.polilinha(pts(x, y, s, 8, 25, 8, 13, 56, 13, 56, 51, 31, 51), false, e, cor);
                p.arco(x + 8 * s, y + 51 * s, 9 * s, 270, 90, e, cor);
                p.arco(x + 8 * s, y + 51 * s, 18 * s, 270, 90, e, cor);
                p.circulo(x + 9 * s, y + 50 * s, 3.5f * s, cor);
                break;
            case TERMOMETRO:
                p.contorno(x + 26 * s, y + 7 * s, 12 * s, 34 * s, 6 * s, e, cor);
                p.anel(x + 32 * s, y + 47 * s, 10 * s, e, cor);
                p.circulo(x + 32 * s, y + 47 * s, 5 * s, cor);
                p.linha(x + 32 * s, y + 24 * s, x + 32 * s, y + 42 * s, e, cor);
                break;
            default:
                break;
        }
    }

    private static void botao(Pintor p, float cx, float cy, float s, int cor, int fundo) {
        p.circulo(cx, cy, 7 * s, fundo);
        p.anel(cx, cy, 6 * s, 4 * s, cor);
    }

    private static float[] pts(float x, float y, float s, float... g) {
        float[] r = new float[g.length];
        for (int i = 0; i < g.length; i += 2) {
            r[i] = x + g[i] * s;
            r[i + 1] = y + g[i + 1] * s;
        }
        return r;
    }
}
