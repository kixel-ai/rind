package io.github.steelhead99x.rindbench;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/**
 * Contender talks to moq-bench.dev for live demo sessions.
 * If health is missing, redirected to a login page, or not JSON, the app shows
 * "Session service not available yet" and does not invent a live session.
 */
final class ContenderClient {
    static final int AVAILABLE = 0, UNAVAILABLE = 1, UNREACHABLE = 2;
    static final String DEFAULT_BASE = "https://moq-bench.dev";

    final String baseURL;

    ContenderClient(String baseURL) {
        this.baseURL = baseURL == null || baseURL.isEmpty() ? DEFAULT_BASE : baseURL;
    }

    static final class Health {
        int status = UNAVAILABLE;
        String detail = "";
        String serviceName = "";
        boolean isLabReferee;
        String baseURL;
    }

    static final class Session {
        String code, name, presenter, state;
        List<JSONObject> ranks = new ArrayList<>();
    }

    interface HealthCb { void done(Health h); }
    interface SessionCb { void done(Session session, String error); }

    static final class HttpResult {
        int code;
        byte[] raw;
        String location = "";
        Exception err;
        String body() { return raw == null ? "" : new String(raw, StandardCharsets.UTF_8); }
        JSONObject json() {
            try { return raw == null ? null : new JSONObject(new String(raw, StandardCharsets.UTF_8)); }
            catch (Exception e) { return null; }
        }
    }

    void get(String path, java.util.function.Consumer<HttpResult> done) {
        new Thread(() -> {
            HttpResult r = new HttpResult();
            HttpURLConnection c = null;
            try {
                URL url = new URL(baseURL + path);
                c = (HttpURLConnection) url.openConnection();
                c.setInstanceFollowRedirects(false);
                c.setConnectTimeout(8000);
                c.setReadTimeout(8000);
                c.setRequestMethod("GET");
                c.setRequestProperty("Accept", "application/json");
                c.setUseCaches(false);
                // Do not send cookies: a Cloudflare Access login page is not a session service.
                try { c.setRequestProperty("Cookie", ""); } catch (Exception ignored) {}
                r.code = c.getResponseCode();
                String loc = c.getHeaderField("Location");
                if (loc != null) r.location = loc;
                InputStream in = r.code >= 400 ? c.getErrorStream() : c.getInputStream();
                if (in != null) {
                    ByteArrayOutputStream out = new ByteArrayOutputStream();
                    byte[] buf = new byte[4096];
                    int n;
                    while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
                    r.raw = out.toByteArray();
                }
            } catch (Exception e) {
                r.err = e;
            } finally {
                if (c != null) c.disconnect();
            }
            done.accept(r);
        }, "contender-http").start();
    }

    void probeHealth(HealthCb done) {
        Health h = new Health();
        h.baseURL = baseURL;
        if (baseURL == null || baseURL.isEmpty()) {
            h.status = UNAVAILABLE;
            h.detail = "No session address is set in this build.";
            done.done(h);
            return;
        }
        get("/api/health", r -> {
            if (r.err != null) {
                h.status = UNREACHABLE;
                h.detail = "Could not reach the session service.";
                done.done(h);
                return;
            }
            String body = r.body();
            boolean access = r.location.contains("cloudflareaccess.com")
                    || body.contains("Log in to moq-bench.dev")
                    || body.contains("Under construction");
            if (access || r.code == 302 || r.code == 401 || r.code == 403) {
                h.status = UNAVAILABLE;
                h.detail = "Session service not available yet.";
                done.done(h);
                return;
            }
            JSONObject json = r.json();
            if (json != null) {
                h.serviceName = json.optString("name", "");
                h.isLabReferee = "moq-contender-referee".equals(h.serviceName);
                h.status = AVAILABLE;
                h.detail = h.isLabReferee ? "Lab referee is reachable." : "Session service is reachable.";
                done.done(h);
                return;
            }
            h.status = UNAVAILABLE;
            h.detail = "Session service not available yet.";
            done.done(h);
        });
    }

