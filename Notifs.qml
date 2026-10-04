pragma Singleton
import QtQml

// Notification history + do-not-disturb + toast state. The NotificationServer
// (shell.qml) feeds arrivals here. Entries are plain JS snapshots, NOT the
// Notification objects themselves — the server-side object is expired once its
// toast is done, while the history is meant to outlive it.
QtObject {
    id: root

    // newest-first, capped at maxHistory; each entry:
    // { appName, summary, body, appIcon, urgency, expireTimeout, when, notif,
    //   osdTag, osdValue } — history never contains OSD-style entries.
    // `notif` is the live Notification object, only set while a toast is up
    // (used to expire/dismiss it server-side).
    property var history: []
    // current toast entry (null = nothing showing)
    property var toast: null
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
        // OSD-style notifications (the user's volume/brightness keybind scripts
        // send notify-send -e -h string:x-canonical-private-synchronous:<tag>
        // -h int:value:<pct>): transient feedback, replace the current toast,
        // never stored in history and never counted unread. The tag + value are
        // kept on the entry for the future in-quickshell OSD.
        const syncTag = n.hints["x-canonical-private-synchronous"];
        const osd = (typeof syncTag === "string" && syncTag !== "") || n.transient;
        const entry = {
            appName: n.appName || "",
            summary: n.summary || "",
            body: n.body || "",
            appIcon: n.appIcon || "",
            urgency: n.urgency, // NotificationUrgency: 0 Low, 1 Normal, 2 Critical
            expireTimeout: n.expireTimeout, // ms; <=0 means the app gave no timeout
            when: new Date(),
            notif: null,
            osdTag: typeof syncTag === "string" ? syncTag : "",
            osdValue: typeof n.hints["value"] === "number" ? n.hints["value"] : -1
        };
        if (root.dnd || Popups.active === "clock") {
            // captured for history only — expire server-side so nothing lingers
            n.expire();
            if (!osd) root.unread++;
            return;
        }
        if (osd && root.toast && root.toast.notif) {
            root.toast.notif.expire();
            root.toast = null;
        }
        entry.notif = n;
        root.toast = entry;
        if (!osd) {
            root.history = [entry].concat(root.history).slice(0, root.maxHistory);
            root.unread++;
        }
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
