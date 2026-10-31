package com.pfl7560.home;

/**
 * O que o desenho da home precisa de uma tela. Duas implementacoes: PintorCanvas (Android, no
 * aparelho) e PintorJ2D (Java2D, no PC, para as previas). O codigo de desenho (Desenho, Icones)
 * e o MESMO nos dois; so muda quem pinta.
 *
 * Coordenadas em pixels de um quadro 1920x1080. Cores em ARGB. Angulos em graus, 0 = 3 horas,
 * sentido horario (o do Android).
 */
public interface Pintor {
    int SANS = 0;          // IBM Plex Sans Condensed Regular
    int SANS_SEMI = 1;     // IBM Plex Sans Condensed SemiBold
    int SANS_NEGRITO = 2;  // IBM Plex Sans Condensed Bold
    int MONO = 3;          // IBM Plex Mono Regular
    int MONO_SEMI = 4;     // IBM Plex Mono SemiBold

    int ESQ = 0;
    int CENTRO = 1;
    int DIR = 2;

    void gradiente(float x, float y, float w, float h, int corTopo, int corBase);

    void retangulo(float x, float y, float w, float h, float raio, int cor);

    void contorno(float x, float y, float w, float h, float raio, float esp, int cor);

    void linha(float x1, float y1, float x2, float y2, float esp, int cor);

    void circulo(float cx, float cy, float r, int cor);

    void anel(float cx, float cy, float r, float esp, int cor);

    void arco(float cx, float cy, float r, float inicio, float varredura, float esp, int cor);

    /** xy = x0,y0,x1,y1,... ; pontas e juncoes arredondadas. */
    void polilinha(float[] xy, boolean fechada, float esp, int cor);

    void texto(String s, float x, float yBase, int fonte, float tam, int cor, int alin);

    float largura(String s, int fonte, float tam);

    /** Desenha o icone de um app (Drawable no Android). Devolve false se nao houver. */
    boolean icone(Object icone, float x, float y, float lado);
}
