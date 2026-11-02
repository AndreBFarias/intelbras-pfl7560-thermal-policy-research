package com.pfl7560.home;

public final class Tema {
    public static final int FUNDO = 0xFF282A36;
    public static final int LINHA = 0xFF44475A;
    public static final int TEXTO = 0xFFF8F8F2;
    public static final int COMENTARIO = 0xFF6272A4;
    public static final int CIANO = 0xFF8BE9FD;
    public static final int VERDE = 0xFF50FA7B;
    public static final int LARANJA = 0xFFFFB86C;
    public static final int ROSA = 0xFFFF79C6;
    public static final int ROXO = 0xFFBD93F9;
    public static final int VERMELHO = 0xFFFF5555;
    public static final int AMARELO = 0xFFF1FA8C;

    public static final int TEXTO_2 = misturar(TEXTO, FUNDO, 0.72f);
    public static final int CARTAO = misturar(LINHA, FUNDO, 0.62f);
    public static final int FUNDO_BASE = misturar(LINHA, FUNDO, 0.34f);

    private Tema() {
    }

    public static int misturar(int a, int b, float t) {
        int r = Math.round(((a >> 16) & 255) * t + ((b >> 16) & 255) * (1 - t));
        int g = Math.round(((a >> 8) & 255) * t + ((b >> 8) & 255) * (1 - t));
        int bl = Math.round((a & 255) * t + (b & 255) * (1 - t));
        return 0xFF000000 | (r << 16) | (g << 8) | bl;
    }
}
