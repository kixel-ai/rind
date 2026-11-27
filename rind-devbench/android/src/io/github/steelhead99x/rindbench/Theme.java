package io.github.steelhead99x.rindbench;

import android.app.Activity;
import android.content.Context;
import android.content.res.ColorStateList;
import android.content.res.Configuration;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.graphics.drawable.ClipDrawable;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.InsetDrawable;
import android.graphics.drawable.LayerDrawable;
import android.graphics.drawable.RippleDrawable;
import android.graphics.drawable.StateListDrawable;
import android.os.Build;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.Switch;
import android.widget.TextView;

/**
 * Material 3 tokens built on platform widgets (this build has no AndroidX).
 * Colour follows the system: dynamic colour on Android 12+, a fixed green
 * scheme before that, light or dark from the system setting. Type uses the
 * M3 scale in sp with no cap, so it follows font size up to 200%.
 */
final class Theme {
    // Colour roles, set by init().
    static int primary, onPrimary, primaryContainer, onPrimaryContainer;
    static int secondaryContainer, onSecondaryContainer;
    static int surface, surfaceContainerLow, surfaceContainer, surfaceContainerHigh, surfaceContainerHighest;
    static int onSurface, onSurfaceVariant, outline, outlineVariant;
    static int error, errorContainer, onErrorContainer;
    static boolean dark;

    static void init(Context c) {
        dark = (c.getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK)
                == Configuration.UI_MODE_NIGHT_YES;
        if (Build.VERSION.SDK_INT >= 31) dynamic(c);
        else fallback();
        error = dark ? 0xFFFFB4AB : 0xFFBA1A1A;
        errorContainer = dark ? 0xFF93000A : 0xFFFFDAD6;
        onErrorContainer = dark ? 0xFFFFDAD6 : 0xFF410002;
    }

    private static void dynamic(Context c) {
        // Same tone mapping as Material's dynamic colour (accent1 = primary, accent2 = secondary, neutral = surfaces).
        if (!dark) {
            primary = col(c, android.R.color.system_accent1_600);
            onPrimary = col(c, android.R.color.system_accent1_0);
            primaryContainer = col(c, android.R.color.system_accent1_100);
            onPrimaryContainer = col(c, android.R.color.system_accent1_900);
            secondaryContainer = col(c, android.R.color.system_accent2_100);
            onSecondaryContainer = col(c, android.R.color.system_accent2_900);
            surface = col(c, android.R.color.system_neutral1_10);
            surfaceContainerLow = mix(col(c, android.R.color.system_neutral1_10), col(c, android.R.color.system_neutral1_50), 0.6f);
            surfaceContainer = col(c, android.R.color.system_neutral1_50);
            surfaceContainerHigh = mix(col(c, android.R.color.system_neutral1_50), col(c, android.R.color.system_neutral1_100), 0.5f);
            surfaceContainerHighest = col(c, android.R.color.system_neutral1_100);
            onSurface = col(c, android.R.color.system_neutral1_900);
            onSurfaceVariant = col(c, android.R.color.system_neutral2_700);
            outline = col(c, android.R.color.system_neutral2_500);
            outlineVariant = col(c, android.R.color.system_neutral2_200);
        } else {
            primary = col(c, android.R.color.system_accent1_200);
            onPrimary = col(c, android.R.color.system_accent1_800);
            primaryContainer = col(c, android.R.color.system_accent1_700);
            onPrimaryContainer = col(c, android.R.color.system_accent1_100);
            secondaryContainer = col(c, android.R.color.system_accent2_700);
            onSecondaryContainer = col(c, android.R.color.system_accent2_100);
            int n900 = col(c, android.R.color.system_neutral1_900), n800 = col(c, android.R.color.system_neutral1_800);
            surface = mix(n900, Color.BLACK, 0.25f);
            surfaceContainerLow = n900;
            surfaceContainer = mix(n900, n800, 0.25f);
            surfaceContainerHigh = mix(n900, n800, 0.6f);
            surfaceContainerHighest = n800;
            onSurface = col(c, android.R.color.system_neutral1_100);
            onSurfaceVariant = col(c, android.R.color.system_neutral2_200);
            outline = col(c, android.R.color.system_neutral2_400);
            outlineVariant = col(c, android.R.color.system_neutral2_700);
        }
    }

