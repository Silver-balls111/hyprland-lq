pragma Singleton
import QtQml

// Which popup is currently open ("clock", "wifi", "bt", "power", "tray" or
// "wall").
QtObject {
    property string active: ""
    property real lastDismiss: 0

    function toggle(name) {
        if (active === name) {
            close();
            return;
        }
        // If a popup was just dismissed by clicking outside, that same physical
        // click may also land on a bar pill — swallow it so the popup stays closed.
        const now = Date.now();
        if (lastDismiss && now - lastDismiss < 250) {
            lastDismiss = 0;
            return;
        }
        lastDismiss = 0;
        active = name;
    }

    function close() {
        active = "";
    }
}
