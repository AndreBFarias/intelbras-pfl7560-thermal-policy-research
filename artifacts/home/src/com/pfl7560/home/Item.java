package com.pfl7560.home;

public final class Item {
    public final String rotulo;
    public final int icone;
    public final String acao;
    public final String pacote;
    public final String classe;

    public Item(String rotulo, int icone, String acao) {
        this(rotulo, icone, acao, null, null);
    }

    public Item(String rotulo, int icone, String acao, String pacote, String classe) {
        this.rotulo = rotulo;
        this.icone = icone;
        this.acao = acao;
        this.pacote = pacote;
        this.classe = classe;
    }

    public static Item app(String rotulo, String pacote, String classe) {
        return new Item(rotulo, Icones.paraPacote(pacote), null, pacote, classe);
    }
}
