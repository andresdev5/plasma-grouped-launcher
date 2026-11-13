/*
    SPDX-FileCopyrightText: 2026 andresdev5
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

DropArea {
    id: root

    required property Flickable targetView
    required property ContainerModel containerModel
    property bool allowFolderCreation: false

    readonly property var store: kickoff.favoriteGroups
    readonly property Item draggedItem: kickoff.dragSource.sourceItem
    readonly property string draggedFavoriteId: draggedItem ? String(draggedItem.model?.favoriteId ?? "") : ""
    property int hoverIndex: -1
    property bool hoverCenter: false

    enabled: Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable

    function locate(x: real, y: real): void {
        if (!targetView) {
            reset()
            return
        }
        const position = mapToItem(targetView.contentItem, x, y)
        const index = targetView.indexAt(position.x, position.y)
        const item = index >= 0 ? targetView.itemAtIndex(index) : null
        if (!item || (draggedItem === item)) {
            hoverIndex = -1
            hoverCenter = false
            return
        }
        hoverIndex = index
        const localX = position.x - item.x
        const localY = position.y - item.y
        hoverCenter = allowFolderCreation
            && containerModel.favoriteIdAt(index) !== draggedFavoriteId
            && localX > item.width * 0.25 && localX < item.width * 0.75
            && localY > item.height * 0.15 && localY < item.height * 0.75
    }

    function reset(): void {
        hoverIndex = -1
        hoverCenter = false
    }

    function applyDrop(favoriteId: string, targetFavoriteId: string, createFolder: bool): void {
        if (createFolder && targetFavoriteId && targetFavoriteId !== favoriteId) {
            store.createFolderWith([targetFavoriteId, favoriteId], store.sectionOfContainer(containerModel.containerId))
            return
        }
        store.moveFavoriteTo(favoriteId, containerModel.containerId, targetFavoriteId)
    }

    onEntered: drag => {
        if (drag.source === kickoff.dragSource && draggedFavoriteId) {
            locate(drag.x, drag.y)
            drag.accept(Qt.MoveAction)
        } else if (drag.hasUrls) {
            drag.accept(Qt.CopyAction)
        } else {
            drag.accepted = false
        }
    }

    onPositionChanged: drag => {
        if (drag.source === kickoff.dragSource && draggedFavoriteId) {
            locate(drag.x, drag.y)
        }
    }

    onExited: reset()

    onDropped: drop => {
        const targetFavoriteId = hoverIndex >= 0 ? containerModel.favoriteIdAt(hoverIndex) : ""
        const createFolder = hoverCenter
        reset()
        if (drop.source === kickoff.dragSource && draggedFavoriteId) {
            const favoriteId = draggedFavoriteId
            drop.accept(Qt.MoveAction)
            Qt.callLater(root.applyDrop, favoriteId, targetFavoriteId, createFolder)
        } else if (drop.hasUrls) {
            for (const url of drop.urls) {
                store.assign(String(url), containerModel.containerId)
                kickoff.rootModel.favoritesModel.addFavoriteTo(url, ":current")
            }
            drop.accept(Qt.CopyAction)
        }
    }

    Rectangle {
        readonly property Item target: root.hoverIndex >= 0 && root.targetView ? root.targetView.itemAtIndex(root.hoverIndex) : null
        readonly property point origin: target ? target.mapToItem(root, 0, 0) : Qt.point(0, 0)
        readonly property bool horizontalLine: root.targetView instanceof ListView
        readonly property real lineSize: Kirigami.Units.smallSpacing
        visible: target !== null && root.containsDrag
        x: root.hoverCenter || horizontalLine ? origin.x : origin.x - lineSize / 2
        y: !root.hoverCenter && horizontalLine ? origin.y - lineSize / 2 : origin.y
        width: root.hoverCenter || horizontalLine ? (target?.width ?? 0) : lineSize
        height: !root.hoverCenter && horizontalLine ? lineSize : (target?.height ?? 0)
        radius: Kirigami.Units.cornerRadius
        color: root.hoverCenter ? "transparent" : Kirigami.Theme.highlightColor
        border.width: root.hoverCenter ? 2 : 0
        border.color: Kirigami.Theme.highlightColor
        z: 10
    }
}