    /** Material 3 scheme from a green seed (close to the rind "peel" brand colour). */
    private static void fallback() {
        if (!dark) {
            primary = 0xFF4C662B; onPrimary = 0xFFFFFFFF;
            primaryContainer = 0xFFCDEDA3; onPrimaryContainer = 0xFF354E16;
            secondaryContainer = 0xFFDCE7C8; onSecondaryContainer = 0xFF404A33;
            surface = 0xFFF9FAEF; surfaceContainerLow = 0xFFF3F4E9; surfaceContainer = 0xFFEEEFE3;
            surfaceContainerHigh = 0xFFE8E9DE; surfaceContainerHighest = 0xFFE2E3D8;
            onSurface = 0xFF1A1C16; onSurfaceVariant = 0xFF44483D;
            outline = 0xFF75796C; outlineVariant = 0xFFC5C8BA;
        } else {
            primary = 0xFFB1D18A; onPrimary = 0xFF1F3701;
            primaryContainer = 0xFF354E16; onPrimaryContainer = 0xFFCDEDA3;
            secondaryContainer = 0xFF404A33; onSecondaryContainer = 0xFFDCE7C8;
            surface = 0xFF12140E; surfaceContainerLow = 0xFF1A1C16; surfaceContainer = 0xFF1E201A;
            surfaceContainerHigh = 0xFF282B24; surfaceContainerHighest = 0xFF33362E;
            onSurface = 0xFFE2E3D8; onSurfaceVariant = 0xFFC5C8BA;
            outline = 0xFF8F9285; outlineVariant = 0xFF44483D;
        }
    }

    private static int col(Context c, int id) { return c.getColor(id); }

    static int mix(int a, int b, float t) {
        return Color.argb(255,
                Math.round(Color.red(a) + (Color.red(b) - Color.red(a)) * t),
                Math.round(Color.green(a) + (Color.green(b) - Color.green(a)) * t),
                Math.round(Color.blue(a) + (Color.blue(b) - Color.blue(a)) * t));
    }

    static int alpha(int color, float a) { return (color & 0x00FFFFFF) | (Math.round(a * 255) << 24); }

    /** Transparent bars, light or dark icons to match the theme. */
    static void styleWindow(Window w) {
        w.setStatusBarColor(Color.TRANSPARENT);
        w.setNavigationBarColor(Color.TRANSPARENT);
        w.setBackgroundDrawable(new ColorDrawable(surface));
        if (Build.VERSION.SDK_INT >= 29) w.setNavigationBarContrastEnforced(false);
        if (Build.VERSION.SDK_INT >= 30) {
            w.setDecorFitsSystemWindows(false);
            int light = android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                    | android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS;
            android.view.WindowInsetsController ic = w.getInsetsController();
            if (ic != null) ic.setSystemBarsAppearance(dark ? 0 : light, light);
        } else {
            int f = View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION;
            if (!dark) f |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
            w.getDecorView().setSystemUiVisibility(f);
        }
    }

    // Spacing on the 8dp grid.
    static final int S1 = 4, S2 = 8, S3 = 12, S4 = 16, S6 = 24;

