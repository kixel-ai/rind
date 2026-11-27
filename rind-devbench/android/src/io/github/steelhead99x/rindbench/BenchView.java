package io.github.steelhead99x.rindbench;

import android.app.Activity;
import android.app.Dialog;
import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Typeface;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.LinearLayout;
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

/** Bench page: fills the remaining height, no page scroll, plain short copy. */
final class BenchView extends LinearLayout {
    private final Activity host;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final LinearLayout colL, colR, page;
    private TextView timingHint, agreeL, startHint, collectorTitle, collectorAddr, collectorNote;
    private TextView statusTitle, statusLbl, resultsTeaser;
    private View collectorDot;
    private LinearLayout collectorCard, runCard, statusCard;
    private Button quickBtn, fullBtn;
    private boolean fullPreset;
    private Switch agree;
    private Button startBtn, stopBtn, clearBtn, libsBtn, groupsBtn, shareBtn, retryBtn, resultsBtn;
    private SegBar progress;
    private boolean running, collectorOK, catalogReady;
    private JSONObject catalog;
    private final Map<String, Switch> libSw = new LinkedHashMap<>();
    private final Map<String, Switch> secSw = new LinkedHashMap<>();
    private final List<View> libRows = new ArrayList<>(), groupRows = new ArrayList<>(), moreRows = new ArrayList<>();
    private String resultsText = "";
    private String detailsText = "Loading device and build details...";
    private String keysDir, colHost;
    private int colPort = Collector.PORT;
    private String colHow = "";
    private final Runnable poll = this::poll;

