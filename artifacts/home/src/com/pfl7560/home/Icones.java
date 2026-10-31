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
    public static final int MONOGRAMA = 10;   // app sem desenho proprio: inicial num circulo (ver monograma())
    public static final int ARQUIVOS = 11;
    public static final int VIDEO = 12;
    public static final int MUSICA = 13;
    public static final int DOCUMENTOS = 14;
    public static final int ALTO_FALANTE = 15;
    public static final int GALERIA = 16;
    public static final int NAVEGADOR = 17;
    public static final int LOJA = 18;
    public static final int JOGO = 19;
    public static final int LUZ = 20;

    /** Os cinco acentos do tema para o monograma (o rosa e o do foco, mas tambem entra no sorteio estavel). */
    private static final int[] CORES_MONOGRAMA = {Tema.ROXO, Tema.ROSA, Tema.CIANO, Tema.VERDE, Tema.LARANJA};

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
            case ARQUIVOS:
                // pasta
                p.polilinha(pts(x, y, s, 6, 18, 24, 18, 31, 26, 58, 26, 58, 50, 6, 50), true, e, cor);
                break;
            case VIDEO:
                // tela com o triangulo de reproduzir
                p.contorno(x + 7 * s, y + 13 * s, 50 * s, 38 * s, 6 * s, e, cor);
                p.polilinha(pts(x, y, s, 27, 24, 27, 40, 41, 32), true, e, cor);
                break;
            case MUSICA:
                // duas notas ligadas por uma barra
                p.anel(x + 21 * s, y + 47 * s, 7 * s, e, cor);
                p.anel(x + 43 * s, y + 43 * s, 7 * s, e, cor);
                p.linha(x + 28 * s, y + 47 * s, x + 28 * s, y + 16 * s, e, cor);
                p.linha(x + 50 * s, y + 43 * s, x + 50 * s, y + 12 * s, e, cor);
                p.linha(x + 28 * s, y + 16 * s, x + 50 * s, y + 12 * s, e, cor);
                break;
            case DOCUMENTOS:
                // folha com a dobra no canto e duas linhas de texto
                p.polilinha(pts(x, y, s, 14, 6, 38, 6, 50, 18, 50, 58, 14, 58), true, e, cor);
                p.polilinha(pts(x, y, s, 38, 6, 38, 18, 50, 18), false, e, cor);
                p.linha(x + 23 * s, y + 33 * s, x + 41 * s, y + 33 * s, e, cor);
                p.linha(x + 23 * s, y + 44 * s, x + 41 * s, y + 44 * s, e, cor);
                break;
            case ALTO_FALANTE:
                // caixa de som: o falante grande embaixo e o pequeno em cima
                p.contorno(x + 16 * s, y + 6 * s, 32 * s, 52 * s, 8 * s, e, cor);
                p.anel(x + 32 * s, y + 40 * s, 9 * s, e, cor);
                p.circulo(x + 32 * s, y + 19 * s, 3.5f * s, cor);
                break;
            case GALERIA:
                // moldura com sol e montanhas
                p.contorno(x + 7 * s, y + 11 * s, 50 * s, 42 * s, 6 * s, e, cor);
                p.polilinha(pts(x, y, s, 10, 47, 23, 32, 33, 43, 41, 36, 54, 47), false, e, cor);
                p.circulo(x + 44 * s, y + 24 * s, 4 * s, cor);
                break;
            case NAVEGADOR:
                // globo: anel, equador e meridiano (dois arcos)
                p.anel(x + 32 * s, y + 32 * s, 24 * s, e, cor);
                p.linha(x + 8 * s, y + 32 * s, x + 56 * s, y + 32 * s, e, cor);
                p.arco(x + 56 * s, y + 32 * s, 33.94f * s, 135, 90, e, cor);
                p.arco(x + 8 * s, y + 32 * s, 33.94f * s, 315, 90, e, cor);
                break;
            case LOJA:
                // sacola com a alca
                p.polilinha(pts(x, y, s, 12, 20, 52, 20, 55, 56, 9, 56), true, e, cor);
                p.arco(x + 32 * s, y + 22 * s, 11 * s, 180, 180, e, cor);
                break;
            case JOGO:
                // controle: cruz a esquerda e dois botoes a direita
                p.contorno(x + 6 * s, y + 20 * s, 52 * s, 28 * s, 14 * s, e, cor);
                p.linha(x + 14 * s, y + 34 * s, x + 26 * s, y + 34 * s, e, cor);
                p.linha(x + 20 * s, y + 28 * s, x + 20 * s, y + 40 * s, e, cor);
                p.circulo(x + 42 * s, y + 30 * s, 3 * s, cor);
                p.circulo(x + 48 * s, y + 37 * s, 3 * s, cor);
                break;
            case LUZ:
                // sol: disco com oito raios
                p.anel(x + 32 * s, y + 32 * s, 11 * s, e, cor);
                for (int k = 0; k < 8; k++) {
                    double a = Math.PI / 4 * k;
                    float c = (float) Math.cos(a);
                    float sn = (float) Math.sin(a);
                    p.linha(x + (32 + 19 * c) * s, y + (32 + 19 * sn) * s, x + (32 + 27 * c) * s, y + (32 + 27 * sn) * s, e, cor);
                }
                break;
            default:
                break;
        }
    }

    /**
     * Qual desenho um app ganha, pelo nome do pacote (minusculas). Pacotes conhecidos por funcao;
     * o que nao casa fica com o monograma. A ordem importa: o alto-falante Bluetooth vem antes de
     * qualquer regra generica, e o Cast antes do video.
     */
    public static int paraPacote(String pacote) {
        String k = pacote == null ? "" : pacote.toLowerCase(java.util.Locale.ROOT);
        if (k.contains("bluetooth")) return ALTO_FALANTE;
        if (k.contains(".cast") || k.contains("miracast") || k.contains("screencast") || k.contains("mirror") || k.contains("airplay")) return ESPELHAR;
        if (k.contains("filemanager") || k.contains("explorer") || k.contains("documentsui")) return ARQUIVOS;
        if (k.contains("mobisystems") || k.contains("office") || k.contains("wps") || k.contains("docs")) return DOCUMENTOS;
        if (k.contains("video") || k.contains("movie") || k.contains("youtube") || k.contains("netflix")) return VIDEO;
        if (k.contains("music") || k.contains("audio") || k.contains("spotify")) return MUSICA;
        if (k.contains("gallery") || k.contains("photo")) return GALERIA;
        if (k.contains("browser") || k.contains("chrome") || k.contains("firefox")) return NAVEGADOR;
        if (k.contains("vending") || k.contains("market") || k.contains("aptoide") || k.contains("appstore")) return LOJA;
        if (k.contains("game")) return JOGO;
        return MONOGRAMA;
    }

    /** Cor do monograma, sorteada de forma estavel pelo nome (o mesmo app tem sempre a mesma cor). */
    public static int corMonograma(String chave) {
        int h = chave == null ? 0 : chave.hashCode();   // String.hashCode e especificado: igual em qualquer JVM
        return CORES_MONOGRAMA[(h & 0x7fffffff) % CORES_MONOGRAMA.length];
    }

    /**
     * App sem desenho proprio: a 1a letra do nome num circulo de contorno, no mesmo traco dos outros
     * icones. `foco` troca tudo para o rosa, como nos demais cartoes.
     */
    public static void monograma(Pintor p, String rotulo, String pacote, float x, float y, float lado, boolean foco) {
        float s = lado / 64f;
        int cor = foco ? Tema.ROSA : corMonograma(pacote != null && !pacote.isEmpty() ? pacote : rotulo);
        p.anel(x + 32 * s, y + 32 * s, 25 * s, 4 * s, cor);
        float tam = 34 * s;
        p.texto(inicial(rotulo), x + 32 * s, y + 32 * s + 0.35f * tam, Pintor.SANS_NEGRITO, tam, cor, Pintor.CENTRO);
    }

    static String inicial(String rotulo) {
        if (rotulo != null) {
            for (int i = 0; i < rotulo.length(); i++) {
                char c = rotulo.charAt(i);
                if (Character.isLetterOrDigit(c)) return String.valueOf(Character.toUpperCase(c));
            }
        }
        return "?";
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
