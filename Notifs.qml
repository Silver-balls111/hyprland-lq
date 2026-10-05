pragma Singleton
import QtQml

// Notification history + do-not-disturb + toast stack state. The
// NotificationServer (shell.qml) feeds arrivals here. Entries are plain JS
// snapshots, NOT the Notification objects themselves — the server-side object
// is expired once its toast is done, while the history is meant to outlive it.
QtObject {
    id: root

    // newest-first, capped at maxHistory; each entry:
    // { id, appName, summary, body, appIcon, urgency, expireTimeout, when,
    //   notif } — `id` is stable (NotifsPanel's ListModel sync keys off it).
    // `notif` is the live Notification object, only set while a toast is up
    // (used to expire/dismiss it server-side).
    property var history: []
    // toast stack (newest first): entries currently showing as banners, each
    // with `expiresAt` (ms epoch). Expanded toasts are frozen by the ticker.
    property var activeToasts: []
    // an OSD (Osd.qml) is currently on screen — the toast stack shifts below it
    property bool osdShowing: false
    property bool dnd: false
    // stable per-entry id (ListModel sync in NotifsPanel keys off this)
    property int nextId: 0

    readonly property int maxHistory: 30
    readonly property int maxToastStack: 4

    function markRead() {
        root.unread = 0;
    }

    property int unread: 0

    function toastDuration(entry) {
        if (entry.expireTimeout > 0)
            return Math.max(2000, Math.min(15000, entry.expireTimeout));
        return entry.urgency === 2 ? 6000 : (entry.urgency === 0 ? 2000 : 4000);
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
            id: root.nextId++,
            appName: n.appName || "",
            summary: n.summary || "",
            body: n.body || "",
            appIcon: n.appIcon || "",
            urgency: n.urgency, // NotificationUrgency: 0 Low, 1 Normal, 2 Critical
            expireTimeout: n.expireTimeout, // ms; <=0 means the app gave no timeout
            when: new Date(),
            notif: null,
            expanded: false, // toast card state (Toast.qml)
            expiresAt: 0
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
        entry.expiresAt = Date.now() + toastDuration(entry);
        // cap the visual stack: the oldest toast leaves immediately
        while (root.activeToasts.length >= root.maxToastStack)
            root.dismissToast(root.activeToasts[root.activeToasts.length - 1], false);
        root.activeToasts = [entry].concat(root.activeToasts);
    }

    // ticker body (the Timer lives in Toast.qml — a QtObject singleton cannot
    // host children): retire toasts past their deadline; expanded ones freeze
    function expireTick() {
        const now = Date.now();
        for (let i = root.activeToasts.length - 1; i >= 0; i--) {
            const t = root.activeToasts[i];
            if (!t.expanded && now >= t.expiresAt)
                root.dismissToast(t, false);
        }
    }

    // remove one toast from the stack (+ server-side cleanup)
    function dismissToast(entry, byUser) {
        const i = root.activeToasts.indexOf(entry);
        if (i !== -1) {
            const next = root.activeToasts.slice();
            next.splice(i, 1);
            root.activeToasts = next;
        }
        if (entry.notif) {
            // the wrapper can die out-of-band (server-side lifecycle) — a dead
            // wrapper throws "Type error is not a function" on any method call
            try {
                if (byUser) entry.notif.dismiss();
                else entry.notif.expire();
            } catch (err) {
                console.warn("dismissToast: notif wrapper already gone:", err);
            }
            entry.notif = null;
        }
    }

    function remove(index) {
        if (index < 0 || index >= root.history.length) return;
        const t = root.history[index];
        if (root.activeToasts.indexOf(t) !== -1)
            root.dismissToast(t, false);
        const next = root.history.slice();
        next.splice(index, 1);
        root.history = next;
    }

    function clearAll() {
        const list = root.activeToasts;
        root.activeToasts = [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].notif) {
                try { list[i].notif.expire(); } catch (err) { console.warn("clearAll: notif wrapper already gone:", err); }
                list[i].notif = null;
            }
        }
        root.history = [];
    }

    onDndChanged: {
        if (dnd) {
            const list = root.activeToasts;
            root.activeToasts = [];
            for (let i = 0; i < list.length; i++) {
                if (list[i].notif) { list[i].notif.expire(); list[i].notif = null; }
            }
        }
    }
}
