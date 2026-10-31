package com.pfl7560.home;

/** Nomes das acoes dos cartoes. Quem abre cada uma e o Abridor (so Android); fontes no doc 45. */
public final class Acoes {
    public static final String HDMI1 = "hdmi1";
    public static final String HDMI2 = "hdmi2";
    public static final String USB_C = "usbc";
    public static final String VERIFICAR = "verificar";
    public static final String WIFI = "wifi";
    public static final String BLUETOOTH = "bluetooth";
    public static final String IMAGEM = "imagem";
    public static final String CONFIG = "config";
    public static final String ESPELHAR = "espelhar";
    /** Abre o painel de luz do proprio app (nao passa pelo Abridor). */
    public static final String LUZ = "luz";

    private Acoes() {
    }
}
