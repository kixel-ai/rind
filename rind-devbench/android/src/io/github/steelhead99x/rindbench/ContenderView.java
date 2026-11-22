package io.github.steelhead99x.rindbench;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.view.Gravity;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Switch;
import android.widget.TextView;


/** Contender is off until turned on and agreed. No network before that. */
final class ContenderView extends LinearLayout {
    static final int REQ_CAMERA = 71;
    static final int REQ_SCAN = 72;

    private final Handler ui = new Handler(Looper.getMainLooper());
    private final Activity host;
    private final ContenderClient client;
    private Switch enable, agree;
    private TextView statusTitle, statusBody;
    private LinearLayout statusCard, joinCard, sessionCard;
    private EditText codeField;
    private TextView sessionName, sessionPresenter, rankBody;
    private boolean enabledOn;

    ContenderView(Activity host) {
        super(host);
        this.host = host;
        setOrientation(VERTICAL);
        setBackgroundColor(Theme.INK);
        setContentDescription("Contender page");
        client = new ContenderClient(ContenderClient.DEFAULT_BASE);

        ScrollView scroll = new ScrollView(host);
        scroll.setFillViewport(true);
        LinearLayout root = new LinearLayout(host);
        root.setOrientation(VERTICAL);
        int pad = Theme.dpi(host, 16);
        root.setPadding(pad, Theme.dpi(host, 8), pad, Theme.dpi(host, 24));

        TextView title = Theme.label(host, "Contender", 28, 36, Theme.TEXT, Typeface.BOLD, 1);
        title.setAccessibilityHeading(true);
        TextView lead = Theme.label(host,
                "Join a live demo or talk, then wait for the presenter to start a run on this phone. Contender is off until you turn it on and agree. Nothing connects before that.",
                15, 22, Theme.MUTED, Typeface.NORMAL, 0);
        root.addView(title);
        space(root, 8);
        root.addView(lead);
        space(root, 12);

        enable = makeSwitch("Turn Contender on");
        enable.setOnCheckedChangeListener((v, on) -> enableChanged());
        LinearLayout enRow = switchRow(enable, Theme.label(host, "Turn Contender on", 16, 22, Theme.TEXT, Typeface.BOLD, 1));

        agree = makeSwitch("I agree to join a live session");
        agree.setEnabled(false);
        agree.setOnCheckedChangeListener((v, on) -> agreeChanged());
        LinearLayout agRow = switchRow(agree, Theme.label(host,
                "I agree  ·  join a session using only timings and a coarse model and chip. No device name, serial, UDID, or IP.",
                14, 20, Theme.TEXT, Typeface.NORMAL, 0));

        LinearLayout toggleCard = Theme.card(host, Theme.LINE);
        toggleCard.addView(enRow);
        space(toggleCard, 10);
        toggleCard.addView(agRow);
        root.addView(toggleCard);
        space(root, 12);

        statusTitle = Theme.label(host, "Contender is off", 17, 24, Theme.TEXT, Typeface.BOLD, 1);
        statusBody = Theme.label(host, "The session service is not contacted while this page is off.", 15, 22, Theme.MUTED, Typeface.NORMAL, 0);
        statusCard = Theme.card(host, Theme.LINE);
        statusCard.addView(statusTitle);
        space(statusCard, 8);
        statusCard.addView(statusBody);
        root.addView(statusCard);
        space(root, 12);

        TextView joinHead = Theme.label(host, "Join a session", 17, 24, Theme.TEXT, Typeface.BOLD, 1);
        TextView hint = Theme.label(host, "Type the session code, or scan the presenter's QR code.", 14, 20, Theme.MUTED, Typeface.NORMAL, 0);
        codeField = new EditText(host);
        codeField.setHint("Session code");
        codeField.setContentDescription("Session code");
        codeField.setTextColor(Theme.TEXT);
        codeField.setHintTextColor(Theme.MUTED);
        codeField.setBackground(Theme.cardBg(host, Theme.LINE));
        codeField.setPadding(Theme.dpi(host, 12), Theme.dpi(host, 12), Theme.dpi(host, 12), Theme.dpi(host, 12));
        codeField.setMinHeight(Theme.dpi(host, 48));
        codeField.setSingleLine(true);
        codeField.setInputType(android.text.InputType.TYPE_CLASS_TEXT | android.text.InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        codeField.setImeOptions(EditorInfo.IME_ACTION_GO);
        codeField.setOnEditorActionListener((v, a, e) -> { joinTapped(); return true; });

        Button scanBtn = Theme.secondary(host, "Scan QR code");
        scanBtn.setContentDescription("Scan QR code");
        scanBtn.setOnClickListener(v -> scanTapped());
        Button joinBtn = Theme.primary(host, "Join session");
        joinBtn.setOnClickListener(v -> joinTapped());
        LinearLayout joinBtns = new LinearLayout(host);
        joinBtns.setOrientation(HORIZONTAL);
        LinearLayout.LayoutParams hp = new LinearLayout.LayoutParams(0, LayoutParams.WRAP_CONTENT, 1);
        hp.rightMargin = Theme.dpi(host, 10);
        joinBtns.addView(scanBtn, hp);
        joinBtns.addView(joinBtn, new LinearLayout.LayoutParams(0, LayoutParams.WRAP_CONTENT, 1));

        joinCard = Theme.card(host, Theme.LINE);
        joinCard.addView(joinHead);
        space(joinCard, 10);
        joinCard.addView(hint);
        space(joinCard, 10);
        joinCard.addView(codeField);
        space(joinCard, 10);
        joinCard.addView(joinBtns);
        joinCard.setVisibility(GONE);
        root.addView(joinCard);
        space(root, 12);

        sessionName = Theme.label(host, "", 22, 30, Theme.TEXT, Typeface.BOLD, 2);
        sessionPresenter = Theme.label(host, "", 15, 22, Theme.MUTED, Typeface.NORMAL, 2);
        rankBody = Theme.label(host, "", 15, 22, Theme.TEXT, Typeface.NORMAL, 0);
        Button leaveBtn = Theme.secondary(host, "Leave session");
        leaveBtn.setOnClickListener(v -> leaveTapped());
        sessionCard = Theme.card(host, Theme.PEEL_MID);
        sessionCard.addView(Theme.eyebrow(host, "session"));
        space(sessionCard, 8);
        sessionCard.addView(sessionName);
        space(sessionCard, 8);
        sessionCard.addView(sessionPresenter);
        space(sessionCard, 8);
        sessionCard.addView(rankBody);
        space(sessionCard, 8);
        sessionCard.addView(leaveBtn);
        sessionCard.setVisibility(GONE);
        root.addView(sessionCard);
        space(root, 12);

        TextView foot = Theme.label(host,
                "Live talks use moq-bench.dev, which runs on moq.pro. This page does not invent a live connection when that service is not available.",
                12, 18, Theme.MUTED, Typeface.NORMAL, 0);
        root.addView(foot);

        scroll.addView(root, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT));
        addView(scroll, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
        refreshGate();
    }

    private Switch makeSwitch(String label) {
        Switch s = new Switch(host);
        s.setThumbTintList(Theme.peelSwitch());
        s.setTrackTintList(Theme.peelSwitch());
        s.setContentDescription(label);
        Theme.minTarget(s, 48);
        return s;
    }
    private LinearLayout switchRow(Switch s, TextView t) {
        LinearLayout row = new LinearLayout(host);
        row.setOrientation(HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setMinimumHeight(Theme.dpi(host, 48));
        LinearLayout.LayoutParams slp = new LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT);
        slp.rightMargin = Theme.dpi(host, 12);
        row.addView(s, slp);
        t.setLayoutParams(new LinearLayout.LayoutParams(0, LayoutParams.WRAP_CONTENT, 1));
        row.addView(t);
        t.setOnClickListener(v -> { if (s.isEnabled()) s.toggle(); });
        return row;
    }
    private static void space(LinearLayout root, int dp) {
        View v = new View(root.getContext());
        root.addView(v, new LayoutParams(LayoutParams.MATCH_PARENT, Theme.dpi(root.getContext(), dp)));
    }

    private void enableChanged() {
        if (!enable.isChecked()) {
            agree.setChecked(false);
            leaveTapped();
        }
        refreshGate();
        if (enable.isChecked() && agree.isChecked()) probe();
    }
    private void agreeChanged() {
        refreshGate();
        if (enable.isChecked() && agree.isChecked()) probe();
        else if (enable.isChecked() && !agree.isChecked()) {
            setStatus("Agree to connect", Theme.GOLD, "Turn on I agree to contact the session service. Nothing is sent until you do.", Theme.GOLD);
            joinCard.setVisibility(GONE);
        }
    }

    private void refreshGate() {
        agree.setEnabled(enable.isChecked());
        enabledOn = enable.isChecked() && agree.isChecked();
        joinCard.setVisibility((enabledOn && sessionCard.getVisibility() != VISIBLE) ? VISIBLE : GONE);
        if (!enable.isChecked()) {
            setStatus("Contender is off", Theme.TEXT, "The session service is not contacted while this page is off.", Theme.LINE);
            joinCard.setVisibility(GONE);
            sessionCard.setVisibility(GONE);
        } else if (!agree.isChecked()) {
            setStatus("Agree to connect", Theme.GOLD, "Turn on I agree to contact the session service. Nothing is sent until you do.", Theme.GOLD);
            joinCard.setVisibility(GONE);
        }
    }

    private void setStatus(String title, int titleColor, String body, int accent) {
        statusTitle.setText(title);
        statusTitle.setTextColor(titleColor);
        statusBody.setText(body);
        Theme.setCardAccent(statusCard, accent);
    }

    private void probe() {
        setStatus("Looking for the session service…", Theme.GOLD, "Checking " + client.baseURL + ".", Theme.GOLD);
        client.probeHealth(h -> ui.post(() -> {
            if (!enabledOn) return;
            if (h.status == ContenderClient.AVAILABLE) {
                setStatus(h.isLabReferee ? "Lab referee is reachable" : "Session service is reachable",
                        Theme.PEEL, h.detail + "\n" + client.baseURL, Theme.PEEL_MID);
                joinCard.setVisibility(sessionCard.getVisibility() == VISIBLE ? GONE : VISIBLE);
            } else {
                String why = h.status == ContenderClient.UNREACHABLE
                        ? "The app could not reach the session service."
                        : "moq-bench.dev did not return a session service. It may still be under construction, or it may ask for a sign-in the crowd app cannot complete.";
                setStatus("Session service not available yet", Theme.HIT,
                        why + "\n\n" + ContenderClient.neededEndpointsText(), Theme.HIT);
                joinCard.setVisibility(VISIBLE);
            }
        }));
    }

    void scanTapped() {
        if (!enabledOn) return;
        if (host.checkSelfPermission(android.Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            openScanner();
        } else {
            host.requestPermissions(new String[]{android.Manifest.permission.CAMERA}, REQ_CAMERA);
        }
    }

    void onPermissionResult(int code, int[] grant) {
        if (code != REQ_CAMERA) return;
        if (grant != null && grant.length > 0 && grant[0] == PackageManager.PERMISSION_GRANTED) openScanner();
        else cameraDenied();
    }

    void onScanResult(int result, Intent data) {
        if (result != Activity.RESULT_OK || data == null) return;
        String code = data.getStringExtra(QrScannerActivity.EXTRA_CODE);
        if (code != null) {
            codeField.setText(code);
            joinTapped();
        }
    }

    private void openScanner() {
        host.startActivityForResult(new Intent(host, QrScannerActivity.class), REQ_SCAN);
    }

    private void cameraDenied() {
        setStatus("Camera is off for this app", Theme.GOLD,
                "This phone is not allowed to use the camera with rind-bench. Type the session code instead, or allow the camera in Settings if you want to scan a QR code.",
                Theme.GOLD);
    }

    private void joinTapped() {
        if (!enabledOn) return;
        String code = ContenderClient.codeFromQRString(codeField.getText() == null ? "" : codeField.getText().toString());
        if (code == null || code.isEmpty()) {
            setStatus("Enter a session code", Theme.GOLD, "Type the code from the presenter, or scan the QR code.", Theme.GOLD);
            return;
        }
        setStatus("Looking up the session…", Theme.GOLD, statusBody.getText().toString(), Theme.GOLD);
        client.lookupSession(code, (session, error) -> ui.post(() -> {
            if (!enabledOn) return;
            if (error != null || session == null) {
                String title = (error != null && error.contains("not available")) ? "Session service not available yet" : (error != null ? error : "Could not join");
                setStatus(title, Theme.HIT, (error != null ? error : "The session could not be opened.") + "\n\n" + ContenderClient.neededEndpointsText(), Theme.HIT);
                sessionCard.setVisibility(GONE);
                joinCard.setVisibility(VISIBLE);
                return;
            }
            sessionName.setText(session.name);
            sessionPresenter.setText(session.presenter != null && !session.presenter.isEmpty()
                    ? "Presenter: " + session.presenter : "Waiting for the presenter.");
            if ("running".equals(session.state))
                rankBody.setText("The presenter has started. Rank updates appear here when the service sends them.");
            else if ("finished".equals(session.state))
                rankBody.setText("This session has finished.");
            else
                rankBody.setText("Waiting for the presenter to start.");
            sessionCard.setVisibility(VISIBLE);
            joinCard.setVisibility(GONE);
            setStatus("Joined", Theme.PEEL,
                    "This phone is in the session. Nothing further is sent except scrubbed results when a run is started by the presenter.",
                    Theme.PEEL_MID);
        }));
    }

    private void leaveTapped() {
        sessionCard.setVisibility(GONE);
        sessionName.setText("");
        if (enabledOn) joinCard.setVisibility(VISIBLE);
    }
}
