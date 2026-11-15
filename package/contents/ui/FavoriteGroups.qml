/*
    SPDX-FileCopyrightText: 2026 andresdev5
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid

QtObject {
    id: root

    required property var favoritesModel

    readonly property int favoriteIdRole: Qt.UserRole + 3
    readonly property int style: Plasmoid.configuration.groupStyle
    readonly property bool sectionsEnabled: style !== 1
    readonly property bool foldersEnabled: style !== 0

    property var sections: []
    property var folders: []
    property var assignments: ({})
    property var order: ({})
    property int revision: 0
    property int favoritesRevision: 0
    readonly property var rowCache: ({ revision: -1, rows: {} })
    property string pendingRenameId: ""
    property string savedText: ""

    signal folderOpenRequested(string folderId)

    readonly property Connections configWatcher: Connections {
        target: Plasmoid.configuration
        function onGroupsDataChanged() {
            if (Plasmoid.configuration.groupsData !== root.savedText) {
                root.load()
            }
        }
        function onGroupStyleChanged() {
            root.revision++
        }
    }

    readonly property Connections favoritesWatcher: Connections {
        target: root.favoritesModel
        function onCountChanged() { Qt.callLater(root.bumpFavorites) }
        function onDataChanged() { Qt.callLater(root.bumpFavorites) }
        function onModelReset() { Qt.callLater(root.bumpFavorites) }
        function onRowsMoved() { Qt.callLater(root.bumpFavorites) }
        function onLayoutChanged() { Qt.callLater(root.bumpFavorites) }
    }

    function bumpFavorites(): void {
        favoritesRevision++
    }

    function load(): void {
        let parsed = {}
        try {
            parsed = JSON.parse(Plasmoid.configuration.groupsData || "{}") ?? {}
        } catch (error) {
            parsed = {}
        }
        sections = Array.isArray(parsed.sections) ? parsed.sections : []
        folders = Array.isArray(parsed.folders) ? parsed.folders : []
        assignments = parsed.assignments && typeof parsed.assignments === "object" ? parsed.assignments : {}
        order = parsed.order && typeof parsed.order === "object" ? parsed.order : {}
        savedText = Plasmoid.configuration.groupsData
        revision++
    }

    function save(): void {
        savedText = JSON.stringify({ sections, folders, assignments, order })
        Plasmoid.configuration.groupsData = savedText
        revision++
    }

    function newId(prefix: string): string {
        return prefix + Date.now().toString(36) + Math.floor(Math.random() * 46656).toString(36)
    }

    function findSection(id: string): var {
        return sections.find(section => section.id === id) ?? null
    }

    function findFolder(id: string): var {
        return folders.find(folder => folder.id === id) ?? null
    }

    function isFolder(id: string): bool {
        return findFolder(id) !== null
    }

    function nameOf(id: string): string {
        return (findFolder(id) ?? findSection(id))?.name ?? ""
    }

    function folderSectionId(folderId: string): string {
        const folder = findFolder(folderId)
        if (!folder || !sectionsEnabled || !findSection(folder.section)) {
            return ""
        }
        return folder.section
    }

    function containerOf(favoriteId: string): string {
        const target = assignments[favoriteId] ?? ""
        if (target === "") {
            return ""
        }
        if (findFolder(target)) {
            return foldersEnabled ? target : folderSectionId(target)
        }
        if (findSection(target)) {
            return sectionsEnabled ? target : ""
        }
        return ""
    }

    function sectionOfContainer(containerId: string): string {
        return isFolder(containerId) ? folderSectionId(containerId) : containerId
    }

    function visibleSections(): var {
        const base = [{ id: "", name: "", collapsed: false }]
        return sectionsEnabled ? base.concat(sections) : base
    }

    function foldersIn(sectionId: string): var {
        return foldersEnabled ? folders.filter(folder => folderSectionId(folder.id) === sectionId) : []
    }

    function favoriteIdAt(model: var, row: int): string {
        return String(model.data(model.index(row, 0), favoriteIdRole) ?? "")
    }

    function rowMap(): var {
        if (rowCache.revision !== favoritesRevision) {
            const rows = {}
            for (let row = 0; row < favoritesModel.count; ++row) {
                rows[favoriteIdAt(favoritesModel, row)] = row
            }
            rowCache.rows = rows
            rowCache.revision = favoritesRevision
        }
        return rowCache.rows
    }

    function sourceRowOf(favoriteId: string): int {
        const row = rowMap()[favoriteId]
        return row === undefined ? -1 : row
    }

    function favoriteData(favoriteId: string, role: int): var {
        const row = sourceRowOf(favoriteId)
        return row < 0 ? undefined : favoritesModel.data(favoritesModel.index(row, 0), role)
    }

    function entriesFor(containerId: string): var {
        const rows = rowMap()
        const appKeys = Object.keys(rows)
            .filter(favoriteId => favoriteId && containerOf(favoriteId) === containerId)
            .sort((a, b) => rows[a] - rows[b])
            .map(favoriteId => "a:" + favoriteId)
        const folderKeys = isFolder(containerId) ? [] : foldersIn(containerId).map(folder => "f:" + folder.id)
        const available = folderKeys.concat(appKeys)
        const availableSet = new Set(available)
        const saved = (order[containerId] ?? []).filter(key => availableSet.has(key))
        const savedSet = new Set(saved)
        return saved.concat(available.filter(key => !savedSet.has(key))).map(key => ({
            key,
            kind: key.startsWith("f:") ? "folder" : "app",
            id: key.slice(2),
        }))
    }

    function placeKey(key: string, containerId: string, beforeKey: string): void {
        const next = {}
        for (const container in order) {
            const keys = order[container].filter(existing => existing !== key)
            if (keys.length > 0) {
                next[container] = keys
            }
        }
        const keys = entriesFor(containerId).map(entry => entry.key).filter(existing => existing !== key)
        const at = beforeKey ? keys.indexOf(beforeKey) : -1
        if (at >= 0) {
            keys.splice(at, 0, key)
        } else {
            keys.push(key)
        }
        next[containerId] = keys
        order = next
    }

    function setAssignment(favoriteId: string, containerId: string): void {
        const next = Object.assign({}, assignments)
        if (containerId) {
            next[favoriteId] = containerId
        } else {
            delete next[favoriteId]
        }
        assignments = next
    }

    function updateSection(id: string, changes: var): void {
        sections = sections.map(section => section.id === id ? Object.assign({}, section, changes) : section)
        save()
    }

    function updateFolder(id: string, changes: var): void {
        folders = folders.map(folder => folder.id === id ? Object.assign({}, folder, changes) : folder)
        save()
    }

    function addSection(name: string, favoriteIds: var): string {
        const section = { id: newId("s"), name, collapsed: false }
        sections = sections.concat([section])
        assignAll(favoriteIds ?? [], section.id)
        return section.id
    }

    function renameSection(id: string, name: string): void {
        updateSection(id, { name })
    }

    function setSectionCollapsed(id: string, collapsed: bool): void {
        updateSection(id, { collapsed })
    }

    function moveSection(id: string, delta: int): void {
        const from = sections.findIndex(section => section.id === id)
        const to = from + delta
        if (from < 0 || to < 0 || to >= sections.length) {
            return
        }
        const reordered = sections.slice()
        reordered.splice(to, 0, reordered.splice(from, 1)[0])
        sections = reordered
        save()
    }

    function removeSection(id: string): void {
        const moved = entriesFor(id).map(entry => entry.key)
        const nextOrder = Object.assign({}, order)
        delete nextOrder[id]
        nextOrder[""] = entriesFor("").map(entry => entry.key).concat(moved)
        order = nextOrder
        sections = sections.filter(section => section.id !== id)
        folders = folders.map(folder => folder.section === id ? Object.assign({}, folder, { section: "" }) : folder)
        const next = Object.assign({}, assignments)
        for (const favoriteId in next) {
            if (next[favoriteId] === id) {
                delete next[favoriteId]
            }
        }
        assignments = next
        save()
    }

    function addFolder(name: string, sectionId: string, favoriteIds: var): string {
        const folder = { id: newId("f"), name, section: sectionId }
        folders = folders.concat([folder])
        assignAll(favoriteIds ?? [], folder.id)
        return folder.id
    }

    function renameFolder(id: string, name: string): void {
        updateFolder(id, { name })
    }

    function moveFolderTo(id: string, sectionId: string, beforeKey: string): void {
        folders = folders.map(folder => folder.id === id ? Object.assign({}, folder, { section: sectionId }) : folder)
        placeKey("f:" + id, sectionId, beforeKey)
        save()
    }

    function removeFolder(id: string): void {
        const target = findFolder(id)?.section ?? ""
        const visibleSection = folderSectionId(id)
        const contents = entriesFor(id).map(entry => entry.key)
        const sectionKeys = entriesFor(visibleSection).map(entry => entry.key)
        const at = sectionKeys.indexOf("f:" + id)
        if (at >= 0) {
            sectionKeys.splice(at, 1, ...contents)
        }
        const nextOrder = Object.assign({}, order)
        delete nextOrder[id]
        nextOrder[visibleSection] = sectionKeys
        order = nextOrder
        folders = folders.filter(folder => folder.id !== id)
        const next = Object.assign({}, assignments)
        for (const favoriteId in next) {
            if (next[favoriteId] === id) {
                if (target) {
                    next[favoriteId] = target
                } else {
                    delete next[favoriteId]
                }
            }
        }
        assignments = next
        save()
    }

    function assignAll(favoriteIds: var, containerId: string): void {
        const next = Object.assign({}, assignments)
        for (const favoriteId of favoriteIds) {
            if (containerId) {
                next[favoriteId] = containerId
            } else {
                delete next[favoriteId]
            }
        }
        assignments = next
        save()
    }

    function assign(favoriteId: string, containerId: string): void {
        assignAll([favoriteId], containerId)
    }

    function ensureFavorite(favoriteId: string): void {
        if (!favoritesModel.isFavorite(favoriteId)) {
            favoritesModel.addFavorite(favoriteId)
        }
    }

    function createSectionWith(favoriteIds: var): string {
        const id = addSection(i18n("Nuevo grupo"), favoriteIds)
        favoriteIds.forEach(favoriteId => ensureFavorite(favoriteId))
        pendingRenameId = id
        return id
    }

    function createFolderWith(favoriteIds: var, sectionId: string, beforeKey: string): string {
        const folder = { id: newId("f"), name: i18n("Nueva carpeta"), section: sectionId }
        folders = folders.concat([folder])
        favoriteIds.forEach(favoriteId => setAssignment(favoriteId, folder.id))
        placeKey("f:" + folder.id, sectionId, beforeKey ?? "")
        save()
        favoriteIds.forEach(favoriteId => ensureFavorite(favoriteId))
        pendingRenameId = folder.id
        return folder.id
    }

    function moveFavoriteTo(favoriteId: string, containerId: string, beforeKey: string): void {
        setAssignment(favoriteId, containerId)
        placeKey("a:" + favoriteId, containerId, beforeKey)
        save()
        ensureFavorite(favoriteId)
    }

    function createActions(favoriteId: string): var {
        if (!favoriteId || !favoritesModel || !favoritesModel.enabled) {
            return []
        }
        const isFavorite = favoritesModel.isFavorite(favoriteId)
        const container = isFavorite ? containerOf(favoriteId) : null
        const currentSection = container === null ? "" : sectionOfContainer(container)
        const actions = []

        if (sectionsEnabled) {
            const subActions = [{
                text: i18n("Sin grupo"),
                checkable: true,
                checked: container === "",
                actionId: "_groups_assign",
                actionArgument: { store: root, favoriteId, target: "" },
            }]
            for (const section of sections) {
                subActions.push({
                    text: section.name,
                    checkable: true,
                    checked: container !== null && currentSection === section.id && !isFolder(container),
                    actionId: "_groups_assign",
                    actionArgument: { store: root, favoriteId, target: section.id },
                })
            }
            subActions.push({ type: "separator" }, {
                text: i18n("Nuevo grupo…"),
                icon: "list-add",
                actionId: "_groups_new_section",
                actionArgument: { store: root, favoriteId },
            })
            actions.push({
                text: isFavorite ? i18n("Mover a grupo") : i18n("Añadir a grupo"),
                icon: "view-group",
                subActions,
            })
        }

        if (foldersEnabled) {
            const subActions = []
            if (container !== null && isFolder(container)) {
                subActions.push({
                    text: i18n("Sacar de la carpeta"),
                    icon: "go-up",
                    actionId: "_groups_assign",
                    actionArgument: { store: root, favoriteId, target: folderSectionId(container) },
                }, { type: "separator" })
            }
            for (const folder of folders) {
                subActions.push({
                    text: folder.name,
                    icon: "folder",
                    checkable: true,
                    checked: container === folder.id,
                    actionId: "_groups_assign",
                    actionArgument: { store: root, favoriteId, target: folder.id },
                })
            }
            if (folders.length > 0) {
                subActions.push({ type: "separator" })
            }
            subActions.push({
                text: i18n("Nueva carpeta…"),
                icon: "folder-new",
                actionId: "_groups_new_folder",
                actionArgument: { store: root, favoriteId, section: currentSection },
            })
            actions.push({
                text: isFavorite ? i18n("Mover a carpeta") : i18n("Añadir a carpeta"),
                icon: "folder",
                subActions,
            })
        }

        return actions
    }

    function handleAction(actionId: string, argument: var): void {
        const favoriteId = argument.favoriteId
        if (actionId === "_groups_assign") {
            moveFavoriteTo(favoriteId, argument.target, "")
        } else if (actionId === "_groups_new_section") {
            createSectionWith([favoriteId])
        } else if (actionId === "_groups_new_folder") {
            createFolderWith([favoriteId], argument.section ?? "", "")
        }
    }

    Component.onCompleted: load()
}
