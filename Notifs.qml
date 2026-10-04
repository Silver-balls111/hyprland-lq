pragma Singleton
import QtQml

// Notification history + do-not-disturb + toast state. The NotificationServer
// (shell.qml) feeds arrivals here. Entries are plain JS snapshots, NOT the
// Notification objects themselves — the server-side object is expired once its
// toast is done, while the history is meant to outlive it.
QtObject {
    id: root

    // newest-first, capped at maxHistory; each entry:
    // { appName, summary, body, appIcon, urgency, expireTimeout, when, notif }
    // `notif` is the live Notification object, only set while a toast is up
    // (used to expire/dismiss it server-side).
    property var history: []
    // current toast entry (null = nothing showing)
    property var toast: null
    // an OSD (Osd.qml) is currently on screen — the toast shifts below it
    property bool osdShowing: false
    property bool dnd: false
    // history entries that arrived since the dashboard was last open
    property int unread: 0

    readonly property int maxHistory: 30

    function markRead() {
        root.unread = 0;
    }

    function push(n) {
        // keep the server-side object alive past this handler, otherwise the
        // wrapper dies and expire()/dismiss() become dead calls from the timer
        n.tracked = true;
        // OSD-style feedback (x-canonical-private-synchronous hint, e.g. the
        // old volume/brightness scripts' notify-send) is handled natively by
        // Osd.qml watching the services — drop these duplicates entirely so
        // they never double up with the real OSD
        const syncTag = n.hints["x-canonical-private-synchronous"];
        if (typeof syncTag === "string" && syncTag !== "") {
            n.expire();
            return;
        }
        const entry = {
            appName: n.appName || "",
            summary: n.summary || "",
            body: n.body || "",
            appIcon: n.appIcon || "",
            urgency: n.urgency, // NotificationUrgency: 0 Low, 1 Normal, 2 Critical
            expireTimeout: n.expireTimeout, // ms; <=0 means the app gave no timeout
            when: new Date(),
            notif: null
        };
        // history + unread ALWAYS happen for normal notifications — even
        // under DND or with the dashboard open. The branch below only
        // suppresses the toast; recording history after it silently lost
        // every DND'd notification (unread counted, panel empty).
        // Transient notifications (apps asking not to be stored) still toast
        // but skip history/unread.
        if (!n.transient) {
            root.history = [entry].concat(root.history).slice(0, root.maxHistory);
            if (Popups.active !== "clock") root.unread++;
        }
        if (root.dnd || Popups.active === "clock") {
            // toast suppressed — expire server-side so nothing lingers
            n.expire();
            return;
        }
        entry.notif = n;
        root.toast = entry;
    }

    function remove(index) {
        if (index < 0 || index >= root.history.length) return;
        const t = root.history[index];
        if (root.toast === t) {
            root.toast = null;
            if (t.notif) t.notif.expire();
        }
        const next = root.history.slice();
        next.splice(index, 1);
        root.history = next;
    }

    function clearAll() {
        if (root.toast && root.toast.notif) root.toast.notif.expire();
        root.history = [];
        root.toast = null;
    }

    // toast lifecycle: dismiss on click, expire on timeout
    function closeToast(dismiss) {
        if (!root.toast) return;
        const t = root.toast;
        root.toast = null;
        if (t.notif) {
            if (dismiss) t.notif.dismiss();
            else t.notif.expire();
            t.notif = null; // dead after this — don't double-expire from remove()/clearAll()
        }
    }

    onDndChanged: {
        if (dnd) closeToast(false);
    }
}
