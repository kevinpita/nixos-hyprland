import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    pluginId: "aiOverviewControl"

    StyledText {
        width: parent.width
        text: "The bar shows only favorite providers. Use the star buttons in the quota popout to change favorites."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeMedium
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "providerSelection"
        label: "Tracked providers"
        description: "Comma-separated provider IDs. The popout shows every provider in this list."
        placeholder: "codex,claude,antigravity"
        defaultValue: "codex,claude,antigravity"
    }

    StringSetting {
        settingKey: "pillProviders"
        label: "Bar favorites"
        description: "Comma-separated provider IDs shown in the bar. You can also change this with the star buttons."
        placeholder: "codex"
        defaultValue: "codex"
    }

    SelectionSetting {
        settingKey: "barDisplayMode"
        label: "Bar display"
        description: "Show each favorite as an icon, or as an icon with its highest usage value."
        options: [
            { label: "Icon and usage", value: "percent" },
            { label: "Icon only", value: "icon" }
        ]
        defaultValue: "percent"
    }

    SelectionSetting {
        settingKey: "refreshInterval"
        label: "Refresh interval"
        description: "How often quota data is updated."
        options: [
            { label: "1 minute", value: "60000" },
            { label: "2 minutes", value: "120000" },
            { label: "5 minutes", value: "300000" },
            { label: "15 minutes", value: "900000" }
        ]
        defaultValue: "120000"
    }
}
