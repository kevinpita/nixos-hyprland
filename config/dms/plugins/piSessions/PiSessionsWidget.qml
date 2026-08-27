import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "pi-sessions"

    property var sessions: []
    property var observedStatuses: ({})
    property string errorMessage: ""
    property bool refreshPending: false
    property bool baselineReady: false

    readonly property int maxStatusDots: 12
    readonly property var statusPalette: ({
        blocked: { label: "Needs input", color: Theme.error },
        done: { label: "Complete", color: Theme.success },
        working: { label: "Working", color: Theme.primary },
        idle: { label: "Idle", color: Theme.surfaceVariantText },
        unknown: { label: "Unknown", color: Theme.warning }
    })

    readonly property color accentColor: {
        if (hasStatus("blocked")) return Theme.error;
        if (hasStatus("done")) return Theme.success;
        if (hasStatus("working")) return Theme.primary;
        if (errorMessage.length > 0) return Theme.error;
        return Theme.surfaceVariantText;
    }

    function stateFor(status) {
        return statusPalette[status] || statusPalette.unknown;
    }

    function hasStatus(status) {
        for (let i = 0; i < sessions.length; i++) {
            if (sessions[i].status === status) return true;
        }
        return false;
    }

    function summaryText() {
        if (sessions.length === 0 && errorMessage.length > 0) return errorMessage;
        const noun = sessions.length === 1 ? "session" : "sessions";
        const summary = `${sessions.length} active Pi ${noun}`;
        return errorMessage.length > 0 ? `${summary} · ${errorMessage}` : summary;
    }

    function detailsFor(record) {
        const parts = [];
        if (record.project) parts.push(record.project);
        if (record.pid) parts.push(`PID ${record.pid}`);
        return parts.join(" · ");
    }

    function normalizedWindowAddress(value) {
        let address = String(value || "").toLowerCase();
        if (address.startsWith("address:")) address = address.slice(8);
        if (address.startsWith("0x")) address = address.slice(2);
        return address;
    }

    function sessionWindowAddress(record) {
        if (!CompositorService.isHyprland) {
            ToastService.showWarning("Cannot focus Pi session", "Hyprland is not active.");
            return "";
        }

        const toplevels = CompositorService.sortedToplevels || [];
        const windowAddress = normalizedWindowAddress(record.windowAddress);
        if (windowAddress) {
            for (let i = 0; i < toplevels.length; i++) {
                const toplevel = toplevels[i];
                if (toplevel && normalizedWindowAddress(toplevel.address) === windowAddress) {
                    return toplevel.address;
                }
            }
        }

        const titleSuffix = `π - ${String(record.label)} - ${String(record.project)}`;
        const matches = [];
        for (let i = 0; i < toplevels.length; i++) {
            const toplevel = toplevels[i];
            const title = String((toplevel && toplevel.title) || "");
            if (toplevel && toplevel.address && (title === titleSuffix || title.endsWith(` ${titleSuffix}`))) {
                matches.push(toplevel);
            }
        }

        if (matches.length !== 1) {
            const message = matches.length > 1
                ? "More than one terminal has this session title."
                : windowAddress
                    ? "The terminal window is no longer available."
                    : "Open this session and send one prompt to enable terminal focus.";
            ToastService.showWarning("Cannot focus Pi session", message);
            return "";
        }

        return matches[0].address;
    }

    function updateNotifications(nextSessions, hasError) {
        if (hasError) return;

        const nextStatuses = {};
        for (let i = 0; i < nextSessions.length; i++) {
            const record = nextSessions[i];
            const previousStatus = observedStatuses[record.id];
            const changed = previousStatus === undefined || previousStatus !== record.status;
            const details = record.project ? `${record.label} · ${record.project}` : record.label;
            const category = `pi-session-${record.pid}`;

            if (baselineReady && changed && record.status === "blocked") {
                ToastService.showWarning("Pi session needs input", details, "", category);
            } else if (baselineReady && changed && record.status === "done") {
                ToastService.showInfo("Pi session is ready", details, "", category);
            }
            nextStatuses[record.id] = record.status;
        }

        observedStatuses = nextStatuses;
        baselineReady = true;
    }

    function applyResponse(stdout, exitCode) {
        refreshPending = false;
        if (exitCode !== 0) {
            sessions = [];
            errorMessage = "Pi session helper failed";
            return;
        }

        try {
            const payload = JSON.parse(stdout);
            const nextSessions = Array.isArray(payload.sessions) ? payload.sessions : [];
            const nextError = payload.error ? String(payload.error) : "";
            updateNotifications(nextSessions, nextError.length > 0);
            sessions = nextSessions;
            errorMessage = nextError;
        } catch (error) {
            sessions = [];
            errorMessage = "Pi session helper returned invalid data";
        }
    }

    function refresh() {
        if (refreshPending) return;
        refreshPending = true;
        Proc.runCommand(
            "piSessions.refresh",
            ["@pi-session-status@"],
            (stdout, exitCode) => applyResponse(stdout, exitCode),
            50
        );
    }

    Component.onCompleted: Qt.callLater(refresh)

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "π"
                color: root.accentColor
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.errorMessage.length > 0 && root.sessions.length === 0
                    ? "!"
                    : root.sessions.length.toString()
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                visible: root.sessions.length > 0

                Repeater {
                    model: root.sessions.slice(0, root.maxStatusDots)

                    Rectangle {
                        required property var modelData

                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: width / 2
                        color: root.stateFor(modelData.status).color

                        SequentialAnimation on opacity {
                            running: modelData.status === "working"
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 600 }
                            NumberAnimation { to: 1; duration: 600 }
                        }
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.sessions.length > root.maxStatusDots
                    text: `+${root.sessions.length - root.maxStatusDots}`
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "π"
                color: root.accentColor
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.errorMessage.length > 0 && root.sessions.length === 0
                    ? "!"
                    : root.sessions.length.toString()
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            property string pendingWindowAddress: ""

            headerText: "Pi sessions"
            detailsText: root.summaryText()
            showCloseButton: true

            Connections {
                target: popout.parentPopout

                function onPopoutClosed() {
                    const address = popout.pendingWindowAddress;
                    popout.pendingWindowAddress = "";
                    if (address) HyprlandService.focusWindow(address);
                }
            }

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popout.headerHeight - popout.detailsHeight - Theme.spacingXL

                StyledText {
                    anchors.centerIn: parent
                    visible: root.sessions.length === 0
                    text: root.errorMessage.length > 0
                        ? "Status is unavailable."
                        : "No active Pi sessions."
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeMedium
                }

                ListView {
                    anchors.fill: parent
                    visible: root.sessions.length > 0
                    model: root.sessions
                    spacing: Theme.spacingS
                    clip: true

                    delegate: StyledRect {
                        id: sessionRow

                        required property var modelData

                        width: ListView.view.width
                        height: 58
                        radius: Theme.cornerRadius
                        color: sessionArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                        Row {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM

                            Rectangle {
                                id: statusDot

                                anchors.verticalCenter: parent.verticalCenter
                                width: 10
                                height: 10
                                radius: width / 2
                                color: root.stateFor(modelData.status).color
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - statusDot.width - statusLabel.implicitWidth - Theme.spacingM * 3
                                spacing: Theme.spacingXS

                                StyledText {
                                    width: parent.width
                                    text: modelData.label
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    width: parent.width
                                    text: root.detailsFor(modelData)
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideMiddle
                                }
                            }

                            StyledText {
                                id: statusLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.stateFor(modelData.status).label
                                color: root.stateFor(modelData.status).color
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                            }
                        }

                        MouseArea {
                            id: sessionArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const address = root.sessionWindowAddress(modelData);
                                if (!address) return;

                                if (popout.closePopout && popout.parentPopout) {
                                    popout.pendingWindowAddress = address;
                                    popout.closePopout();
                                    return;
                                }

                                HyprlandService.focusWindow(address);
                            }
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 380
    popoutHeight: 360
}
