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
    property int revision: 0
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
        savedText = Plasmoid.configuration.groupsData
        revision++
    }

    function save(): void {
        savedText = JSON.stringify({ sections, folders, assignments })
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

    function sourceRowOf(favoriteId: string): int {
        for (let row = 0; row < favoritesModel.count; ++row) {
            if (favoriteIdAt(favoritesModel, row) === favoriteId) {
                return row
            }
        }
        return -1
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

    function moveFolderToSection(id: string, sectionId: string): void {
        updateFolder(id, { section: sectionId })
    }

    function removeFolder(id: string): void {
        const target = findFolder(id)?.section ?? ""
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

    function createFolderWith(favoriteIds: var, sectionId: string): string {
        const id = addFolder(i18n("Nueva carpeta"), sectionId, favoriteIds)
        favoriteIds.forEach(favoriteId => ensureFavorite(favoriteId))
        pendingRenameId = id
        return id
    }

    function moveFavoriteTo(favoriteId: string, containerId: string, beforeFavoriteId: string): void {
        assign(favoriteId, containerId)
        if (!favoritesModel.isFavorite(favoriteId)) {
            const row = beforeFavoriteId ? sourceRowOf(beforeFavoriteId) : -1
            favoritesModel.addFavorite(favoriteId, row)
            return
        }
        if (beforeFavoriteId && beforeFavoriteId !== favoriteId) {
            const from = sourceRowOf(favoriteId)
            const to = sourceRowOf(beforeFavoriteId)
            if (from >= 0 && to >= 0 && from !== to) {
                favoritesModel.moveRow(from, to)
            }
        }
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
            assign(favoriteId, argument.target)
            ensureFavorite(favoriteId)
        } else if (actionId === "_groups_new_section") {
            createSectionWith([favoriteId])
        } else if (actionId === "_groups_new_folder") {
            createFolderWith([favoriteId], argument.section ?? "")
        }
    }

    Component.onCompleted: load()
}
