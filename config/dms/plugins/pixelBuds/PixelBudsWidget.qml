pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "pixel-buds"

    property string deviceAddress: ""
    property string deviceName: "Pixel Buds Pro 2"
    property bool bluetoothConnected: false
    property bool refreshPending: false
    property bool actionPending: false
    property int deviceGeneration: 0
    property var status: emptyStatus("")

    readonly property var leftBattery: status.battery.left
    readonly property var rightBattery: status.battery.right
    readonly property var caseBattery: status.battery.case
    readonly property bool controlsEnabled: bluetoothConnected && status.connected && !actionPending

    function emptyStatus(message) {
        return {
            schema: 1,
            connected: false,
            error: message || null,
            battery: {
                left: { level: null, charging: null },
                right: { level: null, charging: null },
                case: { level: null, charging: null }
            },
            anc: "unknown",
            settings: {
                onHeadDetection: null,
                multipoint: null,
                volumeEq: null,
                speechDetection: null
            }
        };
    }

    function findPixelBuds() {
        if (!BluetoothService.adapter || !BluetoothService.adapter.devices) return null;
        const devices = BluetoothService.adapter.devices.values || [];
        for (let index = 0; index < devices.length; index++) {
            const device = devices[index];
            const name = String((device && (device.name || device.deviceName)) || "").toLowerCase();
            if (device && name.includes("pixel buds pro")) return device;
        }
        return null;
    }

    function syncDevice() {
        const device = findPixelBuds();
        const nextAddress = device ? String(device.address || "") : "";
        const nextName = device ? String(device.name || device.deviceName || "Pixel Buds Pro 2") : "Pixel Buds Pro 2";
        const nextConnected = Boolean(device && device.connected && nextAddress.length > 0);
        const deviceChanged = nextConnected !== bluetoothConnected || nextAddress !== deviceAddress;
        const connectionStarted = nextConnected && deviceChanged;

        if (deviceChanged) {
            deviceGeneration++;
            refreshPending = false;
            actionPending = false;
        }
        deviceAddress = nextAddress;
        deviceName = nextName;
        bluetoothConnected = nextConnected;
        setVisibilityOverride(nextConnected);

        if (connectionStarted) {
            status = emptyStatus("");
            Qt.callLater(refresh);
        } else if (!nextConnected && status.connected) {
            status = emptyStatus("");
        }
    }

    function applyStatus(stdout, exitCode, requestedAddress, requestedGeneration) {
        if (requestedGeneration !== deviceGeneration) return;
        refreshPending = false;
        if (requestedAddress !== deviceAddress || !bluetoothConnected) return;
        if (exitCode !== 0) {
            status = emptyStatus("Pixel Buds status is unavailable.");
            return;
        }

        try {
            const payload = JSON.parse(stdout);
            if (payload.schema !== 1
                    || !payload.battery
                    || !payload.battery.left
                    || !payload.battery.right
                    || !payload.battery.case
                    || !payload.settings) {
                throw new Error("invalid schema");
            }
            status = payload;
        } catch (error) {
            status = emptyStatus("Pixel Buds returned invalid status data.");
        }
    }

    function refresh() {
        if (!bluetoothConnected || deviceAddress.length === 0 || refreshPending) return;
        const requestedAddress = deviceAddress;
        const requestedGeneration = deviceGeneration;
        refreshPending = true;
        Proc.runCommand(
            "",
            ["@pixel-buds-control@", "--device", requestedAddress, "status"],
            (stdout, exitCode) => applyStatus(stdout, exitCode, requestedAddress, requestedGeneration),
            0,
            30000
        );
    }

    function setValue(setting, value) {
        if (!controlsEnabled || deviceAddress.length === 0) return;
        const requestedAddress = deviceAddress;
        const requestedGeneration = deviceGeneration;
        actionPending = true;
        Proc.runCommand(
            "",
            ["@pixel-buds-control@", "--device", requestedAddress, "set", setting, String(value)],
            (stdout, exitCode) => {
                if (requestedGeneration !== deviceGeneration) return;
                actionPending = false;
                if (requestedAddress !== deviceAddress || !bluetoothConnected) return;
                if (exitCode !== 0) {
                    ToastService.showWarning("Pixel Buds", "The setting could not be changed.");
                    refresh();
                    return;
                }
                refresh();
            },
            0,
            12000
        );
    }

    function isBoolean(value) {
        return value === true || value === false;
    }

    function batteryText(battery) {
        return battery && battery.level !== null && battery.level !== undefined
            ? `${battery.level}%`
            : "—";
    }

    function batteryColor(battery) {
        if (!battery || battery.level === null || battery.level === undefined) return Theme.surfaceVariantText;
        if (battery.level <= 20) return Theme.error;
        if (battery.level <= 35) return Theme.warning;
        return Theme.success;
    }

    function barBatteryText() {
        const levels = [leftBattery.level, rightBattery.level].filter(level => level !== null && level !== undefined);
        if (levels.length === 0) return "—";
        return `${Math.min(...levels)}%`;
    }

    function ancLabel() {
        switch (status.anc) {
        case "active": return "Noise cancellation";
        case "aware": return "Transparency";
        case "off": return "Off";
        default: return "Mode unavailable";
        }
    }

    Component.onCompleted: Qt.callLater(syncDevice)

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.syncDevice()
    }

    Timer {
        interval: 30000
        running: root.bluetoothConnected
        repeat: true
        onTriggered: root.refresh()
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "earbuds_battery"
                size: root.iconSize
                color: root.status.error ? Theme.error : Theme.primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.barBatteryText()
                color: root.status.error ? Theme.error : Theme.widgetTextColor
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : undefined, root.barConfig ? root.barConfig.maximizeWidgetText : undefined)
                font.weight: Font.Medium
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXXS

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "earbuds_battery"
                size: root.iconSize
                color: root.status.error ? Theme.error : Theme.primary
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.barBatteryText()
                color: root.status.error ? Theme.error : Theme.widgetTextColor
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "Pixel Buds Pro 2"
            detailsText: root.status.error
                ? root.status.error
                : `${root.deviceName} · ${root.ancLabel()}`
            showCloseButton: true

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popout.headerHeight - popout.detailsHeight - Theme.spacingXL

                Column {
                    anchors.fill: parent
                    spacing: Theme.spacingL

                    StyledRect {
                        width: parent.width
                        height: errorText.implicitHeight + Theme.spacingM * 2
                        visible: Boolean(root.status.error)
                        radius: Theme.cornerRadius
                        color: Theme.errorHover
                        border.width: 0

                        StyledText {
                            id: errorText
                            anchors.centerIn: parent
                            width: parent.width - Theme.spacingM * 2
                            text: root.status.error || ""
                            color: Theme.error
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WordWrap
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: !root.status.error

                        SectionLabel { text: "Battery" }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            BatteryCard {
                                width: (parent.width - parent.spacing * 2) / 3
                                label: "Left"
                                iconName: "earbuds_battery"
                                battery: root.leftBattery
                            }

                            BatteryCard {
                                width: (parent.width - parent.spacing * 2) / 3
                                label: "Right"
                                iconName: "earbuds_battery"
                                battery: root.rightBattery
                            }

                            BatteryCard {
                                width: (parent.width - parent.spacing * 2) / 3
                                label: "Case"
                                iconName: "battery_full"
                                battery: root.caseBattery
                            }
                        }

                        StyledText {
                            width: parent.width
                            visible: root.caseBattery.level === null || root.caseBattery.level === undefined
                            text: "Put one bud in the case to read the case battery."
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: !root.status.error

                        SectionLabel { text: "Listening mode" }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            ModeButton {
                                width: (parent.width - parent.spacing * 2) / 3
                                label: "Off"
                                iconName: "noise_control_off"
                                selected: root.status.anc === "off"
                                controlEnabled: root.controlsEnabled
                                onActivated: root.setValue("anc", "off")
                            }

                            ModeButton {
                                width: (parent.width - parent.spacing * 2) / 3
                                label: "Cancel"
                                iconName: "noise_control_on"
                                selected: root.status.anc === "active"
                                controlEnabled: root.controlsEnabled
                                onActivated: root.setValue("anc", "active")
                            }

                            ModeButton {
                                width: (parent.width - parent.spacing * 2) / 3
                                label: "Aware"
                                iconName: "noise_aware"
                                selected: root.status.anc === "aware"
                                controlEnabled: root.controlsEnabled
                                onActivated: root.setValue("anc", "aware")
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: !root.status.error

                        SectionLabel { text: "Quick settings" }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            ToggleCard {
                                width: (parent.width - parent.spacing) / 2
                                label: "Wear detection"
                                iconName: "hearing"
                                checked: root.status.settings.onHeadDetection === true
                                controlEnabled: root.controlsEnabled && root.isBoolean(root.status.settings.onHeadDetection)
                                onToggled: value => root.setValue("ohd", value)
                            }

                            ToggleCard {
                                width: (parent.width - parent.spacing) / 2
                                label: "Multipoint"
                                iconName: "device_hub"
                                checked: root.status.settings.multipoint === true
                                controlEnabled: root.controlsEnabled && root.isBoolean(root.status.settings.multipoint)
                                onToggled: value => root.setValue("multipoint", value)
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            ToggleCard {
                                width: (parent.width - parent.spacing) / 2
                                label: "Volume EQ"
                                iconName: "graphic_eq"
                                checked: root.status.settings.volumeEq === true
                                controlEnabled: root.controlsEnabled && root.isBoolean(root.status.settings.volumeEq)
                                onToggled: value => root.setValue("volume-eq", value)
                            }

                            ToggleCard {
                                width: (parent.width - parent.spacing) / 2
                                label: "Conversation"
                                iconName: "settings_voice"
                                checked: root.status.settings.speechDetection === true
                                controlEnabled: root.controlsEnabled && root.isBoolean(root.status.settings.speechDetection)
                                onToggled: value => root.setValue("speech-detection", value)
                            }
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 420
    popoutHeight: 560

    component SectionLabel: StyledText {
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
    }

    component BatteryCard: StyledRect {
        id: batteryCard

        required property string label
        required property string iconName
        required property var battery

        height: 108
        radius: Theme.cornerRadius
        color: Theme.nestedSurface
        border.width: 0

        Column {
            anchors.centerIn: parent
            width: parent.width - Theme.spacingM * 2
            spacing: Theme.spacingXS

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: batteryCard.iconName
                size: Theme.iconSizeLarge
                color: root.batteryColor(batteryCard.battery)
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.batteryText(batteryCard.battery)
                color: root.batteryColor(batteryCard.battery)
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: batteryCard.battery && batteryCard.battery.charging === true
                    ? `${batteryCard.label} · Charging`
                    : batteryCard.label
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    component ModeButton: StyledRect {
        id: modeButton

        required property string label
        required property string iconName
        property bool selected: false
        property bool controlEnabled: false
        signal activated

        height: 52
        radius: Theme.cornerRadius
        color: selected ? Theme.primaryContainer : modeArea.containsMouse ? Theme.surfaceContainerHighest : Theme.nestedSurface
        border.width: 0
        opacity: controlEnabled ? 1 : 0.55

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: modeButton.iconName
                size: Theme.iconSize - 2
                color: modeButton.selected ? Theme.primary : Theme.surfaceVariantText
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: modeButton.label
                color: modeButton.selected ? Theme.primary : Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
            }
        }

        MouseArea {
            id: modeArea
            anchors.fill: parent
            enabled: modeButton.controlEnabled
            hoverEnabled: enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: modeButton.activated()
        }
    }

    component ToggleCard: StyledRect {
        id: toggleCard

        required property string label
        required property string iconName
        property bool checked: false
        property bool controlEnabled: false
        signal toggled(bool value)

        height: 66
        radius: Theme.cornerRadius
        color: toggleArea.containsMouse ? Theme.surfaceContainerHighest : Theme.nestedSurface
        border.width: 0
        opacity: controlEnabled ? 1 : 0.55

        Row {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: toggleCard.iconName
                size: Theme.iconSize - 2
                color: toggleCard.checked ? Theme.primary : Theme.surfaceVariantText
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.iconSize - switchTrack.width - Theme.spacingS * 2
                text: toggleCard.label
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Rectangle {
                id: switchTrack
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 22
                radius: height / 2
                color: toggleCard.checked ? Theme.primary : Theme.surfaceVariant

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: toggleCard.checked ? parent.width - width - 3 : 3
                    width: 16
                    height: 16
                    radius: width / 2
                    color: toggleCard.checked ? Theme.onPrimary : Theme.surfaceText

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }
        }

        MouseArea {
            id: toggleArea
            anchors.fill: parent
            enabled: toggleCard.controlEnabled
            hoverEnabled: enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: toggleCard.toggled(!toggleCard.checked)
        }
    }
}
