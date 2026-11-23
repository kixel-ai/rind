package io.github.steelhead99x.rindbench;

import android.content.Context;
import android.graphics.Typeface;
import android.view.Gravity;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

/** Learn: short plain-language FAQ answers (<= 2 short sentences each). */
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

        TextView title = Theme.label(c, "Learn", 26, 34, Theme.TEXT, Typeface.BOLD, 1);
        title.setAccessibilityHeading(true);
        TextView lead = Theme.label(c, "Tap a question to read the answer.",
                16, 22, Theme.MUTED, Typeface.NORMAL, 0);
        root.addView(title);
        spacer(root, 6);
        root.addView(lead);
        spacer(root, 14);

        String[][] items = topics();
        for (int i = 0; i < items.length; i++) root.addView(row(c, items[i][0], items[i][1]));

        spacer(root, 6);
        TextView foot = Theme.label(c, "Unofficial community tool. Not run or endorsed by the rind maintainers.",
                14, 18, Theme.MUTED, Typeface.NORMAL, 0);
        root.addView(foot);

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
        lp.bottomMargin = Theme.dpi(c, 10);
        card.setLayoutParams(lp);

        LinearLayout head = new LinearLayout(c);
        head.setOrientation(HORIZONTAL);
        head.setGravity(Gravity.CENTER_VERTICAL);
        head.setMinimumHeight(Theme.dpi(c, 48));
        head.setPadding(Theme.dpi(c, 2), Theme.dpi(c, 6), Theme.dpi(c, 2), Theme.dpi(c, 6));

        TextView q = Theme.label(c, title, 18, 24, Theme.TEXT, Typeface.BOLD, 0);
        TextView chev = Theme.label(c, "+", 20, 26, Theme.PEEL, Typeface.BOLD, 1);
        chev.setPadding(Theme.dpi(c, 12), 0, Theme.dpi(c, 2), 0);
        chev.setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);

        head.addView(q, new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1));
        head.addView(chev, new LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT));
        head.setFocusable(true);
        head.setContentDescription(title + ", Closed");

        TextView bodyL = Theme.label(c, body, 16, 22, Theme.TEXT, Typeface.NORMAL, 0);
        bodyL.setPadding(Theme.dpi(c, 2), Theme.dpi(c, 6), Theme.dpi(c, 2), Theme.dpi(c, 4));
        bodyL.setVisibility(GONE);

        final boolean[] open = {false};
        head.setOnClickListener(v -> {
            open[0] = !open[0];
            bodyL.setVisibility(open[0] ? VISIBLE : GONE);
            chev.setText(open[0] ? "-" : "+");
            Theme.setCardAccent(card, open[0] ? Theme.PEEL_MID : Theme.LINE);
            v.setContentDescription(title + (open[0] ? ", Open" : ", Closed"));
            v.announceForAccessibility(open[0] ? "Open" : "Closed");
        });
        card.addView(head);
        card.addView(bodyL);
        return card;
    }

    static String[][] topics() {
        return new String[][]{
            {"What is this app?",
                "It times how fast this phone runs math that keeps data safe. Nothing runs or leaves your phone until you agree and tap Start."},
            {"What is rind?",
                "rind is a Rust software library that protects data with math like scrambling and signatures. This app times rind next to other libraries doing the same jobs."},
            {"What are the libraries?",
                "They are code packages that do safety math, like rind, ring, and OpenSSL. You can pick which libraries and groups to run on the Bench tab."},
            {"Quick test vs Full test",
                "Quick test runs 1 round (5 tries of 50 ms) for a fast check. Full test runs 3 rounds (10 tries of 100 ms) for steadier numbers, and More groups add extra tests."},
            {"What do the numbers mean?",
                "Numbers show how long one test took in ns, µs, or ms, so smaller is faster. If another library says 2.00x, rind took twice as long; under 1.00x means rind was faster."},
            {"Why does the phone get warm?",
                "The tests make the chip work hard on purpose to measure real speed. Working chips make heat, and you can tap Stop anytime."},
            {"What is shared?",
                "If you agree, Bench sends timings plus your phone model, chip, and OS to the collector, while Contender shares model and chip only. Neither sends your name, serial, ID, or IP."},
            {"How do I read results?",
                "While it runs, the green bar fills up and shows the current test. When it finishes, tap View results to compare each library side by side."},
            {"How to report a problem",
                "Tap Details on the Bench tab to note your commit, phone model, and preset. Send that note to the person who installed this app."},
        };
    }
}
