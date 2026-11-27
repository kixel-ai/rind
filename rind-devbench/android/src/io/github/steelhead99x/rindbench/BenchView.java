package io.github.steelhead99x.rindbench;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.Typeface;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.CompoundButton;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.Switch;
import android.widget.TextView;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;

/**
 * Bench page. Compact width: one scrolling column with consent and Start
 * pinned at the bottom. Medium/expanded width (phone landscape, tablets):
 * two panes, test setup on the left; collector, run status, consent and
 * Start on the right. Panes scroll, so large font sizes wrap instead of
 * truncating, and consent and Start stay pinned and visible.
 */
final class BenchView extends LinearLayout {
    private final Activity host;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final LinearLayout leftPane, rightPane, colA, colB, footer, testsBlock;
    private final ScrollView scrollA, scrollB;
    private TextView timingHint, statusTitle, statusLbl, resultsTeaser;
    private Theme.Row collector, libsRow, groupsRow, consentRow;
    private LinearLayout statusCard;
    private Button quickBtn, fullBtn;
    private boolean fullPreset;
    private Switch agree;
    private ImageButton shareBtn;
    private Button startBtn, stopBtn, clearBtn, retryBtn, resultsBtn;
    private ProgressBar progress;
    private boolean running, collectorOK, catalogReady;
    private JSONObject catalog;
    private final Map<String, CompoundButton> libSw = new LinkedHashMap<>();
    private final Map<String, CompoundButton> secSw = new LinkedHashMap<>();
    private final List<View> libRows = new ArrayList<>(), groupRows = new ArrayList<>(), moreRows = new ArrayList<>();
    private String resultsText = "";
    private String detailsText = "Loading device and build details...";
    private String keysDir, colHost;
    private int colPort = Collector.PORT;
    private String colHow = "";
    /** The key fixtures, copied and exported once per process; see the constructor. */
    private static String sharedKeysDir;
    /** The native run whose results the person cleared, so a recreated view doesn't bring them back. */
    private static String clearedRun = "";
    /** The collector a device-runner build was given by intent; a failed probe never forgets it. */
    private String runnerHost;
    private int runnerPort = Collector.PORT;
    private final Runnable poll = this::poll;
    private final boolean restored;
    /** Between the activity's onStart and onStop. */
    private boolean onScreen = true;

