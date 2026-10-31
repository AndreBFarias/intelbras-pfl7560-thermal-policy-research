package com.pfl7560.verificar;

import android.app.Activity;
import android.os.Bundle;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

/**
 * "Verificar projetor": grava o arquivo pedir-verificacao na pasta privada do app e fecha em 3 s.
 * Um vigia root (suite-boot.sh, ligado no boot) confere que o dono do arquivo e o dono desta
 * pasta e dispara a suite. Sem permissao nenhuma: so este app grava aqui.
 */
public class VerificarActivity extends Activity {
    static final String ARQUIVO = "pedir-verificacao";

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        if (pedir()) {
            Mensagem.mostrar(this, R.string.verificar_ok_titulo, R.string.verificar_ok_texto, R.color.texto);
        } else {
            Mensagem.mostrar(this, R.string.verificar_erro_titulo, R.string.verificar_erro_texto, R.color.atencao);
        }
    }

    private boolean pedir() {
        File f = new File(getDataDir(), ARQUIVO);
        try (FileOutputStream o = new FileOutputStream(f)) {
            o.write('1');
            o.getFD().sync();
            return true;
        } catch (IOException e) {
            return false;
        }
    }
}
