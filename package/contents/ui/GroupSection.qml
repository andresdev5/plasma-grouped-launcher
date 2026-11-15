/*
    SPDX-FileCopyrightText: 2026 andresdev5
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    required property var section
    required property int position
    required property int total
    required property Item groupedView
    property bool showHeader: section.id !== ""

    readonly property var store: kickoff.favoriteGroups
    readonly property bool listMode: !groupedView.useGrid
    readonly property bool isFolder: store.revision >= 0 && store.isFolder(section.id)
    readonly property bool collapsed: showHeader && section.collapsed === true
    readonly property var entries: store.revision >= 0 && store.favoritesRevision >= 0 ? store.entriesFor(section.id) : []
    readonly property int itemCount: entries.length
    readonly property bool dragging: !!kickoff.dragSource.sourceItem
    readonly property GridView view: grid

    spacing: 0
    visible: showHeader || isFolder || itemCount > 0 || dragging

    function select(index: int): void {
        root.groupedView.keyboardNavigation = false
        grid.currentIndex = index
        root.groupedView.activeView = grid
        if (!(kickoff.searchField?.activeFocus ?? false)) {
            grid.forceActiveFocus(Qt.MouseFocusReason)
        }
    }

    GroupHeader {
        Layout.fillWidth: true
        visible: root.showHeader
        section: root.section
        position: root.position
        total: root.total
        itemCount: root.itemCount
    }

    Item {
        id: gridHolder
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? grid.height : 0
        visible: !root.collapsed && root.itemCount > 0

        GridView {
            id: grid

            readonly property real availableWidth: root.listMode
                ? gridHolder.width
                : gridHolder.width - kickoff.backgroundMetrics.leftPadding - kickoff.backgroundMetrics.rightPadding
            readonly property int columns: Math.max(1, Math.floor(availableWidth / cellWidth))

            x: root.listMode ? 0 : kickoff.backgroundMetrics.leftPadding
            width: root.listMode ? gridHolder.width : columns * cellWidth
            height: cellHeight * Math.ceil(count / columns)
            cellWidth: root.listMode ? gridHolder.width : KickoffSingleton.gridCellSize
            cellHeight: root.listMode ? kickoff.listDelegateHeight : KickoffSingleton.gridCellSize
            interactive: false
            keyNavigationEnabled: false
            highlightFollowsCurrentItem: false
            reuseItems: false
            currentIndex: -1
            model: root.entries
            Accessible.role: root.listMode ? Accessible.List : Accessible.Table

            onActiveFocusChanged: {
                if (activeFocus) {
                    root.groupedView.activeView = grid
                    if (currentIndex < 0 && count > 0) {
                        currentIndex = 0
                    }
                }
            }

            delegate: Item {
                id: cell

                required property var modelData
                required property int index
                readonly property Item tile: tileLoader.item
                readonly property bool isCurrent: cell.GridView.isCurrentItem && root.groupedView.activeView === grid

                width: grid.cellWidth
                height: grid.cellHeight

                Component {
                    id: appComponent
                    AppTile {
                        favoriteId: cell.modelData.id
                        listMode: root.listMode
                        current: cell.isCurrent
                        highlightActive: grid.activeFocus || (kickoff.searchField?.activeFocus ?? false)
                        keyboardSelected: root.groupedView.keyboardNavigation
                        onHoverEntered: root.select(cell.index)
                    }
                }

                Component {
                    id: folderComponent
                    FolderTile {
                        folderId: cell.modelData.id
                        listMode: root.listMode
                        current: cell.isCurrent
                        highlightActive: grid.activeFocus || (kickoff.searchField?.activeFocus ?? false)
                        keyboardSelected: root.groupedView.keyboardNavigation
                        onHoverEntered: root.select(cell.index)
                        onOpenRequested: root.groupedView.openFolder(cell.modelData.id)
                    }
                }

                Loader {
                    id: tileLoader
                    anchors.fill: parent
                    sourceComponent: cell.modelData.kind === "folder" ? folderComponent : appComponent
                }
            }

            Keys.onPressed: event => {
                const searching = kickoff.searchField?.activeFocus ?? false
                const columns = grid.columns
                let handled = true
                switch (event.key) {
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    grid.currentItem?.tile?.activate()
                    break
                case Qt.Key_Menu:
                    grid.currentItem?.tile?.openMenu()
                    break
                case Qt.Key_Left:
                    if (searching) {
                        handled = false
                    } else if (grid.currentIndex > 0) {
                        grid.currentIndex--
                    }
                    break
                case Qt.Key_Right:
                    if (searching) {
                        handled = false
                    } else if (grid.currentIndex < grid.count - 1) {
                        grid.currentIndex++
                    }
                    break
                case Qt.Key_Up:
                    if (grid.currentIndex - columns >= 0) {
                        grid.currentIndex -= columns
                    } else {
                        root.groupedView.focusNeighbour(grid, -1)
                        event.accepted = true
                        return
                    }
                    break
                case Qt.Key_Down:
                    if (grid.currentIndex < 0) {
                        grid.currentIndex = 0
                    } else if (grid.currentIndex + columns < grid.count) {
                        grid.currentIndex += columns
                    } else {
                        root.groupedView.focusNeighbour(grid, 1)
                        event.accepted = true
                        return
                    }
                    break
                default:
                    handled = false
                }
                if (handled) {
                    root.groupedView.keyboardNavigation = true
                    event.accepted = true
                    root.groupedView.activeView = grid
                    if (!grid.activeFocus) {
                        grid.forceActiveFocus(Qt.TabFocusReason)
                    }
                }
            }
        }

        GroupDropArea {
            anchors.fill: parent
            z: 5
            targetView: grid
            containerId: root.section.id
            entries: root.entries
            allowFolderCreation: root.store.foldersEnabled && !root.isFolder
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: kickoff.backgroundMetrics.leftPadding
        Layout.rightMargin: kickoff.backgroundMetrics.rightPadding
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5
        visible: !root.collapsed && root.itemCount === 0
        radius: Kirigami.Units.cornerRadius
        color: emptyDropArea.containsDrag ? Qt.alpha(Kirigami.Theme.highlightColor, 0.3) : "transparent"
        border.width: 1
        border.color: Qt.alpha(Kirigami.Theme.textColor, emptyDropArea.containsDrag ? 0.6 : 0.25)

        PC3.Label {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            opacity: 0.7
            text: root.section.id === "" ? i18n("Suelta aquí para quitar del grupo") : i18n("Arrastra aplicaciones aquí")
        }

        GroupDropArea {
            id: emptyDropArea
            anchors.fill: parent
            targetView: grid
            containerId: root.section.id
            entries: root.entries
        }
    }
}