    static float dp(Context c, float v) {
        return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, c.getResources().getDisplayMetrics());
    }
    static int dpi(Context c, float v) { return Math.round(dp(c, v)); }

    // ---- Type scale (M3). size sp, line height sp, medium weight.
    enum Type {
        HEADLINE_SMALL(24, 32, false), TITLE_LARGE(22, 28, false), TITLE_MEDIUM(16, 24, true),
        TITLE_SMALL(14, 20, true), BODY_LARGE(16, 24, false), BODY_MEDIUM(14, 20, false),
        BODY_SMALL(12, 16, false), LABEL_LARGE(14, 20, true), LABEL_MEDIUM(12, 16, true);
        final float size, line; final boolean medium;
        Type(float s, float l, boolean m) { size = s; line = l; medium = m; }
    }

    static Typeface face(boolean medium) {
        return Typeface.create(medium ? "sans-serif-medium" : "sans-serif", Typeface.NORMAL);
    }

    static void type(TextView t, Type r) {
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, r.size);
        t.setTypeface(face(r.medium));
        float linePx = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, r.line, t.getResources().getDisplayMetrics());
        if (Build.VERSION.SDK_INT >= 28) t.setLineHeight(Math.round(linePx));
        else t.setLineSpacing(0f, r.line / r.size / 1.17f);
    }

    /** Wrapping text, never truncated. */
    static TextView text(Context c, CharSequence s, Type r, int color) {
        TextView t = new TextView(c);
        t.setText(s);
        t.setTextColor(color);
        type(t, r);
        t.setIncludeFontPadding(false);
        return t;
    }

    static TextView heading(Context c, CharSequence s, Type r, int color) {
        TextView t = text(c, s, r, color);
        t.setAccessibilityHeading(true);
        return t;
    }

    // ---- Icons (vector drawables in res/drawable).
    static Drawable icon(Context c, String name, int tint) {
        int id = c.getResources().getIdentifier(name, "drawable", c.getPackageName());
        if (id == 0) return null;
        Drawable d = c.getDrawable(id).mutate();
        d.setTint(tint);
        return d;
    }

    static ImageView iconView(Context c, String name, int tint) {
        ImageView v = new ImageView(c);
        v.setImageDrawable(icon(c, name, tint));
        v.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        return v;
    }

    // ---- Shapes and states.
    static GradientDrawable shape(int color, float radiusPx) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(color);
        g.setCornerRadius(radiusPx);
        return g;
    }

    static RippleDrawable ripple(int rippleBase, Drawable content, Drawable mask) {
        return new RippleDrawable(ColorStateList.valueOf(alpha(rippleBase, 0.12f)), content, mask);
    }

    /** Bounded ripple for a full-width row. */
    static Drawable rowRipple() {
        return ripple(onSurface, null, new ColorDrawable(Color.WHITE));
    }

    private static ColorStateList enabledList(int on, int off) {
        return new ColorStateList(new int[][]{new int[]{android.R.attr.state_enabled}, new int[]{}}, new int[]{on, off});
    }

    // ---- Buttons. 48dp tall (40dp visual + touch), fully rounded, sentence case.
    enum Btn { FILLED, TONAL, OUTLINED, TEXT }

    static Button button(Context c, String title, Btn kind, String iconName) {
        Button b = new Button(c, null, 0);
        b.setText(title);
        b.setAllCaps(false);
        b.setGravity(Gravity.CENTER);
        type(b, Type.LABEL_LARGE);
        b.setIncludeFontPadding(false);
        b.setMinHeight(dpi(c, 48)); b.setMinimumHeight(dpi(c, 48));
        b.setMinWidth(dpi(c, 48)); b.setMinimumWidth(dpi(c, 48));
        b.setStateListAnimator(null);
        int hp = kind == Btn.TEXT ? 12 : 24;
        b.setPadding(dpi(c, hp), dpi(c, 10), dpi(c, hp), dpi(c, 10));
        styleButton(b, kind, iconName);
        return b;
    }

    static void styleButton(Button b, Btn kind, String iconName) {
        Context c = b.getContext();
        float r = dp(c, 24);
        int fg, bg;
        switch (kind) {
            case FILLED: fg = onPrimary; bg = primary; break;
            case TONAL: fg = onSecondaryContainer; bg = secondaryContainer; break;
            default: fg = primary; bg = Color.TRANSPARENT; break;
        }
        int fgOff = alpha(onSurface, 0.38f);
        GradientDrawable g = new GradientDrawable();
        g.setCornerRadius(r);
        boolean filledish = kind == Btn.FILLED || kind == Btn.TONAL;
        g.setColor(filledish ? enabledList(bg, alpha(onSurface, 0.12f)) : ColorStateList.valueOf(Color.TRANSPARENT));
        if (kind == Btn.OUTLINED) g.setStroke(dpi(c, 1), enabledList(outline, alpha(onSurface, 0.12f)));
        // Inset 4dp top/bottom so the visual is 40dp inside a 48dp target.
        InsetDrawable inset = new InsetDrawable(g, 0, dpi(c, 4), 0, dpi(c, 4));
        InsetDrawable mask = new InsetDrawable(shape(Color.WHITE, r), 0, dpi(c, 4), 0, dpi(c, 4));
        b.setBackground(ripple(fg, inset, mask));
        ColorStateList fgList = enabledList(fg, fgOff);
        b.setTextColor(fgList);
        if (iconName != null) {
            Drawable d = icon(c, iconName, fg);
            if (d != null) {
                int s = dpi(c, 18);
                d.setBounds(0, 0, s, s);
                d.setTintList(fgList);
                b.setCompoundDrawablesRelative(d, null, null, null);
                b.setCompoundDrawablePadding(dpi(c, 8));
                int hp = kind == Btn.TEXT ? 12 : 16;
                b.setPaddingRelative(dpi(c, hp), b.getPaddingTop(), dpi(c, kind == Btn.TEXT ? 16 : 24), b.getPaddingBottom());
            }
        } else {
            b.setCompoundDrawablesRelative(null, null, null, null);
        }
    }

    static ImageButton iconButton(Context c, String iconName, String desc) {
        ImageButton b = new ImageButton(c);
        b.setImageDrawable(icon(c, iconName, onSurfaceVariant));
        b.setContentDescription(desc);
        b.setBackground(ripple(onSurfaceVariant, null, null));
        b.setScaleType(ImageView.ScaleType.CENTER);
        int s = dpi(c, 48);
        b.setMinimumWidth(s); b.setMinimumHeight(s);
        b.setLayoutParams(new LinearLayout.LayoutParams(s, s));
        return b;
    }

    // ---- Segmented button (two or more options, single select).
    static Button segment(Context c, String title, int index, int count) {
        Button b = new Button(c, null, 0);
        b.setText(title);
        b.setAllCaps(false);
        b.setGravity(Gravity.CENTER);
        type(b, Type.LABEL_LARGE);
        b.setIncludeFontPadding(false);
        b.setStateListAnimator(null);
        b.setMinHeight(dpi(c, 48)); b.setMinimumHeight(dpi(c, 48));
        b.setPadding(dpi(c, 12), dpi(c, 10), dpi(c, 12), dpi(c, 10));
        b.setTag(new int[]{index, count});
        return b;
    }

    static void selectSegment(Button b, boolean selected, boolean enabled) {
        Context c = b.getContext();
        int[] ic = (int[]) b.getTag();
        float r = dp(c, 20);
        float[] radii = ic[0] == 0 ? new float[]{r, r, 0, 0, 0, 0, r, r}
                : ic[0] == ic[1] - 1 ? new float[]{0, 0, r, r, r, r, 0, 0} : new float[8];
        GradientDrawable g = new GradientDrawable();
        g.setCornerRadii(radii);
        g.setColor(selected ? (enabled ? secondaryContainer : alpha(onSurface, 0.12f)) : Color.TRANSPARENT);
        g.setStroke(dpi(c, 1), enabled ? outline : alpha(onSurface, 0.12f));
        GradientDrawable m = new GradientDrawable();
        m.setCornerRadii(radii);
        m.setColor(Color.WHITE);
        // Overlap the shared 1dp edge so the two outlines read as one line.
        int over = ic[0] == 0 ? 0 : -dpi(c, 1);
        b.setBackground(ripple(onSurface, new InsetDrawable(g, over, dpi(c, 4), 0, dpi(c, 4)),
                new InsetDrawable(m, over, dpi(c, 4), 0, dpi(c, 4))));
        int fg = enabled ? (selected ? onSecondaryContainer : onSurface) : alpha(onSurface, 0.38f);
        b.setTextColor(fg);
        b.setEnabled(enabled);
        b.setSelected(selected);
        Drawable d = selected ? icon(c, "ic_check", fg) : null;
        if (d != null) { int s = dpi(c, 18); d.setBounds(0, 0, s, s); }
        b.setCompoundDrawablesRelative(d, null, null, null);
        b.setCompoundDrawablePadding(dpi(c, 8));
    }

    // ---- Selection controls.
    static Switch switchM3(Context c, String desc) {
        Switch s = new Switch(c);
        s.setContentDescription(desc);
        s.setShowText(false);
        s.setBackground(null);
        s.setTrackDrawable(switchTrack(c));
        s.setThumbDrawable(switchThumb(c));
        s.setThumbTintList(null);
        s.setTrackTintList(null);
        s.setMinimumHeight(dpi(c, 48));
        s.setMinHeight(dpi(c, 48));
        s.setSwitchPadding(0);
        return s;
    }

    private static Drawable switchTrack(Context c) {
        int w = dpi(c, 52), h = dpi(c, 32);
        StateListDrawable s = new StateListDrawable();
        s.addState(new int[]{-android.R.attr.state_enabled, android.R.attr.state_checked},
                track(c, w, h, alpha(onSurface, 0.12f), 0));
        s.addState(new int[]{-android.R.attr.state_enabled},
                track(c, w, h, alpha(surfaceContainerHighest, 0.12f), alpha(onSurface, 0.12f)));
        s.addState(new int[]{android.R.attr.state_checked}, track(c, w, h, primary, 0));
        s.addState(new int[]{}, track(c, w, h, surfaceContainerHighest, outline));
        return s;
    }

    private static GradientDrawable track(Context c, int w, int h, int fill, int stroke) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(fill);
        g.setCornerRadius(h / 2f);
        g.setSize(w, h);
        if (stroke != 0) g.setStroke(dpi(c, 2), stroke);
        return g;
    }

    private static Drawable switchThumb(Context c) {
        StateListDrawable s = new StateListDrawable();
        s.addState(new int[]{-android.R.attr.state_enabled, android.R.attr.state_checked}, thumb(c, 24, surface));
        s.addState(new int[]{-android.R.attr.state_enabled}, thumb(c, 16, alpha(onSurface, 0.38f)));
        s.addState(new int[]{android.R.attr.state_checked}, thumb(c, 24, onPrimary));
        s.addState(new int[]{}, thumb(c, 16, outline));
        return s;
    }

    private static Drawable thumb(Context c, int sizeDp, int color) {
        // 26 x 32 box so two thumbs make the 52dp track; the dot is centred in it.
        GradientDrawable g = new GradientDrawable();
        g.setShape(GradientDrawable.OVAL);
        g.setColor(color);
        int bw = dpi(c, 26), bh = dpi(c, 32), s = dpi(c, sizeDp);
        int ix = (bw - s) / 2, iy = (bh - s) / 2;
        InsetDrawable d = new InsetDrawable(g, ix, iy, bw - s - ix, bh - s - iy) {
            @Override public int getIntrinsicWidth() { return bw; }
            @Override public int getIntrinsicHeight() { return bh; }
        };
        return d;
    }

    static CheckBox checkBox(Context c) {
        CheckBox b = new CheckBox(c);
        b.setButtonTintList(new ColorStateList(new int[][]{
                new int[]{-android.R.attr.state_enabled}, new int[]{android.R.attr.state_checked}, new int[]{}},
                new int[]{alpha(onSurface, 0.38f), primary, onSurfaceVariant}));
        b.setBackground(ripple(primary, null, null));
        b.setMinimumWidth(dpi(c, 48)); b.setMinimumHeight(dpi(c, 48));
        return b;
    }

    // ---- Lists.
    /** One- to three-line list item: optional leading icon, text column, optional trailing views. */
    static final class Row {
        final LinearLayout view;
        final TextView headline, supporting;
        final ImageView leading;
        Row(LinearLayout v, TextView h, TextView s, ImageView l) { view = v; headline = h; supporting = s; leading = l; }
        void setSupporting(CharSequence s) {
            supporting.setText(s);
            supporting.setVisibility(s == null || s.length() == 0 ? View.GONE : View.VISIBLE);
        }
        void setEnabled(boolean en) {
            view.setEnabled(en);
            float a = en ? 1f : 0.38f;
            headline.setAlpha(a); supporting.setAlpha(a);
            if (leading != null) leading.setAlpha(a);
            for (int i = 0; i < view.getChildCount(); i++) view.getChildAt(i).setEnabled(en);
        }
    }

    static Row row(Context c, String headline, String supporting, String leadingIcon, View... trailing) {
        LinearLayout v = new LinearLayout(c);
        v.setOrientation(LinearLayout.HORIZONTAL);
        v.setGravity(Gravity.CENTER_VERTICAL);
        v.setMinimumHeight(dpi(c, 56));
        v.setPaddingRelative(dpi(c, S4), dpi(c, S2), dpi(c, trailing.length > 0 ? S2 : S4), dpi(c, S2));
        ImageView lead = null;
        if (leadingIcon != null) {
            lead = iconView(c, leadingIcon, onSurfaceVariant);
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(dpi(c, 24), dpi(c, 24));
            lp.setMarginEnd(dpi(c, S4));
            v.addView(lead, lp);
        }
        LinearLayout col = new LinearLayout(c);
        col.setOrientation(LinearLayout.VERTICAL);
        TextView h = text(c, headline, Type.BODY_LARGE, onSurface);
        TextView s = text(c, supporting == null ? "" : supporting, Type.BODY_MEDIUM, onSurfaceVariant);
        col.addView(h);
        col.addView(s);
        v.addView(col, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        for (View t : trailing) {
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            lp.setMarginStart(dpi(c, S2));
            if (t.getLayoutParams() instanceof LinearLayout.LayoutParams) {
                LinearLayout.LayoutParams o = (LinearLayout.LayoutParams) t.getLayoutParams();
                lp.width = o.width; lp.height = o.height;
            }
            v.addView(t, lp);
        }
        Row r = new Row(v, h, s, lead);
        r.setSupporting(supporting);
        return r;
    }

    static void clickable(View v, View.OnClickListener l) {
        v.setBackground(rowRipple());
        v.setFocusable(true);
        v.setClickable(true);
        v.setOnClickListener(l);
    }

    static View divider(Context c) {
        View v = new View(c);
        v.setBackgroundColor(outlineVariant);
        v.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        v.setLayoutParams(new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Math.max(1, dpi(c, 1))));
        return v;
    }

    static TextView subheader(Context c, String s) {
        TextView t = heading(c, s, Type.TITLE_SMALL, primary);
        t.setPaddingRelative(dpi(c, S4), dpi(c, S4), dpi(c, S4), dpi(c, S2));
        return t;
    }

    /** Filled card: surface container, 12dp corners, no border, no shadow. */
    static LinearLayout card(Context c) {
        LinearLayout l = new LinearLayout(c);
        l.setOrientation(LinearLayout.VERTICAL);
        l.setPadding(dpi(c, S4), dpi(c, S4), dpi(c, S4), dpi(c, S4));
        l.setBackground(shape(surfaceContainer, dp(c, 12)));
        return l;
    }

    static ProgressBar progress(Context c) {
        ProgressBar p = new ProgressBar(c, null, android.R.attr.progressBarStyleHorizontal);
        float r = dp(c, 2);
        GradientDrawable track = shape(secondaryContainer, r);
        ClipDrawable fill = new ClipDrawable(shape(primary, r), Gravity.START, ClipDrawable.HORIZONTAL);
        LayerDrawable ld = new LayerDrawable(new Drawable[]{track, fill});
        ld.setId(0, android.R.id.background);
        ld.setId(1, android.R.id.progress);
        p.setProgressDrawable(ld);
        p.setIndeterminate(false);
        p.setMax(1);
        return p;
    }

    static void space(LinearLayout root, int dp) {
        View v = new View(root.getContext());
        v.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        root.addView(v, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dpi(root.getContext(), dp)));
    }

    static void haptic(View v, boolean confirm) {
        if (v == null) return;
        int flag = (confirm && Build.VERSION.SDK_INT >= 30)
                ? HapticFeedbackConstants.CONFIRM
                : HapticFeedbackConstants.CONTEXT_CLICK;
        v.performHapticFeedback(flag);
    }


    // ---- Legacy v14.5 styling. Removed once every screen uses the tokens above.
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
