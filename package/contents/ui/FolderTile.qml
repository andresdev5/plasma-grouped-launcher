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

Item {
    id: root

    required property string folderId
    property bool listMode: false
    property bool current: false
    property bool highlightActive: false
    property bool keyboardSelected: false

    readonly property var store: kickoff.favoriteGroups
    readonly property var folder: store.revision >= 0 ? store.findFolder(folderId) : null
    readonly property string folderName: folder?.name ?? ""
    readonly property var contents: store.revision >= 0 && store.favoritesRevision >= 0 ? store.entriesFor(folderId) : []
    readonly property var model: ({ favoriteId: "" })
    readonly property string draggedFolderId: folderId
    readonly property Item dragIcon: listMode ? listPreview : gridPreview

    signal openRequested()
    signal hoverEntered()

    function activate(): void {
        root.openRequested()
    }

    function openMenu(x: var, y: var): void {
        if (x !== undefined && y !== undefined) {
            menu.open(x, y)
        } else {
            menu.openRelative()
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
            kickoff.dragSource.Drag.mimeData = { "text/plain": root.folderName }
            kickoff.dragSource.Drag.active = true
        })
    }

    Accessible.role: Accessible.Button
    Accessible.name: i18n("Carpeta %1", folderName)

    PlasmaExtras.Highlight {
        anchors.fill: parent
        hovered: true
        pressed: mouseArea.pressed
        active: root.highlightActive
        visible: mouseArea.containsMouse || (root.current && root.keyboardSelected)
    }

    component Preview: Rectangle {
        id: preview
        property real size: Kirigami.Units.iconSizes.large
        implicitWidth: size
        implicitHeight: size
        radius: Kirigami.Units.cornerRadius
        color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
        border.width: 1
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.2)

        Grid {
            anchors.centerIn: parent
            columns: 2
            spacing: Math.max(1, Math.round(preview.size / 16))

            Repeater {
                model: root.contents.slice(0, 4)
                delegate: Kirigami.Icon {
                    required property var modelData
                    width: Math.floor((preview.size - preview.size / 4) / 2)
                    height: width
                    source: root.store.favoriteData(modelData.id, 1) ?? ""
                    animated: false
                }
            }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: preview.size * 0.6
            height: width
            visible: root.contents.length === 0
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
            id: gridPreview
            Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
        }

        EditableTitle {
            id: gridTitle
            Layout.fillWidth: true
            Layout.preferredHeight: KickoffSingleton.fontMetrics.height * 2
            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            itemId: root.listMode ? "" : root.folderId
            text: root.folderName
            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 2
            onClicked: root.openRequested()
            onRenamed: name => root.store.renameFolder(root.folderId, name)
        }
    }

    RowLayout {
        visible: root.listMode
        anchors.fill: parent
        anchors.leftMargin: KickoffSingleton.listItemMetrics.margins.left
        anchors.rightMargin: KickoffSingleton.listItemMetrics.margins.right
        spacing: Kirigami.Units.smallSpacing * 2

        Preview {
            id: listPreview
            size: Plasmoid.configuration.compactMode ? Kirigami.Units.iconSizes.smallMedium : Kirigami.Units.iconSizes.medium
        }

        EditableTitle {
            id: listTitle
            Layout.fillWidth: true
            Layout.fillHeight: true
            itemId: root.listMode ? root.folderId : ""
            text: root.folderName
            onClicked: root.openRequested()
            onRenamed: name => root.store.renameFolder(root.folderId, name)
        }

        PC3.Label {
            text: root.contents.length
            opacity: 0.7
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        z: -1
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
                root.openRequested()
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

    PC3.ToolTip.text: root.folderName
    PC3.ToolTip.visible: mouseArea.containsMouse && !root.listMode
    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay

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
            onClicked: root.store.removeFolder(root.folderId)
        }
    }

    Instantiator {
        active: root.store.sectionsEnabled
        model: root.store.revision >= 0 ? root.store.visibleSections() : []
        delegate: PlasmaExtras.MenuItem {
            required property var modelData
            text: modelData.id === "" ? i18n("Mover a: sin grupo") : i18n("Mover a: %1", modelData.name)
            icon: "go-jump"
            visible: modelData.id !== root.store.folderSectionId(root.folderId)
            onClicked: root.store.moveFolderTo(root.folderId, modelData.id, "")
        }
        onObjectAdded: (index, object) => menu.addMenuItem(object, deleteSeparator)
        onObjectRemoved: (index, object) => menu.removeMenuItem(object)
    }
}
