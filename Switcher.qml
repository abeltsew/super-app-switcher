import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    property var managedWindows: ToplevelManager.toplevels.values
    // Keep order stable while removing windows that actually disappeared.
    onManagedWindowsChanged: reconcileWindows()
    function reconcileWindows() {
        if (!opened) return;
        const chosen = windows[selected];
        const remaining = windows.filter(w => w && w.wayland && managedWindows.indexOf(w.wayland) !== -1);
        if (!remaining.length) { cancel(); return; }
        if (remaining.length === windows.length) return;
        const nextIndex = remaining.indexOf(chosen);
        windows = remaining;
        selected = nextIndex >= 0 ? nextIndex : Math.min(selected, remaining.length - 1);
    }
    function closeWindow(index) {
        const window = windows[index];
        // Keep the card until the compositor confirms closure. Apps can refuse
        // or display a save dialog; never force-kill them or hide them early.
        if (opened && window && window.wayland) window.wayland.close();
    }
    function open(payload) { cycle(payload && payload.direction === "previous" ? -1 : 1); }
    function close() { cancel(); }
    Component.onDestruction: { if (opened) Hyprland.dispatch('hl.dsp.submap("reset")'); }
    Timer {
        interval: 150
        running: root.opened
        repeat: true
        onTriggered: root.reconcileWindows()
    }
    property bool opened: false
    property var windows: []
    property int selected: 0
    property var targetScreen: null
    function cycle(step) {
        if (!opened) {
            Hyprland.refreshToplevels();
            windows = Hyprland.toplevels.values.filter(w => w.wayland !== null).sort((a,b) => (a.lastIpcObject.focusHistoryID ?? 999) - (b.lastIpcObject.focusHistoryID ?? 999));
            if (!windows.length) return;
            targetScreen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0];
            selected = 0;
            Hyprland.dispatch('hl.dsp.submap("super-app-switch")');
            opened = true;
        }
        selected = (selected + step + windows.length) % windows.length;
    }
    function accept() {
        if (!opened) return;
        let w = windows[selected];
        opened = false;
        Hyprland.dispatch('hl.dsp.submap("reset")');
        if (w && w.wayland) w.wayland.activate();
        windows = [];
    }
    function cancel() {
        opened = false;
        Hyprland.dispatch('hl.dsp.submap("reset")');
        windows = [];
    }
    IpcHandler {
        target: "super-app-switch"
        function next(): void { root.cycle(1); }
        function previous(): void { root.cycle(-1); }
        function accept(): void { root.accept(); }
        function cancel(): void { root.cancel(); }
        function closeSelected(): void { root.closeWindow(root.selected); }
        function status(): string { return JSON.stringify({open: root.opened, windows: root.windows.length, selected: root.selected, previews: cards.contentItem.children.filter(c => c.previewReady === true).length}); }
    }
    PanelWindow {
        id: panel
        visible: root.opened
        screen: root.targetScreen
        implicitWidth: Math.min((screen?.width || 1200) - 80, Math.max(300, root.windows.length * 254 + 26))
        implicitHeight: 236 + footer.implicitHeight + 16
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "super-app-switch"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        Rectangle {
            anchors.fill: parent
            radius: 22
            color: "#f0222430"
            border.color: "#66708090"
            border.width: 1
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) root.cancel();
                else if (event.key === Qt.Key_Tab) root.cycle(event.modifiers & Qt.ShiftModifier ? -1 : 1);
                else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left) root.cycle(-1);
                else if (event.key === Qt.Key_Right) root.cycle(1);
                else if (event.key === Qt.Key_Return) root.accept();
                else if (event.key === Qt.Key_W && !event.isAutoRepeat) root.closeWindow(root.selected);
                event.accepted = true;
            }
            Keys.onReleased: event => { if (event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R) root.accept(); }
            ListView {
                id: cards
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                height: 196
                orientation: ListView.Horizontal
                spacing: 14
                clip: true
                model: root.windows
                currentIndex: root.selected
                highlightRangeMode: ListView.ApplyRange
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    property bool previewReady: preview.hasContent
                    width: 240; height: 196; radius: 12
                    color: index === root.selected ? "#475976" : "#30333f"
                    border.width: index === root.selected ? 3 : 1
                    border.color: index === root.selected ? "#a6c8ff" : "#555966"
                    ScreencopyView {
                        id: preview
                        anchors.centerIn: previewArea
                        captureSource: root.opened ? card.modelData?.wayland : null
                        live: root.opened
                        constraintSize: Qt.size(220, 140)
                    }
                    Item { id: previewArea; x: 10; y: 10; width: 220; height: 140 }
                    Text {
                        anchors.centerIn: previewArea
                        visible: !preview.hasContent
                        text: card.modelData?.wayland?.appId || "Window"
                        textFormat: Text.PlainText
                        color: "#ffffff"; width: 210; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        x: 12; y: 160; width: 216; height: 26
                        text: card.modelData?.wayland?.title || "Window"
                        textFormat: Text.PlainText
                        elide: Text.ElideRight; color: "#ffffff"; font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        onPositionChanged: { if (containsMouse) root.selected = card.index; }
                        onClicked: { root.selected = card.index; root.accept(); }
                    }
                    Rectangle {
                        id: closeButton
                        anchors { top: parent.top; right: parent.right; margins: 7 }
                        width: 28; height: 28; radius: 14
                        z: 2
                        color: closeMouse.containsMouse ? "#e05263" : "#e6222430"
                        border.color: "#aab8bfcc"
                        border.width: 1
                        Accessible.role: Accessible.Button
                        Accessible.name: "Close " + (card.modelData?.wayland?.title || "window")
                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: "white"
                            font.pixelSize: 23
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            onClicked: root.closeWindow(card.index)
                        }
                    }
                }
            }
            Text {
                id: footer
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Tab to cycle  ·  Shift+Tab to go back  ·  W to close selected app  ·  Release Super to switch  ·  Esc to cancel"
                color: "#b8bfcc"; font.pixelSize: 11
            }
        }
    }
}
