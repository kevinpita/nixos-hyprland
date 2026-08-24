import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginComponent {
    id: root

    property var providers: []
    property bool binaryReady: false
    property bool isLoading: false
    property bool refreshQueued: false
    property bool requestTimedOut: false
    property string fetchError: ""
    property string stdoutBuffer: ""
    property string stderrBuffer: ""
    property string pluginDirectory: ""
    property string lastUpdated: ""
    property int clockTick: 0

    readonly property string providerSelection: String(pluginData.providerSelection || "codex,claude,antigravity")
    readonly property var selectedProviderIds: {
        const selected = parseCsv(providerSelection);
        return selected.length > 0 ? selected : ["codex"];
    }
    readonly property string favoriteSelection: pluginData.pillProviders !== undefined ? String(pluginData.pillProviders) : "codex"
    readonly property var favoriteProviderIds: {
        const selected = selectedProviderIds;
        const favorites = parseCsv(favoriteSelection);
        return favorites.filter(providerId => selected.indexOf(providerId) >= 0);
    }
    readonly property string barDisplayMode: String(pluginData.barDisplayMode || "percent")
    readonly property int barProviderIconSize: Math.max(1, Math.round(root.iconSize * 0.78))
    readonly property int refreshInterval: {
        const value = parseInt(pluginData.refreshInterval || "120000");
        return Number.isFinite(value) && value >= 30000 ? value : 120000;
    }
    readonly property string providerUsageScript: pluginDirectory + "/providers/get-provider-usage"
    readonly property string copilotUsageScript: pluginDirectory + "/providers/get-copilot-usage"
    readonly property var successfulProviders: providers.filter(provider => provider && provider.usage && !provider.error)
    readonly property var orderedProviders: selectedProviderIds.map(providerId => providerById(providerId) || ({
                provider: providerId,
                pending: true
            }))
    property var usageCommand: ["bash", providerUsageScript, selectedProviderIds.join(","), copilotUsageScript]

    function parseCsv(value) {
        const result = [];
        const parts = String(value || "").split(",");
        for (let index = 0; index < parts.length; index++) {
            const providerId = parts[index].trim().toLowerCase();
            if (providerId.length > 0 && result.indexOf(providerId) < 0) {
                result.push(providerId);
            }
        }
        return result;
    }

    function providerById(providerId) {
        for (let index = 0; index < providers.length; index++) {
            const provider = providers[index];
            if (provider && provider.provider === providerId) {
                return provider;
            }
        }
        return null;
    }

    function providerName(providerId) {
        const names = {
            codex: "Codex",
            claude: "Claude",
            copilot: "Copilot",
            antigravity: "Antigravity",
            gemini: "Gemini",
            cursor: "Cursor",
            openrouter: "OpenRouter",
            deepseek: "DeepSeek",
            opencode: "OpenCode",
            xai: "xAI",
            zai: "Z.AI"
        };
        const name = names[providerId];
        if (name) {
            return name;
        }
        const text = String(providerId || "");
        return text.length > 0 ? text.charAt(0).toUpperCase() + text.slice(1) : "Provider";
    }

    function providerError(provider) {
        if (!provider || !provider.error) {
            return "";
        }
        if (typeof provider.error === "string") {
            return provider.error;
        }
        return provider.error.message || "Usage is unavailable.";
    }

    function windowsForProvider(provider) {
        if (!provider || !provider.usage) {
            return [];
        }
        const windows = [];
        const slots = ["primary", "secondary", "tertiary"];
        for (let index = 0; index < slots.length; index++) {
            const slot = slots[index];
            const windowData = provider.usage[slot];
            if (!windowData) {
                continue;
            }
            windows.push({
                slot: slot,
                label: windowData.resetDescription || windowLabel(windowData.windowMinutes, slot),
                data: windowData
            });
        }
        return windows;
    }

    function windowLabel(windowMinutes, slot) {
        const minutes = Number(windowMinutes || 0);
        if (minutes > 0 && minutes <= 300) {
            return "Session";
        }
        if (minutes > 300 && minutes <= 10080) {
            return "Weekly";
        }
        if (minutes > 10080 && minutes <= 43200) {
            return "Monthly";
        }
        if (minutes > 43200) {
            return `${Math.round(minutes / 1440)} days`;
        }
        return slot === "primary" ? "Primary" : slot === "secondary" ? "Secondary" : "Other";
    }

    function strongestWindow(provider) {
        const windows = windowsForProvider(provider);
        let strongest = null;
        for (let index = 0; index < windows.length; index++) {
            const candidate = windows[index].data;
            if (!strongest || Number(candidate.usedPercent || 0) > Number(strongest.usedPercent || 0)) {
                strongest = candidate;
            }
        }
        return strongest;
    }

    function usedPercent(windowData) {
        if (!windowData) {
            return 0;
        }
        return Math.max(0, Math.min(100, Number(windowData.usedPercent || 0)));
    }

    function usageColor(percent) {
        if (percent >= 80) {
            return Theme.error;
        }
        if (percent >= 60) {
            return Theme.warning;
        }
        return Theme.success;
    }

    function usageStatus(percent) {
        if (percent >= 80) {
            return "Near limit";
        }
        if (percent >= 60) {
            return "Use with care";
        }
        return "Plenty available";
    }

    function providerColor(provider) {
        if (provider && provider.error) {
            return Theme.error;
        }
        const windowData = strongestWindow(provider);
        if (windowData) {
            return usageColor(usedPercent(windowData));
        }
        return isLoading ? Theme.primary : Theme.widgetIconColor;
    }

    function barIconColor(provider) {
        if (provider && provider.error) {
            return Theme.error;
        }
        const windowData = strongestWindow(provider);
        if (!windowData) {
            return Theme.primary;
        }
        const urgency = Math.max(0, Math.min(1, (usedPercent(windowData) - 40) / 60));
        return Theme.blend(Theme.primary, Theme.error, urgency);
    }

    function barTextColor(provider) {
        return provider && provider.error ? Theme.error : Theme.widgetTextColor;
    }

    function formatReset(resetTime) {
        clockTick;
        if (!resetTime) {
            return "No reset time";
        }
        const difference = new Date(resetTime).getTime() - Date.now();
        if (!Number.isFinite(difference) || difference <= 0) {
            return "Resets now";
        }
        const minutes = Math.floor(difference / 60000);
        if (minutes < 60) {
            return `Resets in ${minutes}m`;
        }
        const hours = Math.floor(minutes / 60);
        if (hours < 24) {
            return `Resets in ${hours}h ${minutes % 60}m`;
        }
        const days = Math.floor(hours / 24);
        return `Resets in ${days}d ${hours % 24}h`;
    }

    function windowValue(windowData) {
        if (!windowData) {
            return "—";
        }
        if (windowData.displayValue && String(windowData.displayValue).length > 0) {
            return String(windowData.displayValue);
        }
        return `${Math.round(usedPercent(windowData))}% used`;
    }

    function barValue(windowData) {
        if (!windowData) {
            return "—";
        }
        if (windowData.displayValue && String(windowData.displayValue).length > 0) {
            return String(windowData.displayValue);
        }
        return `${Math.round(usedPercent(windowData))}%`;
    }

    function isFavorite(providerId) {
        return favoriteProviderIds.indexOf(providerId) >= 0;
    }

    function toggleFavorite(providerId) {
        if (!pluginService) {
            return;
        }
        const next = favoriteProviderIds.slice();
        const index = next.indexOf(providerId);
        if (index >= 0) {
            next.splice(index, 1);
        } else {
            next.push(providerId);
        }
        pluginService.savePluginData("aiOverviewControl", "pillProviders", next.join(","));
    }

    function resolvePluginDirectory() {
        if (pluginService && pluginId) {
            const path = pluginService.getPluginPath(pluginId);
            if (path && path.length > 0) {
                pluginDirectory = path;
                return;
            }
        }
        const sourceUrl = Qt.resolvedUrl("NativeQuotaWidget.qml").toString();
        const sourcePath = sourceUrl.startsWith("file://") ? sourceUrl.substring(7) : sourceUrl;
        const separator = sourcePath.lastIndexOf("/");
        pluginDirectory = separator >= 0 ? sourcePath.substring(0, separator) : sourcePath;
    }

    function detectCollector() {
        if (collectorCheck.running) {
            return;
        }
        binaryReady = false;
        collectorCheck.running = true;
    }

    function refresh() {
        if (!binaryReady) {
            return;
        }
        if (usageProcess.running) {
            refreshQueued = true;
            return;
        }
        refreshQueued = false;
        requestTimedOut = false;
        isLoading = true;
        fetchError = "";
        stdoutBuffer = "";
        stderrBuffer = "";
        usageProcess.command = ["bash", providerUsageScript, selectedProviderIds.join(","), copilotUsageScript];
        usageProcess.running = true;
        fetchTimeout.restart();
    }

    Component.onCompleted: {
        resolvePluginDirectory();
        detectCollector();
    }

    onProviderSelectionChanged: {
        if (binaryReady) {
            refresh();
        }
    }

    Process {
        id: collectorCheck
        command: ["sh", "-c", "[ -x \"$1\" ] && command -v bash >/dev/null && command -v jq >/dev/null && command -v curl >/dev/null", "sh", root.providerUsageScript]
        onExited: exitCode => {
            root.binaryReady = exitCode === 0;
            if (root.binaryReady) {
                root.refresh();
            } else {
                root.fetchError = "The local quota collector is unavailable.";
            }
        }
    }

    Process {
        id: usageProcess
        command: root.usageCommand
        environment: ({
                AIOC_HISTORY_MAX: "2000"
            })
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => root.stdoutBuffer += data
        }
        stderr: SplitParser {
            onRead: data => root.stderrBuffer += data
        }
        onExited: exitCode => {
            fetchTimeout.stop();
            root.isLoading = false;
            if (root.requestTimedOut) {
                root.requestTimedOut = false;
            } else if (exitCode === 0 && root.stdoutBuffer.length > 0) {
                try {
                    const payload = JSON.parse(root.stdoutBuffer);
                    const entries = Array.isArray(payload) ? payload : [payload];
                    const flattened = [];
                    for (let index = 0; index < entries.length; index++) {
                        if (Array.isArray(entries[index])) {
                            flattened.push(...entries[index]);
                        } else {
                            flattened.push(entries[index]);
                        }
                    }
                    root.providers = flattened;
                    root.fetchError = "";
                    root.lastUpdated = Qt.formatDateTime(new Date(), "hh:mm");
                } catch (error) {
                    root.fetchError = "The quota response could not be read.";
                }
            } else if (exitCode === 0) {
                root.providers = [];
                root.fetchError = "No quota data was returned.";
            } else {
                root.fetchError = root.stderrBuffer.trim() || `The quota collector stopped with code ${exitCode}.`;
            }
            root.stdoutBuffer = "";
            root.stderrBuffer = "";
            if (root.refreshQueued) {
                Qt.callLater(root.refresh);
            }
        }
    }

    Timer {
        id: fetchTimeout
        interval: 45000
        repeat: false
        onTriggered: {
            if (usageProcess.running) {
                root.requestTimedOut = true;
                usageProcess.running = false;
                root.isLoading = false;
                root.fetchError = "The quota request timed out.";
            }
        }
    }

    Timer {
        interval: root.refreshInterval
        running: root.binaryReady
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.clockTick++
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            Repeater {
                model: root.favoriteProviderIds

                Row {
                    id: favoriteEntry
                    required property var modelData
                    readonly property var provider: root.providerById(modelData)
                    readonly property var windowData: root.strongestWindow(provider)
                    spacing: Theme.spacingXS

                    ProviderLogo {
                        providerId: favoriteEntry.modelData
                        logoSize: root.barProviderIconSize
                        tintColor: root.barIconColor(favoriteEntry.provider)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        visible: root.barDisplayMode !== "icon"
                        text: favoriteEntry.provider && favoriteEntry.provider.error
                            ? "!"
                            : favoriteEntry.windowData
                                ? root.barValue(favoriteEntry.windowData)
                                : "—"
                        color: root.barTextColor(favoriteEntry.provider)
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : undefined, root.barConfig ? root.barConfig.maximizeWidgetText : undefined)
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            DankIcon {
                visible: root.favoriteProviderIds.length === 0
                name: root.isLoading ? "sync" : "smart_toy"
                size: root.barProviderIconSize
                color: root.fetchError.length > 0 ? Theme.error : Theme.primary
                anchors.verticalCenter: parent.verticalCenter

                DankBlink {
                    target: parent
                    running: root.isLoading
                }
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            Repeater {
                model: root.favoriteProviderIds

                ProviderLogo {
                    required property var modelData
                    readonly property var provider: root.providerById(modelData)
                    providerId: modelData
                    logoSize: root.barProviderIconSize
                    tintColor: root.barIconColor(provider)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            DankIcon {
                visible: root.favoriteProviderIds.length === 0
                name: root.isLoading ? "sync" : "smart_toy"
                size: root.barProviderIconSize
                color: root.fetchError.length > 0 ? Theme.error : Theme.primary
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutWidth: 400
    popoutHeight: 0

    popoutContent: Component {
        Column {
            id: popout
            width: parent ? parent.width : 384
            spacing: Theme.spacingL

            Row {
                width: parent.width
                height: 48
                spacing: Theme.spacingM

                DankIcon {
                    name: "smart_toy"
                    size: Theme.iconSizeLarge
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    width: parent.width - Theme.iconSizeLarge - headerActions.width - Theme.spacingM * 2
                    spacing: Theme.spacingXXS
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: "AI quotas"
                        font.pixelSize: Theme.fontSizeXLarge
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: root.isLoading
                            ? "Updating…"
                            : `${root.successfulProviders.length} of ${root.selectedProviderIds.length} ready${root.lastUpdated.length > 0 ? ` · ${root.lastUpdated}` : ""}`
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                    }
                }

                Row {
                    id: headerActions
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: refreshArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.14) : "transparent"

                        DankIcon {
                            anchors.centerIn: parent
                            name: "refresh"
                            size: Theme.iconSize - 4
                            color: root.isLoading ? Theme.primary : Theme.surfaceText
                        }

                        MouseArea {
                            id: refreshArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: root.refresh()
                        }
                    }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: closeArea.containsMouse ? Theme.errorHover : "transparent"

                        DankIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: Theme.iconSize - 4
                            color: closeArea.containsMouse ? Theme.error : Theme.surfaceText
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: root.closePopout()
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: fetchErrorText.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.errorHover
                border.width: 0
                visible: root.fetchError.length > 0

                StyledText {
                    id: fetchErrorText
                    width: parent.width - Theme.spacingM * 2
                    anchors.centerIn: parent
                    text: root.fetchError
                    color: Theme.error
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }
            }

            DankFlickable {
                width: parent.width
                height: Math.min(providerList.implicitHeight, 560)
                contentWidth: width
                contentHeight: providerList.implicitHeight
                clip: true

                Column {
                    id: providerList
                    width: parent.width
                    spacing: Theme.spacingM

                    Repeater {
                        model: root.orderedProviders

                        ProviderCard {
                            required property var modelData
                            width: parent.width
                            provider: modelData
                        }
                    }
                }
            }
        }
    }

    component ProviderCard: StyledRect {
        id: card

        required property var provider
        readonly property string providerId: provider ? provider.provider : ""
        readonly property var windows: root.windowsForProvider(provider)
        readonly property var strongest: root.strongestWindow(provider)
        readonly property string errorMessage: root.providerError(provider)

        height: cardContent.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.nestedSurface
        border.width: 0

        Column {
            id: cardContent
            width: parent.width - Theme.spacingM * 2
            anchors.centerIn: parent
            spacing: Theme.spacingM

            Row {
                width: parent.width
                height: 32
                spacing: Theme.spacingM

                ProviderLogo {
                    providerId: card.providerId
                    logoSize: 24
                    tintColor: root.providerColor(card.provider)
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    width: parent.width - 24 - favoriteButton.width - usageSummary.width - Theme.spacingM * 3
                    spacing: Theme.spacingXXS
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        width: parent.width
                        text: root.providerName(card.providerId)
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        text: card.errorMessage.length > 0
                            ? "Unavailable"
                            : card.strongest
                                ? root.usageStatus(root.usedPercent(card.strongest))
                                : "Waiting for data"
                        color: card.errorMessage.length > 0
                            ? Theme.error
                            : card.strongest
                                ? root.usageColor(root.usedPercent(card.strongest))
                                : Theme.surfaceTextMedium
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    id: usageSummary
                    text: card.strongest ? `${Math.round(root.usedPercent(card.strongest))}%` : ""
                    color: card.strongest ? root.usageColor(root.usedPercent(card.strongest)) : Theme.surfaceTextMedium
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    id: favoriteButton
                    width: 32
                    height: 32
                    radius: 16
                    color: favoriteArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.14) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    DankIcon {
                        anchors.centerIn: parent
                        name: root.isFavorite(card.providerId) ? "star" : "star_border"
                        size: Theme.iconSize - 2
                        color: root.isFavorite(card.providerId) ? Theme.primary : Theme.surfaceTextMedium
                    }

                    MouseArea {
                        id: favoriteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: root.toggleFavorite(card.providerId)
                    }
                }
            }

            StyledText {
                width: parent.width
                visible: card.errorMessage.length > 0
                text: card.errorMessage
                color: Theme.error
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: parent.width
                visible: card.errorMessage.length === 0 && card.windows.length === 0
                text: root.isLoading ? "Loading quota windows…" : "No quota window is available."
                color: Theme.surfaceTextMedium
                font.pixelSize: Theme.fontSizeSmall
            }

            Column {
                width: parent.width
                spacing: Theme.spacingM
                visible: card.errorMessage.length === 0 && card.windows.length > 0

                Repeater {
                    model: card.windows

                    Column {
                        id: quotaWindow
                        required property var modelData
                        readonly property real percent: root.usedPercent(modelData.data)
                        width: parent.width
                        spacing: Theme.spacingXS

                        Row {
                            width: parent.width

                            StyledText {
                                width: parent.width - windowValue.width
                                text: quotaWindow.modelData.label
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            StyledText {
                                id: windowValue
                                text: root.windowValue(quotaWindow.modelData.data)
                                color: root.usageColor(quotaWindow.percent)
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 6
                            radius: 3
                            color: Theme.withAlpha(Theme.surfaceVariant, 0.8)

                            Rectangle {
                                width: parent.width * quotaWindow.percent / 100
                                height: parent.height
                                radius: parent.radius
                                color: root.usageColor(quotaWindow.percent)

                                Behavior on width {
                                    NumberAnimation {
                                        duration: Theme.mediumDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                            }
                        }

                        StyledText {
                            text: root.formatReset(quotaWindow.modelData.data.resetsAt)
                            color: Theme.surfaceTextMedium
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
            }
        }
    }
}
