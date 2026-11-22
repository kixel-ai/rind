package io.github.steelhead99x.rindbench;

import android.app.Activity;
import android.content.Intent;
import android.content.res.ColorStateList;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import android.util.Log;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.*;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.*;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.*;

/**
 * RindBench All (v15) for Android: one screen, no scrolling, the same layout,
 * flow and words as the iPad app (ios/main.m). A data-driven picker of every
 * library x operation this build of rind-devbench can time, and a live
 * summary of the run; nothing here names an operation or a library.
 *
 * The collector fills itself in: USB first (127.0.0.1:PORT, live when the
 * computer ran `adb reverse tcp:PORT tcp:PORT`), then the LAN address baked in
 * at build time (Collector.java). Results are always saved on the phone too.
 *
 * adb: am start -n io.github.steelhead99x.rindbench/.MainActivity [--es host H --ei port P]
 *      [--es libraries "rind,ring"] [--es sections "AEADs"] [--es preset quick|full] [--ez autostart true]
 * autostart waits 3 s after the list loads, so a runner can capture the picker first.
 * Each screen state logs one RINDBENCH_LAYOUT line (tag RindBench); see reportLayout.
 */
public class MainActivity extends Activity {
    static final int BG = Color.rgb(13, 15, 20), CARD = Color.rgb(24, 27, 34), LINE = Color.rgb(44, 48, 58),
        CHIP = Color.rgb(36, 40, 50), MUTED = Color.rgb(150, 156, 170), TEXT = Color.rgb(236, 238, 243),
        ACCENT = Color.rgb(250, 191, 51), GOOD = Color.rgb(84, 214, 146), BAD = Color.rgb(255, 120, 110);
    static final String CONSENT = "The run keeps the CPU busy (minutes on Quick, longer on Full) and warms the device. "
        + "It sends only timings and the model, chip, OS version and CPU features to the computer that installed this app. "
        + "No name, account, serial or location. Results are also saved on this device.";

    private final Handler ui = new Handler(Looper.getMainLooper());
    private LinearLayout body, leftCol, pickCard;
    private View resultsCard;
    private TextView picksLbl;
    private boolean wide, showingRun;
    private Flow libFlow, secFlow;
    private TextView deviceLbl, statusLbl, currentLbl, scoreLbl, behindLbl, collectorLbl;
    private ProgressBar progress;
    private Switch agree;
    private TextView quickBtn, fullBtn;
    private boolean full;
    private Button startBtn, stopBtn, clearBtn;
    private JSONObject catalog;
    private final Map<String, TextView> libChips = new LinkedHashMap<>(), secChips = new LinkedHashMap<>();
    private final List<String> moreSections = new ArrayList<>();
    private TextView moreChip;
    private boolean polling, ran;
    private String keysDir;
    private String colHost; private int colPort; private String colHow = "looking…";

