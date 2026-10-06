pragma Singleton
import QtQuick

// Cross-component lock switch: PowerPopup (or anything else in the shell tree)
// sets engaged = true to lock the session; Lockscreen.qml owns the real
// engage/unlock bookkeeping and clears it on successful authentication.
QtObject {
    property bool engaged: false
}
