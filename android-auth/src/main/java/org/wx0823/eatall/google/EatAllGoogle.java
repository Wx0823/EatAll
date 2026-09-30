package org.wx0823.eatall.google;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import com.google.android.gms.common.GoogleApiAvailability;
import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.api.ApiException;
import com.google.android.gms.common.api.CommonStatusCodes;
import com.google.android.gms.games.PlayGames;
import com.google.android.gms.games.PlayGamesSdk;
import com.google.android.gms.games.GamesSignInClient;
import com.google.android.gms.games.gamessignin.AuthScope;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONObject;
import javax.net.ssl.HttpsURLConnection;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** PGS v2 platform auth + explicit OpenID consent; only the server establishes IGA identity. */
public final class EatAllGoogle extends GodotPlugin {
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final ExecutorService network = Executors.newSingleThreadExecutor();
    // All operation state is confined to the Android main thread. No credential is persisted.
    private int generation = 0;
    private boolean busy = false;
    private String sessionToken = "";
    private boolean initialized = false;

    public EatAllGoogle(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "EatAllGoogle"; }
    @Override public Set<SignalInfo> getPluginSignals() {
        return new HashSet<>(Arrays.asList(new SignalInfo("sign_in_succeeded", String.class),
                new SignalInfo("sign_in_failed", String.class)));
    }
    @Override public View onMainCreate(Activity activity) {
        if (is_configured() && activity != null) {
            PlayGamesSdk.initialize(activity.getApplicationContext());
            initialized = true;
        }
        return null;
    }
    @UsedByGodot public boolean is_configured() {
        try {
            URL endpoint = new URL(BuildConfig.AUTH_ENDPOINT);
            return BuildConfig.GAMES_APP_ID.matches("[1-9][0-9]+")
                    && BuildConfig.WEB_CLIENT_ID.endsWith(".apps.googleusercontent.com")
                    && endpoint.getProtocol().equals("https") && !endpoint.getHost().isEmpty()
                    && endpoint.getUserInfo() == null && endpoint.getQuery() == null
                    && endpoint.getRef() == null;
        } catch (Exception ignored) { return false; }
    }
    @UsedByGodot public void sign_in() { ui.post(this::beginSignIn); }
    private void beginSignIn() {
        if (busy) return;
        if (!is_configured()) { emitSignal("sign_in_failed", "not_configured"); return; }
        Activity activity = getActivity();
        if (activity == null || activity.isFinishing()) { emitSignal("sign_in_failed", "unavailable"); return; }
        if (GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(activity) != ConnectionResult.SUCCESS) {
            emitSignal("sign_in_failed", "services_unavailable"); return;
        }
        if (!initialized) { PlayGamesSdk.initialize(activity.getApplicationContext()); initialized = true; }
        busy = true;
        final int operation = ++generation;
        // Timeout also invalidates late SDK / network callbacks after guest selection or sign-out.
        ui.postDelayed(() -> fail(operation, "timeout"), 90000);
        GamesSignInClient client = PlayGames.getGamesSignInClient(activity);
        client.isAuthenticated().addOnCompleteListener(result -> {
            if (!active(operation)) return;
            if (result.isSuccessful() && result.getResult().isAuthenticated()) requestCode(client, operation);
            else client.signIn().addOnCompleteListener(manual -> {
                if (!active(operation)) return;
                if (manual.isSuccessful() && manual.getResult().isAuthenticated()) requestCode(client, operation);
                else fail(operation, errorCode(manual.getException()));
            });
        });
    }
    private void requestCode(GamesSignInClient client, int operation) {
        client.requestServerSideAccess(BuildConfig.WEB_CLIENT_ID, false, Arrays.asList(AuthScope.OPEN_ID))
            .addOnCompleteListener(result -> {
                if (!active(operation)) return;
                if (!result.isSuccessful()) { fail(operation, errorCode(result.getException())); return; }
                if (!result.getResult().getGrantedScopes().contains(AuthScope.OPEN_ID)) {
                    fail(operation, "consent_required"); return;
                }
                final String code = result.getResult().getAuthCode();
                if (code == null || code.isEmpty()) { fail(operation, "invalid_response"); return; }
                network.execute(() -> exchangeCode(operation, code));
            });
    }
    private void exchangeCode(int operation, String code) {
        try {
            String requestId = UUID.randomUUID().toString();
            JSONObject request = new JSONObject().put("auth_code", code).put("request_id", requestId);
            JSONObject response = post(BuildConfig.AUTH_ENDPOINT, request, "");
            String subject = response.optString("subject", "");
            String token = response.optString("session_token", "");
            if (!requestId.equals(response.optString("request_id")) || subject.isEmpty() || subject.length() > 255
                    || token.length() < 32 || token.length() > 4096 || response.optInt("expires_in", 0) <= 0)
                throw new IllegalStateException();
            ui.post(() -> {
                if (!active(operation)) {
                    if (!network.isShutdown()) network.execute(() -> revokeSession(token));
                    return;
                }
                busy = false;
                sessionToken = token;
                emitSignal("sign_in_succeeded", subject);
            });
        } catch (java.net.SocketTimeoutException e) { ui.post(() -> fail(operation, "timeout")); }
        catch (java.io.IOException e) { ui.post(() -> fail(operation, "network")); }
        catch (Exception e) { ui.post(() -> fail(operation, "verification_failed")); }
    }
    private JSONObject post(String endpoint, JSONObject body, String token) throws Exception {
        HttpsURLConnection connection = (HttpsURLConnection) new URL(endpoint).openConnection();
        // Never replace TLS certificate/hostname validation; do not follow a redirect with credentials.
        connection.setInstanceFollowRedirects(false);
        connection.setConnectTimeout(10000); connection.setReadTimeout(15000);
        connection.setRequestMethod("POST"); connection.setDoOutput(true);
        connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
        if (!token.isEmpty()) connection.setRequestProperty("Authorization", "Bearer " + token);
        byte[] payload = body.toString().getBytes(StandardCharsets.UTF_8);
        connection.setFixedLengthStreamingMode(payload.length);
        try {
            try (java.io.OutputStream out = connection.getOutputStream()) { out.write(payload); }
            if (connection.getResponseCode() != 200) throw new IllegalStateException();
            try (InputStream input = connection.getInputStream(); ByteArrayOutputStream output = new ByteArrayOutputStream()) {
                byte[] buffer = new byte[1024]; int count;
                while ((count = input.read(buffer)) != -1) {
                    if (output.size() + count > 16384) throw new IllegalStateException();
                    output.write(buffer, 0, count);
                }
                return new JSONObject(output.toString(StandardCharsets.UTF_8.name()));
            }
        } finally { connection.disconnect(); }
    }
    private boolean active(int operation) { return busy && operation == generation; }
    private void fail(int operation, String error) {
        if (!active(operation)) return;
        busy = false;
        emitSignal("sign_in_failed", error);
    }
    private String errorCode(Exception exception) {
        if (exception instanceof ApiException) {
            int code = ((ApiException) exception).getStatusCode();
            if (code == CommonStatusCodes.CANCELED || code == 12501) return "cancelled";
            if (code == CommonStatusCodes.NETWORK_ERROR) return "network";
            if (code == CommonStatusCodes.TIMEOUT) return "timeout";
        }
        return "unavailable";
    }
    @UsedByGodot public void sign_out() {
        ui.post(() -> {
            generation++; busy = false;
            String previous = sessionToken; sessionToken = "";
            if (!previous.isEmpty() && !network.isShutdown()) network.execute(() -> revokeSession(previous));
        });
    }
    private void revokeSession(String token) {
        try { post(BuildConfig.AUTH_ENDPOINT + "/logout", new JSONObject(), token); }
        catch (Exception ignored) { /* Local exit always works; server sessions have a short expiry. */ }
    }
    @Override public void onMainDestroy() {
        generation++; busy = false; sessionToken = "";
        ui.removeCallbacksAndMessages(null);
        network.shutdown();
    }
}
