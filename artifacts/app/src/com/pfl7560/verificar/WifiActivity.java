package com.pfl7560.verificar;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Intent;
import android.os.Bundle;
import android.provider.Settings;

public class WifiActivity extends Activity {
    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        if (abrir(new Intent(Settings.ACTION_WIFI_SETTINGS))
                || abrir(new Intent().setComponent(new ComponentName(
                        "com.zhiying.settings", "com.zhiying.settings.network.WifiSettingActivity")))) {
            finish();
            return;
        }
        Mensagem.mostrar(this, R.string.wifi_erro_titulo, R.string.wifi_erro_texto, R.color.atencao);
    }

    private boolean abrir(Intent i) {
        try {
            startActivity(i);
            return true;
        } catch (RuntimeException e) {
            return false;
        }
    }
}
