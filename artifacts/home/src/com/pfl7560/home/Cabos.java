package com.pfl7560.home;

import android.content.Context;
import android.media.tv.TvInputInfo;
import android.media.tv.TvInputManager;
import android.os.Handler;

import java.util.List;

/**
 * Le quais portas tem cabo e avisa a home a cada ligar/desligar (bloco 30). O sinal e o estado das entradas de TV
 * do hardware HDMI (Entradas, doc 45 §14): API publica do TvInputManager, sem root nem permissao. Nada de
 * varredura: le uma vez ao ligar e de novo so quando o system_server avisa (TvInputCallback).
 *
 * Tudo roda no fio proprio (o TvInputManager fala com o system_server por binder); a lista pronta vai ao thread
 * principal pelo Ouvinte.
 */
final class Cabos {
    interface Ouvinte {
        /** No thread principal. */
        void entradas(Item[] lista);
    }

    private final Context app;
    private final Handler fio;
    private final Handler principal;
    private final Ouvinte ouvinte;
    /** So no fio. */
    private TvInputManager tv;
    private boolean ouvindo;

    private final TvInputManager.TvInputCallback aviso = new TvInputManager.TvInputCallback() {
        @Override
        public void onInputStateChanged(String id, int estado) {
            ler();
        }

        @Override
        public void onInputAdded(String id) {
            ler();
        }

        @Override
        public void onInputRemoved(String id) {
            ler();
        }

        @Override
        public void onInputUpdated(String id) {
            ler();
        }
    };

    Cabos(Context app, Handler fio, Handler principal, Ouvinte ouvinte) {
        this.app = app;
        this.fio = fio;
        this.principal = principal;
        this.ouvinte = ouvinte;
    }

    /** Passa a ouvir e le agora (a home voltou para a frente: o cabo pode ter mudado enquanto ela nao ouvia). */
    void ligar() {
        fio.post(new Runnable() {
            @Override
            public void run() {
                try {
                    if (tv == null) tv = (TvInputManager) app.getSystemService(Context.TV_INPUT_SERVICE);
                    if (tv != null && !ouvindo) {
                        tv.registerCallback(aviso, fio);
                        ouvindo = true;
                    }
                } catch (RuntimeException e) {
                    Guarda.anotar(app, "entradas de TV", e);
                }
                ler();
            }
        });
    }

    void desligar() {
        fio.post(new Runnable() {
            @Override
            public void run() {
                if (tv == null || !ouvindo) return;
                try {
                    tv.unregisterCallback(aviso);
                } catch (RuntimeException e) {
                    Guarda.anotar(app, "desligar entradas de TV", e);
                }
                ouvindo = false;
            }
        });
    }

    /** No fio. */
    private void ler() {
        final Item[] lista = lerAgora();
        principal.post(new Runnable() {
            @Override
            public void run() {
                ouvinte.entradas(lista);
            }
        });
    }

    private Item[] lerAgora() {
        boolean usbc = Entradas.temUsbC(Leitor.prop("zysys.typec_count"), Leitor.prop("zysys.source.typec1"));
        int h1 = Entradas.porta(Leitor.prop("zysys.source.hdmi1"), Entradas.PADRAO_HDMI1);
        int h2 = Entradas.porta(Leitor.prop("zysys.source.hdmi2"), Entradas.PADRAO_HDMI2);
        int uc = usbc ? Entradas.porta(Leitor.prop("zysys.source.typec1"), Entradas.PADRAO_USBC) : -1;
        if (tv == null) return Entradas.semLeitura(usbc);
        int[] estado = Entradas.estadosVazios();
        try {
            List<TvInputInfo> lista = tv.getTvInputList();
            if (lista == null) return Entradas.semLeitura(usbc);
            for (TvInputInfo info : lista) {
                int p = Entradas.portaDoId(info.getId());
                if (p < 1 || p >= estado.length) continue;
                estado[p] = tv.getInputState(info.getId());
            }
        } catch (RuntimeException e) {
            Guarda.anotar(app, "ler entradas de TV", e);
            return Entradas.semLeitura(usbc);
        }
        return Entradas.comCabo(h1, h2, uc, estado);
    }
}
