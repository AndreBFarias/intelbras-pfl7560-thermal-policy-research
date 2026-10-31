package com.pfl7560.home;

public interface Pintor {
    int SANS = 0;
    int SANS_SEMI = 1;
    int SANS_NEGRITO = 2;
    int MONO = 3;
    int MONO_SEMI = 4;

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

    void polilinha(float[] xy, boolean fechada, float esp, int cor);

    void texto(String s, float x, float yBase, int fonte, float tam, int cor, int alin);

    float largura(String s, int fonte, float tam);
}
