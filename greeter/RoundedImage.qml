import QtQuick

Item {
    id: root
    property string source: ""
    property real rounding: 0
    property alias imgStatus: hiddenImg.status

    Image {
        id: hiddenImg
        visible: false
        source: root.source
        asynchronous: true
        cache: true
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (hiddenImg.status !== Image.Ready || root.source === "") return;
            ctx.beginPath();
            const r = root.rounding;
            const w = width, h = height;
            ctx.moveTo(r, 0);
            ctx.lineTo(w - r, 0);
            ctx.arcTo(w, 0, w, r, r);
            ctx.lineTo(w, h - r);
            ctx.arcTo(w, h, w - r, h, r);
            ctx.lineTo(r, h);
            ctx.arcTo(0, h, 0, h - r, r);
            ctx.lineTo(0, r);
            ctx.arcTo(0, 0, r, 0, r);
            ctx.closePath();
            ctx.clip();
            ctx.drawImage(hiddenImg, 0, 0, w, h);
        }
    }

    Connections {
        target: hiddenImg
        function onStatusChanged() {
            if (hiddenImg.status === Image.Ready) canvas.requestPaint();
        }
    }

    onSourceChanged: {
        canvas.requestPaint();
    }
}
