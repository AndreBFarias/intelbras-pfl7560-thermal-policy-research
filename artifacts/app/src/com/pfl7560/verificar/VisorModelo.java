package com.pfl7560.verificar;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

/**
 * Regras do visor das telas da suite (bloco 29), em Java puro: o teste do PC
 * (tests/test-kit-pendrive.sh, c_app_visor) compila esta classe sem o android.jar.
 *
 * O canal com a suite e o mesmo do "Verificar projetor": arquivos na pasta privada do app.
 * - A suite (root) copia cada tela para getDataDir()/visor/NOME.png (pasta e arquivos do root,
 *   0755/0644) e manda "am start -n com.pfl7560.verificar/.Visor --es tela NOME.png".
 * - Voltar/Sair no visor grava getDataDir()/cancelar-suite; a suite confere o dono (o UID do app)
 *   entre as etapas e dentro das esperas, e para sem resumo.
 */
final class VisorModelo {
    static final String PASTA = "visor";
    static final String CANCELAR = "cancelar-suite";
    static final String EXTRA_TELA = "tela";
    static final String EXTRA_FECHAR = "fechar";
    /** android.view.KeyEvent.KEYCODE_BACK e KEYCODE_ESCAPE (constantes publicas do Android, API 1 e 11). */
    static final int TECLA_VOLTAR = 4;
    static final int TECLA_SAIR = 111;
    private static final int NOME_MAX = 80;

    enum Acao { MOSTRAR, FECHAR, NADA }

    private VisorModelo() {}

    /** So nomes simples: letra minuscula, digito, ponto e hifen, terminando em .png; sem barra nem "..". */
    static boolean nomeValido(String n) {
        if (n == null || n.length() < 5 || n.length() > NOME_MAX || !n.endsWith(".png")) return false;
        if (n.contains("..")) return false;
        for (int i = 0; i < n.length(); i++) {
            char c = n.charAt(i);
            boolean ok = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || (i > 0 && (c == '.' || c == '-'));
            if (!ok) return false;
        }
        return true;
    }

    /** Trocar a imagem nunca fecha o visor: so o pedido explicito de fechar fecha. */
    static Acao acao(String tela, boolean fechar) {
        if (fechar) return Acao.FECHAR;
        if (nomeValido(tela)) return Acao.MOSTRAR;
        return Acao.NADA;
    }

    static boolean cancela(int tecla) {
        return tecla == TECLA_VOLTAR || tecla == TECLA_SAIR;
    }

    static File arquivoDaTela(File dataDir, String tela) {
        if (dataDir == null || !nomeValido(tela)) return null;
        return new File(new File(dataDir, PASTA), tela);
    }

    /** Grava o pedido de cancelar (nasce com o dono do app, como o pedir-verificacao) e sincroniza. */
    static boolean gravarCancelar(File dataDir) {
        if (dataDir == null) return false;
        try (FileOutputStream o = new FileOutputStream(new File(dataDir, CANCELAR))) {
            o.write('1');
            o.getFD().sync();
            return true;
        } catch (IOException e) {
            return false;
        }
    }
}
