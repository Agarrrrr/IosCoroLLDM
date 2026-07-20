package com.lldm.coro;

import com.getcapacitor.BridgeActivity;

import android.os.Bundle;
import androidx.activity.EdgeToEdge;
import androidx.core.view.WindowCompat;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        // Habilitar Edge-to-Edge (requerido por Android 15 / SDK 35)
        EdgeToEdge.enable(this);

        // CRÍTICO: Decirle al sistema que NO aplique márgenes automáticos
        // para las barras del sistema. Nosotros lo manejamos con CSS safe-area-insets.
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);

        registerPlugin(NativePdfPlugin.class);
        super.onCreate(savedInstanceState);
    }
}
