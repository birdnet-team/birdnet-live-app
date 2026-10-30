package org.birdnet.ortbench;

import ai.onnxruntime.*;
import ai.onnxruntime.providers.NNAPIFlags;
import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.WindowManager;
import android.widget.ScrollView;
import android.widget.TextView;
import java.io.File;
import java.io.FileWriter;
import java.nio.FloatBuffer;
import java.util.*;

/**
 * Standalone ONNX Runtime benchmark. Reads model files from getExternalFilesDir() and
 * sweeps thread counts, batch sizes and execution providers. Results go to logcat
 * (tag ORTBENCH) and to files/results.txt. Driven via intent extras:
 *   --es models a.onnx,b.onnx  --es threads 1,4,6  --es batches 1,4,8
 *   --es providers cpu,xnnpack,nnapi  --ei iters 20  --ef windowSec 3
 *   --ez profile true  --ez saveOptimized true  --es configs "k=v;k=v"
 */
public class MainActivity extends Activity {
    static final String TAG = "ORTBENCH";
    TextView text;
    StringBuilder out = new StringBuilder();

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        text = new TextView(this);
        text.setTextSize(11);
        ScrollView sv = new ScrollView(this);
        sv.addView(text);
        setContentView(sv);
        final Intent intent = getIntent();
        new Thread(() -> {
            try { runAll(intent); } catch (Throwable t) { log("FATAL " + Log.getStackTraceString(t)); }
            log("DONE");
        }).start();
    }

    void log(String s) {
        Log.i(TAG, s);
        out.append(s).append('\n');
        runOnUiThread(() -> text.setText(out.toString()));
        try (FileWriter w = new FileWriter(new File(getExternalFilesDir(null), "results.txt"), true)) {
            w.write(s + "\n");
        } catch (Exception ignored) {}
    }

    static int[] ints(String s, int[] def) {
        if (s == null || s.isEmpty()) return def;
        String[] p = s.split(",");
        int[] r = new int[p.length];
        for (int i = 0; i < p.length; i++) r[i] = Integer.parseInt(p[i].trim());
        return r;
    }

    void runAll(Intent in) throws Exception {
        File dir = getExternalFilesDir(null);
        String modelsArg = in.getStringExtra("models");
        List<String> models = new ArrayList<>();
        if (modelsArg == null) {
            for (File f : dir.listFiles()) if (f.getName().endsWith(".onnx")) models.add(f.getName());
        } else {
            models.addAll(Arrays.asList(modelsArg.split(",")));
        }
        int[] threads = ints(in.getStringExtra("threads"), new int[]{4});
        int[] batches = ints(in.getStringExtra("batches"), new int[]{1});
        String provArg = in.getStringExtra("providers");
        String[] providers = (provArg == null ? "cpu" : provArg).split(",");
        int iters = in.getIntExtra("iters", 15);
        float windowSec = in.getFloatExtra("windowSec", 3f);
        boolean profile = in.getBooleanExtra("profile", false);
        boolean saveOpt = in.getBooleanExtra("saveOptimized", false);
        boolean fp16Input = in.getBooleanExtra("fp16Input", false);
        String configs = in.getStringExtra("configs");
        int samples = Math.round(windowSec * 32000);
        OrtEnvironment env = OrtEnvironment.getEnvironment();
        log("ORT " + env.getVersion() + " cores=" + Runtime.getRuntime().availableProcessors()
            + " models=" + models + " threads=" + Arrays.toString(threads) + " batches=" + Arrays.toString(batches)
            + " providers=" + Arrays.toString(providers) + " iters=" + iters + " window=" + windowSec + "s configs=" + configs);
        Random rnd = new Random(42);
        for (String model : models) for (String prov : providers) for (int th : threads) for (int bs : batches) {
            String label = model + " | " + prov + " | " + th + "T | b" + bs;
            try (OrtSession.SessionOptions so = new OrtSession.SessionOptions()) {
                so.setIntraOpNumThreads(th);
                so.setInterOpNumThreads(1);
                so.setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT);
                so.addConfigEntry("mlas.disable_kleidiai", "1");
                if (configs != null) {
                    for (String kv : configs.split("[|]")) {
                        String[] p = kv.split("=", 2);
                        if (p.length == 2) so.addConfigEntry(p[0].trim(), p[1].trim());
                    }
                }
                if (prov.equals("xnnpack")) {
                    Map<String, String> m = new HashMap<>();
                    m.put("intra_op_num_threads", String.valueOf(th));
                    so.addXnnpack(m);
                } else if (prov.startsWith("webgpu")) {
                    Map<String, String> m = new HashMap<>();
                    if (prov.equals("webgpu_fp32")) m.put("preferredLayout", "NCHW");
                    so.addWebGPU(m);
                } else if (prov.equals("nnapi")) {
                    so.addNnapi();
                } else if (prov.equals("nnapi_fp16")) {
                    so.addNnapi(EnumSet.of(NNAPIFlags.USE_FP16));
                }
                String prof = null;
                if (profile) {
                    prof = new File(dir, "prof_" + model + "_" + prov + "_" + th + "T_b" + bs).getPath();
                    so.enableProfiling(prof);
                }
                if (saveOpt) so.setOptimizedModelFilePath(new File(dir, "opt_" + prov + "_" + model).getPath());
                long t0 = System.nanoTime();
                try (OrtSession sess = env.createSession(new File(dir, model).getPath(), so)) {
                    double loadMs = (System.nanoTime() - t0) / 1e6;
                    String inName = sess.getInputNames().iterator().next();
                    boolean half = fp16Input || sess.getInputInfo().get(inName).getInfo().toString().contains("FLOAT16");
                    float[] data = new float[bs * samples];
                    for (int i = 0; i < data.length; i++) data[i] = (float) (rnd.nextGaussian() * 0.05);
                    long[] shape = {bs, samples};
                    OnnxTensor x;
                    if (half) {
                        java.nio.ShortBuffer sb = java.nio.ShortBuffer.allocate(data.length);
                        for (float v : data) sb.put(ai.onnxruntime.platform.Fp16Conversions.floatToFp16(v));
                        sb.rewind();
                        x = OnnxTensor.createTensor(env, sb, shape, OnnxJavaType.FLOAT16);
                    } else {
                        x = OnnxTensor.createTensor(env, FloatBuffer.wrap(data), shape);
                    }
                    Map<String, OnnxTensor> feed = Collections.singletonMap(inName, x);
                    for (int i = 0; i < 3; i++) sess.run(feed).close();
                    double[] times = new double[iters];
                    double sum = 0, min = 1e9, max = 0;
                    long tAll = System.nanoTime();
                    for (int i = 0; i < iters; i++) {
                        long t = System.nanoTime();
                        sess.run(feed).close();
                        times[i] = (System.nanoTime() - t) / 1e6;
                        sum += times[i];
                        min = Math.min(min, times[i]);
                        max = Math.max(max, times[i]);
                    }
                    double wall = (System.nanoTime() - tAll) / 1e6;
                    Arrays.sort(times);
                    double avg = sum / iters, med = times[iters / 2];
                    double rt = bs * windowSec * 1000.0 / avg;
                    log(String.format(Locale.US,
                        "%s | load %.0f ms | avg %.1f med %.1f min %.1f max %.1f ms | %.1fx RT | %.2f win/s | wall %.0f ms",
                        label, loadMs, avg, med, min, max, rt, bs * 1000.0 / avg, wall));
                    x.close();
                    if (prof != null) log("profile -> " + sess.endProfiling());
                }
            } catch (Throwable t) {
                log(label + " | FAILED " + t);
            }
        }
    }
}
