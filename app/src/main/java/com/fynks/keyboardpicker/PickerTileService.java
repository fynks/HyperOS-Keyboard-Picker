package com.fynks.keyboardpicker;

import android.app.PendingIntent;
import android.content.Intent;
import android.graphics.drawable.Icon;
import android.os.Handler;
import android.os.Looper;
import android.service.quicksettings.Tile;
import android.service.quicksettings.TileService;
import android.widget.Toast;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Quick Settings tile that flips between this device's two keyboards in one tap.
 *
 * <p>The switch needs root because Android no longer lets a normal app change the
 * input method through public API. When root is unavailable, or either keyboard is
 * disabled, the tile falls back to launching {@link MainActivity}, which opens the
 * native chooser - the same root-free path the launcher icon uses.
 */
public class PickerTileService extends TileService {

    private static final ExecutorService WORKER = Executors.newSingleThreadExecutor();

    private final Handler main = new Handler(Looper.getMainLooper());

    @Override
    public void onStartListening() {
        super.onStartListening();
        refreshTile();
    }

    @Override
    public void onClick() {
        super.onClick();
        WORKER.execute(() -> {
            KeyboardFlip.Result result = new KeyboardFlip(this).flip();
            main.post(() -> {
                if (result == KeyboardFlip.Result.SWITCHED) {
                    refreshTile();
                } else {
                    Toast.makeText(this, R.string.tile_fallback_toast, Toast.LENGTH_SHORT).show();
                    openChooser();
                }
            });
        });
    }

    private void refreshTile() {
        Tile tile = getQsTile();
        if (tile == null) {
            return;
        }
        String current = new KeyboardFlip(this).currentId();
        String label = ImeIds.labelFor(current);
        tile.setLabel(label == null ? getString(R.string.tile_label) : label);
        tile.setIcon(Icon.createWithResource(this, R.drawable.ic_tile_keyboard));
        tile.setState(ImeIds.SWIFTKEY_ID.equals(current) ? Tile.STATE_ACTIVE : Tile.STATE_INACTIVE);
        String other = ImeIds.otherLabel(current);
        tile.setStateDescription(other == null
                ? getString(R.string.tile_state_open_chooser)
                : getString(R.string.tile_state_switch_to, other));
        tile.updateTile();
    }

    private void openChooser() {
        // The Intent overload of startActivityAndCollapse is deprecated as of API 34.
        PendingIntent openPicker = PendingIntent.getActivity(
                this,
                0,
                new Intent(this, MainActivity.class),
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
        startActivityAndCollapse(openPicker);
    }
}
