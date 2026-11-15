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

    required property GridView targetView
    required property string containerId
    required property var entries
    property bool allowFolderCreation: false

    readonly property var store: kickoff.favoriteGroups
    readonly property Item draggedItem: kickoff.dragSource.sourceItem
    readonly property string draggedFavoriteId: draggedItem ? String(draggedItem.model?.favoriteId ?? "") : ""
    readonly property string draggedFolderId: draggedItem ? String(draggedItem.draggedFolderId ?? "") : ""
    readonly property string draggedKey: draggedFavoriteId ? "a:" + draggedFavoriteId : (draggedFolderId ? "f:" + draggedFolderId : "")
    readonly property bool acceptsDrag: draggedKey !== "" && !(draggedFolderId && store.isFolder(containerId))
    readonly property bool listLayout: targetView ? targetView.cellWidth >= targetView.width - 1 : false
    property int hoverIndex: -1
    property bool hoverCenter: false
    property bool hoverAfter: false

    enabled: Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable

    function reset(): void {
        hoverIndex = -1
        hoverCenter = false
        hoverAfter = false
    }

    function canCombine(entry: var): bool {
        if (!draggedFavoriteId || !store.foldersEnabled) {
            return false
        }
        return entry.kind === "folder" || allowFolderCreation
    }

    function locate(x: real, y: real): void {
        if (!targetView || targetView.count === 0) {
            reset()
            return
        }
        const position = mapToItem(targetView.contentItem, x, y)
        const index = targetView.indexAt(position.x, position.y)
        const item = index >= 0 ? targetView.itemAtIndex(index) : null
        const entry = index >= 0 ? entries[index] : null
        if (!item || !entry || entry.key === draggedKey) {
            reset()
            return
        }
        const localX = position.x - item.x
        const localY = position.y - item.y
        const inCenter = listLayout
            ? localY > item.height * 0.3 && localY < item.height * 0.7
            : localX > item.width * 0.25 && localX < item.width * 0.75 && localY > item.height * 0.15 && localY < item.height * 0.8
        hoverIndex = index
        hoverCenter = inCenter && canCombine(entry)
        hoverAfter = !hoverCenter && (listLayout ? localY > item.height / 2 : localX > item.width / 2)
    }

    function beforeKeyFor(index: int, after: bool): string {
        for (let i = after ? index + 1 : index; i < entries.length; ++i) {
            if (entries[i].key !== draggedKey) {
                return entries[i].key
            }
        }
        return ""
    }

    onEntered: drag => {
        if (drag.source === kickoff.dragSource && acceptsDrag) {
            locate(drag.x, drag.y)
            drag.accept(Qt.MoveAction)
        } else if (drag.source !== kickoff.dragSource && drag.hasUrls) {
            drag.accept(Qt.CopyAction)
        } else {
            drag.accepted = false
        }
    }

    onPositionChanged: drag => {
        if (drag.source === kickoff.dragSource && acceptsDrag) {
            locate(drag.x, drag.y)
        }
    }

    onExited: reset()

    onDropped: drop => {
        const index = hoverIndex
        const center = hoverCenter
        const after = hoverAfter
        reset()
        if (drop.source === kickoff.dragSource && acceptsDrag) {
            const entry = index >= 0 ? entries[index] : null
            const favoriteId = draggedFavoriteId
            const folderId = draggedFolderId
            const containerId = root.containerId
            const store = root.store
            drop.accept(Qt.MoveAction)
            if (center && entry) {
                if (entry.kind === "folder") {
                    Qt.callLater(() => store.moveFavoriteTo(favoriteId, entry.id, ""))
                } else {
                    const before = beforeKeyFor(index, true)
                    Qt.callLater(() => store.createFolderWith([entry.id, favoriteId], store.sectionOfContainer(containerId), before))
                }
                return
            }
            const before = entry ? beforeKeyFor(index, after) : ""
            if (folderId) {
                Qt.callLater(() => store.moveFolderTo(folderId, containerId, before))
            } else {
                Qt.callLater(() => store.moveFavoriteTo(favoriteId, containerId, before))
            }
        } else if (drop.source !== kickoff.dragSource && drop.hasUrls) {
            for (const url of drop.urls) {
                store.moveFavoriteTo(String(url), containerId, "")
            }
            drop.accept(Qt.CopyAction)
        }
    }

    Rectangle {
        readonly property Item target: root.hoverIndex >= 0 && root.targetView ? root.targetView.itemAtIndex(root.hoverIndex) : null
        readonly property point origin: target ? target.mapToItem(root, 0, 0) : Qt.point(0, 0)
        readonly property real lineSize: Kirigami.Units.smallSpacing
        visible: target !== null && root.containsDrag
        x: root.hoverCenter || root.listLayout ? origin.x : origin.x + (root.hoverAfter ? (target?.width ?? 0) : 0) - lineSize / 2
        y: !root.hoverCenter && root.listLayout ? origin.y + (root.hoverAfter ? (target?.height ?? 0) : 0) - lineSize / 2 : origin.y
        width: root.hoverCenter || root.listLayout ? (target?.width ?? 0) : lineSize
        height: !root.hoverCenter && root.listLayout ? lineSize : (target?.height ?? 0)
        radius: Kirigami.Units.cornerRadius
        color: root.hoverCenter ? "transparent" : Kirigami.Theme.highlightColor
        border.width: root.hoverCenter ? 2 : 0
        border.color: Kirigami.Theme.highlightColor
        z: 10
    }
}
