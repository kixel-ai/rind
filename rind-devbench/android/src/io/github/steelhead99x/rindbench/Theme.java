package io.github.steelhead99x.rindbench;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.util.TypedValue;
import android.view.HapticFeedbackConstants;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

/** Original RindBench (v13) palette: ink panels, cream type, peel green, gold for "now". */
final class Theme {
    static final int INK = 0xFF13101B;
    static final int INK2 = 0xFF1A1424;
    static final int PANEL = 0xFF211A2D;
    static final int PANEL2 = 0xFF2A2035;
    static final int LINE = 0xFF50405E;
    static final int LINE_SOFT = 0xFF3A2F47;
    static final int SHADOW = 0xFF09070E;
    static final int TEXT = 0xFFF6F0E4;
    static final int MUTED = 0xFFCFC3DB;
    static final int PEEL = 0xFFADD500;
    static final int PEEL_MID = 0xFF719500;
    static final int PEEL_DEEP = 0xFF4D7000;
    static final int GOLD = 0xFFF0C14A;
    static final int HIT = 0xFFFFB4B4;

    static float dp(Context c, float v) {
        return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, c.getResources().getDisplayMetrics());
    }
    static int dpi(Context c, float v) { return Math.round(dp(c, v)); }

    /** Follows the user's font scale, then caps so single-page layouts still fit. */
    static float sp(Context c, float base, float cap) {
        float px = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, base, c.getResources().getDisplayMetrics());
        float capPx = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, cap, c.getResources().getDisplayMetrics());
        return Math.min(px, capPx);
    }

    static TextView label(Context c, String text, float base, float cap, int color, int style, int lines) {
        TextView t = new TextView(c);
        t.setText(text);
        t.setTextColor(color);
        t.setTextSize(TypedValue.COMPLEX_UNIT_PX, sp(c, base, cap));
        t.setTypeface(Typeface.create("sans-serif", style));
        t.setMaxLines(lines <= 0 ? Integer.MAX_VALUE : lines);
        if (lines == 1) t.setSingleLine(true);
        else t.setLineSpacing(0f, 1.12f);
        t.setElegantTextHeight(true);
        return t;
    }

    static TextView eyebrow(Context c, String text) {
        TextView t = label(c, text.toUpperCase(), 12, 16, PEEL, Typeface.BOLD, 1);
        t.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        t.setLetterSpacing(0.10f);
        t.setContentDescription(text);
        return t;
    }

    static Button primary(Context c, String title) { return button(c, title, true); }
    static Button secondary(Context c, String title) { return button(c, title, false); }
    static Button chip(Context c, String title) {
        Button b = button(c, title, false);
        b.setMinHeight(dpi(c, 44));
        b.setMinimumHeight(dpi(c, 44));
        b.setPadding(dpi(c, 12), dpi(c, 8), dpi(c, 12), dpi(c, 8));
        b.setSingleLine(true);
        if (Build.VERSION.SDK_INT >= 26) {
            b.setAutoSizeTextTypeWithDefaults(TextView.AUTO_SIZE_TEXT_TYPE_NONE);
        }
        b.setTextSize(TypedValue.COMPLEX_UNIT_PX, sp(c, 15, 19));
        return b;
    }

    static GradientDrawable segmentedBg(Context c) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(INK);
        g.setCornerRadius(dp(c, 8));
        g.setStroke(dpi(c, 2), LINE);
        return g;
    }

    static void styleSegment(Button b, boolean selected, boolean enabled) {
        b.setEnabled(enabled);
        b.setSelected(selected);
        GradientDrawable g = new GradientDrawable();
        g.setCornerRadius(dp(b.getContext(), 6));
        if (selected) {
            g.setColor(enabled ? PEEL : LINE);
            b.setTextColor(INK);
        } else {
            g.setColor(Color.TRANSPARENT);
            b.setTextColor(enabled ? TEXT : MUTED);
        }
        b.setBackground(g);
        b.setAlpha(1f);
    }

    static Button button(Context c, String title, boolean primary) {
        Button b = new Button(c, null, android.R.attr.borderlessButtonStyle);
        b.setText(title);
        b.setAllCaps(false);
        b.setMinHeight(dpi(c, 48));
        b.setMinimumHeight(dpi(c, 48));
        b.setPadding(dpi(c, 14), dpi(c, 10), dpi(c, 14), dpi(c, 10));
        b.setSingleLine(true);
        if (Build.VERSION.SDK_INT >= 26) {
            b.setAutoSizeTextTypeUniformWithConfiguration(14, 17, 1, TypedValue.COMPLEX_UNIT_SP);
        } else {
            b.setTextSize(TypedValue.COMPLEX_UNIT_PX, sp(c, 16, 22));
        }
        b.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
        styleButton(b, primary, true);
        return b;
    }

    static void styleButton(Button b, boolean primary, boolean enabled) {
        b.setEnabled(enabled);
        GradientDrawable g = new GradientDrawable();
        g.setCornerRadius(dp(b.getContext(), 8));
        if (primary && enabled) {
            g.setColor(PEEL);
            g.setStroke(dpi(b.getContext(), 2), PEEL_MID);
            b.setTextColor(INK);
        } else if (primary) {
            g.setColor(INK);
            g.setStroke(dpi(b.getContext(), 2), LINE);
            b.setTextColor(MUTED);
        } else {
            g.setColor(INK);
            g.setStroke(dpi(b.getContext(), 2), LINE);
            b.setTextColor(enabled ? TEXT : MUTED);
        }
        b.setBackground(g);
        b.setAlpha(1f);
    }

    static GradientDrawable cardBg(Context c, int accent) {
        GradientDrawable g = new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{PANEL, INK2});
        g.setCornerRadius(dp(c, 8));
        g.setStroke(dpi(c, 2), accent == 0 ? LINE : accent);
        return g;
    }

    static LinearLayout card(Context c, int accent) {
        return card(c, accent, 14, 12);
    }

    static LinearLayout card(Context c, int accent, int hDp, int vDp) {
        LinearLayout l = new LinearLayout(c);
        l.setOrientation(LinearLayout.VERTICAL);
        l.setPadding(dpi(c, hDp), dpi(c, vDp), dpi(c, hDp), dpi(c, vDp));
        l.setBackground(cardBg(c, accent));
        l.setElevation(dp(c, 4));
        return l;
    }

    static void setCardAccent(View card, int accent) {
        card.setBackground(cardBg(card.getContext(), accent));
    }

    static ColorStateList peelSwitch() {
        return new ColorStateList(
                new int[][]{new int[]{android.R.attr.state_checked}, new int[]{}},
                new int[]{PEEL, LINE});
    }

    static void minTarget(View v, float dp) {
        v.setMinimumHeight(dpi(v.getContext(), dp));
        v.setMinimumWidth(dpi(v.getContext(), dp));
    }

    static void haptic(View v, boolean confirm) {
        if (v == null) return;
        int flag = (confirm && Build.VERSION.SDK_INT >= 30)
                ? HapticFeedbackConstants.CONFIRM
                : HapticFeedbackConstants.CONTEXT_CLICK;
        v.performHapticFeedback(flag);
    }
}

