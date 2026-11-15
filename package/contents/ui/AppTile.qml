/*
    SPDX-FileCopyrightText: 2026 andresdev5
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "code/tools.js" as Tools

Item {
    id: root

    required property string favoriteId
    property bool listMode: false
    property bool current: false
    property bool highlightActive: false
    property bool keyboardSelected: false

    readonly property var store: kickoff.favoriteGroups
    readonly property var favoritesModel: kickoff.rootModel.favoritesModel
    readonly property int sourceRow: store.favoritesRevision >= 0 ? store.sourceRowOf(favoriteId) : -1
    readonly property var model: ({ favoriteId: root.favoriteId })
    readonly property string displayName: roleValue(0) ?? ""
    readonly property string description: roleValue(257) ?? ""
    readonly property string gridLabel: roleValue(271) ?? roleValue(270) ?? roleValue(269) ?? displayName
    readonly property var decoration: roleValue(1)
    readonly property url url: roleValue(266) ?? ""
    readonly property Item dragIcon: listMode ? listIcon : gridIcon

    signal hoverEntered()

    function roleValue(role: int): var {
        return store.favoritesRevision >= 0 && sourceRow >= 0
            ? favoritesModel.data(favoritesModel.index(sourceRow, 0), role)
            : undefined
    }

    function activate(): void {
        if (sourceRow >= 0 && favoritesModel.trigger(sourceRow, "", null) && kickoff.hideOnWindowDeactivate) {
            kickoff.expanded = false
        }
    }

    function openMenu(x: var, y: var): void {
        let actions = Array.from(roleValue(265) ?? [])
        const favoriteActions = Tools.createFavoriteActions(i18n, favoritesModel, favoriteId)
        if (favoriteActions) {
            const at = actions.findIndex(action => ["addToDesktop", "addToTaskManager", "addToPanel"].includes(action?.actionId))
            if (at >= 0) {
                actions.splice(at, 0, ...favoriteActions)
            } else if (actions.length > 0) {
                actions.push({ type: "separator" }, ...favoriteActions)
            } else {
                actions = favoriteActions
            }
        }
        const groupActions = store.createActions(favoriteId)
        if (groupActions.length > 0) {
            actions = actions.concat([{ type: "separator" }], groupActions)
        }
        if (actions.length === 0) {
            return
        }
        ActionMenu.plasmoid = kickoff
        ActionMenu.menu.visualParent = menuAnchor
        ActionMenu.actionList = actions
        if (x !== undefined && y !== undefined) {
            ActionMenu.menu.open(x, y)
        } else {
            ActionMenu.menu.openRelative()
        }
    }

    function performDrag(active: bool): void {
        if (!active) {
            kickoff.dragSource.Drag.active = false
            kickoff.dragSource.Drag.imageSource = ""
            kickoff.dragSource.sourceItem = null
            return
        }
        root.dragIcon.grabToImage(result => {
            if (!dragHandler.active) {
                return
            }
            kickoff.dragSource.sourceItem = root
            kickoff.dragSource.Drag.imageSource = result.url
            kickoff.dragSource.Drag.mimeData = { "text/uri-list": [root.url.toString()] }
            kickoff.dragSource.Drag.active = true
        })
    }

    Accessible.role: Accessible.ListItem
    Accessible.name: displayName
    Accessible.description: description !== displayName ? description : ""

    Item {
        id: menuAnchor
        anchors.fill: parent
        readonly property int index: root.sourceRow
        readonly property QtObject view: QtObject {
            readonly property QtObject model: QtObject {
                function trigger(row: int, actionId: string, argument: var): bool {
                    return kickoff.rootModel.favoritesModel.trigger(row, actionId, argument)
                }
            }
        }
    }

    PlasmaExtras.Highlight {
        anchors.fill: parent
        hovered: true
        pressed: mouseArea.pressed
        active: root.highlightActive
        visible: mouseArea.containsMouse || (root.current && root.keyboardSelected)
    }

    ColumnLayout {
        visible: !root.listMode
        anchors.fill: parent
        anchors.leftMargin: KickoffSingleton.listItemMetrics.margins.left
        anchors.rightMargin: KickoffSingleton.listItemMetrics.margins.right
        anchors.topMargin: Kirigami.Units.smallSpacing * 2
        anchors.bottomMargin: Kirigami.Units.smallSpacing * 2
        spacing: KickoffSingleton.fontMetrics.descent

        Kirigami.Icon {
            id: gridIcon
            Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
            implicitWidth: Kirigami.Units.iconSizes.large
            implicitHeight: Kirigami.Units.iconSizes.large
            source: root.decoration ?? ""
            animated: false
            selected: mouseArea.pressed
        }

        PC3.Label {
            id: gridText
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.preferredHeight: lineCount === 1 ? implicitHeight * 2 : implicitHeight
            text: root.gridLabel
            textFormat: Text.PlainText
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            maximumLineCount: 2
            wrapMode: Text.Wrap
        }
    }

    RowLayout {
        visible: root.listMode
        anchors.fill: parent
        anchors.leftMargin: KickoffSingleton.listItemMetrics.margins.left
        anchors.rightMargin: KickoffSingleton.listItemMetrics.margins.right
        spacing: Kirigami.Units.smallSpacing * 2

        Kirigami.Icon {
            id: listIcon
            implicitWidth: Plasmoid.configuration.compactMode ? Kirigami.Units.iconSizes.smallMedium : Kirigami.Units.iconSizes.medium
            implicitHeight: implicitWidth
            source: root.decoration ?? ""
            animated: false
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            PC3.Label {
                Layout.fillWidth: true
                text: root.displayName
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }

            PC3.Label {
                Layout.fillWidth: true
                visible: !Plasmoid.configuration.compactMode && text.length > 0 && text !== root.displayName
                text: root.description
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: root.hoverEntered()
        onPressed: mouse => {
            root.hoverEntered()
            if (mouse.button === Qt.RightButton) {
                root.openMenu(mouse.x, mouse.y)
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.activate()
            }
        }
    }

    DragHandler {
        id: dragHandler
        target: null
        enabled: Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        onActiveChanged: root.performDrag(active)
    }

    PC3.ToolTip.text: !root.listMode && gridText.truncated ? root.displayName : ""
    PC3.ToolTip.visible: mouseArea.containsMouse && PC3.ToolTip.text.length > 0
    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
}