    BenchView(Activity host, Intent intent) {
        super(host);
        this.host = host;
        setOrientation(VERTICAL);
        setBackgroundColor(Theme.INK);
        setContentDescription("Bench page");

        page = new LinearLayout(host);
        colL = new LinearLayout(host);
        colR = new LinearLayout(host);
        colL.setOrientation(VERTICAL);
        colR.setOrientation(VERTICAL);
        page.addView(colL, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT));
        page.addView(colR, new LayoutParams(LayoutParams.MATCH_PARENT, 0, 1));
        addView(page, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
        int pad = Theme.dpi(host, 16);
        page.setPadding(pad, Theme.dpi(host, 4), pad, Theme.dpi(host, 8));

        // Collector card
        collectorCard = Theme.card(host, Theme.LINE, 14, 10);
        LinearLayout dotRow = new LinearLayout(host);
        dotRow.setOrientation(HORIZONTAL);
        dotRow.setGravity(Gravity.CENTER_VERTICAL);
        collectorDot = new View(host);
        int d = Theme.dpi(host, 12);
        LinearLayout.LayoutParams dlp = new LinearLayout.LayoutParams(d, d);
        dlp.rightMargin = Theme.dpi(host, 8);
        collectorDot.setLayoutParams(dlp);
        collectorDot.setBackground(oval(Theme.MUTED));
        collectorDot.setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);
        collectorTitle = Theme.label(host, "Checking collector...", 18, 24, Theme.TEXT, Typeface.BOLD, 1);
        collectorAddr = Theme.label(host, "", 16, 20, Theme.TEXT, Typeface.BOLD, 1);
        collectorAddr.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        dotRow.addView(collectorDot);
        dotRow.addView(collectorTitle, new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1));
        dotRow.addView(collectorAddr);
        collectorCard.addView(dotRow);

        space(collectorCard, 6);
        LinearLayout noteRow = new LinearLayout(host);
        noteRow.setOrientation(HORIZONTAL);
        noteRow.setGravity(Gravity.CENTER_VERTICAL);
        collectorNote = Theme.label(host, "Results also save on this phone.", 16, 20, Theme.MUTED, Typeface.NORMAL, 1);
        collectorNote.setEllipsize(TextUtils.TruncateAt.END);
        retryBtn = Theme.chip(host, "Retry");
        retryBtn.setContentDescription("Retry collector connection");
        retryBtn.setOnClickListener(v -> findCollector());
        retryBtn.setVisibility(GONE);
        noteRow.addView(collectorNote, new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1));
        noteRow.addView(retryBtn);
        collectorCard.addView(noteRow);
        LayoutParams ccLp = new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT);
        ccLp.bottomMargin = Theme.dpi(host, 8);
        colL.addView(collectorCard, ccLp);

        // Run controls card
        runCard = Theme.card(host, Theme.LINE, 14, 12);
        LinearLayout segWrap = new LinearLayout(host);
        segWrap.setOrientation(HORIZONTAL);
        segWrap.setBackground(Theme.segmentedBg(host));
        int sp = Theme.dpi(host, 3);
        segWrap.setPadding(sp, sp, sp, sp);
        segWrap.setContentDescription("Test length");
        quickBtn = segButton("Quick test");
        fullBtn = segButton("Full test");
        quickBtn.setOnClickListener(v -> { if (!running) { fullPreset = false; presetChanged(); } });
        fullBtn.setOnClickListener(v -> { if (!running) { fullPreset = true; presetChanged(); } });
        LayoutParams qLp = new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1);
        qLp.rightMargin = sp;
        segWrap.addView(quickBtn, qLp);
        segWrap.addView(fullBtn, new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1));

        timingHint = Theme.label(host, "", 16, 20, Theme.MUTED, Typeface.NORMAL, 1);
        timingHint.setEllipsize(TextUtils.TruncateAt.END);

        libsBtn = Theme.chip(host, "Libraries");
        libsBtn.setContentDescription("Libraries. Choose which libraries to test.");
        libsBtn.setOnClickListener(v -> openLibraries());
        groupsBtn = Theme.chip(host, "Groups");
        groupsBtn.setContentDescription("Groups. Choose which test groups to run.");
        groupsBtn.setOnClickListener(v -> openGroups());
        LinearLayout customize = new LinearLayout(host);
        customize.setOrientation(HORIZONTAL);
        LayoutParams hp = new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1);
        hp.rightMargin = Theme.dpi(host, 8);
        customize.addView(libsBtn, hp);
        customize.addView(groupsBtn, new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1));

        agree = new Switch(host);
        agree.setThumbTintList(Theme.peelSwitch());
        agree.setTrackTintList(Theme.peelSwitch());
        agree.setContentDescription("I agree to share timings");
        Theme.minTarget(agree, 48);
        agree.setOnCheckedChangeListener((v, on) -> agreeChanged());
        agreeL = Theme.label(host, "I agree to share timings", 16, 22, Theme.TEXT, Typeface.BOLD, 2);
        shareBtn = Theme.chip(host, "What's shared");
        shareBtn.setContentDescription("What's shared. Opens the list of what is sent.");
        shareBtn.setOnClickListener(v -> openShare());
        LinearLayout agreeRow = new LinearLayout(host);
        agreeRow.setOrientation(HORIZONTAL);
        agreeRow.setGravity(Gravity.CENTER_VERTICAL);
        agreeRow.setMinimumHeight(Theme.dpi(host, 48));
        LayoutParams as = new LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT);
        as.rightMargin = Theme.dpi(host, 8);
        agreeRow.addView(agree, as);
        LayoutParams al = new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1);
        al.rightMargin = Theme.dpi(host, 8);
        agreeRow.addView(agreeL, al);
        agreeRow.addView(shareBtn, new LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT));
        agreeL.setOnClickListener(v -> { if (agree.isEnabled()) agree.toggle(); });

        startBtn = Theme.primary(host, "Start");
        startBtn.setEnabled(false);
        Theme.styleButton(startBtn, true, false);
        startBtn.setOnClickListener(v -> startTapped());
        stopBtn = Theme.secondary(host, "Stop");
        stopBtn.setOnClickListener(v -> stopTapped());
        stopBtn.setVisibility(GONE);
        clearBtn = Theme.secondary(host, "Clear");
        clearBtn.setOnClickListener(v -> clearTapped());
        clearBtn.setVisibility(GONE);
        LinearLayout action = new LinearLayout(host);
        action.setOrientation(HORIZONTAL);
        LayoutParams ap = new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1);
        LayoutParams cp = new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1);
        cp.leftMargin = Theme.dpi(host, 10);
        action.addView(startBtn, ap);
        action.addView(stopBtn, new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1));
        action.addView(clearBtn, cp);

        startHint = Theme.label(host, "Turn on I agree to start.", 16, 20, Theme.GOLD, Typeface.BOLD, 1);
        startHint.setEllipsize(TextUtils.TruncateAt.END);
        startHint.setContentDescription("Turn on I agree to start.");

        runCard.addView(segWrap);
        space(runCard, 8);
        runCard.addView(timingHint);
        space(runCard, 8);
        runCard.addView(customize);
        space(runCard, 8);
        runCard.addView(agreeRow);
        space(runCard, 8);
        runCard.addView(action);
        space(runCard, 6);
        runCard.addView(startHint);
        colL.addView(runCard);
        space(colL, 8);

        // Status card: expands to fill remaining height with no dead space.
        statusCard = Theme.card(host, Theme.LINE, 14, 12);
        statusTitle = Theme.label(host, "Ready", 20, 26, Theme.TEXT, Typeface.BOLD, 1);
        progress = new SegBar(host);
        statusLbl = Theme.label(host, "Pick Quick or Full, then tap Start.", 16, 22, Theme.TEXT, Typeface.NORMAL, 1);
        statusLbl.setEllipsize(TextUtils.TruncateAt.END);
        resultsTeaser = Theme.label(host, "", 15, 20, Theme.TEXT, Typeface.NORMAL, 0);
        resultsTeaser.setTypeface(Typeface.MONOSPACE);
        resultsBtn = Theme.chip(host, "View results");
        resultsBtn.setContentDescription("View results. Opens the full results list.");
        resultsBtn.setOnClickListener(v -> openResults());
        resultsBtn.setVisibility(GONE);
        resultsTeaser.setVisibility(GONE);

        statusCard.addView(statusTitle);
        space(statusCard, 8);
        statusCard.addView(progress, new LayoutParams(LayoutParams.MATCH_PARENT, Theme.dpi(host, 24)));
        space(statusCard, 8);
        statusCard.addView(statusLbl);
        LayoutParams teaseLp = new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT);
        teaseLp.topMargin = Theme.dpi(host, 8);
        statusCard.addView(resultsTeaser, teaseLp);
        LayoutParams resLp = new LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT);
        resLp.topMargin = Theme.dpi(host, 8);
        statusCard.addView(resultsBtn, resLp);
        statusCard.addView(new View(host), new LayoutParams(LayoutParams.MATCH_PARENT, 0, 1));

        colR.addView(statusCard, new LayoutParams(LayoutParams.MATCH_PARENT, 0, 1));

        onChromeRelayout();
        presetChanged();
        applyIntent(intent);
        findCollector();
        ui.postDelayed(() -> { if (!running && !collectorOK) findCollector(); }, 4000);
        new Thread(() -> {
            keysDir = copyKeys();
            Native.setenv("RIND_BENCH_KEYS_DIR", keysDir);
            String cat = Native.catalog();
            ui.post(() -> loaded(cat, intent));
        }, "devbench-catalog").start();
    }

    void onChromeRelayout() {
        boolean land = getResources().getConfiguration().orientation == Configuration.ORIENTATION_LANDSCAPE
                && getResources().getDisplayMetrics().widthPixels > getResources().getDisplayMetrics().heightPixels;
        page.setOrientation(land ? HORIZONTAL : VERTICAL);
        LayoutParams lpL = (LayoutParams) colL.getLayoutParams();
        LayoutParams lpR = (LayoutParams) colR.getLayoutParams();
        if (land) {
            lpL.width = 0; lpL.height = LayoutParams.MATCH_PARENT; lpL.weight = 1; lpL.rightMargin = Theme.dpi(host, 12);
            lpR.width = 0; lpR.height = LayoutParams.MATCH_PARENT; lpR.weight = 1;
        } else {
            lpL.width = LayoutParams.MATCH_PARENT; lpL.height = LayoutParams.WRAP_CONTENT; lpL.weight = 0; lpL.rightMargin = 0;
            lpR.width = LayoutParams.MATCH_PARENT; lpR.height = 0; lpR.weight = 1;
        }
        colL.setLayoutParams(lpL);
        colR.setLayoutParams(lpR);
        // In landscape the collector card sits on top of the status column, so the
        // run controls (consent and Start) get the whole left column. On a phone
        // (about 400dp tall) both cards in one column squeezed Start to a sliver.
        LinearLayout want = land ? colR : colL;
        if (collectorCard.getParent() != want) {
            ((LinearLayout) collectorCard.getParent()).removeView(collectorCard);
            want.addView(collectorCard, 0);
        }
    }

    void applyIntent(Intent it) {
        if (it == null) return;
        // The launcher is exported, so any app can send these extras. Only a
        // device-runner build (build-apk.sh with DEVICE_RUNNER=1) takes a collector
        // or autostart from them; the other extras only preselect the picker.
        if (Collector.RUNNER && it.hasExtra("host")) {
            colHost = it.getStringExtra("host");
            colPort = it.getIntExtra("port", Collector.PORT);
            colHow = "set by adb";
        }
        if ("full".equals(it.getStringExtra("preset"))) { fullPreset = true; presetChanged(); }
        if ("quick".equals(it.getStringExtra("preset"))) { fullPreset = false; presetChanged(); }
    }

    private Button segButton(String title) {
        Button b = new Button(host, null, android.R.attr.borderlessButtonStyle);
        b.setText(title);
        b.setAllCaps(false);
        b.setMinHeight(Theme.dpi(host, 44));
        b.setMinimumHeight(Theme.dpi(host, 44));
        b.setPadding(Theme.dpi(host, 10), Theme.dpi(host, 6), Theme.dpi(host, 10), Theme.dpi(host, 6));
        b.setSingleLine(true);
        if (android.os.Build.VERSION.SDK_INT >= 26) {
            b.setAutoSizeTextTypeUniformWithConfiguration(14, 17, 1, android.util.TypedValue.COMPLEX_UNIT_SP);
        } else {
            b.setTextSize(android.util.TypedValue.COMPLEX_UNIT_PX, Theme.sp(host, 16, 20));
        }
        b.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
        return b;
    }

    private static android.graphics.drawable.GradientDrawable oval(int color) {
        android.graphics.drawable.GradientDrawable g = new android.graphics.drawable.GradientDrawable();
        g.setShape(android.graphics.drawable.GradientDrawable.OVAL);
        g.setColor(color);
        return g;
    }

    private static void space(LinearLayout root, int dp) {
        View v = new View(root.getContext());
        root.addView(v, new LayoutParams(LayoutParams.MATCH_PARENT, Theme.dpi(root.getContext(), dp)));
    }

    private void presetChanged() {
        boolean full = fullPreset;
        Theme.styleSegment(quickBtn, !full, !running);
        Theme.styleSegment(fullBtn, full, !running);
        quickBtn.setContentDescription("Quick test" + (!full ? ", selected" : ""));
        fullBtn.setContentDescription("Full test" + (full ? ", selected" : ""));
        timingHint.setText(full ? "3 rounds, 10 × 100 ms, 300 ms warm-up" : "1 round, 5 × 50 ms, 150 ms warm-up");
    }

    private void countsChanged() {
        int lon = 0, gon = 0, mon = 0, mall = 0, gall = 0;
        for (Switch s : libSw.values()) if (s.isChecked()) lon++;
        for (Map.Entry<String, Switch> e : secSw.entrySet()) {
            if (e.getKey().startsWith("More: ")) { mall++; if (e.getValue().isChecked()) mon++; }
            else { gall++; if (e.getValue().isChecked()) gon++; }
        }
        libsBtn.setText("Libraries " + lon + "/" + libSw.size());
        groupsBtn.setText(mon > 0
                ? ("Groups " + gon + "/" + gall + " +" + mon)
                : ("Groups " + gon + "/" + gall));
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
                libRows.add(switchRow(l + " (" + lc.getOrDefault(l, 0) + ")", on, true, libSw, l));
            }
            for (int i = 0; i < secs.length(); i++) {
                String s = secs.getString(i);
                int n = sc.getOrDefault(s, 0);
                boolean on = n > 0 && (wantSecs.isEmpty() ? !s.startsWith("More: ") : wantSecs.contains(s));
                View row = switchRow(s + " (" + n + ")", on, n > 0, secSw, s);
                if (s.startsWith("More: ")) moreRows.add(row); else groupRows.add(row);
            }
            if (!running && resultsText.isEmpty()) {
                statusTitle.setText("Ready");
                statusLbl.setText("Pick Quick or Full, then tap Start.");
            }
        } catch (Exception e) {
            statusLbl.setText("Could not load tests.");
        }
        countsChanged();
        agreeChanged();
        if (Collector.RUNNER && intent != null && intent.getBooleanExtra("autostart", false)) {
            agree.setChecked(true);
            startTapped();
        }
    }

    private static java.util.Set<String> csv(String s) {
        java.util.Set<String> out = new java.util.LinkedHashSet<>();
        if (s != null) for (String p : s.split(",")) if (!p.trim().isEmpty()) out.add(p.trim());
        return out;
    }

    private View switchRow(String title, boolean on, boolean en, Map<String, Switch> dict, String key) {
        LinearLayout row = new LinearLayout(host);
        row.setOrientation(HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setMinimumHeight(Theme.dpi(host, 48));
        Switch sw = new Switch(host);
        sw.setChecked(on);
        sw.setEnabled(en);
        sw.setThumbTintList(Theme.peelSwitch());
        sw.setTrackTintList(Theme.peelSwitch());
        sw.setContentDescription(title);
        sw.setOnCheckedChangeListener((v, c) -> countsChanged());
        Theme.minTarget(sw, 48);
        dict.put(key, sw);
        TextView l = Theme.label(host, title, 16, 22, en ? Theme.TEXT : Theme.MUTED, Typeface.NORMAL, 1);
        l.setEllipsize(TextUtils.TruncateAt.END);
        LayoutParams sl = new LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT);
        sl.rightMargin = Theme.dpi(host, 10);
        row.addView(sw, sl);
        row.addView(l, new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1));
        l.setOnClickListener(v -> { if (sw.isEnabled()) sw.toggle(); });
        return row;
    }

    private java.util.List<String[]> candidates() {
        java.util.List<String[]> c = new ArrayList<>();
        if (colHost != null && !colHost.isEmpty() && "set by adb".equals(colHow))
            c.add(new String[]{colHost, String.valueOf(colPort), "set by adb"});
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

    private void applyCollector(String[] h) {
        if (h != null) {
            colHost = h[0]; colPort = Integer.parseInt(h[1]); colHow = h[2];
            collectorOK = true;
            collectorTitle.setText("Connected");
            collectorTitle.setTextColor(Theme.PEEL);
            collectorDot.setBackground(oval(Theme.PEEL));
            collectorAddr.setText(colHost + ":" + colPort);
            collectorNote.setText(("over USB".equals(colHow) ? "USB ready." : "Collector ready.") + " Saves on phone too.");
            Theme.setCardAccent(collectorCard, Theme.PEEL_MID);
            retryBtn.setVisibility(GONE);
            collectorCard.setContentDescription("Collector connected at " + colHost + ":" + colPort);
        } else {
            collectorOK = false;
            String[] d = candidates().get(candidates().size() - 1);
            colHost = d[0]; colPort = Integer.parseInt(d[1]); colHow = "not reachable now";
            collectorTitle.setText("Not connected");
            collectorTitle.setTextColor(Theme.HIT);
            collectorDot.setBackground(oval(Theme.HIT));
            collectorAddr.setText(colHost + ":" + colPort);
            collectorNote.setText("Results still save on this phone.");
            Theme.setCardAccent(collectorCard, Theme.HIT);
            retryBtn.setVisibility(VISIBLE);
            collectorCard.setContentDescription("Collector not connected at " + colHost + ":" + colPort);
        }
    }

    private void updateCollectorFromSink(String sink) {
        if (sink == null || sink.isEmpty()) return;
        if ("connected".equals(sink)) {
            collectorOK = true;
            collectorTitle.setText("Sending");
            collectorTitle.setTextColor(Theme.PEEL);
            collectorDot.setBackground(oval(Theme.PEEL));
            collectorNote.setText("Saving here and to collector.");
            Theme.setCardAccent(collectorCard, Theme.PEEL_MID);
            retryBtn.setVisibility(GONE);
        } else if ("unreachable".equals(sink)) {
            collectorOK = false;
            collectorTitle.setText("Not connected");
            collectorTitle.setTextColor(Theme.HIT);
            collectorDot.setBackground(oval(Theme.HIT));
            collectorNote.setText("Results save on this phone.");
            Theme.setCardAccent(collectorCard, Theme.HIT);
            retryBtn.setVisibility(VISIBLE);
        }
    }

    private void agreeChanged() {
        boolean on = agree.isChecked() && catalogReady && !running;
        startBtn.setEnabled(on);
        Theme.styleButton(startBtn, true, on);
        if (running) startHint.setText("Tap Stop to quit after this test.");
        else if (!catalogReady) startHint.setText("Loading tests...");
        else if (!agree.isChecked()) startHint.setText("Turn on I agree to start.");
        else startHint.setText("Ready to start.");
        startHint.setTextColor(on ? Theme.PEEL : Theme.GOLD);
        startHint.setContentDescription(startHint.getText());
    }

    private void startTapped() {
        if (!agree.isChecked() || !catalogReady || running) return;
        List<String> libs = new ArrayList<>(), secs = new ArrayList<>();
        for (Map.Entry<String, Switch> e : libSw.entrySet()) if (e.getValue().isChecked()) libs.add(e.getKey());
        for (Map.Entry<String, Switch> e : secSw.entrySet()) if (e.getValue().isChecked()) secs.add(e.getKey());
        if (libs.isEmpty() || secs.isEmpty()) {
            statusTitle.setText("Nothing picked");
            statusLbl.setText("Turn on at least one library and group.");
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
                statusLbl.setText(new JSONObject(Native.status()).optString("start_error"));
                return;
            }
        } catch (Exception e) {
            statusTitle.setText("Could not start");
            statusLbl.setText(String.valueOf(e));
            return;
        }
        Theme.haptic(startBtn, true);
        host.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        startBtn.setVisibility(GONE);
        clearBtn.setVisibility(GONE);
        stopBtn.setVisibility(VISIBLE);
        stopBtn.setEnabled(true);
        Theme.styleButton(stopBtn, false, true);
        agree.setEnabled(false);
        running = true;
        Theme.styleSegment(quickBtn, !fullPreset, false); Theme.styleSegment(fullBtn, fullPreset, false);
        libsBtn.setEnabled(false); groupsBtn.setEnabled(false);
        resultsTeaser.setVisibility(GONE);
        resultsBtn.setVisibility(GONE);
        statusTitle.setText("Starting");
        statusLbl.setText("Warming up...");
        findCollector();
        agreeChanged();
        ui.post(poll);
    }

    private void stopTapped() {
        Theme.haptic(stopBtn, false);
        Native.stop();
        stopBtn.setEnabled(false);
        Theme.styleButton(stopBtn, false, false);
        statusTitle.setText("Stopping");
        statusLbl.setText("Stopping after this test...");
    }

    private void clearTapped() {
        if (running) return;
        agree.setChecked(false);
        agree.setEnabled(true);
        resultsTeaser.setText("");
        resultsTeaser.setVisibility(GONE);
        resultsText = "";
        resultsBtn.setVisibility(GONE);
        clearBtn.setVisibility(GONE);
        startBtn.setText("Start");
        startBtn.setVisibility(VISIBLE);
        stopBtn.setVisibility(GONE);
        Theme.styleSegment(quickBtn, !fullPreset, true); Theme.styleSegment(fullBtn, fullPreset, true);
        libsBtn.setEnabled(true); groupsBtn.setEnabled(true);
        progress.setProgress(0, 24, false);
        Theme.setCardAccent(statusCard, Theme.LINE);
        statusTitle.setText("Ready");
        statusLbl.setText("Pick Quick or Full, then tap Start.");
        agreeChanged();
        findCollector();
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
            progress.setProgress(still ? (int) Math.floor(24.0 * done / total) : (done > 0 ? 24 : 0), 24, still);
            updateCollectorFromSink(s.optString("sink"));
            if (still) {
                statusTitle.setText("Running " + s.optInt("round") + " of " + s.optInt("rounds"));
                String cur = s.optString("current", "");
                String warm = isWarm() ? " (warm)" : "";
                statusLbl.setText(done + " of " + total + (cur.isEmpty() ? "" : " · " + cur) + warm);
                Theme.setCardAccent(statusCard, Theme.GOLD);
            } else {
                boolean stopped = s.optBoolean("stopped");
                Theme.haptic(statusCard, !stopped);
                statusTitle.setText(stopped ? "Stopped" : "Done");
                int errs = s.optInt("errors");
                String errTxt = errs > 0 ? " (" + errs + " errors)" : "";
                statusLbl.setText(String.format(Locale.US, "%d tests in %.0f s%s",
                        s.optInt("done"), s.optDouble("elapsed_s", 0), errTxt));
                Theme.setCardAccent(statusCard, stopped ? Theme.GOLD : Theme.PEEL);
            }
            renderResults(s.optJSONObject("results"));
            if (!still) {
                host.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                startBtn.setVisibility(VISIBLE);
                startBtn.setText("Start");
                stopBtn.setVisibility(GONE);
                clearBtn.setVisibility(VISIBLE);
                agree.setEnabled(true);
                Theme.styleSegment(quickBtn, !fullPreset, true); Theme.styleSegment(fullBtn, fullPreset, true);
                libsBtn.setEnabled(true); groupsBtn.setEnabled(true);
                agreeChanged();
                return;
            }
        } catch (Exception e) {
            statusLbl.setText("Status error.");
        }
        ui.postDelayed(poll, 1000);
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

    private void presentSheet(String title, View content) {
        Dialog d = new Dialog(host, android.R.style.Theme_DeviceDefault_NoActionBar);
        LinearLayout box = new LinearLayout(host);
        box.setOrientation(VERTICAL);
        box.setBackgroundColor(Theme.INK);
        int pad = Theme.dpi(host, 16);
        box.setPadding(pad, pad + Theme.dpi(host, 12), pad, pad);
        box.setOnApplyWindowInsetsListener((v, insets) -> {
            if (android.os.Build.VERSION.SDK_INT >= 30) {
                android.graphics.Insets s = insets.getInsets(android.view.WindowInsets.Type.systemBars());
                v.setPadding(pad + s.left, pad + s.top, pad + s.right, pad + s.bottom);
            } else {
                v.setPadding(pad + insets.getSystemWindowInsetLeft(), pad + insets.getSystemWindowInsetTop(),
                        pad + insets.getSystemWindowInsetRight(), pad + insets.getSystemWindowInsetBottom());
            }
            return insets;
        });
        LinearLayout top = new LinearLayout(host);
        top.setOrientation(HORIZONTAL);
        top.setGravity(Gravity.CENTER_VERTICAL);
        TextView t = Theme.label(host, title, 24, 32, Theme.TEXT, Typeface.BOLD, 1);
        t.setAccessibilityHeading(true);
        top.addView(t, new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1));
        Button done = Theme.chip(host, "Done");
        done.setOnClickListener(v -> d.dismiss());
        top.addView(done);
        box.addView(top);
        space(box, 16);
        ScrollView sc = new ScrollView(host);
        if (content.getParent() instanceof ViewGroup) ((ViewGroup) content.getParent()).removeView(content);
        sc.addView(content, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT));
        box.addView(sc, new LayoutParams(LayoutParams.MATCH_PARENT, 0, 1));
        d.setContentView(box);
        d.show();
    }

    private LinearLayout sectionStack(String title, List<View> rows, String empty) {
        LinearLayout s = new LinearLayout(host);
        s.setOrientation(VERTICAL);
        s.addView(Theme.label(host, title, 18, 24, Theme.TEXT, Typeface.BOLD, 1));
        space(s, 10);
        if (rows.isEmpty()) s.addView(Theme.label(host, empty, 16, 22, Theme.MUTED, Typeface.NORMAL, 0));
        else for (View r : rows) {
            if (r.getParent() instanceof ViewGroup) ((ViewGroup) r.getParent()).removeView(r);
            s.addView(r);
            space(s, 8);
        }
        return s;
    }

    private void openLibraries() { presentSheet("Libraries", sectionStack("Libraries in this run", libRows, "No libraries found.")); }

    private void openGroups() {
        LinearLayout s = new LinearLayout(host);
        s.setOrientation(VERTICAL);
        s.addView(sectionStack("Default groups", groupRows, "None."));
        space(s, 18);
        s.addView(sectionStack("More groups (off by default)", moreRows, "None."));
        presentSheet("Groups", s);
    }

    private void openShare() {
        TextView t = Theme.label(host,
                "When you agree and tap Start, this app runs CPU tests that warm your phone.\n\n"
                + "It sends only timings plus your phone model, chip, system version, and CPU features to the collector. "
                + "It never sends your name, account, serial number, or location.\n\n"
                + "Results always save on this phone too, and you can tap Stop anytime.",
                16, 22, Theme.TEXT, Typeface.NORMAL, 0);
        presentSheet("What's shared", t);
    }

    void openDetails() {
        String col = (colHost == null || colHost.isEmpty()) ? "None" : (colHost + ":" + colPort + " (" + colHow + ")");
        TextView t = Theme.label(host, detailsText + "\nCollector: " + col,
                16, 22, Theme.TEXT, Typeface.NORMAL, 0);
        t.setTypeface(Typeface.MONOSPACE);
        presentSheet("Details", t);
    }

    private void openResults() {
        TextView tv = Theme.label(host, resultsText.isEmpty() ? "(no results yet)" : resultsText, 15, 20, Theme.TEXT, Typeface.NORMAL, 0);
        tv.setTypeface(Typeface.MONOSPACE);
        tv.setContentDescription("Results");
        presentSheet("Results", tv);
    }
}
