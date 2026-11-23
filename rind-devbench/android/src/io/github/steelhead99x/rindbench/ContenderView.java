package io.github.steelhead99x.rindbench;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Typeface;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
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
    private TextView statusTitle, statusBody, endpointsBody;
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
        root.setPadding(pad, Theme.dpi(host, 4), pad, Theme.dpi(host, 18));

        TextView title = Theme.label(host, "Contender", 26, 34, Theme.TEXT, Typeface.BOLD, 1);
        title.setAccessibilityHeading(true);
        TextView lead = Theme.label(host, "Join a live talk demo. Off until you turn both switches on.",
                16, 22, Theme.MUTED, Typeface.NORMAL, 0);
        root.addView(title);
        space(root, 6);
        root.addView(lead);
        space(root, 10);

        enable = makeSwitch("Turn Contender on");
        enable.setOnCheckedChangeListener((v, on) -> enableChanged());
        LinearLayout enRow = switchRow(enable, Theme.label(host, "Turn Contender on", 17, 23, Theme.TEXT, Typeface.BOLD, 1));

        agree = makeSwitch("I agree to share timings");
        agree.setEnabled(false);
        agree.setOnCheckedChangeListener((v, on) -> agreeChanged());
        LinearLayout agText = new LinearLayout(host);
        agText.setOrientation(VERTICAL);
        agText.addView(Theme.label(host, "I agree to share timings", 17, 23, Theme.TEXT, Typeface.BOLD, 1));
        agText.addView(Theme.label(host, "Model and chip only. No name, ID, or IP.", 15, 20, Theme.MUTED, Typeface.NORMAL, 0));
        LinearLayout agRow = switchRowView(agree, agText);

        LinearLayout toggleCard = Theme.card(host, Theme.LINE);
        toggleCard.addView(enRow);
        space(toggleCard, 12);
        toggleCard.addView(agRow);
        root.addView(toggleCard);
        space(root, 10);

        statusTitle = Theme.label(host, "Contender is off", 18, 24, Theme.TEXT, Typeface.BOLD, 1);
        statusBody = Theme.label(host, "Nothing connects while this is off.", 16, 22, Theme.TEXT, Typeface.NORMAL, 0);
        endpointsBody = Theme.label(host, ContenderClient.neededEndpointsText(), 14, 18, Theme.MUTED, Typeface.NORMAL, 0);
        endpointsBody.setTypeface(Typeface.MONOSPACE);
        endpointsBody.setVisibility(GONE);

        statusCard = Theme.card(host, Theme.LINE);
        statusCard.addView(statusTitle);
        space(statusCard, 6);
        statusCard.addView(statusBody);
        space(statusCard, 8);
        statusCard.addView(endpointsBody);
        root.addView(statusCard);
        space(root, 10);

        TextView joinHead = Theme.label(host, "Join a session", 18, 24, Theme.TEXT, Typeface.BOLD, 1);
        TextView hint = Theme.label(host, "Type the session code or scan a QR code.", 16, 22, Theme.MUTED, Typeface.NORMAL, 0);
        codeField = new EditText(host);
        codeField.setHint("Session code");
        codeField.setContentDescription("Session code");
        codeField.setTextSize(android.util.TypedValue.COMPLEX_UNIT_PX, Theme.sp(host, 16, 22));
        codeField.setTextColor(Theme.TEXT);
        codeField.setHintTextColor(Theme.MUTED);
        codeField.setBackground(Theme.cardBg(host, Theme.LINE));
        codeField.setPadding(Theme.dpi(host, 12), Theme.dpi(host, 12), Theme.dpi(host, 12), Theme.dpi(host, 12));
        codeField.setMinHeight(Theme.dpi(host, 48));
        codeField.setSingleLine(true);
        codeField.setInputType(android.text.InputType.TYPE_CLASS_TEXT | android.text.InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        codeField.setImeOptions(EditorInfo.IME_ACTION_GO);
        codeField.setOnEditorActionListener((v, a, e) -> { joinTapped(); return true; });

        Button scanBtn = Theme.secondary(host, "Scan QR");
        scanBtn.setContentDescription("Scan QR code");
        scanBtn.setOnClickListener(v -> scanTapped());
        Button joinBtn = Theme.primary(host, "Join");
        joinBtn.setContentDescription("Join session");
        joinBtn.setOnClickListener(v -> joinTapped());
        LinearLayout joinBtns = new LinearLayout(host);
        joinBtns.setOrientation(HORIZONTAL);
        LinearLayout.LayoutParams hp = new LinearLayout.LayoutParams(0, LayoutParams.WRAP_CONTENT, 1);
        hp.rightMargin = Theme.dpi(host, 10);
        joinBtns.addView(scanBtn, hp);
        joinBtns.addView(joinBtn, new LinearLayout.LayoutParams(0, LayoutParams.WRAP_CONTENT, 1));

        joinCard = Theme.card(host, Theme.LINE);
        joinCard.addView(joinHead);
        space(joinCard, 8);
        joinCard.addView(hint);
        space(joinCard, 8);
        joinCard.addView(codeField);
        space(joinCard, 8);
        joinCard.addView(joinBtns);
        joinCard.setVisibility(GONE);
        root.addView(joinCard);
        space(root, 12);

        sessionName = Theme.label(host, "", 22, 30, Theme.TEXT, Typeface.BOLD, 2);
        sessionPresenter = Theme.label(host, "", 16, 22, Theme.MUTED, Typeface.NORMAL, 2);
        rankBody = Theme.label(host, "", 16, 22, Theme.TEXT, Typeface.NORMAL, 0);
        Button leaveBtn = Theme.secondary(host, "Leave");
        leaveBtn.setContentDescription("Leave session");
        leaveBtn.setOnClickListener(v -> leaveTapped());
        sessionCard = Theme.card(host, Theme.PEEL_MID);
        sessionCard.addView(Theme.eyebrow(host, "session"));
        space(sessionCard, 8);
        sessionCard.addView(sessionName);
        space(sessionCard, 6);
        sessionCard.addView(sessionPresenter);
        space(sessionCard, 8);
        sessionCard.addView(rankBody);
        space(sessionCard, 10);
        sessionCard.addView(leaveBtn);
        sessionCard.setVisibility(GONE);
        root.addView(sessionCard);
        space(root, 10);

        TextView foot = Theme.label(host, "Uses moq-bench.dev on moq.pro. Off by default.",
                14, 18, Theme.MUTED, Typeface.NORMAL, 0);
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
        return switchRowView(s, t);
    }

    private LinearLayout switchRowView(Switch s, android.view.View content) {
        LinearLayout row = new LinearLayout(host);
        row.setOrientation(HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setMinimumHeight(Theme.dpi(host, 48));
        LinearLayout.LayoutParams slp = new LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT);
        slp.rightMargin = Theme.dpi(host, 12);
        row.addView(s, slp);
        content.setLayoutParams(new LinearLayout.LayoutParams(0, LayoutParams.WRAP_CONTENT, 1));
        row.addView(content);
        content.setOnClickListener(v -> { if (s.isEnabled()) s.toggle(); });
        return row;
    }

    private static void space(LinearLayout root, int dp) {
        android.view.View v = new android.view.View(root.getContext());
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
            setStatus("Turn on I agree", Theme.GOLD, "Nothing connects until you agree.", Theme.GOLD, false);
            joinCard.setVisibility(GONE);
        }
    }

    private void refreshGate() {
        agree.setEnabled(enable.isChecked());
        enabledOn = enable.isChecked() && agree.isChecked();
        joinCard.setVisibility((enabledOn && sessionCard.getVisibility() != VISIBLE) ? VISIBLE : GONE);
        if (!enable.isChecked()) {
            setStatus("Contender is off", Theme.TEXT, "Nothing connects while this is off.", Theme.LINE, false);
            joinCard.setVisibility(GONE);
            sessionCard.setVisibility(GONE);
        } else if (!agree.isChecked()) {
            setStatus("Turn on I agree", Theme.GOLD, "Nothing connects until you agree.", Theme.GOLD, false);
            joinCard.setVisibility(GONE);
        }
    }

    private void setStatus(String title, int titleColor, String body, int accent, boolean showEndpoints) {
        statusTitle.setText(title);
        statusTitle.setTextColor(titleColor);
        statusBody.setText(body);
        endpointsBody.setVisibility(showEndpoints ? VISIBLE : GONE);
        Theme.setCardAccent(statusCard, accent);
    }

    private void probe() {
        setStatus("Checking moq-bench.dev...", Theme.GOLD, "Looking for the live session service.", Theme.GOLD, false);
        client.probeHealth(h -> ui.post(() -> {
            if (!enabledOn) return;
            if (h.status == ContenderClient.AVAILABLE) {
                setStatus(h.isLabReferee ? "Lab referee ready" : "Session service ready",
                        Theme.PEEL, client.baseURL, Theme.PEEL_MID, false);
                joinCard.setVisibility(sessionCard.getVisibility() == VISIBLE ? GONE : VISIBLE);
            } else {
                String body = h.status == ContenderClient.UNREACHABLE
                        ? "Could not reach moq-bench.dev."
                        : "moq-bench.dev is not ready for live sessions yet.";
                setStatus("Session service not available yet", Theme.HIT, body, Theme.HIT, true);
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
        setStatus("Camera is off", Theme.GOLD,
                "Type the session code instead, or allow the camera in Settings.",
                Theme.GOLD, false);
    }

    private void joinTapped() {
        if (!enabledOn) return;
        String code = ContenderClient.codeFromQRString(codeField.getText() == null ? "" : codeField.getText().toString());
        if (code == null || code.isEmpty()) {
            setStatus("Enter a code", Theme.GOLD, "Type the session code or scan a QR code.", Theme.GOLD, false);
            return;
        }
        setStatus("Joining session...", Theme.GOLD, "Checking code " + code + ".", Theme.GOLD, false);
        client.lookupSession(code, (session, error) -> ui.post(() -> {
            if (!enabledOn) return;
            if (error != null || session == null) {
                boolean unavail = error != null && error.contains("not available");
                String title = unavail ? "Session service not available yet" : (error != null ? error : "Could not join");
                String body = unavail ? "moq-bench.dev is not ready for live sessions yet." : (error != null ? error : "Could not open that session.");
                setStatus(title, Theme.HIT, body, Theme.HIT, unavail);
                sessionCard.setVisibility(GONE);
                joinCard.setVisibility(VISIBLE);
                return;
            }
            sessionName.setText(session.name);
            sessionPresenter.setText(session.presenter != null && !session.presenter.isEmpty()
                    ? "Presenter: " + session.presenter : "Waiting for presenter.");
            if ("running".equals(session.state))
                rankBody.setText("Running. Live rank appears here.");
            else if ("finished".equals(session.state))
                rankBody.setText("Session finished.");
            else
                rankBody.setText("Waiting for the presenter to start.");
            sessionCard.setVisibility(VISIBLE);
            joinCard.setVisibility(GONE);
            setStatus("Joined", Theme.PEEL,
                    "Only scrubbed results are shared when the presenter starts.",
                    Theme.PEEL_MID, false);
        }));
    }

    private void leaveTapped() {
        sessionCard.setVisibility(GONE);
        sessionName.setText("");
        if (enabledOn) joinCard.setVisibility(VISIBLE);
    }
}
