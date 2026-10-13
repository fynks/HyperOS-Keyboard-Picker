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
 * plus one retry is what reliably opens it.
 *
 * <p>Focus is the signal for when the chooser opened and closed, but only after a
 * request has actually been made. Losing focus before then - to the notification
 * shade, a system dialog, or the screen turning off - says nothing about the
 * chooser, so {@link #IDLE} is tracked separately from {@link #PENDING}.
 */
public class MainActivity extends Activity {

    /** Delay before the first request, once the window has settled. */
    private static final long FIRST_REQUEST_AFTER_MS = 500L;
    /** The first request is not always enough; ask once more. */
    private static final long RETRY_REQUEST_AFTER_MS = 1_500L;
    /** If the chooser never opened, close instead of stranding an idle window. */
    private static final long GIVE_UP_AFTER_MS = 10_000L;

    /** Created, but no request has been made yet. */
    private static final int IDLE = 0;
    /** Request made; waiting to see whether the chooser opened. */
    private static final int PENDING = 1;
    /** The chooser took focus, so it is on screen. */
    private static final int SHOWN = 2;
    /** Focus returned after the chooser had it; safe to finish. */
    private static final int CLOSED = 3;

    private final Handler ui = new Handler(Looper.getMainLooper());
    // Held as fields: a method reference creates a new instance each time, so
    // removeCallbacks would not match the instance that was posted.
    private final Runnable requestTask = this::requestChooser;
    private final Runnable retryTask = this::retryChooser;
    private final Runnable giveUpTask = this::giveUp;

    private InputMethodManager imm;
    private int state = IDLE;
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
        ui.postDelayed(requestTask, FIRST_REQUEST_AFTER_MS);
    }

    private void requestChooser() {
        if (isFinishing() || isDestroyed()) {
            return;
        }
        state = PENDING;
        imm.showInputMethodPicker();
        ui.postDelayed(retryTask, RETRY_REQUEST_AFTER_MS);
        ui.postDelayed(giveUpTask, GIVE_UP_AFTER_MS);
    }

    private void retryChooser() {
        if (retried || state != PENDING) {
            return;
        }
        retried = true;
        imm.showInputMethodPicker();
    }

    private void giveUp() {
        // Still PENDING means the chooser never took focus: the request was
        // refused, so close instead of leaving a window that does nothing.
        if (state == PENDING) {
            finish();
        }
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (state == PENDING && !hasFocus) {
            // The chooser opened: the retry and the give-up timer are moot now.
            state = SHOWN;
            ui.removeCallbacks(retryTask);
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