    /**
     * `restored`: the activity is being recreated from saved state, after a
     * configuration change or after Android killed the process. Its launch
     * intent comes back with it, so a device runner's autostart must not fire
     * again; the native run state alone can't tell, since process death
     * clears it.
     */
    BenchView(Activity host, Intent intent, boolean restored) {
        super(host);
        this.host = host;
        this.restored = restored;
        setBackgroundColor(Theme.surface);
        setContentDescription("Bench page");
        int s2 = Theme.dpi(host, 8), s4 = Theme.dpi(host, 16);

        // Collector status: one quiet row, secondary to the run controls.
        retryBtn = Theme.button(host, "Retry", Theme.Btn.TEXT, null);
        retryBtn.setContentDescription("Retry collector connection");
        retryBtn.setOnClickListener(v -> findCollector());
        retryBtn.setVisibility(GONE);
        collector = Theme.row(host, "Checking collector…", null, "ic_cloud_off", retryBtn);
        Theme.type(collector.headline, Theme.Type.BODY_MEDIUM);
        Theme.type(collector.supporting, Theme.Type.BODY_SMALL);
        collector.view.setFocusable(true);

        // Test setup.
        testsBlock = new LinearLayout(host);
        testsBlock.setOrientation(VERTICAL);
        testsBlock.addView(Theme.subheader(host, "Tests"));
        LinearLayout seg = new LinearLayout(host);
        seg.setOrientation(HORIZONTAL);
        seg.setPadding(s4, 0, s4, 0);
        seg.setContentDescription("Test length");
        quickBtn = Theme.segment(host, "Quick test", 0, 2);
        fullBtn = Theme.segment(host, "Full test", 1, 2);
        quickBtn.setOnClickListener(v -> { if (!running) { fullPreset = false; presetChanged(); } });
        fullBtn.setOnClickListener(v -> { if (!running) { fullPreset = true; presetChanged(); } });
        // MATCH_PARENT height keeps both halves the same height when one wraps or carries the check icon.
        seg.addView(quickBtn, new LayoutParams(0, LayoutParams.MATCH_PARENT, 1));
        seg.addView(fullBtn, new LayoutParams(0, LayoutParams.MATCH_PARENT, 1));
        testsBlock.addView(seg);
        timingHint = Theme.text(host, "", Theme.Type.BODY_SMALL, Theme.onSurfaceVariant);
        timingHint.setPadding(s4, Theme.dpi(host, 4), s4, s2);
        testsBlock.addView(timingHint);
        libsRow = Theme.row(host, "Libraries", null, null, chevron());
        Theme.clickable(libsRow.view, v -> openLibraries());
        groupsRow = Theme.row(host, "Groups", null, null, chevron());
        Theme.clickable(groupsRow.view, v -> openGroups());
        testsBlock.addView(libsRow.view);
        testsBlock.addView(groupsRow.view);

        // Run status card.
        statusCard = Theme.card(host);
        statusTitle = Theme.text(host, "Loading tests…", Theme.Type.TITLE_MEDIUM, Theme.onSurface);
        statusTitle.setAccessibilityLiveRegion(ACCESSIBILITY_LIVE_REGION_POLITE);
        statusLbl = Theme.text(host, "", Theme.Type.BODY_MEDIUM, Theme.onSurfaceVariant);
        statusLbl.setVisibility(GONE);
        progress = Theme.progress(host);
        progress.setVisibility(GONE);
        progress.setContentDescription("Run progress");
        resultsTeaser = Theme.text(host, "", Theme.Type.BODY_SMALL, Theme.onSurface);
        resultsTeaser.setTypeface(Typeface.MONOSPACE);
        resultsTeaser.setVisibility(GONE);
        resultsBtn = Theme.button(host, "View results", Theme.Btn.TONAL, null);
        resultsBtn.setOnClickListener(v -> openResults());
        clearBtn = Theme.button(host, "Clear", Theme.Btn.TEXT, null);
        clearBtn.setContentDescription("Clear results");
        clearBtn.setOnClickListener(v -> clearTapped());
        resultsBtn.setVisibility(GONE);
        clearBtn.setVisibility(GONE);
        // Header: state and summary on the left, View results on the right so it
        // stays in view on short screens (phone landscape) without scrolling.
        LinearLayout head = new LinearLayout(host);
        head.setOrientation(HORIZONTAL);
        head.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout headText = new LinearLayout(host);
        headText.setOrientation(VERTICAL);
        headText.addView(statusTitle);
        LayoutParams sl = new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT);
        sl.topMargin = Theme.dpi(host, 4);
        headText.addView(statusLbl, sl);
        head.addView(headText, new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1));
        LayoutParams rb = new LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT);
        rb.setMarginStart(s2);
        head.addView(resultsBtn, rb);
        statusCard.addView(head);
        LayoutParams pl = new LayoutParams(LayoutParams.MATCH_PARENT, Theme.dpi(host, 4));
        pl.topMargin = Theme.dpi(host, 12);
        statusCard.addView(progress, pl);
        LayoutParams tl = new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT);
        tl.topMargin = Theme.dpi(host, 12);
        statusCard.addView(resultsTeaser, tl);
        LinearLayout acts = new LinearLayout(host);
        acts.setOrientation(HORIZONTAL);
        acts.setGravity(Gravity.CENTER_VERTICAL);
        acts.setGravity(Gravity.END | Gravity.CENTER_VERTICAL);
        acts.addView(clearBtn);
        LayoutParams al = new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT);
        al.topMargin = Theme.dpi(host, 4);
        statusCard.addView(acts, al);

        // Footer: consent and Start, always on screen.
        footer = new LinearLayout(host);
        footer.setOrientation(VERTICAL);
        footer.setBackgroundColor(Theme.surface);
        footer.addView(Theme.divider(host));
        shareBtn = Theme.iconButton(host, "ic_info", "What's shared");
        shareBtn.setTooltipText("What's shared");
        shareBtn.setOnClickListener(v -> openShare());
        agree = Theme.switchM3(host, "I agree to share timings");
        agree.setOnCheckedChangeListener((v, on) -> agreeChanged());
        consentRow = Theme.row(host, "I agree to share timings", "Timings and device info only", null, shareBtn, agree);
        Theme.toggleRow(consentRow.view, agree, "I agree to share timings. Timings and device info only.", Switch.class);
        footer.addView(consentRow.view);
        startBtn = Theme.button(host, "Start", Theme.Btn.FILLED, "ic_play");
        startBtn.setEnabled(false);
        startBtn.setOnClickListener(v -> startTapped());
        stopBtn = Theme.button(host, "Stop", Theme.Btn.TONAL, "ic_stop");
        stopBtn.setOnClickListener(v -> stopTapped());
        stopBtn.setVisibility(GONE);
        LayoutParams bl = new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT);
        bl.leftMargin = bl.rightMargin = s4;
        bl.bottomMargin = s2;
        footer.addView(startBtn, bl);
        footer.addView(stopBtn, new LayoutParams(bl));

        colA = column();
        colB = column();
        scrollA = scroller(colA);
        scrollB = scroller(colB);
        leftPane = new LinearLayout(host);
        leftPane.setOrientation(VERTICAL);
        leftPane.addView(scrollA, new LayoutParams(LayoutParams.MATCH_PARENT, 0, 1));
        rightPane = new LinearLayout(host);
        rightPane.setOrientation(VERTICAL);
        rightPane.addView(scrollB, new LayoutParams(LayoutParams.MATCH_PARENT, 0, 1));

        onChromeRelayout();
        presetChanged();
        applyIntent(intent);
        findCollector();
        ui.postDelayed(() -> { if (!running && !collectorOK) findCollector(); }, 4000);
        new Thread(() -> {
            // Once per process: a run outlives its activity, and a recreated view must not rewrite the
            // key files that run reads, nor call setenv while its threads read the environment.
            synchronized (BenchView.class) {
                if (sharedKeysDir == null) {
                    sharedKeysDir = copyKeys();
                    Native.setenv("RIND_BENCH_KEYS_DIR", sharedKeysDir);
                }
                keysDir = sharedKeysDir;
            }
            String cat = Native.catalog();
            ui.post(() -> loaded(cat, intent));
        }, "devbench-catalog").start();
    }

    private ImageView chevron() {
        ImageView v = Theme.iconView(host, "ic_chevron_right", Theme.onSurfaceVariant);
        v.setLayoutParams(new LayoutParams(Theme.dpi(host, 24), Theme.dpi(host, 24)));
        return v;
    }

    private LinearLayout column() {
        LinearLayout l = new LinearLayout(host);
        l.setOrientation(VERTICAL);
        l.setPadding(0, 0, 0, Theme.dpi(host, 16));
        return l;
    }

    private ScrollView scroller(View child) {
        ScrollView s = new ScrollView(host);
        s.setFillViewport(true);
        s.addView(child, new ScrollView.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT));
        return s;
    }

    private static void detach(View v) {
        if (v.getParent() instanceof ViewGroup) ((ViewGroup) v.getParent()).removeView(v);
    }

    /** Re-flows the panes for the current window size class. */
    void onChromeRelayout() {
        boolean wide = MainActivity.isWide(host);
        int s4 = Theme.dpi(host, 16);
        removeAllViews();
        colA.removeAllViews();
        colB.removeAllViews();
        detach(collector.view); detach(testsBlock); detach(statusCard); detach(footer);
        LayoutParams foot = new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT);
        LayoutParams card = new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT);
        card.leftMargin = card.rightMargin = s4;
        card.topMargin = Theme.dpi(host, 8);
        card.bottomMargin = Theme.dpi(host, 8);
        if (wide) {
            setOrientation(HORIZONTAL);
            colA.addView(testsBlock);
            colB.addView(statusCard, card);
            colB.addView(collector.view);
            rightPane.addView(footer, foot);
            addView(leftPane, new LayoutParams(0, LayoutParams.MATCH_PARENT, 1));
            View rule = new View(host);
            rule.setBackgroundColor(Theme.outlineVariant);
            addView(rule, new LayoutParams(Math.max(1, Theme.dpi(host, 1)), LayoutParams.MATCH_PARENT));
            addView(rightPane, new LayoutParams(0, LayoutParams.MATCH_PARENT, 1));
        } else {
            setOrientation(VERTICAL);
            colA.addView(testsBlock);
            colA.addView(statusCard, card);
            colA.addView(collector.view);
            leftPane.addView(footer, foot);
            addView(leftPane, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
        }
    }

    void applyIntent(Intent it) {
        if (it == null) return;
        // The launcher is exported, so any app can send these extras. Only a
        // device-runner build (build-apk.sh with DEVICE_RUNNER=1) takes a collector
        // or autostart from them; the other extras only preselect the picker.
        if (Collector.RUNNER && it.hasExtra("host")) {
            runnerHost = it.getStringExtra("host");
            runnerPort = it.getIntExtra("port", Collector.PORT);
            colHost = runnerHost;
            colPort = runnerPort;
            colHow = "set by adb";
        }
        // As the preset buttons, a preset can't change while a run is going.
        if (running) return;
        if ("full".equals(it.getStringExtra("preset"))) { fullPreset = true; presetChanged(); }
        if ("quick".equals(it.getStringExtra("preset"))) { fullPreset = false; presetChanged(); }
    }

    private void setBody(String s) {
        statusLbl.setText(s);
        statusLbl.setVisibility(s == null || s.isEmpty() ? GONE : VISIBLE);
    }

    private void presetChanged() {
        boolean full = fullPreset;
        Theme.selectSegment(quickBtn, !full, !running);
        Theme.selectSegment(fullBtn, full, !running);
        quickBtn.setContentDescription("Quick test" + (!full ? ", selected" : ""));
        fullBtn.setContentDescription("Full test" + (full ? ", selected" : ""));
        timingHint.setText(full ? "3 rounds, 10 × 100 ms, 300 ms warm-up" : "1 round, 5 × 50 ms, 150 ms warm-up");
    }

    private void countsChanged() {
        int lon = 0, gon = 0, mon = 0, mall = 0, gall = 0;
        for (CompoundButton s : libSw.values()) if (s.isChecked()) lon++;
        for (Map.Entry<String, CompoundButton> e : secSw.entrySet()) {
            if (e.getKey().startsWith("More: ")) { mall++; if (e.getValue().isChecked()) mon++; }
            else { gall++; if (e.getValue().isChecked()) gon++; }
        }
        String libs = libSw.isEmpty() ? "" : lon == libSw.size() ? "All " + lon + " selected" : lon + " of " + libSw.size() + " selected";
        String groups = gall == 0 ? "" : gon + " of " + gall + " selected" + (mon > 0 ? ", plus " + mon + " more" : "");
        libsRow.setSupporting(libs);
        groupsRow.setSupporting(groups);
        libsRow.view.setContentDescription("Libraries" + (libs.isEmpty() ? "" : ", " + libs));
        groupsRow.view.setContentDescription("Groups" + (groups.isEmpty() ? "" : ", " + groups));
        agreeChanged();
    }

    private void loaded(String cat, Intent intent) {
        try { catalog = new JSONObject(cat); catalogReady = true; }
        catch (Exception e) {
            catalog = null; catalogReady = false;
            detailsText = "Could not load test list.";
            agreeChanged();
            return;
        }
        try {
            JSONObject d = catalog.getJSONObject("device");
            String sha = catalog.optString("rind_commit");
            if (sha.length() > 12) sha = sha.substring(0, 12);
            JSONArray rows = catalog.getJSONArray("rows"), libs = catalog.getJSONArray("libraries"), secs = catalog.getJSONArray("sections");
            detailsText = String.format(Locale.US,
                    "Device: %s\nChip: %s\nSystem: %s\nrind commit: %s\nTests: %d rows across %d libraries\nOpenSSL: %s",
                    d.optString("product"), d.optString("cpu"), d.optString("os"),
                    sha, rows.length(), libs.length(),
                    catalog.optBoolean("openssl") ? "Built in" : "Not in this build");
            Map<String, Integer> lc = new LinkedHashMap<>(), sc = new LinkedHashMap<>();
            for (int i = 0; i < rows.length(); i++) {
                JSONObject r = rows.getJSONObject(i);
                String lib = r.optString("library"), sec = r.optString("section");
                lc.put(lib, lc.getOrDefault(lib, 0) + 1);
                sc.put(sec, sc.getOrDefault(sec, 0) + 1);
            }
            java.util.Set<String> wantLibs = csv(intent == null ? null : intent.getStringExtra("libraries"));
            java.util.Set<String> wantSecs = csv(intent == null ? null : intent.getStringExtra("sections"));
            for (int i = 0; i < libs.length(); i++) {
                String l = libs.getString(i);
                boolean on = wantLibs.isEmpty() || wantLibs.contains(l);
                libRows.add(checkRow(l, lc.getOrDefault(l, 0), on, true, libSw, l));
            }
            for (int i = 0; i < secs.length(); i++) {
                String s = secs.getString(i);
                int n = sc.getOrDefault(s, 0);
                boolean on = n > 0 && (wantSecs.isEmpty() ? !s.startsWith("More: ") : wantSecs.contains(s));
                View row = checkRow(s.startsWith("More: ") ? s.substring(6) : s, n, on, n > 0, secSw, s);
                if (s.startsWith("More: ")) moreRows.add(row); else groupRows.add(row);
            }
            if (!running && resultsText.isEmpty()) {
                statusTitle.setText("Ready");
                setBody("");
            }
        } catch (Exception e) {
            statusTitle.setText("Could not load tests");
        }
        countsChanged();
        agreeChanged();
        // The run lives in the native library, past this activity: after a recreation, such as a
        // dark mode switch, pick up a run that's going, or show the results of one that finished.
        JSONObject st = nativeStatus();
        if (st.optBoolean("running")) {
            enterRunning();
            return;
        }
        String run = st.optString("run_id", "");
        if (!run.isEmpty()) {
            // A recreated activity gets its intent again: autostart only the process's first run.
            if (!run.equals(clearedRun)) showFinished(st, false);
            return;
        }
        // A launch's autostart is consumed by its first view: never by one restored from saved state,
        // nor while the operator has left the app, since a runner's run needs the screen it set up.
        if (Collector.RUNNER && !restored && onScreen && intent != null && intent.getBooleanExtra("autostart", false)) {
            agree.setChecked(true);
            startTapped();
        }
    }

    private static java.util.Set<String> csv(String s) {
        java.util.Set<String> out = new java.util.LinkedHashSet<>();
        if (s != null) for (String p : s.split(",")) if (!p.trim().isEmpty()) out.add(p.trim());
        return out;
    }

    /** Multi-select list item for the Libraries and Groups sheets. */
    private View checkRow(String title, int count, boolean on, boolean en, Map<String, CompoundButton> dict, String key) {
        LinearLayout row = new LinearLayout(host);
        row.setOrientation(HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setMinimumHeight(Theme.dpi(host, 56));
        row.setPaddingRelative(Theme.dpi(host, 12), Theme.dpi(host, 4), Theme.dpi(host, 24), Theme.dpi(host, 4));
        CheckBox cb = Theme.checkBox(host);
        cb.setChecked(on);
        cb.setEnabled(en);
        cb.setOnCheckedChangeListener((v, c) -> countsChanged());
        dict.put(key, cb);
        TextView l = Theme.text(host, title, Theme.Type.BODY_LARGE, Theme.onSurface);
        TextView n = Theme.text(host, String.valueOf(count), Theme.Type.BODY_MEDIUM, Theme.onSurfaceVariant);
        LayoutParams lp = new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1);
        lp.setMarginStart(Theme.dpi(host, 4));
        lp.setMarginEnd(Theme.dpi(host, 16));
        row.addView(cb);
        row.addView(l, lp);
        row.addView(n);
        String noun = count == 1 ? " test" : " tests";
        Theme.toggleRow(row, cb, title + ", " + count + noun, CheckBox.class);
        row.setEnabled(en);
        if (!en) { l.setAlpha(0.38f); n.setAlpha(0.38f); }
        return row;
    }

    private java.util.List<String[]> candidates() {
        java.util.List<String[]> c = new ArrayList<>();
        // A runner's collector, set by intent, is the only candidate: when it's down, results
        // save on the phone and go nowhere else, rather than to whichever collector answers.
        if (runnerHost != null && !runnerHost.isEmpty()) {
            c.add(new String[]{runnerHost, String.valueOf(runnerPort), "set by adb"});
            return c;
        }
        c.add(new String[]{"127.0.0.1", String.valueOf(Collector.PORT), "over USB"});
        if (Collector.HOST != null && !Collector.HOST.isEmpty())
            c.add(new String[]{Collector.HOST, String.valueOf(Collector.PORT), "over Wi-Fi"});
        return c;
    }

    private void findCollector() {
        new Thread(() -> {
            String[] hit = null;
            for (String[] c : candidates()) {
                try (Socket s = new Socket()) {
                    s.connect(new InetSocketAddress(c[0], Integer.parseInt(c[1])), 2000);
                    hit = c;
                    break;
                } catch (Exception ignored) {}
            }
            final String[] h = hit;
            ui.post(() -> applyCollector(h));
        }, "collector-probe").start();
    }

    private void showCollector(String icon, int tint, String title, String sub, boolean retry) {
        collector.leading.setImageDrawable(Theme.icon(host, icon, tint));
        collector.headline.setText(title);
        collector.setSupporting(sub);
        retryBtn.setVisibility(retry ? VISIBLE : GONE);
        collector.view.setContentDescription(title + (sub.isEmpty() ? "" : ". " + sub));
    }

    private void applyCollector(String[] h) {
        if (h != null) {
            colHost = h[0]; colPort = Integer.parseInt(h[1]); colHow = h[2];
            collectorOK = true;
            showCollector("ic_cloud_done", Theme.primary, "Collector connected",
                    colHost + ":" + colPort + ("over USB".equals(colHow) ? " over USB" : ""), false);
        } else {
            collectorOK = false;
            // A runner's own collector stays the target while it's down; otherwise the last place tried.
            List<String[]> all = candidates();
            String[] d = runnerHost != null && !runnerHost.isEmpty() ? all.get(0) : all.get(all.size() - 1);
            colHost = d[0]; colPort = Integer.parseInt(d[1]); colHow = "not reachable now";
            showCollector("ic_cloud_off", Theme.onSurfaceVariant, "Collector not connected",
                    "Results save on this phone", true);
        }
    }

    private void updateCollectorFromSink(String sink) {
        if (sink == null || sink.isEmpty()) return;
        if ("connected".equals(sink)) {
            collectorOK = true;
            showCollector("ic_cloud_upload", Theme.primary, "Sending to collector",
                    "Results also save on this phone", false);
        } else if ("unreachable".equals(sink)) {
            collectorOK = false;
            showCollector("ic_cloud_off", Theme.onSurfaceVariant, "Collector not connected",
                    "Results save on this phone", true);
        }
    }

    private void agreeChanged() {
        boolean on = agree.isChecked() && catalogReady && !running;
        startBtn.setEnabled(on);
        if (!catalogReady) startBtn.setContentDescription("Start, loading tests");
        else if (!agree.isChecked()) startBtn.setContentDescription("Start, turn on I agree to share timings first");
        else startBtn.setContentDescription("Start");
    }

    private void setControlsEnabled(boolean en) {
        Theme.selectSegment(quickBtn, !fullPreset, en);
        Theme.selectSegment(fullBtn, fullPreset, en);
        libsRow.setEnabled(en);
        groupsRow.setEnabled(en);
    }

    private void setAgreeEnabled(boolean en) {
        agree.setEnabled(en);
        consentRow.setEnabled(en);
        shareBtn.setEnabled(true);
        shareBtn.setAlpha(1f);
    }

    private void startTapped() {
        if (!agree.isChecked() || !catalogReady || running) return;
        List<String> libs = new ArrayList<>(), secs = new ArrayList<>();
        for (Map.Entry<String, CompoundButton> e : libSw.entrySet()) if (e.getValue().isChecked()) libs.add(e.getKey());
        for (Map.Entry<String, CompoundButton> e : secSw.entrySet()) if (e.getValue().isChecked()) secs.add(e.getKey());
        if (libs.isEmpty() || secs.isEmpty()) {
            statusTitle.setText("Nothing picked");
            setBody("Turn on at least one library and group.");
            return;
        }
        try {
            boolean full = fullPreset;
            JSONObject cfg = new JSONObject();
            cfg.put("libraries", new JSONArray(libs));
            cfg.put("sections", new JSONArray(secs));
            cfg.put("rounds", full ? 3 : 1);
            cfg.put("samples", full ? 10 : 5);
            cfg.put("sample_ms", full ? 100 : 50);
            cfg.put("warm_ms", full ? 300 : 150);
            File out = host.getExternalFilesDir(null);
            if (out == null) out = host.getFilesDir();
            cfg.put("out_dir", out.getAbsolutePath());
            cfg.put("label", "android");
            if (colHost == null || colHost.isEmpty()) { String[] d = candidates().get(0); colHost = d[0]; colPort = Integer.parseInt(d[1]); }
            cfg.put("host", colHost); cfg.put("port", colPort);
            JSONObject env = new JSONObject();
            env.put("RIND_BENCH_KEYS_DIR", keysDir);
            cfg.put("env", env);
            if (Native.start(cfg.toString()) != 0) {
                statusTitle.setText("Could not start");
                setBody(new JSONObject(Native.status()).optString("start_error"));
                return;
            }
        } catch (Exception e) {
            statusTitle.setText("Could not start");
            setBody(String.valueOf(e));
            return;
        }
        Theme.haptic(startBtn, true);
        enterRunning();
    }

    /** Shows a run as going and polls it: one this view started, or one already going when it was made. */
    private void enterRunning() {
        host.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        startBtn.setVisibility(GONE);
        clearBtn.setVisibility(GONE);
        stopBtn.setVisibility(VISIBLE);
        stopBtn.setEnabled(true);
        setAgreeEnabled(false);
        running = true;
        setControlsEnabled(false);
        resultsTeaser.setVisibility(GONE);
        resultsBtn.setVisibility(GONE);
        progress.setMax(1);
        progress.setProgress(0);
        progress.setVisibility(VISIBLE);
        statusTitle.setText("Starting");
        setBody("Warming up…");
        findCollector();
        agreeChanged();
        ui.post(poll);
    }

    private void stopTapped() {
        Theme.haptic(stopBtn, false);
        Native.stop();
        stopBtn.setEnabled(false);
        statusTitle.setText("Stopping");
        setBody("Stops after the current test.");
    }

    private void clearTapped() {
        if (running) return;
        clearedRun = nativeStatus().optString("run_id", "");
        agree.setChecked(false);
        setAgreeEnabled(true);
        resultsTeaser.setText("");
        resultsTeaser.setVisibility(GONE);
        resultsText = "";
        resultsBtn.setVisibility(GONE);
        clearBtn.setVisibility(GONE);
        startBtn.setVisibility(VISIBLE);
        stopBtn.setVisibility(GONE);
        setControlsEnabled(true);
        progress.setProgress(0);
        progress.setVisibility(GONE);
        statusTitle.setText("Ready");
        setBody("");
        agreeChanged();
        findCollector();
    }

    private static JSONObject nativeStatus() {
        try {
            return new JSONObject(Native.status());
        } catch (Exception e) {
            return new JSONObject();
        }
    }

    /** The activity's onStart and onStop. */
    void setOnScreen(boolean on) {
        onScreen = on;
    }

    /** Stops polling, for the activity's onDestroy: a recreated activity's new view picks the run up. */
    void dispose() {
        ui.removeCallbacksAndMessages(null);
    }

    private boolean isWarm() {
        if (android.os.Build.VERSION.SDK_INT < 29) return false;
        int t = ((android.os.PowerManager) host.getSystemService(Context.POWER_SERVICE)).getCurrentThermalStatus();
        return t >= android.os.PowerManager.THERMAL_STATUS_SEVERE;
    }

    private void poll() {
        if (!running) return;
        try {
            JSONObject s = new JSONObject(Native.status());
            boolean still = s.optBoolean("running");
            running = still;
            int done = s.optInt("done"), total = Math.max(1, s.optInt("total"));
            progress.setMax(total);
            progress.setProgress(still ? done : (done > 0 ? total : 0));
            progress.setContentDescription("Run progress, " + (still ? done : (done > 0 ? total : 0)) + " of " + total);
            updateCollectorFromSink(s.optString("sink"));
            if (still) {
                statusTitle.setText("Running " + s.optInt("round") + " of " + s.optInt("rounds"));
                String cur = s.optString("current", "");
                String warm = isWarm() ? " (warm)" : "";
                setBody(done + " of " + total + (cur.isEmpty() ? "" : " · " + cur) + warm);
            } else {
                showFinished(s, true);
                return;
            }
            renderResults(s.optJSONObject("results"));
        } catch (Exception e) {
            setBody("Status error.");
        }
        ui.postDelayed(poll, 1000);
    }

    /** A finished run's state: as poll sees it end, or as a recreated view finds it. */
    private void showFinished(JSONObject s, boolean justEnded) {
        running = false;
        boolean stopped = s.optBoolean("stopped");
        if (justEnded) Theme.haptic(statusCard, !stopped);
        statusTitle.setText(stopped ? "Stopped" : "Done");
        int errs = s.optInt("errors");
        String errTxt = errs > 0 ? " (" + errs + " errors)" : "";
        setBody(String.format(Locale.US, "%d tests in %.0f s%s",
                s.optInt("done"), s.optDouble("elapsed_s", 0), errTxt));
        int total = Math.max(1, s.optInt("total"));
        progress.setMax(total);
        progress.setProgress(s.optInt("done") > 0 ? total : 0);
        progress.setVisibility(VISIBLE);
        try {
            renderResults(s.optJSONObject("results"));
        } catch (Exception e) {
            setBody("Status error.");
        }
        host.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        startBtn.setVisibility(VISIBLE);
        stopBtn.setVisibility(GONE);
        clearBtn.setVisibility(VISIBLE);
        setAgreeEnabled(true);
        setControlsEnabled(true);
        agreeChanged();
    }

    private void renderResults(JSONObject res) throws Exception {
        if (res == null) return;
        Map<String, Map<String, Double>> byOp = new TreeMap<>();
        List<String> errs = new ArrayList<>();
        for (Iterator<String> it = res.keys(); it.hasNext(); ) {
            String id = it.next();
            JSONObject r = res.getJSONObject(id);
            if ("error".equals(r.optString("t"))) { errs.add("ERROR " + id + ": " + r.optString("error")); continue; }
            String op = r.isNull("op") ? id : r.optString("op", id);
            String lib = r.isNull("library") ? "?" : r.optString("library", "?");
            byOp.computeIfAbsent(op, k -> new TreeMap<>()).put(lib, r.optDouble("ns"));
        }
        StringBuilder out = new StringBuilder();
        for (Map.Entry<String, Map<String, Double>> e : byOp.entrySet()) {
            Double rind = e.getValue().get("rind");
            out.append(e.getKey().replace("/{lib}", "")).append('\n');
            for (Map.Entry<String, Double> l : e.getValue().entrySet()) {
                out.append(String.format(Locale.US, "   %-16s %12s", l.getKey(), fmt(l.getValue())));
                if (rind != null && !"rind".equals(l.getKey()))
                    out.append(String.format(Locale.US, "   rind %.2fx", rind / l.getValue()));
                out.append('\n');
            }
        }
        for (String e : errs) out.append(e).append('\n');
        resultsText = out.toString();
        if (!byOp.isEmpty()) {
            StringBuilder tease = new StringBuilder();
            int show = Math.min(byOp.size(), 4), i = 0;
            for (Map.Entry<String, Map<String, Double>> e : byOp.entrySet()) {
                if (i++ >= show) break;
                Double rind = e.getValue().get("rind");
                tease.append(e.getKey().replace("/{lib}", "")).append("  ").append(rind == null ? "-" : fmt(rind)).append('\n');
            }
            if (byOp.size() > 4) tease.append("+").append(byOp.size() - 4).append(" more");
            resultsTeaser.setText(tease.toString().trim());
            resultsTeaser.setVisibility(VISIBLE);
            resultsBtn.setVisibility(VISIBLE);
        }
    }

    private static String fmt(double ns) {
        if (ns >= 1e6) return String.format(Locale.US, "%.3f ms", ns / 1e6);
        if (ns >= 1e3) return String.format(Locale.US, "%.3f µs", ns / 1e3);
        return String.format(Locale.US, "%.1f ns", ns);
    }

    private String copyKeys() {
        File dst = new File(host.getFilesDir(), "keys");
        try {
            String[] dirs = host.getAssets().list("keys");
            if (dirs == null) return dst.getAbsolutePath();
            for (String dir : dirs) {
                File d = new File(dst, dir);
                d.mkdirs();
                String[] files = host.getAssets().list("keys/" + dir);
                if (files == null) continue;
                for (String f : files) {
                    try (java.io.InputStream in = host.getAssets().open("keys/" + dir + "/" + f);
                         java.io.OutputStream out = new java.io.FileOutputStream(new File(d, f))) {
                        byte[] buf = new byte[8192];
                        int n;
                        while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
                    }
                }
            }
        } catch (Exception ignored) {}
        return dst.getAbsolutePath();
    }

    private LinearLayout listSection(String title, List<View> rows, String empty) {
        LinearLayout s = new LinearLayout(host);
        s.setOrientation(VERTICAL);
        if (title != null) {
            TextView h = Theme.subheader(host, title);
            h.setPaddingRelative(Theme.dpi(host, 24), Theme.dpi(host, 16), Theme.dpi(host, 24), Theme.dpi(host, 4));
            s.addView(h);
        }
        if (rows.isEmpty()) s.addView(Sheet.body(host, empty, false));
        else for (View r : rows) { detach(r); s.addView(r); }
        return s;
    }

    private void openLibraries() { Sheet.show(host, "Libraries", listSection(null, libRows, "No libraries found.")); }

    private void openGroups() {
        LinearLayout s = new LinearLayout(host);
        s.setOrientation(VERTICAL);
        s.addView(listSection("Default groups", groupRows, "None."));
        s.addView(listSection("More groups, off by default", moreRows, "None."));
        Sheet.show(host, "Groups", s);
    }

    private void openShare() {
        Sheet.show(host, "What's shared", Sheet.body(host,
                "When you agree and tap Start, this app runs CPU tests that warm your phone.\n\n"
                + "It sends only timings plus your phone model, chip, system version, and CPU features to the collector. "
                + "It never sends your name, account, serial number, or location.\n\n"
                + "Results always save on this phone too, and you can tap Stop anytime.", false));
    }

    void openDetails() {
        String col = (colHost == null || colHost.isEmpty()) ? "None" : (colHost + ":" + colPort + " (" + colHow + ")");
        Sheet.show(host, "Details", Sheet.body(host, detailsText + "\nCollector: " + col, true));
    }

    private void openResults() {
        // Results are a table: keep columns aligned and scroll sideways instead of wrapping.
        TextView tv = Sheet.body(host, resultsText.isEmpty() ? "No results yet." : resultsText, true);
        Theme.type(tv, Theme.Type.BODY_SMALL);
        tv.setTypeface(Typeface.MONOSPACE);
        tv.setHorizontallyScrolling(false);
        tv.setContentDescription("Results");
        android.widget.HorizontalScrollView h = new android.widget.HorizontalScrollView(host);
        h.addView(tv, new android.widget.HorizontalScrollView.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT));
        Sheet.show(host, "Results", h);
    }
}
