package org.openglyph.sensorprobe;

import android.app.Activity;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Bundle;
import android.util.Log;
import android.widget.TextView;

import java.util.Arrays;

/** Logs every event of the light, proximity and Nothing pocket/matrix sensors until closed. */
public class MainActivity extends Activity implements SensorEventListener {
    private static final String TAG = "SensorProbe";
    private static final int[] TYPES = {5, 8, 33171066, 33171067, 65538, 65539, 65548, 65549};
    private SensorManager mSensors;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        TextView t = new TextView(this);
        t.setText("Sensor Probe: logging (adb logcat -s SensorProbe)");
        setContentView(t);
        mSensors = getSystemService(SensorManager.class);
        for (Sensor s : mSensors.getSensorList(Sensor.TYPE_ALL)) {
            for (int type : TYPES) {
                if (s.getType() != type) continue;
                boolean ok = mSensors.registerListener(this, s, SensorManager.SENSOR_DELAY_NORMAL);
                Log.i(TAG, "register " + s.getName() + " type=" + type + " wake=" + s.isWakeUpSensor()
                        + " mode=" + s.getReportingMode() + " max=" + s.getMaximumRange() + " ok=" + ok);
            }
        }
    }

    @Override
    protected void onDestroy() {
        mSensors.unregisterListener(this);
        super.onDestroy();
    }

    private final long[] mLast = new long[TYPES.length * 2];

    @Override
    public void onSensorChanged(SensorEvent e) {
        // Continuous sensors: at most one line per 500 ms each.
        int i = Arrays.binarySearch(TYPES, e.sensor.getType()) * 2 + (e.sensor.isWakeUpSensor() ? 1 : 0);
        long now = System.currentTimeMillis();
        if (i >= 0 && e.sensor.getReportingMode() == Sensor.REPORTING_MODE_CONTINUOUS && now - mLast[i] < 500) return;
        if (i >= 0) mLast[i] = now;
        Log.i(TAG, e.sensor.getName() + " " + Arrays.toString(Arrays.copyOf(e.values, Math.min(6, e.values.length))));
    }

    @Override
    public void onAccuracyChanged(Sensor s, int a) {}
}
