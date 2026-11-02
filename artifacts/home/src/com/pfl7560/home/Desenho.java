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

    static final float ATA_TITULO = 432f;
    static final float ATA_Y = 456f;
    static final float ATA_H = 172f;

    public static final int APPS_VISIVEIS = 7;
    static final float APP_TITULO = 724f;
    static final float APP_Y = 748f;
    static final float APP_H = 190f;
    static final float APP_W = (CONTEUDO - (APPS_VISIVEIS - 1) * VAO) / APPS_VISIVEIS;

    static final float ESTADO_BASE = 1000f;

    static final float TITULO_TAM = 30f;

    private Desenho() {
    }

    /** As entradas encostam na direita, quantas forem. */
    static float entX0(Modelo m) {
        int n = Math.max(1, m.entradas.length);
        return DIREITA - (n * ENT_W + (n - 1) * VAO);
    }

    /** Os atalhos dividem a largura toda entre si. */
    static float ataW(Modelo m) {
        int n = Math.max(1, m.atalhos.length);
        return (CONTEUDO - (n - 1) * VAO) / n;
    }

    public static float centroX(Modelo m, int fileira, int i) {
        if (fileira == Modelo.ENTRADAS) return entX0(m) + i * (ENT_W + VAO) + ENT_W / 2;
        if (fileira == Modelo.ATALHOS) return MX + i * (ataW(m) + VAO) + ataW(m) / 2;
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
        if (m.curvasAberta) painelCurvas(p, m);
        if (m.ajustesAberta) painelAjustes(p, m);
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
        float x0 = entX0(m);
        titulo(p, "Entradas", x0, ENT_TITULO);
        for (int i = 0; i < m.entradas.length; i++) {
            float x = x0 + i * (ENT_W + VAO);
            boolean f = m.fileira == Modelo.ENTRADAS && m.coluna == i;
            cartao(p, x, ENT_Y, ENT_W, ENT_H, f);
            int cf = f ? Tema.LINHA : Tema.CARTAO;
            Icones.desenhar(p, m.entradas[i].icone, x + 26, ENT_Y + 22, 76, f ? Tema.ROSA : Tema.TEXTO_2, cf);
            p.texto(m.entradas[i].rotulo, x + 30, ENT_Y + ENT_H - 32, Pintor.SANS_NEGRITO, 44, Tema.TEXTO, Pintor.ESQ);
        }
    }

    private static void atalhos(Pintor p, Modelo m) {
        titulo(p, "Atalhos", MX, ATA_TITULO);
        final float ATA_W = ataW(m);
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
        if (m.bluetooth != null) {
            Icones.desenhar(p, Icones.BLUETOOTH, x, ESTADO_BASE - 28, 34, Tema.TEXTO_2, Tema.FUNDO_BASE);
            x += 46;
            p.texto(m.bluetooth, x, ESTADO_BASE, Pintor.SANS, t, Tema.TEXTO_2, Pintor.ESQ);
            x += p.largura(m.bluetooth, Pintor.SANS, t) + 48;
        }
        if (m.temperatura != null || m.temperaturaPlaca != null) {
            Icones.desenhar(p, Icones.TERMOMETRO, x, ESTADO_BASE - 28, 34, Tema.TEXTO_2, Tema.FUNDO_BASE);
            x += 42;
            if (m.temperatura != null) x = graus(p, "LED", m.temperatura, x, t) + 32;
            if (m.temperaturaPlaca != null) graus(p, "Placa", m.temperaturaPlaca, x, t);
        }
        if (m.aviso != null) {
            p.texto(m.aviso, DIREITA, ESTADO_BASE, Pintor.SANS_SEMI, t, Tema.AMARELO, Pintor.DIR);
        }
    }

    /** "Nome nn °C" no rodape; devolve onde termina. */
    private static float graus(Pintor p, String nome, String valor, float x, float t) {
        p.texto(nome, x, ESTADO_BASE, Pintor.SANS, t, Tema.TEXTO_2, Pintor.ESQ);
        x += p.largura(nome + " ", Pintor.SANS, t);
        p.texto(valor, x, ESTADO_BASE, Pintor.MONO, 27, Tema.TEXTO_2, Pintor.ESQ);
        x += p.largura(valor, Pintor.MONO, 27) + 5;
        p.texto("°C", x, ESTADO_BASE, Pintor.SANS, t, Tema.TEXTO_2, Pintor.ESQ);
        return x + p.largura("°C", Pintor.SANS, t);
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

    static final float CV_ABA_Y = 140f;
    static final float CV_PERFIL_Y = 224f;
    static final float CV_CHIP_H = 60f;
    static final float CV_GX = MX + 80f;
    static final float CV_GY = 344f;
    static final float CV_GW = 1080f;
    static final float CV_GH = 490f;
    static final float CV_MODO_Y = 898f;

    private static void chip(Pintor p, float x, float y, float w, String s, boolean sel, boolean foco) {
        if (foco) {
            p.retangulo(x, y, w, CV_CHIP_H, 14, Tema.LINHA);
            p.contorno(x - 6, y - 6, w + 12, CV_CHIP_H + 12, 20, 4, Tema.ROSA);
        } else {
            p.retangulo(x, y, w, CV_CHIP_H, 14, sel ? Tema.LINHA : Tema.CARTAO);
        }
        p.texto(s, x + w / 2, y + 40, Pintor.SANS_SEMI, 30, sel || foco ? Tema.TEXTO : Tema.TEXTO_2, Pintor.CENTRO);
        if (sel) p.retangulo(x + 18, y + CV_CHIP_H - 9, w - 36, 4, 2, Tema.VERDE);
    }

    private static float cvX(float t, float t0, float t1) {
        return CV_GX + (t - t0) / (t1 - t0) * CV_GW;
    }

    private static float cvY(float v, float v0, float v1) {
        return CV_GY + CV_GH - (v - v0) / (v1 - v0) * CV_GH;
    }

    private static void painelCurvas(Pintor p, Modelo m) {
        Curvas c = m.curvas;
        boolean vent = c.aba == Curvas.ABA_VENT;
        p.gradiente(0, 0, LARGURA, ALTURA, Tema.FUNDO, Tema.FUNDO_BASE);
        titulo(p, "Curvas do projetor", MX, ENT_TITULO);
        String[] abas = {"Ventiladores", "Brilho do LED", "Logo do boot"};
        for (int i = 0; i < abas.length; i++) {
            chip(p, MX + i * (300 + VAO), CV_ABA_Y, 300, abas[i], c.aba == i, c.zona == Curvas.ZONA_ABA && c.aba == i);
        }
        if (c.aba == Curvas.ABA_LOGO) {
            painelLogo(p, m);
            return;
        }
        String[] perfis = c.rotulosPerfil();
        float pw = vent ? 236 : 300;
        for (int i = 0; i < perfis.length; i++) {
            chip(p, MX + i * (pw + 16), CV_PERFIL_Y, pw, perfis[i], c.perfil() == i,
                    c.zona == Curvas.ZONA_PERFIL && c.perfil() == i);
        }
        grafico(p, m, vent);
        painelDireito(p, m, vent);
        float mx = MX;
        for (int i = 0; i < Curvas.MODOS.length; i++) {
            float w = i == 1 ? 330 : 230;
            chip(p, mx, CV_MODO_Y, w, Curvas.ROTULOS_MODO[i], c.modo == i, c.zona == Curvas.ZONA_MODO && c.modo == i);
            mx += w + 16;
        }
        boolean fa = c.zona == Curvas.ZONA_APLICAR;
        String rot = c.pedindo != null ? "Enviando..." : "Aplicar";
        float ax = DIREITA - 300;
        if (fa) {
            p.retangulo(ax, CV_MODO_Y, 300, CV_CHIP_H, 14, Tema.ROSA);
            p.texto(rot, ax + 150, CV_MODO_Y + 40, Pintor.SANS_NEGRITO, 32, Tema.FUNDO, Pintor.CENTRO);
        } else {
            p.retangulo(ax, CV_MODO_Y, 300, CV_CHIP_H, 14, Tema.CARTAO);
            p.texto(rot, ax + 150, CV_MODO_Y + 40, Pintor.SANS_NEGRITO, 32, Tema.TEXTO_2, Pintor.CENTRO);
        }
        // a unica dica que fica: com a bola pega, as setas mudam de papel
        if (c.zona == Curvas.ZONA_GRAFICO && c.pegando) {
            p.texto("Setas: mover a bola    OK ou Voltar: soltar", MX, 1030, Pintor.SANS, 28, Tema.TEXTO_2, Pintor.ESQ);
        }
        if (m.aviso != null) p.texto(m.aviso, DIREITA, 1030, Pintor.SANS_SEMI, 28, Tema.AMARELO, Pintor.DIR);
    }

    static final float LG_CHAVE_Y = 250f;
    static final float LG_INFO_Y = 400f;

    private static void painelLogo(Pintor p, Modelo m) {
        Curvas c = m.curvas;
        boolean ligado = c.logoLigado();
        boolean foco = c.zona == Curvas.ZONA_PERFIL;
        float w = 900;
        if (foco) {
            p.retangulo(MX, LG_CHAVE_Y, w, 96, 18, Tema.LINHA);
            p.contorno(MX - 6, LG_CHAVE_Y - 6, w + 12, 108, 24, 4, Tema.ROSA);
        } else {
            p.retangulo(MX, LG_CHAVE_Y, w, 96, 18, Tema.CARTAO);
        }
        p.texto("Logo automático", MX + 32, LG_CHAVE_Y + 60, Pintor.SANS_SEMI, 34, Tema.TEXTO, Pintor.ESQ);
        String rot = c.pedindo != null ? "Enviando..." : "erro".equals(c.logoEstado) ? "Erro" : ligado ? "Ligado" : "Desligado";
        float sx = MX + w - 220;
        p.retangulo(sx, LG_CHAVE_Y + 22, 188, 52, 26, ligado ? Tema.VERDE : Tema.LINHA);
        p.texto(rot, sx + 94, LG_CHAVE_Y + 58, Pintor.SANS_NEGRITO, 28, ligado ? Tema.FUNDO : Tema.TEXTO_2, Pintor.CENTRO);
        String[][] linhas = {
            {"Cantos do logo gravado", Curvas.rotuloCantos(c.logoCantos)},
            {"Última gravação", c.logoHora == null || c.logoHora.isEmpty() ? "Nenhuma por aqui" : c.logoHora},
            {"Última recusa", Curvas.rotuloMotivo(c.logoMotivo)},
        };
        float y = LG_INFO_Y;
        for (String[] l : linhas) {
            p.texto(l[0], MX, y, Pintor.SANS, 28, Tema.TEXTO_2, Pintor.ESQ);
            p.texto(l[1], MX, y + 44, Pintor.SANS_SEMI, 32, Tema.TEXTO, Pintor.ESQ);
            y += 118;
        }
        if (m.aviso != null) p.texto(m.aviso, DIREITA, 1030, Pintor.SANS_SEMI, 28, Tema.AMARELO, Pintor.DIR);
    }

    private static void grafico(Pintor p, Modelo m, boolean vent) {
        Curvas c = m.curvas;
        float t0 = vent ? 25 : 40;
        float t1 = 75;
        float v0 = vent ? 0 : 840;
        float v1 = vent ? 100 : 1000;
        p.retangulo(CV_GX, CV_GY, CV_GW, CV_GH, 14, Tema.CARTAO);
        for (int t = (int) t0; t <= (int) t1; t += 5) {
            float x = cvX(t, t0, t1);
            p.linha(x, CV_GY, x, CV_GY + CV_GH, 1.5f, Tema.LINHA);
            if (t % 10 == 0 || t == (int) t0) {
                p.texto(String.valueOf(t), x, CV_GY + CV_GH + 36, Pintor.MONO, 24, Tema.TEXTO_2, Pintor.CENTRO);
            }
        }
        int[] marcas = vent ? new int[] {0, 20, 40, 60, 80, 100} : new int[] {850, 900, 950, 1000};
        for (int v : marcas) {
            float y = cvY(v, v0, v1);
            p.linha(CV_GX, y, CV_GX + CV_GW, y, 1.5f, Tema.LINHA);
            String s = vent ? v + "%" : String.valueOf(v);
            p.texto(s, CV_GX - 12, y + 8, Pintor.MONO, 24, Tema.TEXTO_2, Pintor.DIR);
        }
        p.texto("Temperatura do LED (°C)", CV_GX + CV_GW, CV_GY + CV_GH + 74, Pintor.SANS, 26,
                Tema.TEXTO_2, Pintor.DIR);
        p.texto(vent ? "Velocidade dos ventiladores" : "Brilho do LED (0 a 1000)", CV_GX - 68, CV_GY - 14, Pintor.SANS, 26, Tema.TEXTO_2, Pintor.ESQ);
        int[] t = c.temps();
        int[] v = c.valores();
        int n = c.pontos();
        if (vent) {
            float xf = cvX(Curvas.T_CHEIA, t0, t1);
            p.retangulo(xf, CV_GY, CV_GX + CV_GW - xf, CV_GH, 0, Tema.misturar(Tema.VERMELHO, Tema.CARTAO, 0.22f));
            p.texto("100% obrigatório", (xf + CV_GX + CV_GW) / 2, CV_GY + 110, Pintor.SANS_SEMI, 24, Tema.VERMELHO, Pintor.CENTRO);
            float yp = cvY(Curvas.V_MIN, v0, v1);
            p.linha(CV_GX, yp, CV_GX + CV_GW, yp, 3, Tema.LARANJA);
            p.texto("piso 70%", CV_GX + 16, yp + 40, Pintor.SANS_SEMI, 24, Tema.LARANJA, Pintor.ESQ);
            float[] xy = new float[2 * (n + 2)];
            xy[0] = cvX(t0, t0, t1);
            xy[1] = cvY(v[0], v0, v1);
            for (int i = 0; i < n; i++) {
                xy[2 + 2 * i] = cvX(t[i], t0, t1);
                xy[3 + 2 * i] = cvY(v[i], v0, v1);
            }
            xy[2 * n + 2] = cvX(t1, t0, t1);
            xy[2 * n + 3] = cvY(100, v0, v1);
            p.polilinha(xy, false, 6, Tema.ROXO);
        } else {
            float xf = cvX(70, t0, t1);
            p.retangulo(xf, CV_GY, CV_GX + CV_GW - xf, CV_GH, 0, Tema.misturar(Tema.VERMELHO, Tema.CARTAO, 0.22f));
            p.texto("do firmware", (xf + CV_GX + CV_GW) / 2, CV_GY + 40, Pintor.SANS_SEMI, 24, Tema.VERMELHO, Pintor.CENTRO);
            if (c.perfilLed == 0) {
                p.linha(cvX(t0, t0, t1), cvY(1000, v0, v1), xf, cvY(1000, v0, v1), 6, Tema.COMENTARIO);
                p.texto("sem curva: o firmware decide", CV_GX + 20, cvY(1000, v0, v1) + 44, Pintor.SANS, 26, Tema.TEXTO_2, Pintor.ESQ);
            } else {
                float[] xy = new float[2 * (2 * n + 2)];
                int k = 0;
                xy[k++] = cvX(t0, t0, t1);
                xy[k++] = cvY(1000, v0, v1);
                float anterior = 1000;
                for (int i = 0; i < n; i++) {
                    xy[k++] = cvX(t[i], t0, t1);
                    xy[k++] = cvY(anterior, v0, v1);
                    xy[k++] = cvX(t[i], t0, t1);
                    xy[k++] = cvY(v[i], v0, v1);
                    anterior = v[i];
                }
                xy[k++] = xf;
                xy[k++] = cvY(anterior, v0, v1);
                p.polilinha(xy, false, 6, Tema.ROXO);
            }
        }
        if (m.temperatura != null) {
            try {
                float tt = Float.parseFloat(m.temperatura);
                if (tt >= t0 && tt <= t1) {
                    float x = cvX(tt, t0, t1);
                    p.linha(x, CV_GY, x, CV_GY + CV_GH, 3, Tema.CIANO);
                    p.texto("LED " + m.temperatura + " °C", x + 10, CV_GY + CV_GH - 14, Pintor.SANS_SEMI, 24, Tema.CIANO, Pintor.ESQ);
                }
            } catch (NumberFormatException e) {
            }
        }
        if (c.perfilLed == 0 && !vent) return;
        for (int i = 0; i < n; i++) {
            float x = cvX(t[i], t0, t1);
            float y = cvY(v[i], v0, v1);
            boolean sel = c.zona == Curvas.ZONA_GRAFICO && c.bola == i;
            if (sel) {
                p.anel(x, y, 27, 5, c.pegando ? Tema.VERDE : Tema.ROSA);
                p.circulo(x, y, 17, c.pegando ? Tema.VERDE : Tema.ROSA);
            } else {
                p.circulo(x, y, 14, Tema.ROSA);
            }
            p.texto(String.valueOf(i + 1), x, y - 36, Pintor.MONO_SEMI, 22, Tema.TEXTO_2, Pintor.CENTRO);
        }
    }

    static final float AJ_ABA_Y = 140f;
    static final float AJ_LINHA_Y = 228f;
    static final float AJ_LINHA_H = 58f;
    static final float AJ_CHAVE_X = MX + 1060f;
    static final float AJ_ESTADO_X = MX + 1190f;

    /** O interruptor de um SERVICO: '1' ligado (verde, a direita), '0' desligado, 'p' parcial (no meio). */
    private static void chave(Pintor p, float x, float y, char c, boolean foco, boolean emCurso) {
        float w = 84f;
        float h = 40f;
        int fundo = c == '1' ? Tema.VERDE : c == 'p' ? Tema.LARANJA : Tema.LINHA;
        if (emCurso) fundo = Tema.misturar(fundo, Tema.CARTAO, 0.5f);
        p.retangulo(x, y, w, h, h / 2, foco && !emCurso && c != '1' && c != 'p' ? Tema.COMENTARIO : fundo);
        float cx = c == '1' ? x + w - h / 2 : c == 'p' ? x + w / 2 : x + h / 2;
        p.circulo(cx, y + h / 2, h / 2 - 5, Tema.TEXTO);
    }

    private static void fundoLinha(Pintor p, float y, boolean f) {
        if (f) {
            p.retangulo(MX, y, CONTEUDO, AJ_LINHA_H - 6, 12, Tema.LINHA);
            p.contorno(MX - 4, y - 4, CONTEUDO + 8, AJ_LINHA_H + 2, 16, 4, Tema.ROSA);
        } else {
            p.retangulo(MX, y, CONTEUDO, AJ_LINHA_H - 6, 12, Tema.CARTAO);
        }
    }

    private static boolean temChave(char c) {
        return c == '1' || c == '0' || c == 'p';
    }

    private static int corEstado(char c, boolean emCurso) {
        if (emCurso) return Tema.AMARELO;
        return c == '1' ? Tema.VERDE : c == 'p' ? Tema.LARANJA : c == '0' ? Tema.TEXTO_2 : Tema.COMENTARIO;
    }

    private static void listaServicos(Pintor p, Modelo m) {
        Ajustes a = m.ajustes;
        for (int l = 0; l < Ajustes.VISIVEIS.length; l++) {
            int i = Ajustes.VISIVEIS[l];
            float y = AJ_LINHA_Y + l * AJ_LINHA_H;
            boolean f = a.zona == Ajustes.ZONA_LINHAS && a.linha == l;
            char c = a.lido() ? a.servico(i) : '?';
            boolean ec = a.emCurso(i);
            fundoLinha(p, y, f);
            p.texto(Ajustes.ROTULOS[i], MX + 24, y + 38, Pintor.SANS_SEMI, 30, c == '-' ? Tema.TEXTO_2 : Tema.TEXTO, Pintor.ESQ);
            if (temChave(c)) chave(p, AJ_CHAVE_X, y + 7, c, f, ec);
            float ex = temChave(c) ? AJ_ESTADO_X : AJ_CHAVE_X;
            p.texto(a.rotuloServico(i), ex, y + 37, Pintor.SANS, 28, corEstado(c, ec), Pintor.ESQ);
        }
        linhaDescanso(p, a, AJ_LINHA_Y + Ajustes.VISIVEIS.length * AJ_LINHA_H);
        if (a.zona == Ajustes.ZONA_LINHAS) {
            float ty = AJ_LINHA_Y + (Ajustes.VISIVEIS.length + 1) * AJ_LINHA_H + 40;
            String faz = a.naLinhaDescanso() ? Ajustes.DESCANSO_FAZ : Ajustes.FAZ[a.indice()];
            p.texto(reticencias(p, faz, Pintor.SANS, 28, CONTEUDO), MX, ty, Pintor.SANS, 28, Tema.TEXTO_2, Pintor.ESQ);
        }
        // a unica linha em que esquerda/direita nao troca a aba: o rodape diz o que as teclas fazem nela
        if (a.naLinhaDescanso()) {
            p.texto(Ajustes.DESCANSO_TECLAS, MX, 1030, Pintor.SANS, 28, Tema.TEXTO_2, Pintor.ESQ);
        }
    }

    /** "Desligar no descanso": interruptor como os servicos e o tempo encostado na direita. */
    private static void linhaDescanso(Pintor p, Ajustes a, float y) {
        boolean f = a.naLinhaDescanso();
        char c = a.estadoDescanso();
        boolean ec = a.descansoAplicando != null;
        fundoLinha(p, y, f);
        p.texto(Ajustes.DESCANSO_ROTULO, MX + 24, y + 38, Pintor.SANS_SEMI, 30, Tema.TEXTO, Pintor.ESQ);
        if (temChave(c)) chave(p, AJ_CHAVE_X, y + 7, c, f, ec);
        float ex = temChave(c) ? AJ_ESTADO_X : AJ_CHAVE_X;
        p.texto(a.rotuloDescanso(), ex, y + 37, Pintor.SANS, 28, corEstado(c, ec), Pintor.ESQ);
        if (c != '?') {
            p.texto(a.minutosDescanso() + " min", DIREITA - 24, y + 38, Pintor.MONO_SEMI, 30,
                    ec ? Tema.AMARELO : c == '1' ? Tema.TEXTO : Tema.TEXTO_2, Pintor.DIR);
        }
    }

    private static void listaDiario(Pintor p, Modelo m) {
        Ajustes a = m.ajustes;
        for (int i = 0; i < Ajustes.DIARIO_ROTULOS.length; i++) {
            float y = AJ_LINHA_Y + i * AJ_LINHA_H;
            boolean f = a.zona == Ajustes.ZONA_LINHAS && a.linha == i;
            fundoLinha(p, y, f);
            p.texto(Ajustes.DIARIO_ROTULOS[i], MX + 24, y + 38, Pintor.SANS_SEMI, 30, Tema.TEXTO, Pintor.ESQ);
            if (i == 0) {
                char c = a.estadoDiario();
                boolean ec = a.diarioAplicando == '1' || a.diarioAplicando == '0';
                if (c == '1' || c == '0') chave(p, AJ_CHAVE_X, y + 7, c, f, ec);
                float ex = (c == '1' || c == '0') ? AJ_ESTADO_X : AJ_CHAVE_X;
                p.texto(a.rotuloEstadoDiario(), ex, y + 37, Pintor.SANS, 28, corEstado(c, ec), Pintor.ESQ);
            } else if (a.diarioAplicando == 'e') {
                p.texto("Pedindo…", AJ_CHAVE_X, y + 37, Pintor.SANS, 28, Tema.AMARELO, Pintor.ESQ);
            } else if (!a.diarioLido()) {
                p.texto("Lendo…", AJ_CHAVE_X, y + 37, Pintor.SANS, 28, Tema.COMENTARIO, Pintor.ESQ);
            } else if (a.diarioPedido()) {
                p.texto("Esperando o PC", AJ_CHAVE_X, y + 37, Pintor.SANS, 28, Tema.AMARELO, Pintor.ESQ);
            }
        }
        float ty = AJ_LINHA_Y + Ajustes.DIARIO_ROTULOS.length * AJ_LINHA_H + 40;
        if (a.diarioLido()) {
            p.texto("Tamanho: " + Ajustes.rotuloTamanho(a.diarioBytes()) + " de 512 KB", MX, ty, Pintor.SANS_SEMI, 30, Tema.TEXTO, Pintor.ESQ);
            ty += 42;
            p.texto("Último envio: " + Ajustes.rotuloEnvio(a.diarioEnvio), MX, ty, Pintor.SANS_SEMI, 30, Tema.TEXTO, Pintor.ESQ);
            ty += 64;
        }
        if (a.zona == Ajustes.ZONA_LINHAS) {
            p.texto(Ajustes.DIARIO_FAZ[a.linha], MX, ty, Pintor.SANS, 28, Tema.TEXTO_2, Pintor.ESQ);
        }
    }

    private static void painelAjustes(Pintor p, Modelo m) {
        Ajustes a = m.ajustes;
        p.gradiente(0, 0, LARGURA, ALTURA, Tema.FUNDO, Tema.FUNDO_BASE);
        titulo(p, "Ajustes do sistema", MX, ENT_TITULO);
        for (int i = 0; i < a.abas(); i++) {
            chip(p, MX + i * (300 + VAO), AJ_ABA_Y, 300, Ajustes.ABAS[i], a.aba == i, a.zona == Ajustes.ZONA_ABA && a.aba == i);
        }
        if (a.aba == Ajustes.ABA_DIARIO) listaDiario(p, m);
        else listaServicos(p, m);
        if (a.confirmando >= 0 && a.confirmando == a.linha) {
            p.texto("OK de novo para desligar", MX, 1030, Pintor.SANS_SEMI, 28, Tema.AMARELO, Pintor.ESQ);
        }
        if (m.aviso != null) p.texto(m.aviso, DIREITA, 1030, Pintor.SANS_SEMI, 28, Tema.AMARELO, Pintor.DIR);
    }

    private static void painelDireito(Pintor p, Modelo m, boolean vent) {
        Curvas c = m.curvas;
        float x = CV_GX + CV_GW + 56;
        float w = DIREITA - x;
        float y = 332;
        p.texto("Bola " + (c.bola + 1) + " de " + c.pontos(), x, y, Pintor.SANS_SEMI, 30, Tema.ROXO, Pintor.ESQ);
        y += 52;
        if (!(c.aba == Curvas.ABA_LED && c.perfilLed == 0)) {
            p.texto(c.temps()[c.bola] + " °C", x, y, Pintor.MONO_SEMI, 54, Tema.TEXTO, Pintor.ESQ);
            y += 60;
            String vs = vent ? c.valores()[c.bola] + " %" : String.valueOf(c.valores()[c.bola]);
            p.texto(vs, x, y, Pintor.MONO_SEMI, 54, Tema.TEXTO, Pintor.ESQ);
            y += 52;
        } else {
            p.texto("Sem curva", x, y, Pintor.MONO_SEMI, 44, Tema.TEXTO_2, Pintor.ESQ);
            y += 60;
        }
        y += 24;
        String ativo = vent ? c.ventEstado : c.ledEstado;
        p.texto("Ativo agora", x, y, Pintor.SANS_SEMI, 26, Tema.ROXO, Pintor.ESQ);
        y += 34;
        for (String l : quebrar(p, Curvas.rotuloEstado(ativo), Pintor.SANS, 26, w, 2)) {
            p.texto(l, x, y, Pintor.SANS, 26, Tema.VERDE, Pintor.ESQ);
            y += 32;
        }
        String av = Curvas.rotuloAviso(vent ? c.ventAviso : c.ledAviso, vent);
        if (!av.isEmpty()) {
            y += 8;
            for (String l : quebrar(p, av, Pintor.SANS_SEMI, 24, w, 3)) {
                p.texto(l, x, y, Pintor.SANS_SEMI, 24, Tema.AMARELO, Pintor.ESQ);
                y += 30;
            }
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