    /** Lays its children out left to right, wrapping to a new line when one is full. */
    static final class Flow extends ViewGroup {
        final int gap;
        Flow(Activity a, int gap) { super(a); this.gap = gap; }
        @Override protected void onMeasure(int wSpec, int hSpec) {
            int width = MeasureSpec.getSize(wSpec) - getPaddingLeft() - getPaddingRight();
            int x = 0, y = 0, line = 0;
            for (int i = 0; i < getChildCount(); i++) {
                View c = getChildAt(i);
                if (c.getVisibility() == GONE) continue;
                c.measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.AT_MOST), MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED));
                int w = c.getMeasuredWidth(), h = c.getMeasuredHeight();
                if (x > 0 && x + w > width) { x = 0; y += line + gap; line = 0; }
                x += w + gap; line = Math.max(line, h);
            }
            setMeasuredDimension(MeasureSpec.getSize(wSpec), y + line + getPaddingTop() + getPaddingBottom());
        }
        @Override protected void onLayout(boolean changed, int l, int t, int r, int b) {
            int width = r - l - getPaddingLeft() - getPaddingRight();
            int x = 0, y = 0, line = 0;
            for (int i = 0; i < getChildCount(); i++) {
                View c = getChildAt(i);
                if (c.getVisibility() == GONE) continue;
                int w = c.getMeasuredWidth(), h = c.getMeasuredHeight();
                if (x > 0 && x + w > width) { x = 0; y += line + gap; line = 0; }
                c.layout(getPaddingLeft() + x, getPaddingTop() + y, getPaddingLeft() + x + w, getPaddingTop() + y + h);
                x += w + gap; line = Math.max(line, h);
            }
        }
    }

    private int dp(float v) { return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, getResources().getDisplayMetrics()); }

    private TextView label(String t, float sp, int style, int color) {
        TextView l = new TextView(this); l.setText(t); l.setTextSize(sp); l.setTextColor(color);
        l.setTypeface(Typeface.create(Typeface.DEFAULT, style)); return l;
    }
    private TextView heading(String t) {
        TextView l = label(t.toUpperCase(Locale.US), 12, Typeface.BOLD, MUTED); l.setLetterSpacing(0.1f); return l;
    }
    private GradientDrawable round(int fill, int stroke, float radius) {
        GradientDrawable g = new GradientDrawable(); g.setColor(fill); g.setCornerRadius(dp(radius));
        if (stroke != 0) g.setStroke(dp(1), stroke);
        return g;
    }
    private LinearLayout card(View... views) {
        LinearLayout s = new LinearLayout(this); s.setOrientation(LinearLayout.VERTICAL);
        s.setPadding(dp(16), dp(14), dp(16), dp(14)); s.setBackground(round(CARD, LINE, 16));
        for (View v : views) addSpaced(s, v, 10);
        return s;
    }
    private void addSpaced(LinearLayout parent, View v, int gap) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        if (parent.getChildCount() > 0) lp.topMargin = dp(gap);
        parent.addView(v, lp);
    }
    private TextView chip(String title, boolean on, boolean en) {
        boolean small = getResources().getConfiguration().screenWidthDp < 500;
        TextView c = label(title, small ? 13 : 14, Typeface.BOLD, TEXT);
        if (small) c.setPadding(dp(10), dp(5), dp(10), dp(5)); else c.setPadding(dp(12), dp(7), dp(12), dp(7));
        c.setSingleLine(true);
        c.setEllipsize(android.text.TextUtils.TruncateAt.END);
        c.setSelected(on); c.setEnabled(en);
        c.setOnClickListener(v -> { if (!polling && v.isEnabled()) { v.setSelected(!v.isSelected()); paintChip((TextView) v); } });
        paintChip(c); return c;
    }
    private void paintChip(TextView c) {
        boolean on = c.isSelected();
        c.setBackground(round(on ? ACCENT : CHIP, on ? ACCENT : LINE, 15));
        c.setTextColor(!c.isEnabled() ? MUTED : on ? Color.BLACK : TEXT);
        c.setAlpha(c.isEnabled() ? 1f : 0.45f);
    }
    private Switch makeSwitch(boolean on, boolean en) {
        Switch sw = new Switch(this); sw.setChecked(on); sw.setEnabled(en);
        int[][] st = {{android.R.attr.state_checked}, {}};
        sw.setThumbTintList(new ColorStateList(st, new int[]{ACCENT, Color.rgb(220, 220, 220)}));
        sw.setTrackTintList(new ColorStateList(st, new int[]{Color.argb(140, 250, 191, 51), Color.rgb(80, 80, 88)}));
        return sw;
    }
    private Button button(String t, boolean primary, View.OnClickListener a) {
        Button b = new Button(this); b.setText(t); b.setAllCaps(false); b.setTextSize(17);
        b.setTextColor(primary ? Color.BLACK : TEXT); b.setTypeface(Typeface.DEFAULT_BOLD);
        b.setBackground(round(primary ? ACCENT : CHIP, 0, 12));
        b.setPadding(dp(20), dp(10), dp(20), dp(10)); b.setOnClickListener(a); return b;
    }
    private void setEnabledLook(View b, boolean en) { b.setEnabled(en); b.setAlpha(en ? 1f : 0.4f); }

    /** Quick/Full as a two-part segmented control, like the iPad's. */
    private LinearLayout segmented() {
        LinearLayout seg = new LinearLayout(this); seg.setBackground(round(CHIP, LINE, 10)); seg.setPadding(dp(3), dp(3), dp(3), dp(3));
        quickBtn = label("Quick · 1 round", 14, Typeface.BOLD, TEXT); fullBtn = label("Full · 3 rounds", 14, Typeface.BOLD, TEXT);
        for (TextView t : new TextView[]{quickBtn, fullBtn}) {
            t.setGravity(Gravity.CENTER); t.setPadding(dp(8), dp(8), dp(8), dp(8));
            seg.addView(t, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        }
        quickBtn.setOnClickListener(v -> { if (!polling) setFull(false); });
        fullBtn.setOnClickListener(v -> { if (!polling) setFull(true); });
        setFull(false); return seg;
    }
    private void setFull(boolean f) {
        full = f;
        quickBtn.setBackground(f ? null : round(ACCENT, 0, 8)); quickBtn.setTextColor(f ? TEXT : Color.BLACK);
        fullBtn.setBackground(f ? round(ACCENT, 0, 8) : null); fullBtn.setTextColor(f ? Color.BLACK : TEXT);
    }

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().setStatusBarColor(BG); getWindow().setNavigationBarColor(BG);
        LinearLayout root = new LinearLayout(this); root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(BG); root.setPadding(dp(20), dp(16), dp(20), dp(16));
        setContentView(root);
        // Draw edge-to-edge on every version, as Android 15 does anyway for
        // targetSdk 35, so the inset padding below is right everywhere.
        if (Build.VERSION.SDK_INT >= 30) getWindow().setDecorFitsSystemWindows(false);
        else root.setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
        // Android 15 draws a targetSdk 35 app under the status and navigation
        // bars (edge-to-edge); keep the screen clear of them and of a cutout.
        root.setOnApplyWindowInsetsListener((v, ins) -> {
            int l, t, r, bt;
            if (Build.VERSION.SDK_INT >= 30) {
                android.graphics.Insets i = ins.getInsets(android.view.WindowInsets.Type.systemBars() | android.view.WindowInsets.Type.displayCutout());
                l = i.left; t = i.top; r = i.right; bt = i.bottom;
            } else {
                l = ins.getSystemWindowInsetLeft(); t = ins.getSystemWindowInsetTop(); r = ins.getSystemWindowInsetRight(); bt = ins.getSystemWindowInsetBottom();
            }
            v.setPadding(dp(20) + l, dp(16) + t, dp(20) + r, dp(16) + bt);
            return ins;
        });

        // Header: name, device, where results go.
        LinearLayout titleRow = new LinearLayout(this); titleRow.setGravity(Gravity.BOTTOM);
        titleRow.addView(label("RindBench", 28, Typeface.BOLD, TEXT));
        TextView tag = label("every library", 15, Typeface.BOLD, ACCENT); tag.setPadding(dp(10), 0, 0, dp(4));
        titleRow.addView(tag);
        deviceLbl = label("Reading the list of tests…", 13, Typeface.NORMAL, MUTED);
        collectorLbl = label("Results: looking for the computer that installed this app…", 13, Typeface.NORMAL, MUTED);
        addSpaced(root, titleRow, 0); addSpaced(root, deviceLbl, 4); addSpaced(root, collectorLbl, 4);

        // Left column: what to run, and how.
        libFlow = new Flow(this, dp(8)); secFlow = new Flow(this, dp(8));
        LinearLayout pick = card(heading("Libraries"), libFlow, heading("Operations"), secFlow);
        pickCard = pick;
        pick.setClipChildren(true); pick.setClipToOutline(true);
        agree = makeSwitch(false, true);
        TextView agreeL = label("I agree: busy CPU for minutes; sends only timings and device model.", 14, Typeface.NORMAL, TEXT);
        TextView info = label("ⓘ", 20, Typeface.BOLD, ACCENT); info.setPadding(dp(10), 0, dp(4), 0);
        info.setOnClickListener(v -> new android.app.AlertDialog.Builder(this).setTitle("Before you start").setMessage(CONSENT).setPositiveButton("OK", null).show());
        LinearLayout agreeRow = new LinearLayout(this); agreeRow.setGravity(Gravity.CENTER_VERTICAL); agreeRow.addView(agree);
        LinearLayout.LayoutParams alp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1); alp.leftMargin = dp(10);
        agreeRow.addView(agreeL, alp); agreeRow.addView(info);
        agreeL.setOnClickListener(v -> { if (agree.isEnabled()) agree.toggle(); });
        agree.setOnCheckedChangeListener((v, on) -> agreeChanged());
        startBtn = button("Start test", true, v -> startTapped());
        stopBtn = button("Stop", false, v -> stopTapped()); stopBtn.setVisibility(View.GONE);
        clearBtn = button("Clear", false, v -> clearTapped()); clearBtn.setVisibility(View.GONE);
        setEnabledLook(startBtn, false);
        LinearLayout btns = new LinearLayout(this);
        for (Button bt : new Button[]{startBtn, stopBtn, clearBtn}) {
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
            lp.rightMargin = bt == clearBtn ? 0 : dp(10);
            btns.addView(bt, lp);
        }
        LinearLayout run = card(segmented(), agreeRow, btns);
        leftCol = new LinearLayout(this); leftCol.setOrientation(LinearLayout.VERTICAL);
        addSpaced(leftCol, pick, 0); addSpaced(leftCol, run, 12);

        // Right column: the run, summarised to fit. Every row's full timings go
        // to the collector and to the phone's files.
        statusLbl = label("", 16, Typeface.BOLD, TEXT);
        // On a narrow screen the picker folds away during and after a run, and this line stands in for it.
        picksLbl = label("", 13, Typeface.BOLD, ACCENT); picksLbl.setVisibility(View.GONE);
        progress = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progress.setMax(1000); progress.setProgress(0);
        progress.setProgressTintList(ColorStateList.valueOf(ACCENT)); progress.setProgressBackgroundTintList(ColorStateList.valueOf(LINE));
        currentLbl = label("", 13, Typeface.NORMAL, MUTED); currentLbl.setMaxLines(2);
        scoreLbl = label("", 30, Typeface.BOLD, GOOD); scoreLbl.setSingleLine(true);
        scoreLbl.setAutoSizeTextTypeUniformWithConfiguration(14, 30, 1, TypedValue.COMPLEX_UNIT_SP);
        behindLbl = label("", 13, Typeface.NORMAL, TEXT); behindLbl.setTypeface(Typeface.MONOSPACE);
        TextView foot = label("An unofficial community tool, not run or endorsed by the rind maintainers.", 11, Typeface.NORMAL, MUTED);
        LinearLayout results = card(heading("Run"), picksLbl, statusLbl, progress, currentLbl, scoreLbl);
        // The list takes what height is left, and is cut off rather than scrolled.
        LinearLayout.LayoutParams blp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1); blp.topMargin = dp(10);
        results.addView(behindLbl, blp);
        addSpaced(results, foot, 10);
        // Autosizing needs a fixed height, not wrap_content.
        ((LinearLayout.LayoutParams) scoreLbl.getLayoutParams()).height = dp(40);
        resultsCard = results;

        body = new LinearLayout(this);
        root.addView(body, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        ((LinearLayout.LayoutParams) body.getLayoutParams()).topMargin = dp(14);
        body.addView(leftCol); body.addView(resultsCard);
        arrange(getResources().getConfiguration());
        body.addOnLayoutChangeListener((v, l, t, r, bt, ol, ot, or, ob) -> v.post(this::fitPicker));

        Intent it = getIntent();
        if ("full".equals(it.getStringExtra("preset"))) setFull(true);
        new Thread(() -> {
            String keys = copyKeys();
            Native.setenv("RIND_BENCH_KEYS_DIR", keys);
            String cat = Native.catalog();
            ui.post(() -> loaded(cat, keys));
        }).start();
        findCollector(null);
    }

    /** Wide screens put the picker and the run side by side; narrow ones stack them. */
    private void arrange(Configuration c) {
        wide = c.orientation == Configuration.ORIENTATION_LANDSCAPE && c.screenWidthDp >= 600;
        foldPicker();
        body.setOrientation(wide ? LinearLayout.HORIZONTAL : LinearLayout.VERTICAL);
        LinearLayout.LayoutParams l, r;
        if (wide) {
            l = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1); l.rightMargin = dp(6);
            r = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1); r.leftMargin = dp(6);
        } else {
            l = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            r = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1); r.topMargin = dp(12);
        }
        leftCol.setLayoutParams(l); resultsCard.setLayoutParams(r);
        // A cap fitPicker set for a short portrait screen doesn't carry over.
        LinearLayout.LayoutParams p = (LinearLayout.LayoutParams) pickCard.getLayoutParams();
        if (p.height != ViewGroup.LayoutParams.WRAP_CONTENT) { p.height = ViewGroup.LayoutParams.WRAP_CONTENT; pickCard.setLayoutParams(p); }
    }
    @Override public void onConfigurationChanged(Configuration c) { super.onConfigurationChanged(c); arrange(c); }

    /**
     * On a short screen, cap the picker's height so the run controls and some
     * of the run panel always fit: the picker's chips are clipped, never the
     * Start button. Runs after each layout of the body.
     */
    private void fitPicker() {
        if (wide || pickCard.getVisibility() != View.VISIBLE || body.getHeight() == 0) return;
        View run = leftCol.getChildAt(1);
        int width = MeasureSpecs.exactly(pickCard.getWidth() > 0 ? pickCard.getWidth() : body.getWidth());
        pickCard.measure(width, MeasureSpecs.unspecified());
        int natural = pickCard.getMeasuredHeight();
        int room = body.getHeight() - run.getHeight() - dp(12) - dp(12) - dp(110);
        int want = natural > room ? Math.max(dp(80), room) : ViewGroup.LayoutParams.WRAP_CONTENT;
        LinearLayout.LayoutParams lp = (LinearLayout.LayoutParams) pickCard.getLayoutParams();
        if (lp.height != want) { lp.height = want; pickCard.setLayoutParams(lp); }
    }
    private static final class MeasureSpecs {
        static int exactly(int px) { return View.MeasureSpec.makeMeasureSpec(px, View.MeasureSpec.EXACTLY); }
        static int unspecified() { return View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED); }
    }

    /**
     * Narrow screens have room for the picker or a run's results, not both: the
     * picker shows until Start, then folds into one line until Clear.
     */
    private void foldPicker() {
        boolean fold = showingRun && !wide;
        pickCard.setVisibility(fold ? View.GONE : View.VISIBLE);
        picksLbl.setVisibility(fold ? View.VISIBLE : View.GONE);
        // The run card's top margin assumes something above it in the column.
        View run = leftCol.getChildAt(1);
        if (run != null) ((LinearLayout.LayoutParams) run.getLayoutParams()).topMargin = fold ? 0 : dp(12);
    }

    // ---- the collector fills itself in: USB (adb reverse) first, then the LAN address baked in at build time.
    private List<String[]> candidates() {
        List<String[]> c = new ArrayList<>();
        Intent it = getIntent();
        if (it.hasExtra("host")) c.add(new String[]{it.getStringExtra("host"), String.valueOf(it.getIntExtra("port", Collector.PORT)), "set by adb"});
        c.add(new String[]{"127.0.0.1", String.valueOf(Collector.PORT), "over USB"});
        if (!Collector.HOST.isEmpty()) c.add(new String[]{Collector.HOST, String.valueOf(Collector.PORT), "over Wi-Fi"});
        return c;
    }
    private void findCollector(Runnable then) {
        new Thread(() -> {
            List<String[]> cs = candidates();
            String[] hit = null;
            for (String[] c : cs) {
                try (Socket s = new Socket()) { s.connect(new InetSocketAddress(c[0], Integer.parseInt(c[1])), 800); hit = c; break; }
                catch (Exception e) { /* next */ }
            }
            final String[] h = hit;
            ui.post(() -> {
                if (h != null) { colHost = h[0]; colPort = Integer.parseInt(h[1]); colHow = h[2];
                    collectorLbl.setText("Results go to: " + colHost + ":" + colPort + " (" + colHow + ", found automatically). They are also saved on this phone.");
                    collectorLbl.setTextColor(Color.WHITE); }
                else { String[] d = cs.get(cs.size() - 1); colHost = d[0]; colPort = Integer.parseInt(d[1]); colHow = "not reachable now";
                    collectorLbl.setText("Results go to: " + colHost + ":" + colPort + " (could not reach it yet; will try again at Start). They are saved on this phone either way.");
                    collectorLbl.setTextColor(MUTED); }
                if (then != null) then.run();
            });
        }).start();
    }

    /** rind-bench's rustls rows read certificates from RIND_BENCH_KEYS_DIR. */
    private String copyKeys() {
        File dst = new File(getFilesDir(), "keys");
        try {
            for (String dir : getAssets().list("keys")) {
                File d = new File(dst, dir); d.mkdirs();
                for (String f : getAssets().list("keys/" + dir)) {
                    try (InputStream in = getAssets().open("keys/" + dir + "/" + f); OutputStream out = new FileOutputStream(new File(d, f))) {
                        byte[] buf = new byte[8192]; int n; while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
                    }
                }
            }
        } catch (IOException e) { /* rustls rows will fail and be reported as errors */ }
        return dst.getAbsolutePath();
    }

    private void loaded(String cat, String keys) {
        keysDir = keys;
        try { catalog = new JSONObject(cat); } catch (Exception e) { catalog = null; }
        if (catalog == null) { deviceLbl.setText("Could not read the list of tests."); return; }
        try {
            JSONObject d = catalog.getJSONObject("device");
            String sha = catalog.optString("rind_commit"); if (sha.length() > 12) sha = sha.substring(0, 12);
            JSONArray rows = catalog.getJSONArray("rows"), libs = catalog.getJSONArray("libraries"), secs = catalog.getJSONArray("sections");
            // Only the fields this device reports.
            List<String> parts = new ArrayList<>();
            for (String k : new String[]{"product", "cpu", "os"}) {
                String v = d.optString(k, "");
                if (!v.isEmpty() && !v.equals("unknown") && !v.equals("null")) parts.add(v);
            }
            if (!sha.isEmpty()) parts.add("rind " + sha);
            parts.add(rows.length() + " rows");
            parts.add(catalog.optBoolean("openssl") ? "OpenSSL built in" : "no OpenSSL in this build");
            deviceLbl.setText(String.join(" · ", parts));
            Map<String, Integer> sc = new HashMap<>();
            for (int i = 0; i < rows.length(); i++) sc.merge(rows.getJSONObject(i).getString("section"), 1, Integer::sum);
            Set<String> wantLibs = csv(getIntent().getStringExtra("libraries")), wantSecs = csv(getIntent().getStringExtra("sections"));
            for (int i = 0; i < libs.length(); i++) {
                String l = libs.getString(i);
                TextView c = chip(l, wantLibs.isEmpty() || wantLibs.contains(l), true); libChips.put(l, c); libFlow.addView(c);
            }
            // rind-bench's extra rows ("More: <file>", off by default) share one chip, so the screen never has to scroll.
            boolean moreOn = false;
            for (int i = 0; i < secs.length(); i++) {
                String s = secs.getString(i); int n = sc.getOrDefault(s, 0);
                if (s.startsWith("More: ")) { if (n > 0) { moreSections.add(s); moreOn |= wantSecs.contains(s); } continue; }
                boolean on = n > 0 && (wantSecs.isEmpty() || wantSecs.contains(s));
                TextView c = chip(s, on, n > 0); secChips.put(s, c); secFlow.addView(c);
            }
            if (!moreSections.isEmpty()) { moreChip = chip("+ " + moreSections.size() + " more groups", moreOn, true); secFlow.addView(moreChip); }
            ready();
        } catch (Exception e) { statusLbl.setText("Could not read the list of tests: " + e); }
        agreeChanged();
        reportLayout("ready");
        if (getIntent().getBooleanExtra("autostart", false)) ui.postDelayed(() -> { agree.setChecked(true); startTapped(); }, 3000);
    }

    /**
     * One machine-readable line saying whether the screen fits, for a device
     * runner checking "no scrolling" without a person looking:
     *   RINDBENCH_LAYOUT {"phase":"ready","w":411,"h":914,"wide":false,"folded":false,"fits":true,"clipped":[]}
     * w and h are dp. fits: the run controls are whole and on screen, and the
     * run panel shows its status (and score, once there is one). "picker" in
     * clipped means some chips are cut off, which a short screen allows.
     */
    private void reportLayout(String phase) {
        ui.postDelayed(() -> {
            try {
                View run = leftCol.getChildAt(1);
                int bottom = bottomOf(body) + 1;
                List<String> clipped = new ArrayList<>();
                if (!whole(run) || bottomOf(run) > bottom) clipped.add("run controls");
                if (pickCard.getVisibility() == View.VISIBLE && !whole(pickCard)) clipped.add("picker");
                if (statusLbl.getText().length() > 0 && !shown(statusLbl, bottom)) clipped.add("status");
                if (scoreLbl.getText().length() > 0 && !shown(scoreLbl, bottom)) clipped.add("score");
                boolean fits = true;
                for (String c : clipped) if (!c.equals("picker")) fits = false;
                float d = getResources().getDisplayMetrics().density;
                View root = getWindow().getDecorView();
                JSONObject o = new JSONObject();
                o.put("phase", phase); o.put("w", Math.round(root.getWidth() / d)); o.put("h", Math.round(root.getHeight() / d));
                o.put("wide", wide); o.put("folded", pickCard.getVisibility() != View.VISIBLE);
                o.put("fits", fits); o.put("clipped", new JSONArray(clipped));
                Log.i("RindBench", "RINDBENCH_LAYOUT " + o);
            } catch (Exception e) { Log.w("RindBench", "RINDBENCH_LAYOUT failed: " + e); }
        }, 600);
    }
    private static int bottomOf(View v) { int[] xy = new int[2]; v.getLocationInWindow(xy); return xy[1] + v.getHeight(); }
    /** Whether v got all the height it asks for at its width. Re-lays out afterwards, since measure() overwrites its size. */
    private static boolean whole(View v) {
        if (v.getWidth() == 0) return false;
        v.measure(MeasureSpecs.exactly(v.getWidth()), MeasureSpecs.unspecified());
        boolean ok = v.getMeasuredHeight() <= v.getHeight() + 1;
        v.requestLayout();
        return ok;
    }
    private boolean shown(TextView v, int bottom) {
        // The text's own layout, not a re-measure: scoreLbl has a fixed height and shrinks its text to fit.
        android.text.Layout l = v.getLayout();
        boolean textFits = l != null && l.getHeight() <= v.getHeight() - v.getTotalPaddingTop() - v.getTotalPaddingBottom() + 1;
        return v.getVisibility() == View.VISIBLE && v.getHeight() > 0 && textFits
            && bottomOf(v) <= bottomOf(resultsCard) + 1 && bottomOf(v) <= bottom;
    }

    private void ready() {
        statusLbl.setText("Ready"); progress.setProgress(0); scoreLbl.setText(""); behindLbl.setText("");
        try { currentLbl.setText(catalog.getJSONArray("operations_without_rows").length() + " report operations have no row on this platform."); }
        catch (Exception e) { currentLbl.setText(""); }
    }

    private static Set<String> csv(String s) {
        Set<String> out = new HashSet<>();
        if (s != null) for (String p : s.split(",")) if (!p.trim().isEmpty()) out.add(p.trim());
        return out;
    }

    private void agreeChanged() { setEnabledLook(startBtn, agree.isChecked() && catalog != null && !polling); }

    private void startTapped() {
        if (!agree.isChecked() || catalog == null || polling) return;
        List<String> libs = new ArrayList<>(), secs = new ArrayList<>();
        for (Map.Entry<String, TextView> e : libChips.entrySet()) if (e.getValue().isSelected()) libs.add(e.getKey());
        for (Map.Entry<String, TextView> e : secChips.entrySet()) if (e.getValue().isSelected()) secs.add(e.getKey());
        if (moreChip != null && moreChip.isSelected()) secs.addAll(moreSections);
        if (libs.isEmpty() || secs.isEmpty()) { statusLbl.setText("Pick at least one library and one operation"); return; }
        setEnabledLook(startBtn, false);
        statusLbl.setText("Starting. Connecting to the computer that installed this app.");
        // Look again right before the run, so a cable plugged in (or Wi-Fi joined) since launch is used.
        findCollector(() -> begin(libs, secs));
    }

    private void begin(List<String> libs, List<String> secs) {
        try {
            JSONObject cfg = new JSONObject();
            cfg.put("libraries", new JSONArray(libs)); cfg.put("sections", new JSONArray(secs));
            cfg.put("rounds", full ? 3 : 1); cfg.put("samples", full ? 10 : 5); cfg.put("sample_ms", full ? 100 : 50); cfg.put("warm_ms", full ? 300 : 150);
            File out = getExternalFilesDir(null); if (out == null) out = getFilesDir();
            cfg.put("out_dir", out.getAbsolutePath()); cfg.put("label", "android");
            if (colHost != null) { cfg.put("host", colHost); cfg.put("port", colPort); }
            JSONObject env = new JSONObject(); env.put("RIND_BENCH_KEYS_DIR", keysDir); cfg.put("env", env);
            if (Native.start(cfg.toString()) != 0) {
                statusLbl.setText("Could not start: " + new JSONObject(Native.status()).optString("start_error")); agreeChanged(); return;
            }
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
            startBtn.setVisibility(View.GONE); clearBtn.setVisibility(View.GONE);
            stopBtn.setVisibility(View.VISIBLE); setEnabledLook(stopBtn, true); agree.setEnabled(false);
            statusLbl.setText("Starting…"); scoreLbl.setText(""); behindLbl.setText("");
            picksLbl.setText((full ? "Full" : "Quick") + " · " + libs.size() + " libraries · " + secs.size() + " groups");
            showingRun = true; foldPicker();
            polling = true; ran = true; ui.post(this::poll);
            reportLayout("run");
        } catch (Exception e) { statusLbl.setText("Could not start: " + e); agreeChanged(); }
    }

    private void stopTapped() { Native.stop(); setEnabledLook(stopBtn, false); statusLbl.setText("Stopping after the current row…"); }

    private void clearTapped() {
        if (polling) return;
        ran = false; agree.setChecked(false); agree.setEnabled(true);
        clearBtn.setVisibility(View.GONE);
        startBtn.setText("Start test"); startBtn.setVisibility(View.VISIBLE); agreeChanged(); ready();
        showingRun = false; foldPicker();
        findCollector(null);
    }

    /** iOS NSProcessInfo.thermalState words, from Android's thermal status. */
    private String thermal() {
        if (Build.VERSION.SDK_INT < 29) return "unknown";
        int t = ((PowerManager) getSystemService(POWER_SERVICE)).getCurrentThermalStatus();
        if (t <= PowerManager.THERMAL_STATUS_NONE) return "nominal";
        if (t <= PowerManager.THERMAL_STATUS_MODERATE) return "fair";
        if (t == PowerManager.THERMAL_STATUS_SEVERE) return "serious";
        return "critical";
    }

    private void poll() {
        if (!polling) return;
        try {
            JSONObject s = new JSONObject(Native.status());
            boolean running = s.optBoolean("running");
            String th = thermal();
            int total = Math.max(1, s.optInt("total"));
            progress.setProgress((int) (1000L * s.optInt("done") / total));
            if (running) {
                statusLbl.setText(String.format(Locale.US, "Running %d of %d · round %d of %d", s.optInt("done"), s.optInt("total"), s.optInt("round"), s.optInt("rounds")));
                currentLbl.setText(String.format(Locale.US, "%s\nerrors %d · sent %d lines (%s) · thermal %s",
                    s.optString("current", ""), s.optInt("errors"), s.optInt("lines"), s.optString("sink"), th));
            } else {
                statusLbl.setText(String.format(Locale.US, "%s · %d rows in %.0f s", s.optBoolean("stopped") ? "Stopped" : "Finished", s.optInt("done"), s.optDouble("elapsed_s", 0)));
                currentLbl.setText(String.format(Locale.US, "errors %d · sent %d lines (%s) · thermal %s · full timings saved on this phone",
                    s.optInt("errors"), s.optInt("lines"), s.optString("sink"), th));
            }
            summarize(s.optJSONObject("results"));
            if (!running) {
                polling = false; getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                startBtn.setText("Run again"); startBtn.setVisibility(View.VISIBLE); stopBtn.setVisibility(View.GONE);
                clearBtn.setVisibility(View.VISIBLE); setEnabledLook(clearBtn, true); agree.setEnabled(true); agreeChanged();
                reportLayout("done");
                return;
            }
        } catch (Exception e) { statusLbl.setText("status: " + e); }
        ui.postDelayed(this::poll, 1000);
    }

    /**
     * Per operation, the fastest library. The score counts the operations rind
     * is fastest at; the list shows where it is not, worst first, as many as fit.
     */
    private void summarize(JSONObject res) throws Exception {
        if (res == null) return;
        Map<String, Map<String, Double>> byOp = new TreeMap<>();
        int errors = 0;
        for (Iterator<String> it = res.keys(); it.hasNext(); ) {
            String id = it.next(); JSONObject r = res.getJSONObject(id);
            if ("error".equals(r.optString("t"))) { errors++; continue; }
            String op = r.isNull("op") ? id : r.optString("op", id);
            String lib = r.isNull("library") ? "?" : r.optString("library", "?");
            byOp.computeIfAbsent(op, k -> new TreeMap<>()).put(lib, r.optDouble("ns"));
        }
        int compared = 0, wins = 0;
        List<Object[]> behind = new ArrayList<>();
        for (Map.Entry<String, Map<String, Double>> e : byOp.entrySet()) {
            Double rind = e.getValue().get("rind");
            if (rind == null || e.getValue().size() < 2) continue;
            compared++;
            String best = null; double bestNs = Double.MAX_VALUE;
            for (Map.Entry<String, Double> l : e.getValue().entrySet()) if (l.getValue() < bestNs) { bestNs = l.getValue(); best = l.getKey(); }
            if ("rind".equals(best)) wins++;
            else behind.add(new Object[]{e.getKey().replace("/{lib}", ""), best, rind / bestNs, rind});
        }
        if (compared == 0) { scoreLbl.setText(""); behindLbl.setText(errors > 0 ? errors + " rows failed so far" : ""); return; }
        scoreLbl.setText("rind fastest on " + wins + " of " + compared);
        scoreLbl.setTextColor(wins * 2 >= compared ? GOOD : ACCENT);
        behind.sort((a, b) -> Double.compare((Double) b[2], (Double) a[2]));
        android.text.SpannableStringBuilder out = new android.text.SpannableStringBuilder();
        if (!behind.isEmpty()) {
            int st = out.length(); out.append("Where another library is faster\n");
            out.setSpan(new android.text.style.ForegroundColorSpan(MUTED), st, out.length(), 0);
            out.setSpan(new android.text.style.StyleSpan(Typeface.BOLD), st, out.length(), 0);
        }
        for (Object[] b : behind) {
            int st = out.length();
            out.append(String.format(Locale.US, "%.2f×  %s  (vs %s, rind %s)\n", (Double) b[2], b[0], b[1], fmt((Double) b[3])));
            out.setSpan(new android.text.style.ForegroundColorSpan((Double) b[2] > 1.10 ? BAD : TEXT), st, out.length(), 0);
        }
        if (errors > 0) {
            int st = out.length(); out.append(errors + " rows failed; see the saved results\n");
            out.setSpan(new android.text.style.ForegroundColorSpan(BAD), st, out.length(), 0);
        }
        behindLbl.setText(out);
    }

    private static String fmt(double ns) {
        if (ns >= 1e6) return String.format(Locale.US, "%.2f ms", ns / 1e6);
        if (ns >= 1e3) return String.format(Locale.US, "%.2f µs", ns / 1e3);
        return String.format(Locale.US, "%.0f ns", ns);
    }
}
