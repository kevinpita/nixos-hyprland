import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
    id: root

    property var pluginService: null
    property string trigger: ""

    signal itemsChanged

    Component.onCompleted: Hyprland.refreshToplevels()

    function findHyprlandWindow(toplevel, address) {
        const windows = Hyprland.toplevels?.values || [];
        for (const window of windows) {
            if (window?.wayland === toplevel || window?.address === address)
                return window;
        }
        return null;
    }

    function monitorName(window) {
        const directName = window?.monitor?.name || "";
        if (directName)
            return directName;

        const monitorId = window?.lastIpcObject?.monitor;
        const monitors = Hyprland.monitors?.values || [];
        for (const monitor of monitors) {
            const candidateId = monitor?.id ?? monitor?.lastIpcObject?.id;
            if (candidateId === monitorId)
                return monitor?.name || monitor?.lastIpcObject?.name || "";
        }
        return "";
    }

    function workspaceLabel(window) {
        const workspace = window?.lastIpcObject?.workspace || window?.workspace;
        const name = String(workspace?.name ?? workspace?.id ?? "");
        if (!name)
            return "";
        if (name.startsWith("special:"))
            return "Special " + name.substring(8);
        return "Workspace " + name;
    }

    function fallbackAppName(appId) {
        const genericParts = new Set(["com", "org", "net", "io", "desktop"]);
        const parts = appId.split(".").filter(part => !genericParts.has(part.toLowerCase()));
        const name = parts.length > 0 ? parts[parts.length - 1] : appId;
        return name.replace(/[-_]+/g, " ").replace(/\b\w/g, character => character.toUpperCase()) || "Window";
    }

    function windowItem(toplevel, index) {
        const appId = String(toplevel?.appId || "");
        const desktopEntry = appId ? DesktopEntries.heuristicLookup(appId) : null;
        const appName = String(desktopEntry?.name || fallbackAppName(appId));
        const title = String(toplevel?.title || "").trim();
        const displayName = title && title.toLowerCase() !== appName.toLowerCase() ? appName + " — " + title : appName;
        const knownAddress = String(toplevel?.address || "");
        const window = findHyprlandWindow(toplevel, knownAddress);
        const hyprlandAddress = String(window?.address || knownAddress);
        const address = hyprlandAddress || appId + ":" + title + ":" + index;
        const workspace = workspaceLabel(window);
        const monitor = monitorName(window);
        const metadata = [workspace, monitor].filter(value => value.length > 0);
        const icon = String(desktopEntry?.icon || appId || "material:select_window");

        return {
            id: address,
            name: displayName,
            icon: icon,
            comment: metadata.join(" · "),
            action: "focus:" + address,
            categories: ["Open Windows"],
            keywords: [appId, appName, title, workspace, monitor, "open", "running", "window"],
            address: address,
            hyprlandAddress: hyprlandAddress,
            toplevel: toplevel,
            primaryAction: {
                name: "Focus",
                icon: "select_window",
                action: "execute"
            }
        };
    }

    function getItems(_query) {
        const items = [];
        const windows = ToplevelManager.toplevels?.values || [];
        for (let index = 0; index < windows.length; index++)
            items.push(windowItem(windows[index], index));
        return items;
    }

    function executeItem(item) {
        const address = String(item?.hyprlandAddress || "");
        if (/^(0x)?[0-9a-f]+$/i.test(address)) {
            const prefixedAddress = address.startsWith("0x") ? address : "0x" + address;
            Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + prefixedAddress + "\" })");
            return;
        }
        if (item?.toplevel)
            item.toplevel.activate();
    }

    Connections {
        target: ToplevelManager.toplevels

        function onValuesChanged() {
            root.itemsChanged();
        }
    }
}
