package com.fynks.keyboardpicker;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.inputmethod.InputMethodManager;

/**
 * Opens the real system keyboard chooser via InputMethodManager#showInputMethodPicker().
 *
 * The recipe (delay + real focused host window) was reverse-engineered from Tasker's
 * working "Input Method Select" action (GenericActionActivityShowKeyboardSelector),
 * which sleeps 500ms and then calls showInputMethodPicker() from a dedicated,
 * fully visible Activity. A translucent, content-less host window is NOT enough on
 * HyperOS - the request is silently dropped.
 */
public class MainActivity extends Activity {
    private static final String TAG = "KeyboardPicker";

    private static final int WAITING = 0;      // picker requested, not yet seen
    private static final int PICKER_SHOWN = 1; // focus lost -> picker is up
    private static final int CLOSED = 2;       // focus returned -> picker dismissed

    /** Matches Tasker's working implementation. */
    private static final long PICKER_DELAY_MS = 500L;
    private static final long RETRY_AFTER_MS = 1500L;
    private static final long WATCHDOG_MS = 10000L;

    private final Handler ui = new Handler(Looper.getMainLooper());
    private InputMethodManager imm;
    private int state = WAITING;
    private boolean retried;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // A real, opaque, focused content view: the system attaches the picker dialog to
        // this window, so an empty/translucent window gets ignored.
        setContentView(R.layout.activity_main);

        imm = (InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
        if (imm == null) {
            Log.w(TAG, "InputMethodManager unavailable, finishing");
            finish();
            return;
        }
        Log.i(TAG, "onCreate, posting picker in " + PICKER_DELAY_MS + "ms");
        ui.postDelayed(this::requestPicker, PICKER_DELAY_MS);
    }

    private void requestPicker() {
        if (isFinishing() || isDestroyed()) return;
        Log.i(TAG, "showInputMethodPicker() state=" + state);
        imm.showInputMethodPicker(); // stays WAITING until focus is lost
        ui.postDelayed(this::maybeRetry, RETRY_AFTER_MS);
        ui.postDelayed(this::watchdog, WATCHDOG_MS);
    }

    /** If focus was never lost, the first call was dropped. Try exactly once more. */
    private void maybeRetry() {
        if (state != WAITING || retried) return;
        retried = true;
        Log.i(TAG, "no focus change yet, retrying showInputMethodPicker()");
        imm.showInputMethodPicker();
    }

    /** Never leave an invisible activity hanging around. */
    private void watchdog() {
        if (state != WAITING) return;
        Log.w(TAG, "picker never took focus after " + WATCHDOG_MS + "ms, giving up");
        finish();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (!hasFocus && state == WAITING) {
            // Picker took focus - the user can now choose.
            Log.i(TAG, "focus lost -> picker shown");
            state = PICKER_SHOWN;
            ui.removeCallbacks(this::watchdog);
        } else if (hasFocus && state == PICKER_SHOWN) {
            // Picker dismissed - now it is safe to tear down.
            Log.i(TAG, "focus returned -> picker dismissed, finishing");
            state = CLOSED;
            ui.removeCallbacks(this::maybeRetry);
            finish();
        }
    }

    @Override
    protected void onDestroy() {
        Log.i(TAG, "onDestroy state=" + state);
        ui.removeCallbacksAndMessages(null);
        super.onDestroy();
    }
}