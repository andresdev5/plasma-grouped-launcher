/*
    SPDX-FileCopyrightText: 2026 andresdev5
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

Item {
    id: root

    required property string itemId
    required property string text
    property font font: Kirigami.Theme.defaultFont
    property int horizontalAlignment: Text.AlignLeft
    property int maximumLineCount: 1
    property color color: Kirigami.Theme.textColor
    property bool editing: false

    readonly property var store: kickoff.favoriteGroups

    signal renamed(string text)
    signal clicked()

    implicitWidth: editing ? field.implicitWidth : label.implicitWidth
    implicitHeight: editing ? field.implicitHeight : label.implicitHeight

    function startEditing(): void {
        field.text = root.text
        editing = true
        field.forceActiveFocus(Qt.ShortcutFocusReason)
        field.selectAll()
    }

    function finish(commit: bool): void {
        if (!editing) {
            return
        }
        editing = false
        const value = field.text.trim()
        if (commit && value.length > 0 && value !== root.text) {
            root.renamed(value)
        }
    }

    function checkPendingRename(): void {
        if (store.pendingRenameId !== "" && store.pendingRenameId === itemId) {
            store.pendingRenameId = ""
            Qt.callLater(startEditing)
        }
    }

    Connections {
        target: root.store
        function onPendingRenameIdChanged() {
            root.checkPendingRename()
        }
    }

    Component.onCompleted: checkPendingRename()

    PC3.Label {
        id: label
        anchors.fill: parent
        visible: !root.editing
        text: root.text
        font: root.font
        color: root.color
        elide: Text.ElideRight
        wrapMode: root.maximumLineCount > 1 ? Text.Wrap : Text.NoWrap
        maximumLineCount: root.maximumLineCount
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText

        TapHandler {
            onTapped: root.clicked()
            onDoubleTapped: root.startEditing()
        }
    }

    PC3.TextField {
        id: field
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.editing
        font: root.font
        horizontalAlignment: root.horizontalAlignment
        onAccepted: root.finish(true)
        onActiveFocusChanged: {
            if (!activeFocus) {
                root.finish(true)
            }
        }
        Keys.onEscapePressed: event => {
            root.finish(false)
            event.accepted = true
        }
    }
}
