import QtQuick
import Quickshell
import qs.config

// A seamless horizontal marquee, faded out at both ends.
//
// **Scrolling costs one number per step.** The line is rendered once into a
// texture (`strip`, redrawn only when the text changes) and drawn by a small
// shader (assets/shaders/ticker.frag) that offsets it, repeats it every
// `contentWidth` pixels -- so the loop has no seam -- and fades both ends. A
// step changes the shader's `offset` and nothing else: no text is laid out
// and no offscreen pass is made.
//
// It used to move two live copies of the text inside a layer masked by a
// MultiEffect, which re-rendered the layer and then the window for every step
// -- two frames per step, sixty a second, the whole bar redrawn each time.
// Measured in a nested session: the shell idled at 4.5% of a core with the old
// ticker, 3.0% with this one (one frame per step), and 0.7-1.0% with no ticker
// at all. What remains is the fixed cost of presenting a frame, thirty times a
// second, which any scrolling ticker pays.
Item {
    id: root

    property string text: ""
    property real speed: Appearance.metrics.tickerSpeed
    property real fade: Appearance.metrics.tickerFade

    readonly property real contentWidth: line.implicitWidth

    // The line, drawn once into the texture below and never shown itself.
    Text {
        id: line

        // A whole number of pixels wide, so the repeat lands exactly.
        width: Math.max(1, Math.ceil(implicitWidth))
        height: Math.ceil(implicitHeight)
        color: Tokens.color.dim
        text: root.text
        // Untrusted (a player's track title, among others): plain text only,
        // so markup in a title is shown as typed, never rendered.
        textFormat: Text.PlainText
        font.family: Tokens.font.data
        font.pixelSize: Appearance.size.ticker
        font.letterSpacing: Appearance.size.ticker * Appearance.tickerTracking
        renderType: Text.NativeRendering
    }

    ShaderEffectSource {
        id: strip

        sourceItem: line
        hideSource: true
        live: true // re-rendered only when the line itself changes
        smooth: false
        visible: false
    }

    ShaderEffect {
        id: scroller

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: line.height
        visible: root.contentWidth > 0

        property var source: strip
        property real offset: 0
        property real period: line.width
        property real viewWidth: width
        property real fade: root.fade

        vertexShader: Paths.url(Quickshell.shellPath("assets/shaders/ticker.vert.qsb"))
        fragmentShader: Paths.url(Quickshell.shellPath("assets/shaders/ticker.frag.qsb"))

        // **One whole pixel at a time, at exactly `speed` pixels a second.**
        // The text is natively rendered, so it only ever lands on whole pixels;
        // a smoother animation would draw the same positions twice.
        Timer {
            interval: Math.max(8, Math.round(1000 / Math.max(1, root.speed)))
            repeat: true
            running: root.contentWidth > 0 && root.visible && root.width > 0
            onTriggered: scroller.offset = (scroller.offset + 1) % Math.max(1, scroller.period)
        }
    }

    // A content change starts the loop again from the beginning, as before.
    onContentWidthChanged: scroller.offset = 0
}
