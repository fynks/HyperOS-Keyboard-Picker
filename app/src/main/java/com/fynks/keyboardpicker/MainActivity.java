package com.fynks.keyboardpicker;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.inputmethod.InputMethodManager;

/**
 * Opens Android's own keyboard chooser via
 * {@link InputMethodManager#showInputMethodPicker()} and gets out of the way.
 *
 * <p>The chooser is a system dialog attached to this activity's window, so the
 * activity has to stay alive while that dialog is up, and the window itself has
 * to be a real, opaque, focused one or the request is dropped silently.
 *
 * <p>The timing below is not decorative. Requesting the chooser as soon as the
 * activity is created, or from the first focus callback, was measured to fail on
 * Android 15 / HyperOS: the window has not been registered with the window
 * manager yet, so the dialog has nothing to attach to. A delayed first request
 * plus one retry is what reliably opens it. Focus changes, in turn, are the
 * reliable signal for when the chooser actually opened and closed.
 */
public class MainActivity extends Activity {

    /** Delay before the first request, once the window has settled. */
    private static final long FIRST_REQUEST_AFTER_MS = 500L;
    /** The first request is not always enough; ask once more. */
    private static final long RETRY_REQUEST_AFTER_MS = 1_500L;
    /** If the chooser never opened, close instead of stranding an idle window. */
    private static final long GIVE_UP_AFTER_MS = 10_000L;

    private static final int WAITING = 0;
    private static final int SHOWN = 1;
    private static final int CLOSED = 2;

    private final Handler ui = new Handler(Looper.getMainLooper());

    private InputMethodManager imm;
    private int state = WAITING;
    private boolean retried;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // An opaque view: a translucent or content-less window gets ignored.
        setContentView(R.layout.activity_main);

        imm = (InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
        if (imm == null) {
            finish();
            return;
        }
        ui.postDelayed(this::requestChooser, FIRST_REQUEST_AFTER_MS);
    }

    private void requestChooser() {
        if (isFinishing() || isDestroyed()) {
            return;
        }
        imm.showInputMethodPicker();
        ui.postDelayed(this::retryChooser, RETRY_REQUEST_AFTER_MS);
        ui.postDelayed(this::giveUp, GIVE_UP_AFTER_MS);
    }

    private void retryChooser() {
        if (retried || state != WAITING) {
            return;
        }
        retried = true;
        imm.showInputMethodPicker();
    }

    private void giveUp() {
        if (state == WAITING) {
            finish();
        }
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (state == WAITING && !hasFocus) {
            state = SHOWN;
        } else if (state == SHOWN && hasFocus) {
            state = CLOSED;
            finish();
        }
    }

    @Override
    protected void onDestroy() {
        ui.removeCallbacksAndMessages(null);
        super.onDestroy();
    }
}