package org.openglyph.devicetest;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.BluetoothManager;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.SurfaceTexture;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.hardware.biometrics.BiometricPrompt;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.location.LocationManager;
import android.media.AudioAttributes;
import android.media.AudioDeviceInfo;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioRecord;
import android.media.AudioTrack;
import android.media.MediaRecorder;
import android.net.wifi.WifiManager;
import android.nfc.NfcAdapter;
import android.os.BatteryManager;
import android.os.Bundle;
import android.os.CancellationSignal;
import android.os.Handler;
import android.os.Looper;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.telephony.TelephonyManager;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.Surface;
import android.view.TextureView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Temporary hardware test for the Nothing Phone (3) ROM (installed with adb, not shipped):
 * display, speakers, each microphone, vibration, torch, cameras, sensors, keys, fingerprint,
 * radios and battery. Every screen is built in code, so the APK needs no resources.
 */
public final class MainActivity extends Activity {
    private final Handler mHandler = new Handler(Looper.getMainLooper());
    private Runnable mOnLeave;
    private TextView mKeyLog;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestPermissions(new String[] {Manifest.permission.RECORD_AUDIO, Manifest.permission.CAMERA,
                Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.READ_PHONE_STATE}, 1);
        showMenu();
    }

    // ---- navigation ----

    private void show(View v) {
        if (mOnLeave != null) {
            mOnLeave.run();
            mOnLeave = null;
        }
        mKeyLog = null;
        setContentView(v);
    }

    @Override
    public void onBackPressed() {
        if (mOnLeave == null && mKeyLog == null && findViewById(1) != null) {
            super.onBackPressed();
        } else {
            showMenu();
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (mOnLeave != null) {
            mOnLeave.run();
            mOnLeave = null;
        }
    }

    private LinearLayout column() {
        LinearLayout l = new LinearLayout(this);
        l.setOrientation(LinearLayout.VERTICAL);
        int p = dp(16);
        l.setPadding(p, p, p, p);
        return l;
    }

    private View scroll(View content) {
        ScrollView s = new ScrollView(this);
        s.setFitsSystemWindows(true);
        s.addView(content);
        return s;
    }

    private TextView text(LinearLayout parent, String s, float sp) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextSize(sp);
        t.setPadding(0, dp(6), 0, dp(6));
        parent.addView(t);
        return t;
    }

    private Button button(LinearLayout parent, String label, View.OnClickListener l) {
        Button b = new Button(this);
        b.setText(label);
        b.setAllCaps(false);
        b.setOnClickListener(l);
        parent.addView(b, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));
        return b;
    }

    private int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density);
    }

    private void showMenu() {
        LinearLayout l = column();
        l.setId(1);
        text(l, "Cihaz Testi", 26);
        text(l, "Nothing Phone (3) — geçici donanım testi", 14);
        button(l, "Ekran: renkler", v -> screenColours());
        button(l, "Ekran: dokunmatik", v -> touch());
        button(l, "Hoparlör ve ahize", v -> speakers());
        button(l, "Mikrofonlar (her biri ayrı)", v -> microphones());
        button(l, "Titreşim ve fener", v -> vibrationTorch());
        button(l, "Kameralar", v -> cameras());
        button(l, "Sensörler", v -> sensors());
        button(l, "Tuşlar", v -> keys());
        button(l, "Parmak izi", v -> fingerprint());
        button(l, "Bağlantı ve pil", v -> radios());
        button(l, "Glyph Matrix ayarları", v -> {
            try {
                startActivity(new Intent("org.openglyph.SETTINGS"));
            } catch (Exception e) {
                // OpenGlyph missing
            }
        });
        show(scroll(l));
    }

    // ---- display ----

    private void screenColours() {
        int[] colours = {Color.RED, Color.GREEN, Color.BLUE, Color.WHITE, Color.BLACK, Color.GRAY};
        View v = new View(this);
        int[] i = {0};
        v.setBackgroundColor(colours[0]);
        v.setOnClickListener(x -> {
            i[0]++;
            if (i[0] >= colours.length) showMenu(); else v.setBackgroundColor(colours[i[0]]);
        });
        show(v);
        v.setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
    }

    private void touch() {
        View v = new View(this) {
            final Path path = new Path();
            final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
            {
                paint.setColor(Color.rgb(215, 25, 33));
                paint.setStrokeWidth(dp(4));
                paint.setStyle(Paint.Style.STROKE);
            }

            @Override
            public boolean onTouchEvent(MotionEvent e) {
                for (int p = 0; p < e.getPointerCount(); p++) {
                    if (e.getActionMasked() == MotionEvent.ACTION_DOWN
                            || e.getActionMasked() == MotionEvent.ACTION_POINTER_DOWN) {
                        path.moveTo(e.getX(p), e.getY(p));
                    } else {
                        path.lineTo(e.getX(p), e.getY(p));
                    }
                }
                invalidate();
                return true;
            }

            @Override
            protected void onDraw(Canvas c) {
                c.drawColor(Color.WHITE);
                c.drawPath(path, paint);
            }
        };
        show(v);
    }

    // ---- audio ----

    /** One second of a sine tone as 16-bit PCM. */
    private static short[] tone(double hz, int rate) {
        short[] s = new short[rate];
        for (int i = 0; i < s.length; i++) {
            s[i] = (short) (Math.sin(2 * Math.PI * hz * i / rate) * 12000);
        }
        return s;
    }

    private AudioTrack playTone(int usage, AudioDeviceInfo device) {
        int rate = 48000;
        short[] pcm = tone(1000, rate);
        AudioTrack t = new AudioTrack.Builder()
                .setAudioAttributes(new AudioAttributes.Builder().setUsage(usage).build())
                .setAudioFormat(new AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(rate).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
                .setTransferMode(AudioTrack.MODE_STATIC).setBufferSizeInBytes(pcm.length * 2).build();
        t.write(pcm, 0, pcm.length);
        t.setLoopPoints(0, pcm.length, -1);
        if (device != null) t.setPreferredDevice(device);
        t.play();
        return t;
    }

    private void speakers() {
        LinearLayout l = column();
        text(l, "Hoparlör ve ahize", 22);
        AudioManager am = getSystemService(AudioManager.class);
        AudioTrack[] playing = {null};
        Runnable stop = () -> {
            if (playing[0] != null) {
                playing[0].stop();
                playing[0].release();
                playing[0] = null;
            }
            am.clearCommunicationDevice();
            am.setMode(AudioManager.MODE_NORMAL);
        };
        button(l, "Hoparlör: 1 kHz ton", v -> {
            stop.run();
            playing[0] = playTone(AudioAttributes.USAGE_MEDIA, null);
        });
        button(l, "Ahize (kulak hoparlörü): 1 kHz ton", v -> {
            stop.run();
            am.setMode(AudioManager.MODE_IN_COMMUNICATION);
            for (AudioDeviceInfo d : am.getAvailableCommunicationDevices()) {
                if (d.getType() == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE) am.setCommunicationDevice(d);
            }
            playing[0] = playTone(AudioAttributes.USAGE_VOICE_COMMUNICATION, null);
        });
        button(l, "Durdur", v -> stop.run());
        mOnLeave = stop;
        show(scroll(l));
        mOnLeave = stop;
    }

    private void microphones() {
        LinearLayout l = column();
        text(l, "Mikrofonlar", 22);
        text(l, "Her mikrofon ayrı kaydedilir. Seviye dBFS: konuşurken -30 ile -10 arası normaldir.", 14);
        AudioManager am = getSystemService(AudioManager.class);
        List<AudioDeviceInfo> mics = new ArrayList<>();
        for (AudioDeviceInfo d : am.getDevices(AudioManager.GET_DEVICES_INPUTS)) {
            if (d.getType() == AudioDeviceInfo.TYPE_BUILTIN_MIC) mics.add(d);
        }
        TextView meter = text(l, "—", 18);
        boolean[] stop = {false};
        for (AudioDeviceInfo mic : mics) {
            String name = "Mikrofon " + (mics.indexOf(mic) + 1) + " (" + mic.getAddress() + ")";
            button(l, name + ": 3 sn kaydet ve dinle", v -> recordAndPlay(mic, name, meter, stop, false));
        }
        if (mics.isEmpty()) text(l, "Dahili mikrofon bulunamadı", 16);
        // How Recorder and the camera record: stereo, no preferred mic (the HAL picks a profile).
        button(l, "Stereo (Kaydedici/Kamera gibi): 3 sn kaydet ve dinle",
                v -> recordAndPlay(null, "Stereo", meter, stop, true));
        button(l, "Kamera kaynağı (CAMCORDER, stereo): 3 sn kaydet ve dinle",
                v -> recordAndPlay(null, "Kamera", meter, stop, true, MediaRecorder.AudioSource.CAMCORDER));
        mOnLeave = () -> stop[0] = true;
        show(scroll(l));
        mOnLeave = () -> stop[0] = true;
    }

    private void recordAndPlay(AudioDeviceInfo mic, String name, TextView meter, boolean[] stop,
            boolean stereo) {
        recordAndPlay(mic, name, meter, stop, stereo, MediaRecorder.AudioSource.MIC);
    }

    private void recordAndPlay(AudioDeviceInfo mic, String name, TextView meter, boolean[] stop,
            boolean stereo, int source) {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            meter.setText("Mikrofon izni yok");
            return;
        }
        stop[0] = false;
        new Thread(() -> {
            int rate = 48000;
            int channel = stereo ? AudioFormat.CHANNEL_IN_STEREO : AudioFormat.CHANNEL_IN_MONO;
            int ch = stereo ? 2 : 1;
            int min = AudioRecord.getMinBufferSize(rate, channel, AudioFormat.ENCODING_PCM_16BIT);
            AudioRecord rec = new AudioRecord(source, rate, channel, AudioFormat.ENCODING_PCM_16BIT,
                    Math.max(min, 9600 * ch));
            if (mic != null) rec.setPreferredDevice(mic);
            short[] all = new short[rate * 3 * ch];
            short[] buf = new short[rate / 20];
            int pos = 0;
            double peakAll = 0;
            rec.startRecording();
            while (pos < all.length && !stop[0]) {
                int n = rec.read(buf, 0, Math.min(buf.length, all.length - pos));
                if (n <= 0) break;
                System.arraycopy(buf, 0, all, pos, n);
                pos += n;
                double sum = 0, peak = 0;
                for (int i = 0; i < n; i++) {
                    sum += (double) buf[i] * buf[i];
                    peak = Math.max(peak, Math.abs(buf[i]));
                }
                peakAll = Math.max(peakAll, peak);
                double rms = 20 * Math.log10(Math.max(1e-9, Math.sqrt(sum / n) / 32768));
                double pk = 20 * Math.log10(Math.max(1e-9, peak / 32768));
                String s = String.format(Locale.ROOT, "%s\nRMS %.1f dBFS   tepe %.1f dBFS\n%s",
                        name, rms, pk, "█".repeat((int) Math.max(0, Math.min(40, (rms + 70) * 40 / 70))));
                mHandler.post(() -> meter.setText(s));
            }
            rec.stop();
            rec.release();
            double best = 20 * Math.log10(Math.max(1e-9, peakAll / 32768));
            mHandler.post(() -> meter.append(String.format(Locale.ROOT,
                    "\nEn yüksek: %.1f dBFS — kayıt çalınıyor", best)));
            if (stop[0]) return;
            AudioTrack t = new AudioTrack.Builder()
                    .setAudioAttributes(new AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA).build())
                    .setAudioFormat(new AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(rate).setChannelMask(stereo ? AudioFormat.CHANNEL_OUT_STEREO
                            : AudioFormat.CHANNEL_OUT_MONO).build())
                    .setTransferMode(AudioTrack.MODE_STATIC).setBufferSizeInBytes(pos * 2).build();
            t.write(all, 0, pos);
            t.play();
            try {
                Thread.sleep(pos * 1000L / rate / ch + 200);
            } catch (InterruptedException ignored) {
            }
            t.release();
        }, "mic-test").start();
    }

    // ---- vibration, torch ----

    private void vibrationTorch() {
        LinearLayout l = column();
        text(l, "Titreşim ve fener", 22);
        Vibrator vib = getSystemService(Vibrator.class);
        button(l, "Kısa tık", v -> vib.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK)));
        button(l, "Ağır tık", v -> vib.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_HEAVY_CLICK)));
        button(l, "1 saniye", v -> vib.vibrate(VibrationEffect.createOneShot(1000, 255)));
        button(l, "Desen", v -> vib.vibrate(VibrationEffect.createWaveform(
                new long[] {0, 100, 100, 300, 100, 600}, -1)));
        CameraManager cm = getSystemService(CameraManager.class);
        boolean[] on = {false};
        button(l, "Fener aç / kapat", v -> {
            try {
                for (String id : cm.getCameraIdList()) {
                    Boolean flash = cm.getCameraCharacteristics(id).get(CameraCharacteristics.FLASH_INFO_AVAILABLE);
                    if (Boolean.TRUE.equals(flash)) {
                        on[0] = !on[0];
                        cm.setTorchMode(id, on[0]);
                        break;
                    }
                }
            } catch (Exception e) {
                text(l, "Fener hatası: " + e.getMessage(), 14);
            }
        });
        mOnLeave = () -> {
            if (!on[0]) return;
            try {
                for (String id : cm.getCameraIdList()) cm.setTorchMode(id, false);
            } catch (Exception ignored) {
            }
        };
        Runnable leave = mOnLeave;
        show(scroll(l));
        mOnLeave = leave;
    }

    // ---- cameras ----

    private void cameras() {
        LinearLayout l = column();
        text(l, "Kameralar", 22);
        CameraManager cm = getSystemService(CameraManager.class);
        try {
            for (String id : cm.getCameraIdList()) {
                CameraCharacteristics c = cm.getCameraCharacteristics(id);
                Integer facing = c.get(CameraCharacteristics.LENS_FACING);
                float[] focal = c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS);
                String f = facing == null ? "?" : facing == CameraCharacteristics.LENS_FACING_FRONT ? "ön" : "arka";
                button(l, String.format(Locale.ROOT, "Kamera %s (%s, %.1f mm)", id, f,
                        focal != null && focal.length > 0 ? focal[0] : 0), v -> preview(id));
            }
        } catch (Exception e) {
            text(l, "Kameralar okunamadı: " + e.getMessage(), 14);
        }
        show(scroll(l));
    }

    private void preview(String id) {
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) return;
        TextureView tv = new TextureView(this);
        CameraDevice[] dev = {null};
        tv.setSurfaceTextureListener(new TextureView.SurfaceTextureListener() {
            @Override
            public void onSurfaceTextureAvailable(SurfaceTexture st, int w, int h) {
                try {
                    getSystemService(CameraManager.class).openCamera(id, new CameraDevice.StateCallback() {
                        @Override
                        public void onOpened(CameraDevice d) {
                            dev[0] = d;
                            st.setDefaultBufferSize(1920, 1080);
                            Surface s = new Surface(st);
                            try {
                                CaptureRequest.Builder b = d.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
                                b.addTarget(s);
                                d.createCaptureSession(List.of(s), new CameraCaptureSession.StateCallback() {
                                    @Override
                                    public void onConfigured(CameraCaptureSession session) {
                                        try {
                                            session.setRepeatingRequest(b.build(), null, mHandler);
                                        } catch (Exception ignored) {
                                        }
                                    }

                                    @Override
                                    public void onConfigureFailed(CameraCaptureSession session) {}
                                }, mHandler);
                            } catch (Exception ignored) {
                            }
                        }

                        @Override public void onDisconnected(CameraDevice d) { d.close(); }
                        @Override public void onError(CameraDevice d, int error) { d.close(); }
                    }, mHandler);
                } catch (Exception ignored) {
                }
            }

            @Override public void onSurfaceTextureSizeChanged(SurfaceTexture st, int w, int h) {}
            @Override public boolean onSurfaceTextureDestroyed(SurfaceTexture st) { return true; }
            @Override public void onSurfaceTextureUpdated(SurfaceTexture st) {}
        });
        tv.setOnClickListener(v -> cameras());
        show(tv);
        mOnLeave = () -> {
            if (dev[0] != null) dev[0].close();
        };
    }

    // ---- sensors ----

    private void sensors() {
        LinearLayout l = column();
        text(l, "Sensörler (canlı)", 22);
        SensorManager sm = getSystemService(SensorManager.class);
        List<SensorEventListener> listeners = new ArrayList<>();
        for (Sensor s : sm.getSensorList(Sensor.TYPE_ALL)) {
            if (s.isWakeUpSensor() || s.getReportingMode() == Sensor.REPORTING_MODE_ONE_SHOT) continue;
            TextView t = text(l, s.getName() + "\n—", 13);
            SensorEventListener sel = new SensorEventListener() {
                long last;

                @Override
                public void onSensorChanged(SensorEvent e) {
                    if (e.timestamp - last < 200_000_000L) return;
                    last = e.timestamp;
                    StringBuilder b = new StringBuilder(s.getName()).append('\n');
                    for (int i = 0; i < Math.min(3, e.values.length); i++) {
                        b.append(String.format(Locale.ROOT, "%.2f  ", e.values[i]));
                    }
                    t.setText(b);
                }

                @Override public void onAccuracyChanged(Sensor sensor, int accuracy) {}
            };
            if (sm.registerListener(sel, s, SensorManager.SENSOR_DELAY_UI)) listeners.add(sel);
        }
        show(scroll(l));
        mOnLeave = () -> {
            for (SensorEventListener sel : listeners) sm.unregisterListener(sel);
        };
    }

    // ---- keys ----

    private void keys() {
        LinearLayout l = column();
        text(l, "Tuşlar", 22);
        text(l, "Bir tuşa bas: ses, güç (kısa), vs. Essential Key ve Glyph Button sistem tarafından "
                + "yakalanır, burada görünmez.", 14);
        TextView log = text(l, "", 16);
        show(scroll(l));
        mKeyLog = log;
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent e) {
        if (mKeyLog != null && e.getAction() == KeyEvent.ACTION_DOWN && e.getKeyCode() != KeyEvent.KEYCODE_BACK) {
            mKeyLog.append(KeyEvent.keyCodeToString(e.getKeyCode()) + "  (scan " + e.getScanCode() + ")\n");
            return true;
        }
        return super.dispatchKeyEvent(e);
    }

    // ---- fingerprint ----

    private void fingerprint() {
        LinearLayout l = column();
        text(l, "Parmak izi", 22);
        TextView result = text(l, "", 18);
        button(l, "Parmak izini doğrula", v -> new BiometricPrompt.Builder(this)
                .setTitle("Parmak izi testi")
                .setNegativeButton("İptal", getMainExecutor(), (d, w) -> {})
                .build()
                .authenticate(new CancellationSignal(), getMainExecutor(),
                        new BiometricPrompt.AuthenticationCallback() {
                            @Override
                            public void onAuthenticationSucceeded(BiometricPrompt.AuthenticationResult r) {
                                result.setText("✓ Doğrulandı");
                            }

                            @Override
                            public void onAuthenticationFailed() {
                                result.setText("✗ Tanınmadı");
                            }

                            @Override
                            public void onAuthenticationError(int code, CharSequence msg) {
                                result.setText("Hata: " + msg);
                            }
                        }));
        show(scroll(l));
    }

    // ---- radios and battery ----

    private void radios() {
        LinearLayout l = column();
        text(l, "Bağlantı ve pil", 22);
        TextView t = text(l, "", 15);
        Runnable refresh = new Runnable() {
            @Override
            public void run() {
                t.setText(radioStatus());
                mHandler.postDelayed(this, 1000);
            }
        };
        show(scroll(l));
        mHandler.post(refresh);
        mOnLeave = () -> mHandler.removeCallbacks(refresh);
    }

    private String radioStatus() {
        StringBuilder b = new StringBuilder();
        try {
            WifiManager wm = getSystemService(WifiManager.class);
            b.append("Wi-Fi: ").append(wm.isWifiEnabled() ? "açık" : "kapalı");
            if (wm.isWifiEnabled() && wm.getConnectionInfo() != null) {
                b.append(", ").append(wm.getConnectionInfo().getRssi()).append(" dBm, ")
                        .append(wm.getConnectionInfo().getLinkSpeed()).append(" Mbps");
            }
            b.append('\n');
        } catch (Exception e) {
            b.append("Wi-Fi: ?\n");
        }
        try {
            BluetoothManager bm = getSystemService(BluetoothManager.class);
            b.append("Bluetooth: ").append(bm.getAdapter() != null && bm.getAdapter().isEnabled()
                    ? "açık" : "kapalı").append('\n');
        } catch (Exception e) {
            b.append("Bluetooth: ? (izin)\n");
        }
        NfcAdapter nfc = NfcAdapter.getDefaultAdapter(this);
        b.append("NFC: ").append(nfc == null ? "yok" : nfc.isEnabled() ? "açık" : "kapalı").append('\n');
        LocationManager lm = getSystemService(LocationManager.class);
        b.append("Konum (GPS): ").append(lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ? "açık" : "kapalı")
                .append('\n');
        try {
            TelephonyManager tm = getSystemService(TelephonyManager.class);
            b.append("Operatör: ").append(tm.getNetworkOperatorName()).append(", sinyal seviyesi ")
                    .append(tm.getSignalStrength() == null ? "?" : tm.getSignalStrength().getLevel())
                    .append("/4\n");
        } catch (Exception e) {
            b.append("Operatör: ? (izin)\n");
        }
        BatteryManager bat = getSystemService(BatteryManager.class);
        Intent st = registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        int level = bat.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY);
        int currentUa = bat.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW);
        b.append(String.format(Locale.ROOT, "Pil: %%%d, akım %d mA", level, currentUa / 1000));
        if (st != null) {
            b.append(String.format(Locale.ROOT, ", %.2f V, %.1f °C",
                    st.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0) / 1000.0,
                    st.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) / 10.0));
            b.append(bat.isCharging() ? ", şarj oluyor" : "");
        }
        return b.toString();
    }
}
