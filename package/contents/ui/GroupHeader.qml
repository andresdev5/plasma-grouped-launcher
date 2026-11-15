/*
    SPDX-FileCopyrightText: 2026 andresdev5
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

Item {
    id: root

    required property var section
    required property int position
    required property int total
    required property int itemCount

    readonly property var store: kickoff.favoriteGroups
    readonly property bool collapsed: section.collapsed === true
    readonly property Item draggedItem: kickoff.dragSource.sourceItem
    readonly property string draggedFavoriteId: draggedItem ? String(draggedItem.model?.favoriteId ?? "") : ""
    readonly property string draggedFolderId: draggedItem ? String(draggedItem.draggedFolderId ?? "") : ""

    implicitHeight: Math.max(KickoffSingleton.compactListDelegateHeight, title.implicitHeight + Kirigami.Units.smallSpacing * 2)

    function toggle(): void {
        store.setSectionCollapsed(section.id, !collapsed)
    }

    PlasmaExtras.Highlight {
        anchors.fill: parent
        hovered: true
        active: dropArea.containsDrag
        visible: dropArea.containsDrag || hoverHandler.hovered
        opacity: dropArea.containsDrag ? 1 : 0.5
    }

    HoverHandler {
        id: hoverHandler
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: kickoff.backgroundMetrics.leftPadding
        anchors.rightMargin: kickoff.backgroundMetrics.rightPadding
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: root.collapsed ? (Application.layoutDirection === Qt.RightToLeft ? "go-previous-symbolic" : "go-next-symbolic") : "go-down-symbolic"

            TapHandler {
                onTapped: root.toggle()
            }
        }

        EditableTitle {
            id: title
            Layout.fillWidth: true
            Layout.fillHeight: true
            itemId: root.section.id
            text: root.section.name
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize
            onClicked: root.toggle()
            onRenamed: name => root.store.renameSection(root.section.id, name)
        }

        PC3.Label {
            visible: root.collapsed && root.itemCount > 0
            text: root.itemCount
            opacity: 0.7
        }

        PC3.ToolButton {
            id: menuButton
            icon.name: "overflow-menu"
            display: PC3.AbstractButton.IconOnly
            text: i18n("Opciones del grupo")
            opacity: hoverHandler.hovered || activeFocus ? 1 : 0.4
            onClicked: menu.openRelative()
        }
    }

    DropArea {
        id: dropArea
        anchors.fill: parent

        onEntered: drag => {
            if (drag.source === kickoff.dragSource && (root.draggedFavoriteId || root.draggedFolderId)) {
                drag.accept(Qt.MoveAction)
                if (root.collapsed) {
                    expandTimer.restart()
                }
            } else {
                drag.accepted = false
            }
        }
        onExited: expandTimer.stop()
        onDropped: drop => {
            expandTimer.stop()
            if (drop.source === kickoff.dragSource && (root.draggedFavoriteId || root.draggedFolderId)) {
                const favoriteId = root.draggedFavoriteId
                const folderId = root.draggedFolderId
                const sectionId = root.section.id
                const store = root.store
                drop.accept(Qt.MoveAction)
                if (folderId) {
                    Qt.callLater(() => store.moveFolderTo(folderId, sectionId, ""))
                } else {
                    Qt.callLater(() => store.moveFavoriteTo(favoriteId, sectionId, ""))
                }
            }
        }
    }

    Timer {
        id: expandTimer
        interval: 700
        onTriggered: root.store.setSectionCollapsed(root.section.id, false)
    }

    PlasmaExtras.Menu {
        id: menu
        visualParent: menuButton
        placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup

        PlasmaExtras.MenuItem {
            text: i18n("Renombrar")
            icon: "edit-rename"
            onClicked: Qt.callLater(title.startEditing)
        }
        PlasmaExtras.MenuItem {
            text: root.collapsed ? i18n("Expandir") : i18n("Plegar")
            icon: root.collapsed ? "go-down" : "go-up"
            onClicked: root.toggle()
        }
        PlasmaExtras.MenuItem {
            text: i18n("Subir")
            icon: "arrow-up"
            enabled: root.position > 0
            onClicked: root.store.moveSection(root.section.id, -1)
        }
        PlasmaExtras.MenuItem {
            text: i18n("Bajar")
            icon: "arrow-down"
            enabled: root.position < root.total - 1
            onClicked: root.store.moveSection(root.section.id, 1)
        }
        PlasmaExtras.MenuItem {
            visible: root.store.foldersEnabled
            text: i18n("Nueva carpeta en este grupo")
            icon: "folder-new"
            onClicked: root.store.createFolderWith([], root.section.id, "")
        }
        PlasmaExtras.MenuItem {
            separator: true
        }
        PlasmaExtras.MenuItem {
            text: i18n("Eliminar grupo (las apps quedan sin grupo)")
            icon: "edit-delete"
            onClicked: root.store.removeSection(root.section.id)
        }
    }
}
