package com.fynks.keyboardpicker;

/** Identities of the two keyboards this device actually switches between. */
final class ImeIds {

    static final String SWIFTKEY_ID = "com.touchtype.swiftkey.beta/com.touchtype.KeyboardService";
    static final String GBOARD_ID = "com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME";
    static final String SWIFTKEY_LABEL = "SwiftKey";
    static final String GBOARD_LABEL = "Gboard";

    static String flip(String currentId) {
        if (SWIFTKEY_ID.equals(currentId)) {
            return GBOARD_ID;
        }
        if (GBOARD_ID.equals(currentId)) {
            return SWIFTKEY_ID;
        }
        return null;
    }

    static String labelFor(String id) {
        if (SWIFTKEY_ID.equals(id)) {
            return SWIFTKEY_LABEL;
        }
        if (GBOARD_ID.equals(id)) {
            return GBOARD_LABEL;
        }
        return null;
    }

    static String otherLabel(String currentId) {
        return labelFor(flip(currentId));
    }
}
