/*
    SPDX-FileCopyrightText: 2026 andresdev5
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kitemmodels as KItemModels

KItemModels.KSortFilterProxyModel {
    id: root

    required property string containerId

    readonly property var favoritesModel: kickoff.rootModel.favoritesModel
    readonly property var store: kickoff.favoriteGroups
    readonly property bool isGroupedFavorites: true

    sourceModel: favoritesModel
    filterRowCallback: (sourceRow, sourceParent) => {
        const favoriteId = root.sourceModel.data(root.sourceModel.index(sourceRow, 0, sourceParent), root.store.favoriteIdRole)
        return root.store.containerOf(String(favoriteId ?? "")) === root.containerId
    }

    function sourceRow(row: int): int {
        return mapToSource(index(row, 0)).row
    }

    function favoriteIdAt(row: int): string {
        return store.favoriteIdAt(root, row)
    }

    function trigger(row: int, actionId: string, argument: var): bool {
        return favoritesModel.trigger(sourceRow(row), actionId, argument)
    }

    readonly property Connections refresher: Connections {
        target: root.store
        function onRevisionChanged() {
            root.invalidateFilter()
        }
    }

    onContainerIdChanged: invalidateFilter()
}
