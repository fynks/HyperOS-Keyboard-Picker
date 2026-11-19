package com.fynks.keyboardpicker;

import android.content.Context;
import android.provider.Settings;

import java.util.concurrent.TimeUnit;

/** Switches between the two keyboards configured in {@link ImeIds}, using root. */
final class KeyboardFlip {

    enum Result { SWITCHED, UNAVAILABLE, FAILED }

    private final Context context;

    KeyboardFlip(Context context) {
        this.context = context;
    }

    String currentId() {
        return Settings.Secure.getString(context.getContentResolver(), Settings.Secure.DEFAULT_INPUT_METHOD);
    }

    Result flip() {
        String target = ImeIds.flip(currentId());
        if (target == null) {
            return Result.UNAVAILABLE;
        }

        Process process = null;
        try {
            process = new ProcessBuilder("/system/bin/su", "-c", "ime set " + target)
                    .redirectErrorStream(true)
                    .start();
            if (!process.waitFor(3, TimeUnit.SECONDS)) {
                process.destroyForcibly();
                return Result.FAILED;
            }
        } catch (Exception failure) {
            return Result.FAILED;
        }
        // The command's exit code is not enough: verify the setting actually changed.
        return target.equals(currentId()) ? Result.SWITCHED : Result.FAILED;
    }
}
