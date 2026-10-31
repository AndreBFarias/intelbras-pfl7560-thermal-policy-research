package com.pfl7560.home;

/** Um cartao da home: uma entrada, um atalho ou um app. */
public final class Item {
    public final String rotulo;
    public final int icone;        // Icones.*
    public final String acao;      // Acoes.* para entradas e atalhos; null para app
    public final String pacote;    // app: pacote e classe da atividade MAIN+LAUNCHER
    public final String classe;
    public final Object imagem;    // app: o icone dele (Drawable no Android), ou null

    public Item(String rotulo, int icone, String acao) {
        this(rotulo, icone, acao, null, null, null);
    }

    public Item(String rotulo, int icone, String acao, String pacote, String classe, Object imagem) {
        this.rotulo = rotulo;
        this.icone = icone;
        this.acao = acao;
        this.pacote = pacote;
        this.classe = classe;
        this.imagem = imagem;
    }

    public static Item app(String rotulo, String pacote, String classe, Object imagem) {
        return new Item(rotulo, Icones.MONOGRAMA, null, pacote, classe, imagem);
    }
}
