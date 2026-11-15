/*
    SPDX-FileCopyrightText: 2026 andresdev5
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

FocusScope {
    id: root

    objectName: "groupedFavoritesView"

    readonly property var store: kickoff.favoriteGroups
    readonly property bool useGrid: Plasmoid.configuration.favoritesDisplay === 0
    readonly property var sectionList: store.revision >= 0 ? store.visibleSections() : []
    readonly property var openedFolder: store.revision >= 0 && openFolderId ? store.findFolder(openFolderId) : null
    readonly property Flickable flickable: openFolderId ? folderFlickable : sectionsFlickable
    property string openFolderId: ""
    property Flickable activeView: null
    property bool keyboardNavigation: false
    readonly property real sidePadding: Kirigami.Units.largeSpacing * 2
    readonly property Flickable view: activeView
    readonly property Item currentItem: activeView ? activeView.currentItem : null

    implicitWidth: KickoffSingleton.gridCellSize * kickoff.minimumGridRowCount
        + kickoff.backgroundMetrics.leftPadding + kickoff.backgroundMetrics.rightPadding + sidePadding * 2
        + (kickoff.mayHaveGridWithScrollBar ? scrollBar.implicitWidth : 0)
    implicitHeight: KickoffSingleton.gridCellSize * kickoff.minimumGridRowCount
        + KickoffSingleton.listItemMetrics.margins.top + KickoffSingleton.listItemMetrics.margins.bottom

    function openFolder(folderId: string): void {
        activeView = null
        openFolderId = folderId
        folderFlickable.contentY = 0
    }

    function closeFolder(): void {
        if (openFolderId === "") {
            return
        }
        activeView = null
        openFolderId = ""
    }

    function contentViews(): var {
        const views = []
        if (openFolderId) {
            const section = folderLoader.item
            if (section && section.view && section.view.count > 0) {
                views.push(section.view)
            }
            return views
        }
        for (let i = 0; i < sectionRepeater.count; ++i) {
            const section = sectionRepeater.itemAt(i)
            if (section && section.visible && !section.collapsed && section.view && section.view.count > 0) {
                views.push(section.view)
            }
        }
        return views
    }

    function ensureVisible(item: Item): void {
        if (!item) {
            return
        }
        const target = root.flickable
        const position = item.mapToItem(target.contentItem, 0, 0)
        if (position.y < target.contentY) {
            target.contentY = Math.max(0, position.y)
        } else if (position.y + item.height > target.contentY + target.height) {
            target.contentY = Math.min(Math.max(0, target.contentHeight - target.height), position.y + item.height - target.height)
        }
    }

    function focusNeighbour(view: Flickable, direction: int): void {
        const views = contentViews()
        const next = views[views.indexOf(view) + direction]
        if (!next) {
            if (direction < 0) {
                kickoff.searchField.forceActiveFocus(Qt.BacktabFocusReason)
            }
            return
        }
        keyboardNavigation = true
        activeView = next
        next.currentIndex = direction > 0 ? 0 : next.count - 1
        next.forceActiveFocus(direction > 0 ? Qt.TabFocusReason : Qt.BacktabFocusReason)
        ensureVisible(next.currentItem)
    }

    function scrollToEnd(): void {
        sectionsFlickable.contentY = Math.max(0, sectionsFlickable.contentHeight - sectionsFlickable.height)
    }

    onActiveFocusChanged: {
        if (activeFocus && root.Window.activeFocusItem === root) {
            const target = activeView ?? contentViews()[0]
            if (target) {
                keyboardNavigation = true
                activeView = target
                target.forceActiveFocus()
            }
        }
    }

    onOpenedFolderChanged: {
        if (openFolderId && !openedFolder) {
            closeFolder()
        }
    }

    Keys.onEscapePressed: event => {
        if (openFolderId) {
            closeFolder()
            event.accepted = true
        } else {
            event.accepted = false
        }
    }

    Connections {
        target: kickoff
        function onExpandedChanged() {
            if (!kickoff.expanded) {
                root.closeFolder()
                root.activeView = null
                root.keyboardNavigation = false
                sectionsFlickable.contentY = 0
            }
        }
    }

    Connections {
        target: root.activeView
        function onCurrentIndexChanged() {
            if (root.activeView.activeFocus || root.activeView.currentItem?.activeFocus) {
                root.ensureVisible(root.activeView.currentItem)
            }
        }
    }

    component CreateButton: PC3.ToolButton {
        id: button

        readonly property Item draggedItem: kickoff.dragSource.sourceItem
        readonly property string draggedFavoriteId: draggedItem ? String(draggedItem.model?.favoriteId ?? "") : ""

        signal create(var favoriteIds)

        font: Kirigami.Theme.smallFont
        down: buttonDropArea.containsDrag || pressed
        onClicked: create([])

        DropArea {
            id: buttonDropArea
            anchors.fill: parent
            onEntered: drag => {
                if (drag.source === kickoff.dragSource && button.draggedFavoriteId) {
                    drag.accept(Qt.MoveAction)
                } else {
                    drag.accepted = false
                }
            }
            onDropped: drop => {
                if (drop.source === kickoff.dragSource && button.draggedFavoriteId) {
                    const favoriteId = button.draggedFavoriteId
                    drop.accept(Qt.MoveAction)
                    Qt.callLater(() => button.create([favoriteId]))
                }
            }
        }
    }

    RowLayout {
        id: createButtons
        visible: root.openFolderId === ""
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.sidePadding + kickoff.backgroundMetrics.rightPadding
        anchors.bottomMargin: root.sidePadding
        spacing: Kirigami.Units.smallSpacing

        CreateButton {
            visible: root.store.sectionsEnabled
            text: i18n("Nuevo grupo")
            icon.name: "list-add"
            onCreate: favoriteIds => {
                root.store.createSectionWith(favoriteIds)
                Qt.callLater(root.scrollToEnd)
            }
        }

        CreateButton {
            visible: root.store.foldersEnabled
            text: i18n("Nueva carpeta")
            icon.name: "folder-new"
            onCreate: favoriteIds => {
                root.store.createFolderWith(favoriteIds, "", "")
                sectionsFlickable.contentY = 0
            }
        }
    }

    Flickable {
        id: sectionsFlickable
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: createButtons.top
        anchors.bottomMargin: Kirigami.Units.smallSpacing
        visible: root.openFolderId === ""
        clip: true
        contentWidth: width
        contentHeight: sectionsColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        pixelAligned: true

        PC3.ScrollBar.vertical: PC3.ScrollBar {
            id: scrollBar
        }

        Kirigami.WheelHandler {
            target: sectionsFlickable
            filterMouseEvents: true
            horizontalStepSize: 20 * Qt.styleHints.wheelScrollLines
            verticalStepSize: 20 * Qt.styleHints.wheelScrollLines
        }

        ColumnLayout {
            id: sectionsColumn
            x: root.sidePadding
            width: sectionsFlickable.width - (scrollBar.visible ? scrollBar.width : 0) - root.sidePadding * 2
            spacing: 0

            Item {
                Layout.preferredHeight: KickoffSingleton.listItemMetrics.margins.top + root.sidePadding
            }

            Repeater {
                id: sectionRepeater
                model: root.sectionList
                delegate: GroupSection {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    section: modelData
                    position: index - 1
                    total: root.store.sections.length
                    groupedView: root
                }
            }

            Item {
                Layout.preferredHeight: KickoffSingleton.listItemMetrics.margins.bottom
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        visible: root.openFolderId !== ""
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: kickoff.backgroundMetrics.leftPadding + root.sidePadding
            Layout.rightMargin: kickoff.backgroundMetrics.rightPadding + root.sidePadding
            Layout.topMargin: KickoffSingleton.listItemMetrics.margins.top + root.sidePadding
            spacing: Kirigami.Units.smallSpacing

            PC3.ToolButton {
                id: backButton

                readonly property Item draggedItem: kickoff.dragSource.sourceItem
                readonly property string draggedFavoriteId: draggedItem ? String(draggedItem.model?.favoriteId ?? "") : ""

                icon.name: Application.layoutDirection === Qt.RightToLeft ? "go-next" : "go-previous"
                text: i18n("Volver")
                display: PC3.AbstractButton.IconOnly
                down: backDropArea.containsDrag || pressed
                onClicked: root.closeFolder()

                PC3.ToolTip.text: i18n("Volver (suelta una app aquí para sacarla de la carpeta)")
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay

                DropArea {
                    id: backDropArea
                    anchors.fill: parent
                    onEntered: drag => {
                        if (drag.source === kickoff.dragSource && backButton.draggedFavoriteId) {
                            drag.accept(Qt.MoveAction)
                        } else {
                            drag.accepted = false
                        }
                    }
                    onDropped: drop => {
                        if (drop.source === kickoff.dragSource && backButton.draggedFavoriteId) {
                            const favoriteId = backButton.draggedFavoriteId
                            const sectionId = root.store.folderSectionId(root.openFolderId)
                            drop.accept(Qt.MoveAction)
                            Qt.callLater(() => root.store.moveFavoriteTo(favoriteId, sectionId, ""))
                        }
                    }
                }
            }

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                source: "folder-open"
            }

            EditableTitle {
                id: folderTitle
                Layout.fillWidth: true
                Layout.preferredHeight: backButton.implicitHeight
                itemId: root.openFolderId
                text: root.openedFolder?.name ?? ""
                font.bold: true
                onRenamed: name => root.store.renameFolder(root.openFolderId, name)
            }

            PC3.ToolButton {
                icon.name: "edit-rename"
                text: i18n("Renombrar carpeta")
                display: PC3.AbstractButton.IconOnly
                onClicked: folderTitle.startEditing()
                PC3.ToolTip.text: text
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        Flickable {
            id: folderFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: (folderLoader.item ? folderLoader.item.implicitHeight : 0) + root.sidePadding
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            pixelAligned: true

            PC3.ScrollBar.vertical: PC3.ScrollBar {
                id: folderScrollBar
            }

            Kirigami.WheelHandler {
                target: folderFlickable
                filterMouseEvents: true
                horizontalStepSize: 20 * Qt.styleHints.wheelScrollLines
                verticalStepSize: 20 * Qt.styleHints.wheelScrollLines
            }

            Loader {
                id: folderLoader
                x: root.sidePadding
                width: folderFlickable.width - (folderScrollBar.visible ? folderScrollBar.width : 0) - root.sidePadding * 2
                active: root.openFolderId !== "" && root.openedFolder !== null
                sourceComponent: GroupSection {
                    section: ({ id: root.openFolderId, name: root.openedFolder?.name ?? "", collapsed: false })
                    position: -1
                    total: 0
                    groupedView: root
                    showHeader: false
                }
            }
        }
    }
}