    void lookupSession(String code, SessionCb done) {
        String enc;
        try { enc = java.net.URLEncoder.encode(code, "UTF-8").replace("+", "%20"); }
        catch (Exception e) { enc = code; }
        get("/api/sessions/" + enc, r -> {
            if (r.err != null) { done.done(null, "Could not reach the session service."); return; }
            if (r.code == 404) { done.done(null, "No session uses that code."); return; }
            String body = r.body();
            JSONObject json = r.json();
            if (r.code == 302 || r.code == 401 || r.code == 403
                    || r.location.contains("cloudflareaccess.com")
                    || body.contains("Log in to moq-bench.dev")
                    || json == null) {
                done.done(null, "Session service not available yet.");
                return;
            }
            Session s = new Session();
            s.code = code;
            s.name = first(json, "name", "title", "Session");
            s.presenter = first(json, "presenter", "host", "");
            s.state = first(json, "state", "status", "waiting");
            JSONArray ranks = json.optJSONArray("ranks");
            if (ranks != null) {
                for (int i = 0; i < ranks.length(); i++) s.ranks.add(ranks.optJSONObject(i));
            }
            done.done(s, null);
        });
    }

    private static String first(JSONObject o, String a, String b, String fallback) {
        String v = o.optString(a, "");
        if (!v.isEmpty()) return v;
        v = o.optString(b, "");
        return v.isEmpty() ? fallback : v;
    }

    static String codeFromQRString(String raw) {
        if (raw == null) return null;
        String s = raw.trim();
        if (s.isEmpty()) return null;
        try {
            URL u = new URL(s);
            String path = u.getPath() == null ? "" : u.getPath();
            String[] parts = path.split("/");
            java.util.ArrayList<String> bits = new java.util.ArrayList<>();
            for (String p : parts) if (p != null && !p.isEmpty()) bits.add(p);
            if (bits.size() >= 2) {
                String prev = bits.get(bits.size() - 2);
                if ("join".equals(prev) || "s".equals(prev) || "session".equals(prev))
                    return bits.get(bits.size() - 1);
            }
            if (bits.size() == 1) return bits.get(0);
        } catch (Exception ignored) {}
        String rest = Pattern.compile("[^A-Za-z0-9\\-_]").matcher(s).replaceAll("");
        return rest.isEmpty() ? null : rest;
    }

    static JSONObject scrubbedDeviceFromCatalog(JSONObject catalog) {
        // Coarse model and chip only. No device name, serial, UDID, or IP.
        JSONObject d = catalog != null ? catalog.optJSONObject("device") : null;
        if (d == null) d = new JSONObject();
        JSONObject out = new JSONObject();
        try {
            out.put("model", d.optString("product", "phone"));
            out.put("soc", d.optString("cpu", "unknown"));
        } catch (Exception ignored) {}
        return out;
    }

    static String neededEndpointsText() {
        return "This app looks for these addresses on moq-bench.dev:\n\n"
                + "GET /api/health\n"
                + "GET /api/sessions/{code}\n"
                + "POST /api/sessions/{code}/join\n"
                + "GET /api/sessions/{code}/status\n"
                + "POST /api/sessions/{code}/results\n\n"
                + "A QR code can be a short session code, or a link such as https://moq-bench.dev/join/{code}.\n\n"
                + "If a lab referee is used instead, the existing moq-contender routes apply: "
                + "GET /api/health, POST /api/announce, GET /api/assignment, POST /api/heartbeat, "
                + "POST /api/contendertrack, GET and POST /api/bouts, GET /api/live, GET /api/live-matches/{id}.\n\n"
                + "Nothing is sent until you turn Contender on and agree. Results shared with a session "
                + "are limited to timings and a coarse model and chip. No device name, serial, UDID, or IP.";
    }
}
