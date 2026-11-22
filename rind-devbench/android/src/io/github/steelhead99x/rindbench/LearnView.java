package io.github.steelhead99x.rindbench;

import android.content.Context;
import android.graphics.Typeface;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

/** Learn: plain-language FAQ accordion. Copy matches the iOS 14.4 Learn page. */
final class LearnView extends LinearLayout {
    LearnView(Context c) {
        super(c);
        setOrientation(VERTICAL);
        setBackgroundColor(Theme.INK);
        setContentDescription("Learn page");

        ScrollView scroll = new ScrollView(c);
        scroll.setFillViewport(true);
        LinearLayout root = new LinearLayout(c);
        root.setOrientation(VERTICAL);
        int pad = Theme.dpi(c, 16);
        root.setPadding(pad, Theme.dpi(c, 8), pad, Theme.dpi(c, 24));

        TextView title = Theme.label(c, "Learn", 28, 36, Theme.TEXT, Typeface.BOLD, 1);
        title.setAccessibilityHeading(true);
        TextView lead = Theme.label(c, "Short answers about this app, the tests, and what is shared. Open a topic to read it.",
                15, 22, Theme.MUTED, Typeface.NORMAL, 0);
        root.addView(title);
        spacer(root, 8);
        root.addView(lead);
        spacer(root, 16);

        String[][] items = topics();
        for (int i = 0; i < items.length; i++) root.addView(row(c, items[i][0], items[i][1]));

        scroll.addView(root, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT));
        addView(scroll, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
    }

    private static void spacer(LinearLayout root, int dp) {
        View v = new View(root.getContext());
        root.addView(v, new LayoutParams(LayoutParams.MATCH_PARENT, Theme.dpi(root.getContext(), dp)));
    }

    private static View row(Context c, String title, String body) {
        LinearLayout card = Theme.card(c, Theme.LINE);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT);
        lp.bottomMargin = Theme.dpi(c, 12);
        card.setLayoutParams(lp);

        Button head = new Button(c, null, android.R.attr.borderlessButtonStyle);
        head.setText(title);
        head.setAllCaps(false);
        head.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
        head.setTextColor(Theme.TEXT);
        head.setTextSize(android.util.TypedValue.COMPLEX_UNIT_PX, Theme.sp(c, 17, 24));
        head.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
        head.setBackground(null);
        head.setMinHeight(Theme.dpi(c, 48));
        head.setPadding(Theme.dpi(c, 4), Theme.dpi(c, 12), Theme.dpi(c, 4), Theme.dpi(c, 12));
        head.setContentDescription(title);
        head.setAccessibilityPaneTitle(title);

        TextView bodyL = Theme.label(c, body, 15, 22, Theme.TEXT, Typeface.NORMAL, 0);
        bodyL.setVisibility(GONE);
        head.setTag(new Object[]{bodyL, false});
        head.setOnClickListener(v -> {
            Object[] st = (Object[]) v.getTag();
            TextView b = (TextView) st[0];
            boolean open = !(Boolean) st[1];
            st[1] = open;
            b.setVisibility(open ? VISIBLE : GONE);
            v.setContentDescription(title + (open ? ", Open" : ", Closed"));
            v.announceForAccessibility(open ? "Open" : "Closed");
        });
        card.addView(head);
        card.addView(bodyL);
        return card;
    }

    /** Same topics and facts as iOS 14.4; "phone" in place of "iPad". */
    static String[][] topics() {
        return new String[][]{
            {"What is this app?",
                "rind-bench is an unofficial community tool. It times cryptography operations on this phone and can send those times to the computer that installed the app.\n\nIt is not run or endorsed by the rind maintainers. Nothing runs, and nothing is sent, until you agree and press Start test on the Bench page."},
            {"What is rind?",
                "rind is a cryptography library written in Rust. The rind project describes it as a drop-in replacement for other Rust libraries such as ring, aws-lc-rs, and rustls.\n\nThis app does not rank products or award a score. It measures how long the same operations take on this phone, so the times can be compared on the same device."},
            {"What are the libraries?",
                "The Bench page lists every library this build can time, under Libraries. The list comes from the build itself, not from a fixed menu in this screen.\n\nReport operations are on by default. Extra groups appear under More, and stay off until you turn them on. That split comes from this app's own catalog: the default report set, and the extra bench files offered as More groups."},
            {"Quick and Full",
                "Quick runs 1 round, with 5 samples of 50 milliseconds each, and a 150 millisecond warm-up.\n\nFull runs 3 rounds, with 10 samples of 100 milliseconds each, and a 300 millisecond warm-up.\n\nFull takes longer and keeps the CPU busy for more time. For a complete pass of every operation this build can time, choose Full and turn on the More groups as well. Leaving More off runs only the default report set."},
            {"What the numbers mean",
                "Times are shown in nanoseconds, microseconds, or milliseconds per operation. Shorter is faster.\n\nThe figure this app records as ns is the median of each round's median. The low and high values are the smallest and largest of those per-round medians. They are not a statistical confidence interval.\n\nWhen a line says “rind 2.00× its time”, rind took twice as long as that other library on the same operation. A figure below 1× means rind was faster than that library."},
            {"Why the phone gets warm",
                "A run keeps the CPU busy, on purpose, so the times reflect a working chip rather than an idle one. A busy chip produces heat, so the phone can feel warm. That is expected.\n\nIf the system reports a thermal state during a run, the Bench page shows it. You can press Stop at any time."},
            {"What is shared, and what is not",
                "When you agree and start a Bench run, the app can send timings and this device's model, chip, system version, and CPU features to the computer that installed the app. Results are also saved on this phone.\n\nThe app does not send your name, account, serial number, or location.\n\nThe collector address is chosen at install time and is shown on the Bench page. If the collector cannot be reached, the run still finishes and the results stay on this phone.\n\nContender, on its own page, is off until you turn it on and agree. A live session, when the service is available, is limited to timings and a coarse model and chip. It does not include a device name, serial, UDID, or IP address."},
            {"How to read results",
                "During a run, the progress bar and status line show how far the test has got, which operation is running, and how many result lines have been sent.\n\nWhen the run finishes, a short summary appears on the Bench page. Open View results for the full list, grouped by operation, with each library's time.\n\nCompare numbers from the same kind of run. A Quick run and a Full run, or a run with More off and a run with More on, are not the same test set."},
            {"How to report a problem",
                "This is an unofficial community tool, and it is not a product of the rind maintainers.\n\nIf something looks wrong, write down the rind commit shown on the Bench page, the phone model and system version, whether you chose Quick or Full, whether More groups were on, and what you saw. Give that to the person who installed the app on this phone."},
        };
    }
}
