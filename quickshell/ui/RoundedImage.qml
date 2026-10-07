import QtQuick

// Rounded-corner image. The original implementation masked through
// MultiEffect (offscreen white mask item) — probes (2026-10-05) showed the
// maskSource texture NEVER samples inside layer-shell windows: mask-enabled
// MultiEffects render nothing while the same effect without a mask renders
// fine (both offscreen and on-screen mask items fail). The lock screen never
// caught it because the photo file never existed and the media card block is
// commented out. Rewritten as a Canvas-drawn clip — software-rasterized, so
// it works in every window type. The hidden Image still feeds `imgStatus`
// and the natural size (sourceSize read-back) for cover-crop math.
Item {
    id: ri

    property alias source: img.source
    property alias imgStatus: img.status
    // corner radius; width/2 (with a square item) = circle
    property real rounding: 0

    Image {
        id: img
        visible: false // painted only by the Canvas below
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        onStatusChanged: cvs.requestPaint()
    }

    Canvas {
        id: cvs
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (img.status !== Image.Ready || ri.source === "") return;
            ctx.save();
            const r = Math.min(ri.rounding, width / 2, height / 2);
            ctx.beginPath();
            ctx.moveTo(r, 0);
            ctx.arcTo(width, 0, width, height, r);
            ctx.arcTo(width, height, 0, height, r);
            ctx.arcTo(0, height, 0, 0, r);
            ctx.arcTo(0, 0, width, 0, r);
            ctx.closePath();
            ctx.clip();
            // cover-crop (PreserveAspectCrop parity): scale to fill, center
            const nat = img.sourceSize; // read-back gives the natural size
            if (nat.width > 0 && nat.height > 0) {
                const s = Math.max(width / nat.width, height / nat.height);
                const dw = nat.width * s;
                const dh = nat.height * s;
                ctx.drawImage(ri.source, (width - dw) / 2, (height - dh) / 2, dw, dh);
            } else {
                ctx.drawImage(ri.source, 0, 0, width, height);
            }
            ctx.restore();
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    // register the pixel data with the canvas for every new source
    onSourceChanged: {
        if (source !== "")
            cvs.loadImage(source);
        cvs.requestPaint();
    }
    Component.onCompleted: if (source !== "") cvs.loadImage(source);
}
