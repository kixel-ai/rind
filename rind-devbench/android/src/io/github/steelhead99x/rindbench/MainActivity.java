package io.github.steelhead99x.rindbench;

import android.app.Activity;
import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Typeface;
import android.graphics.drawable.ColorDrawable;
import android.os.Build;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowInsets;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * Root chrome: logo + rind-bench title, Bench / Learn / Contender.
 * Portrait uses a bottom tab bar; landscape uses a left rail.
 */
public class MainActivity extends Activity {
    private LinearLayout root, header, tabBar, sidebar, railTabs, content;
    private static final String[] TAB_NAMES = {"Bench", "Learn", "Contender"};
    private static final String[] TAB_HINTS = {
            "Run speed tests on this phone.",
            "Short answers about how this app works.",
            "Join a live demo or talk. Off by default."
    };
    private final View[] pages = new View[3];
    private final Button[] tabsBottom = new Button[3], tabsRail = new Button[3];
    private int selected;
    private BenchView bench;
    private ContenderView contender;
    private Button detailsBtn;
    private int insetL, insetT, insetR, insetB;

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        Window w = getWindow();
        w.setStatusBarColor(Theme.INK);
        w.setNavigationBarColor(Theme.INK2);
        w.setBackgroundDrawable(new ColorDrawable(Theme.INK));
        if (Build.VERSION.SDK_INT >= 30) w.setDecorFitsSystemWindows(false);
        else w.getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);

        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Theme.INK);
        root.setOnApplyWindowInsetsListener((v, insets) -> {
            if (Build.VERSION.SDK_INT >= 30) {
                android.graphics.Insets s = insets.getInsets(WindowInsets.Type.systemBars());
                insetL = s.left; insetT = s.top; insetR = s.right; insetB = s.bottom;
            } else {
                insetL = insets.getSystemWindowInsetLeft();
                insetT = insets.getSystemWindowInsetTop();
                insetR = insets.getSystemWindowInsetRight();
                insetB = insets.getSystemWindowInsetBottom();
            }
            relayout();
            return insets;
        });

        bench = new BenchView(this, getIntent());
        LearnView learn = new LearnView(this);
        contender = new ContenderView(this);
        pages[0] = bench; pages[1] = learn; pages[2] = contender;
        for (View p : pages) p.setVisibility(View.GONE);

        detailsBtn = Theme.chip(this, "Details");
        detailsBtn.setContentDescription("Details. Shows device, chip, and build commit.");
        detailsBtn.setOnClickListener(v -> { if (bench != null) bench.openDetails(); });

        header = makeHeader();

        content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        for (View p : pages) content.addView(p, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        tabBar = makeTabRow(tabsBottom, true);
        sidebar = new LinearLayout(this);
        sidebar.setOrientation(LinearLayout.VERTICAL);
        sidebar.setBackgroundColor(Theme.INK2);
        sidebar.setPadding(Theme.dpi(this, 12), Theme.dpi(this, 16), Theme.dpi(this, 12), Theme.dpi(this, 16));
        railTabs = makeTabRow(tabsRail, false);
        relayout();
        selectTab(0);
        setContentView(root);
    }

    private LinearLayout makeHeader() {
        LinearLayout h = new LinearLayout(this);
        h.setOrientation(LinearLayout.HORIZONTAL);
        h.setGravity(Gravity.CENTER_VERTICAL);
        ImageView logo = new ImageView(this);
        int id = getResources().getIdentifier("rindlogo", "drawable", getPackageName());
        if (id != 0) logo.setImageResource(id);
        logo.setContentDescription("rind-bench");
        int s = Theme.dpi(this, 38);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(s, s);
        lp.rightMargin = Theme.dpi(this, 10);
        h.addView(logo, lp);

        TextView title = Theme.label(this, "rind-bench", 24, 32, Theme.TEXT, Typeface.BOLD, 1);
        title.setAccessibilityHeading(true);
        h.addView(title, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        return h;
    }

    private LinearLayout makeTabRow(Button[] store, boolean horizontal) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(horizontal ? LinearLayout.HORIZONTAL : LinearLayout.VERTICAL);
        for (int i = 0; i < 3; i++) {
            Button b = Theme.secondary(this, TAB_NAMES[i]);
            b.setTag(i);
            b.setContentDescription(TAB_NAMES[i] + ". " + TAB_HINTS[i]);
            final int idx = i;
            b.setOnClickListener(v -> selectTab(idx));
            LinearLayout.LayoutParams lp = horizontal
                    ? new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1)
                    : new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            if (horizontal && i < 2) lp.rightMargin = Theme.dpi(this, 8);
            if (!horizontal && i < 2) lp.bottomMargin = Theme.dpi(this, 8);
            row.addView(b, lp);
            store[i] = b;
        }
        if (horizontal) {
            LinearLayout wrap = new LinearLayout(this);
            wrap.setOrientation(LinearLayout.VERTICAL);
            wrap.setBackgroundColor(Theme.INK2);
            View topLine = new View(this);
            topLine.setBackgroundColor(Theme.LINE);
            wrap.addView(topLine, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Theme.dpi(this, 2)));
            LinearLayout inner = new LinearLayout(this);
            inner.setOrientation(LinearLayout.VERTICAL);
            inner.setPadding(Theme.dpi(this, 12), Theme.dpi(this, 6), Theme.dpi(this, 12), Theme.dpi(this, 6));
            inner.addView(row, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
            wrap.addView(inner, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
            return wrap;
        }
        return row;
    }

    private void selectTab(int i) {
        selected = i;
        for (int n = 0; n < pages.length; n++) {
            pages[n].setVisibility(n == i ? View.VISIBLE : View.GONE);
            pages[n].setImportantForAccessibility(n == i
                    ? View.IMPORTANT_FOR_ACCESSIBILITY_YES
                    : View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS);
        }
        if (detailsBtn != null) detailsBtn.setVisibility(i == 0 ? View.VISIBLE : View.GONE);
        styleTabs(tabsBottom);
        styleTabs(tabsRail);
    }

    private void styleTabs(Button[] tabs) {
        for (Button b : tabs) {
            if (b == null) continue;
            int i = (Integer) b.getTag();
            boolean on = i == selected;
            Theme.styleButton(b, on, true);
            b.setSelected(on);
            b.setContentDescription(TAB_NAMES[i] + (on ? ", selected. " : ". ") + TAB_HINTS[i]);
        }
    }

    private boolean isLandscape() {
        return getResources().getConfiguration().orientation == Configuration.ORIENTATION_LANDSCAPE
                && getResources().getDisplayMetrics().widthPixels > getResources().getDisplayMetrics().heightPixels;
    }

    private void relayout() {
        root.removeAllViews();
        sidebar.removeAllViews();
        if (header.getParent() instanceof ViewGroup) ((ViewGroup) header.getParent()).removeView(header);
        if (railTabs.getParent() instanceof ViewGroup) ((ViewGroup) railTabs.getParent()).removeView(railTabs);
        if (detailsBtn.getParent() instanceof ViewGroup) ((ViewGroup) detailsBtn.getParent()).removeView(detailsBtn);
        boolean land = isLandscape();
        root.setPadding(insetL, insetT, insetR, land ? insetB : 0);
        if (land) {
            root.setOrientation(LinearLayout.HORIZONTAL);
            sidebar.addView(header);
            View spacer = new View(this);
            sidebar.addView(spacer, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Theme.dpi(this, 20)));
            sidebar.addView(railTabs);
            View flex = new View(this);
            sidebar.addView(flex, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
            sidebar.addView(detailsBtn, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
            LinearLayout.LayoutParams slp = new LinearLayout.LayoutParams(Theme.dpi(this, 210), ViewGroup.LayoutParams.MATCH_PARENT);
            root.addView(sidebar, slp);
            LinearLayout.LayoutParams clp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1);
            clp.leftMargin = Theme.dpi(this, 8);
            root.addView(content, clp);
        } else {
            root.setOrientation(LinearLayout.VERTICAL);
            header.addView(detailsBtn, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
            LinearLayout.LayoutParams hlp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            hlp.leftMargin = Theme.dpi(this, 16);
            hlp.rightMargin = Theme.dpi(this, 16);
            hlp.topMargin = Theme.dpi(this, 6);
            hlp.bottomMargin = Theme.dpi(this, 6);
            root.addView(header, hlp);
            root.addView(content, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
            tabBar.setPadding(0, 0, 0, insetB);
            root.addView(tabBar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        }
        styleTabs(tabsBottom);
        styleTabs(tabsRail);
        if (bench != null) bench.onChromeRelayout();
    }

    @Override public void onConfigurationChanged(Configuration cfg) {
        super.onConfigurationChanged(cfg);
        relayout();
    }

    @Override public void onRequestPermissionsResult(int c, String[] p, int[] g) {
        super.onRequestPermissionsResult(c, p, g);
        if (contender != null) contender.onPermissionResult(c, g);
    }

    @Override protected void onActivityResult(int req, int res, Intent data) {
        super.onActivityResult(req, res, data);
        if (contender != null && req == ContenderView.REQ_SCAN) contender.onScanResult(res, data);
    }

    @Override protected void onNewIntent(Intent i) {
        super.onNewIntent(i);
        setIntent(i);
        if (bench != null) bench.applyIntent(i);
    }
}