/** Segmented progress bar used on the Bench page. */
final class SegBar extends View {
    int total = 24, done;
    boolean running;
    private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);

    SegBar(Context c) {
        super(c);
        setMinimumHeight(Theme.dpi(c, 24));
        setContentDescription("Run progress");
        setFocusable(true);
        if (Build.VERSION.SDK_INT >= 28) setScreenReaderFocusable(true);
    }
    void setProgress(int done, int total, boolean running) {
        this.done = done;
        this.total = Math.max(1, total);
        this.running = running;
        setContentDescription("Run progress, " + done + " of " + total);
        invalidate();
    }
    @Override protected void onMeasure(int w, int h) {
        int minH = Theme.dpi(getContext(), 24);
        int width = View.MeasureSpec.getSize(w);
        if (View.MeasureSpec.getMode(h) == View.MeasureSpec.UNSPECIFIED) {
            setMeasuredDimension(width, minH);
        } else {
            setMeasuredDimension(width, Math.max(minH, View.MeasureSpec.getSize(h)));
        }
    }
    @Override protected void onDraw(Canvas c) {
        float inset = Theme.dp(getContext(), 5), gap = Theme.dp(getContext(), 3);
        int n = Math.max(1, total);
        float w = (getWidth() - inset * 2 - gap * (n - 1)) / n;
        float h = getHeight() - inset * 2;
        p.setStyle(Paint.Style.FILL);
        p.setColor(Theme.INK);
        c.drawRoundRect(0, 0, getWidth(), getHeight(), Theme.dp(getContext(), 6), Theme.dp(getContext(), 6), p);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(Theme.dp(getContext(), 2));
        p.setColor(Theme.LINE);
        c.drawRoundRect(Theme.dp(getContext(), 1), Theme.dp(getContext(), 1), getWidth() - Theme.dp(getContext(), 1), getHeight() - Theme.dp(getContext(), 1), Theme.dp(getContext(), 6), Theme.dp(getContext(), 6), p);
        p.setStyle(Paint.Style.FILL);
        for (int i = 0; i < n; i++) {
            p.setColor(i < done ? Theme.PEEL : (i == done && running ? Theme.GOLD : Theme.PANEL2));
            float x = inset + i * (w + gap);
            c.drawRoundRect(x, inset, x + w, inset + h, Theme.dp(getContext(), 2), Theme.dp(getContext(), 2), p);
        }
    }
}
