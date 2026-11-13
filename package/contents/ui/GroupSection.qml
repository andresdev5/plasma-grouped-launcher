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

ColumnLayout {
    id: root

    required property var section
    required property int position
    required property int total
    required property Item groupedView
    property bool showHeader: section.id !== ""

    readonly property var store: kickoff.favoriteGroups
    readonly property bool useGrid: groupedView.useGrid
    readonly property bool isFolder: store.revision >= 0 && store.isFolder(section.id)
    readonly property bool collapsed: showHeader && section.collapsed === true
    readonly property var folderList: store.revision >= 0 && !isFolder ? store.foldersIn(section.id) : []
    readonly property int itemCount: sectionModel.count + folderList.length
    readonly property bool dragging: !!kickoff.dragSource.sourceItem
    readonly property Flickable view: contentLoader.item ? contentLoader.item.view : null

    spacing: 0
    visible: showHeader || isFolder || itemCount > 0 || dragging

    ContainerModel {
        id: sectionModel
        containerId: root.section.id
    }

    GroupHeader {
        Layout.fillWidth: true
        visible: root.showHeader
        section: root.section
        position: root.position
        total: root.total
        itemCount: root.itemCount
    }

    Flow {
        id: folderFlow
        Layout.fillWidth: true
        Layout.leftMargin: root.useGrid ? kickoff.backgroundMetrics.leftPadding : 0
        Layout.rightMargin: root.useGrid ? kickoff.backgroundMetrics.rightPadding : 0
        visible: !root.collapsed && root.folderList.length > 0

        Repeater {
            model: root.folderList
            delegate: FolderTile {
                required property var modelData
                folder: modelData
                listMode: !root.useGrid
                width: root.useGrid ? KickoffSingleton.gridCellSize : folderFlow.width
                onOpenRequested: root.groupedView.openFolder(modelData.id)
            }
        }
    }

    Loader {
        id: contentLoader
        Layout.fillWidth: true
        Layout.preferredHeight: item && visible ? item.implicitHeight : 0
        visible: !root.collapsed && sectionModel.count > 0
        sourceComponent: root.useGrid ? gridComponent : listComponent
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: kickoff.backgroundMetrics.leftPadding
        Layout.rightMargin: kickoff.backgroundMetrics.rightPadding
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5
        visible: !root.collapsed && sectionModel.count === 0 && root.folderList.length === 0
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
            targetView: root.view
            containerModel: sectionModel
        }
    }

    Component {
        id: gridComponent

        KickoffGridView {
            id: grid
            model: sectionModel
            flickableToScroll: root.groupedView.flickable
            view.height: view.cellHeight * Math.ceil(count / Math.max(1, view.columns))
            view.implicitHeight: view.contentHeight
            view.interactive: false

            onActiveFocusChanged: {
                if (activeFocus) {
                    root.groupedView.activeView = view
                }
            }

            delegate: KickoffGridDelegate {
                id: itemDelegate
                width: grid.view.cellWidth
                Accessible.role: Accessible.Cell

                background: Loader {
                    active: itemDelegate.GridView.isCurrentItem && root.groupedView.activeView === grid.view
                    sourceComponent: PlasmaExtras.Highlight {
                        anchors.fill: parent
                        hovered: true
                        pressed: itemDelegate.down
                        active: grid.view.activeFocus || kickoff.searchField?.activeFocus
                    }
                }

                Connections {
                    target: itemDelegate.mouseArea
                    function onEntered() {
                        root.groupedView.activeView = grid.view
                    }
                    function onPressed() {
                        root.groupedView.activeView = grid.view
                    }
                }
            }

            Keys.onUpPressed: event => root.groupedView.focusNeighbour(grid.view, -1)
            Keys.onDownPressed: event => root.groupedView.focusNeighbour(grid.view, 1)

            GroupDropArea {
                parent: grid
                anchors.fill: parent
                z: 5
                targetView: grid.view
                containerModel: sectionModel
                allowFolderCreation: root.store.foldersEnabled && !root.isFolder
            }
        }
    }

    Component {
        id: listComponent

        KickoffListView {
            id: list
            model: sectionModel
            mainContentView: true
            flickableToScroll: root.groupedView.flickable
            section.property: ""
            view.implicitHeight: view.contentHeight
            view.interactive: false

            onActiveFocusChanged: {
                if (activeFocus) {
                    root.groupedView.activeView = view
                }
            }

            delegate: KickoffListDelegate {
                id: listDelegate
                width: list.view.availableWidth

                background: Loader {
                    active: listDelegate.ListView.isCurrentItem && root.groupedView.activeView === list.view
                    sourceComponent: PlasmaExtras.Highlight {
                        anchors.fill: parent
                        hovered: true
                        pressed: listDelegate.down
                        active: list.view.activeFocus || kickoff.searchField?.activeFocus
                    }
                }

                Connections {
                    target: listDelegate.mouseArea
                    function onEntered() {
                        root.groupedView.activeView = list.view
                    }
                    function onPressed() {
                        root.groupedView.activeView = list.view
                    }
                }
            }

            Keys.onUpPressed: event => root.groupedView.focusNeighbour(list.view, -1)
            Keys.onDownPressed: event => root.groupedView.focusNeighbour(list.view, 1)

            GroupDropArea {
                parent: list
                anchors.fill: parent
                z: 5
                targetView: list.view
                containerModel: sectionModel
                allowFolderCreation: root.store.foldersEnabled && !root.isFolder
            }
        }
    }
}
