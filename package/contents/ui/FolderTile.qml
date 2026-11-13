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
import org.kde.plasma.plasmoid

Item {
    id: root

    required property var folder
    property bool listMode: false

    readonly property var store: kickoff.favoriteGroups
    readonly property Item draggedItem: kickoff.dragSource.sourceItem
    readonly property string draggedFavoriteId: draggedItem ? String(draggedItem.model?.favoriteId ?? "") : ""
    readonly property ContainerModel contentModel: ContainerModel {
        containerId: root.folder.id
    }

    signal openRequested()

    activeFocusOnTab: true
    implicitWidth: listMode ? Kirigami.Units.gridUnit * 10 : KickoffSingleton.gridCellSize
    implicitHeight: listMode ? kickoff.listDelegateHeight : KickoffSingleton.gridCellSize

    Accessible.role: Accessible.Button
    Accessible.name: i18n("Carpeta %1", folder.name)

    Keys.onReturnPressed: root.openRequested()
    Keys.onEnterPressed: root.openRequested()
    Keys.onSpacePressed: root.openRequested()
    Keys.onMenuPressed: menu.openRelative()

    PlasmaExtras.Highlight {
        anchors.fill: parent
        hovered: true
        pressed: mouseArea.pressed
        active: dropArea.containsDrag || root.activeFocus
        visible: mouseArea.containsMouse || dropArea.containsDrag || root.activeFocus
    }

    component Preview: Rectangle {
        id: preview
        property real size: Kirigami.Units.iconSizes.large
        implicitWidth: size
        implicitHeight: size
        radius: Kirigami.Units.cornerRadius
        color: Qt.alpha(Kirigami.Theme.textColor, dropArea.containsDrag ? 0.25 : 0.12)
        border.width: 1
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.2)

        Grid {
            anchors.centerIn: parent
            columns: 2
            spacing: Math.max(1, Math.round(preview.size / 16))

            Repeater {
                model: root.contentModel
                delegate: Kirigami.Icon {
                    required property var decoration
                    required property int index
                    visible: index < 4
                    width: Math.floor((preview.size - preview.size / 4) / 2)
                    height: width
                    source: decoration
                    animated: false
                }
            }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: preview.size * 0.6
            height: width
            visible: root.contentModel.count === 0
            source: "folder-symbolic"
            opacity: 0.6
        }
    }

    ColumnLayout {
        visible: !root.listMode
        anchors.fill: parent
        anchors.topMargin: Kirigami.Units.smallSpacing * 2
        anchors.bottomMargin: Kirigami.Units.smallSpacing * 2
        anchors.leftMargin: KickoffSingleton.listItemMetrics.margins.left
        anchors.rightMargin: KickoffSingleton.listItemMetrics.margins.right
        spacing: KickoffSingleton.fontMetrics.descent

        Preview {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
        }

        EditableTitle {
            id: gridTitle
            Layout.fillWidth: true
            Layout.preferredHeight: KickoffSingleton.fontMetrics.height * 2
            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            itemId: root.listMode ? "" : root.folder.id
            text: root.folder.name
            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 2
            onClicked: root.openRequested()
            onRenamed: name => root.store.renameFolder(root.folder.id, name)
        }
    }

    RowLayout {
        visible: root.listMode
        anchors.fill: parent
        anchors.leftMargin: KickoffSingleton.listItemMetrics.margins.left
        anchors.rightMargin: KickoffSingleton.listItemMetrics.margins.right
        spacing: Kirigami.Units.smallSpacing * 2

        Preview {
            size: Plasmoid.configuration.compactMode ? Kirigami.Units.iconSizes.smallMedium : Kirigami.Units.iconSizes.medium
        }

        EditableTitle {
            id: listTitle
            Layout.fillWidth: true
            Layout.fillHeight: true
            itemId: root.listMode ? root.folder.id : ""
            text: root.folder.name
            onClicked: root.openRequested()
            onRenamed: name => root.store.renameFolder(root.folder.id, name)
        }

        PC3.Label {
            text: root.contentModel.count
            opacity: 0.7
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                menu.open(mouse.x, mouse.y)
            } else {
                root.openRequested()
            }
        }
    }

    PC3.ToolTip.text: root.folder.name
    PC3.ToolTip.visible: mouseArea.containsMouse && !root.listMode
    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay

    DropArea {
        id: dropArea
        anchors.fill: parent

        onEntered: drag => {
            if (drag.source === kickoff.dragSource && root.draggedFavoriteId) {
                drag.accept(Qt.MoveAction)
            } else {
                drag.accepted = false
            }
        }
        onDropped: drop => {
            if (drop.source === kickoff.dragSource && root.draggedFavoriteId) {
                const favoriteId = root.draggedFavoriteId
                const folderId = root.folder.id
                drop.accept(Qt.MoveAction)
                Qt.callLater(() => root.store.moveFavoriteTo(favoriteId, folderId, ""))
            }
        }
    }

    PlasmaExtras.Menu {
        id: menu
        visualParent: root
        placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup

        PlasmaExtras.MenuItem {
            text: i18n("Abrir")
            icon: "folder-open"
            onClicked: root.openRequested()
        }
        PlasmaExtras.MenuItem {
            text: i18n("Renombrar")
            icon: "edit-rename"
            onClicked: Qt.callLater((root.listMode ? listTitle : gridTitle).startEditing)
        }
        PlasmaExtras.MenuItem {
            id: moveSeparator
            separator: true
            visible: root.store.sectionsEnabled
        }
        PlasmaExtras.MenuItem {
            id: deleteSeparator
            separator: true
        }
        PlasmaExtras.MenuItem {
            text: i18n("Eliminar carpeta (las apps vuelven al grupo)")
            icon: "edit-delete"
            onClicked: root.store.removeFolder(root.folder.id)
        }
    }

    Instantiator {
        active: root.store.sectionsEnabled
        model: root.store.revision >= 0 ? root.store.visibleSections() : []
        delegate: PlasmaExtras.MenuItem {
            required property var modelData
            text: modelData.id === "" ? i18n("Mover a: sin grupo") : i18n("Mover a: %1", modelData.name)
            icon: "go-jump"
            visible: modelData.id !== root.store.folderSectionId(root.folder.id)
            onClicked: root.store.moveFolderToSection(root.folder.id, modelData.id)
        }
        onObjectAdded: (index, object) => menu.addMenuItem(object, deleteSeparator)
        onObjectRemoved: (index, object) => menu.removeMenuItem(object)
    }
}
