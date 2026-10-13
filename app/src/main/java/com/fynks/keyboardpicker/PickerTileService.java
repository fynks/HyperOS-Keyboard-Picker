package com.fynks.keyboardpicker;

import android.app.PendingIntent;
import android.content.Intent;
import android.service.quicksettings.Tile;
import android.service.quicksettings.TileService;

/**
 * Quick Settings tile that opens the keyboard chooser without going through the
 * home screen.
 *
 * <p>It launches {@link MainActivity} rather than calling the input method API
 * from here. The chooser is a system dialog attached to the calling window, and
 * the activity's delayed request is the path measured to work; duplicating the
 * picker logic in a service would be a second, unverified copy of it.
 */
public class PickerTileService extends TileService {

    @Override
    public void onStartListening() {
        super.onStartListening();
        // Opening the chooser is a momentary action with no state to reflect.
        Tile tile = getQsTile();
        if (tile != null) {
            tile.setState(Tile.STATE_INACTIVE);
            tile.updateTile();
        }
    }

    @Override
    public void onClick() {
        super.onClick();
        // The Intent overload of startActivityAndCollapse is deprecated as of API 34.
        PendingIntent openPicker = PendingIntent.getActivity(
                this,
                0,
                new Intent(this, MainActivity.class),
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
        startActivityAndCollapse(openPicker);
    }
}