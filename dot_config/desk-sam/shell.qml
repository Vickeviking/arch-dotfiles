// Sam, the desk cat: Viktor's grey tabby living just under the top bar.
//
// A Quickshell overlay above every window that only takes input where Sam
// (or his ball, bowl, treat) is; clicks everywhere else pass straight through.
// Started and stopped by ~/.local/bin/desk-sam (waybar 🐈 toggles him).
//
//   idle       sits and blinks, wanders now and then
//   you're away (3 min)  walks home and sleeps; wakes with a stretch
//   click      purrs (hearts, soft purr sound)
//   hover      pounces in place
//   pomodoro   during focus he sleeps in his corner and ignores everything;
//              when focus ends he stretches and purrs
//   desk-sam feed | ball | yarn | treat | home   (IPC, also from the waybar menu)

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string art: Qt.resolvedUrl("frames/")
    property var man: ({})
    readonly property string home: Quickshell.env("HOME")

    // what Sam is doing: idle | walking | chasing | eating | sleeping | purring | stretching | pouncing
    property string mode: "idle"
    property bool userIdle: false
    property bool focusing: false      // a pomodoro focus round is running
    property int lastRounds: -1
    property var arrive: null          // called when a walk ends
    property int hits: 0               // ball/yarn hits this game
    property string toy: ""            // "ball" | "yarn" | "" while a toy is out
    property real spotX: -1            // where you dropped him last (-1: upper right)
    property real spotY: -1
    property bool dragged: false

    FileView {
        id: spotFile
        path: root.home + "/.local/state/desk-sam.json"
        onLoaded: { try { const o = JSON.parse(text()); root.spotX = o.x; root.spotY = o.y } catch (e) {} }
    }
    // colors from desk-theme (~/.config/themes/current/nvim.lua), so the menu matches the desk
    property var pal: ({ surface: "#0F1216", panel: "#171B21", border: "#2A3038", text: "#E6DCCB", muted: "#8E949B", accent: "#F0913C" })
    FileView {
        path: root.home + "/.config/themes/current/nvim.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const p = Object.assign({}, root.pal)
            for (const k of ["surface", "panel", "border", "text", "muted", "accent"]) {
                const m = text().match(new RegExp("\\b" + k + "\\s*=\\s*\"(#[0-9A-Fa-f]{6})\""))
                if (m) p[k] = m[1]
            }
            root.pal = p
        }
    }
    function saveSpot() { spotFile.setText(JSON.stringify({ x: Math.round(spotX), y: Math.round(spotY) }) + "\n") }

    FileView {
        path: Qt.resolvedUrl("frames/manifest.json").toString().replace("file://", "")
        onLoaded: { root.man = JSON.parse(text()); entrance.start() }
    }

    Timer {
        id: entrance
        interval: 400
        onTriggered: {
            if (win.width <= 0) { restart(); return }
            cat.x = win.width + 10
            root.walkTo(win.homeX, false, () => { if (root.focusing || root.userIdle) root.sleep(); else root.sit() })
        }
    }

    // ---- pomodoro: calm during focus ------------------------------------
    FileView {
        id: pomo
        path: root.home + "/.local/state/desk-pomodoro.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.readPomodoro(text())
    }
    Timer {        // the pomodoro file only changes on clicks; poll lightly for phase changes too
        interval: 5000; running: true; repeat: true
        onTriggered: pomo.reload()
    }

    function readPomodoro(t) {
        let s
        try { s = JSON.parse(t) } catch (e) { return }
        const was = focusing
        focusing = s.phase === "focus" && (s.paused === null || s.paused === undefined)
        const rounds = s.rounds || 0
        if (lastRounds >= 0 && rounds > lastRounds) celebrate()
        lastRounds = rounds
        if (focusing && !was) goNap()
    }

    // ---- you're away ----------------------------------------------------
    IdleMonitor {
        timeout: 180
        respectInhibitors: true
        onIsIdleChanged: {
            root.userIdle = isIdle
            if (isIdle) root.goNap()
            else if (root.mode === "sleeping" && !root.focusing) root.wake()
        }
    }

    // ---- control from desk-sam / waybar -----------------------------------
    IpcHandler {
        target: "sam"
        function feed(): string { return root.feed() }
        function ball(): string { return root.throwToy("ball") }
        function yarn(): string { return root.throwToy("yarn") }
        function treat(): string { return root.treat() }
        function home(): string { root.goHome(false); return "going home" }
        function status(): string { return root.focusing ? "focus" : root.mode }
        function menu(): string { menuBox.openOver(); return "menu" }
    }

    function frameFile(anim, i) {
        const a = man[anim]
        if (!a) return ""
        return a.frames[Math.min(i, a.frames.length - 1)]
    }
    function frames(anim) { return man[anim] ? man[anim].frames.length : 1 }
    function rand(a, b) { return a + Math.random() * (b - a) }
    function sound(name) { soundProc.command = [root.home + "/.local/bin/desk-sound", name]; soundProc.running = true }
    function busy() { return mode === "chasing" || mode === "eating" || mode === "purring" || mode === "stretching" }

    Process { id: soundProc }
    Process { id: notifyProc }
    function notify(msg) { notifyProc.command = ["notify-send", "-a", "Sam", "-i", "face-smile", "Sam", msg]; notifyProc.running = true }

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === "eDP-2") || Quickshell.screens[0]
        anchors { top: true; left: true; right: true; bottom: true }   // whole screen; input only on Sam and his things
        margins.top: 44
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "desk:sam"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        readonly property real dpr: screen ? screen.devicePixelRatio : 1
        // his spot: upper right by default, or wherever you last dropped him
        readonly property real floorY: root.spotY > 0 ? Math.min(root.spotY, height - 10) : 118
        readonly property real homeX: root.spotX >= 0 ? Math.min(root.spotX, width - 120) : width - 190
        // his part of the screen: the upper right
        readonly property real roamFrom: Math.max(4, homeX - width * 0.3)
        readonly property real roamTo: Math.min(width - 120, homeX + width * 0.15)

        mask: Region {
            item: cat
            Region { item: toyItem }
            Region { item: bowl }
            Region { item: treatItem }
            Region { item: menuBox.visible ? menuBox : null }
        }

        // ---- Sam ---------------------------------------------------------
        Item {
            id: cat
            property string anim: "blink"
            property int frame: 0
            property bool faceLeft: false
            width: img.width; height: img.height
            x: 99999                // placed off the right edge until he walks in
            y: win.floorY - height

            Image {
                id: img
                source: root.man[cat.anim] ? root.art + root.frameFile(cat.anim, cat.frame) : ""
                width: sourceSize.width / win.dpr
                height: sourceSize.height / win.dpr
                smooth: false
                transform: Scale { origin.x: img.width / 2; xScale: cat.faceLeft ? -1 : 1 }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                drag.target: pressedButtons & Qt.LeftButton ? cat : null
                drag.threshold: 6
                drag.minimumX: 0; drag.maximumX: win.width - cat.width
                drag.minimumY: 0; drag.maximumY: win.height - cat.height
                onPressed: root.dragged = false
                drag.onActiveChanged: drag.active ? root.pickUp() : root.drop()
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) menuBox.openOver()
                    else if (!root.dragged) root.purr()
                }
                onEntered: if (!pressed) root.pounce()
            }
        }

        // frame clock: each animation at its own pace; one-shots hold the last frame
        Timer {
            running: true; repeat: true
            interval: ({ walk: 130, run: 75, sleep: 1400, blink: 2500, eat: 280, jump: 110, play: 140, purr: 700, stretch: 1000 })[cat.anim] || 200
            onTriggered: {
                if (root.mode === "carried") return
                const n = root.frames(cat.anim)
                if (cat.anim === "jump" || cat.anim === "play" || cat.anim === "stretch") {
                    if (cat.frame < n - 1) cat.frame++
                } else if (cat.anim === "blink") {
                    cat.frame = 0
                    if (Math.random() < 0.45) blinkTimer.restart()
                } else {
                    cat.frame = (cat.frame + 1) % n
                }
            }
        }
        Timer { id: blinkTimer; interval: 90; onTriggered: { cat.frame = cat.frame < 2 ? cat.frame + 1 : 0; if (cat.frame !== 0) restart() } }

        NumberAnimation {
            id: walkAnim
            target: cat; property: "x"
            easing.type: Easing.Linear
            onFinished: { const f = root.arrive; root.arrive = null; if (f) f() }
        }

        // ---- toys and food -----------------------------------------------
        Image {
            id: toyItem
            property real vx: 0
            visible: root.toy !== ""
            source: root.toy ? root.art + root.toy + ".png" : ""
            width: sourceSize.width / win.dpr; height: sourceSize.height / win.dpr
            y: win.floorY - height
            smooth: false
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }
        Timer {
            id: physics
            interval: 16; repeat: true; running: root.toy !== ""
            onTriggered: {
                const dt = interval / 1000
                toyItem.x += toyItem.vx * dt
                toyItem.vx *= root.toy === "yarn" ? 0.955 : 0.975
                toyItem.rotation += toyItem.vx * dt * (root.toy === "yarn" ? 1.4 : 3)
                if (toyItem.x < 4) { toyItem.x = 4; toyItem.vx = Math.abs(toyItem.vx) * 0.7 }
                if (toyItem.x > win.width - toyItem.width - 4) { toyItem.x = win.width - toyItem.width - 4; toyItem.vx = -Math.abs(toyItem.vx) * 0.7 }
                if (Math.abs(toyItem.vx) < 6) toyItem.vx = 0
            }
        }
        Timer {        // the chase: retarget while the toy rolls, bat it when close
            id: chase
            interval: 250; repeat: true; running: root.mode === "chasing"
            onTriggered: {
                const tx = toyItem.x + toyItem.width / 2 - cat.width / 2
                const near = Math.abs(tx - cat.x) < 26
                if (near && Math.abs(toyItem.vx) < 140) {
                    walkAnim.stop()
                    root.bat()
                } else if (!walkAnim.running || Math.abs(walkAnim.to - tx) > 40) {
                    root.walkTo(tx, true, null)
                }
            }
        }

        Image {
            id: bowl
            property bool full: true
            visible: false
            source: root.art + (full ? "bowl_full.png" : "bowl_empty.png")
            width: sourceSize.width / win.dpr; height: sourceSize.height / win.dpr
            y: win.floorY - height
            smooth: false
            Behavior on opacity { NumberAnimation { duration: 600 } }
        }
        Image {
            id: treatItem
            visible: false
            source: root.art + "treat.png"
            width: sourceSize.width / win.dpr; height: sourceSize.height / win.dpr
            smooth: false
            NumberAnimation on y { id: treatFall; running: false; from: -30; to: win.floorY - treatItem.height; duration: 700; easing.type: Easing.OutBounce }
        }

        // ---- his menu: right click Sam (or the waybar paw) ------------------
        Rectangle {
            id: menuBox
            visible: false
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            width: 260
            height: menuCol.implicitHeight + 14
            radius: 12
            color: root.pal.panel
            border.color: Qt.tint(root.pal.border, Qt.rgba(1, 1, 1, 0.06))
            border.width: 1
            z: 50
            function openOver() {
                x = Math.max(8, Math.min(win.width - width - 8, cat.x + cat.width / 2 - width / 2))
                y = cat.y - height - 10 > 4 ? cat.y - height - 10 : cat.y + cat.height + 10
                visible = true
            }
            HoverHandler { id: menuHover }
            Timer {        // no keyboard focus here, so it closes once the mouse has left it a moment
                interval: 2200; running: menuBox.visible && !menuHover.hovered
                onTriggered: menuBox.visible = false
            }
            Column {
                id: menuCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 7 }
                spacing: 2
                Text {
                    text: root.focusing ? "Sam · napping · games after your break" : "Sam"
                    color: root.pal.muted
                    font { family: "FantasqueSansM Nerd Font"; pixelSize: 13 }
                    leftPadding: 8; topPadding: 2; bottomPadding: 4
                }
                Repeater {
                    model: [
                        { icon: "🍗", label: "Feed him", act: "feed", play: true },
                        { icon: "🔴", label: "Throw the ball", act: "ball", play: true },
                        { icon: "🧶", label: "Throw the yarn", act: "yarn", play: true },
                        { icon: "🐟", label: "Give a treat", act: "treat", play: true },
                        { icon: "🏠", label: "Back to his spot", act: "home", play: false },
                        { icon: "💤", label: "Hide Sam", act: "off", play: false }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool enabled_: !(modelData.play && root.focusing)
                        width: menuCol.width; height: 32; radius: 8
                        color: itemArea.containsMouse && enabled_ ? Qt.tint(root.pal.panel, Qt.rgba(1, 0.57, 0.24, 0.16)) : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 10; spacing: 10
                            Text { text: modelData.icon; font.pixelSize: 15; opacity: enabled_ ? 1 : 0.4 }
                            Text {
                                text: modelData.label
                                color: enabled_ ? (itemArea.containsMouse ? root.pal.accent : root.pal.text) : root.pal.muted
                                font { family: "FantasqueSansM Nerd Font"; pixelSize: 14 }
                            }
                        }
                        MouseArea {
                            id: itemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: enabled_ ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: { if (!enabled_) return; menuBox.visible = false; root.act(modelData.act) }
                        }
                    }
                }
            }
        }

        // a speech bubble over him, for a couple of seconds
        Rectangle {
            id: bubble
            visible: false
            z: 40
            radius: 9
            color: root.pal.panel
            border.color: root.pal.border
            width: bubbleText.implicitWidth + 22; height: bubbleText.implicitHeight + 12
            x: Math.max(6, Math.min(win.width - width - 6, cat.x + cat.width / 2 - width / 2))
            y: cat.y - height - 6
            function say(t) { bubbleText.text = t; visible = true; bubbleTimer.restart() }
            Text {
                id: bubbleText
                anchors.centerIn: parent
                color: root.pal.text
                font { family: "FantasqueSansM Nerd Font"; pixelSize: 14 }
            }
            Timer { id: bubbleTimer; interval: 2600; onTriggered: bubble.visible = false }
        }

        // ---- little effects: z's while asleep, hearts while purring -------
        Component {
            id: floater
            Image {
                id: f
                property string kind: "z"
                source: root.art + kind + ".png"
                width: sourceSize.width / win.dpr * 0.8; height: sourceSize.height / win.dpr * 0.8
                smooth: false
                ParallelAnimation {
                    running: true
                    NumberAnimation { target: f; property: "y"; to: f.y - 34; duration: 2200 }
                    NumberAnimation { target: f; property: "x"; to: f.x + root.rand(-8, 12); duration: 2200 }
                    NumberAnimation { target: f; property: "opacity"; from: 1; to: 0; duration: 2200 }
                    onFinished: f.destroy()
                }
            }
        }
        function puff(kind) {
            floater.createObject(win.contentItem, { kind: kind, x: cat.x + cat.width * (cat.faceLeft ? 0.2 : 0.65), y: cat.y - 4 })
        }
        Timer { interval: 2600; repeat: true; running: root.mode === "sleeping"; onTriggered: win.puff("z") }
        Timer { interval: 650; repeat: true; running: root.mode === "purring" && !root.focusing; onTriggered: win.puff("heart") }

        // ---- the everyday rhythm -------------------------------------------
        Timer {
            id: wander
            interval: 30000; repeat: true; running: true
            onTriggered: {
                interval = root.rand(25000, 70000)
                if (root.mode !== "idle" || root.focusing || root.userIdle) return
                const r = Math.random()
                if (r < 0.7) root.walkTo(root.rand(win.roamFrom, win.roamTo), false, () => root.sit())
                else if (r < 0.85) { root.mode = "pouncing"; root.setAnim("play"); later.go(900, () => root.sit()) }
            }
        }
        Timer {
            id: later
            property var fn: null
            function go(ms, f) { fn = f; interval = ms; restart() }
            onTriggered: { const f = fn; fn = null; if (f) f() }
        }
    }

    // ---- behaviours ---------------------------------------------------------
    function setAnim(a) { if (cat.anim !== a) { cat.anim = a; cat.frame = 0 } }

    // picked up with the mouse: dangle mid-air; dropped: that's his new spot
    function pickUp() {
        dragged = true
        walkAnim.stop()
        arrive = null
        later.stop()
        mode = "carried"
        setAnim("jump")
        cat.frame = 1
    }
    function drop() {
        spotX = cat.x
        spotY = cat.y + cat.height
        saveSpot()
        cat.y = Qt.binding(() => win.floorY - cat.height)
        mode = "pouncing"
        cat.frame = 2
        later.go(450, () => { if (focusing || userIdle) sleep(); else sit() })
    }
    function sit() { mode = "idle"; setAnim("blink") }

    function walkTo(x, run, then) {
        x = Math.max(4, Math.min(win.width - cat.width - 4, x))   // targets stay on screen
        walkAnim.stop()
        cat.faceLeft = x < cat.x
        setAnim(run ? "run" : "walk")
        if (mode === "idle" || mode === "sleeping") mode = "walking"
        walkAnim.from = cat.x
        walkAnim.to = x
        walkAnim.duration = Math.max(120, Math.abs(x - cat.x) / (run ? 340 : 90) * 1000)
        arrive = then
        walkAnim.start()
    }

    function goHome(sleepAfter) {
        if (busy() && !focusing) return
        toy = ""
        bowl.visible = false
        treatItem.visible = false
        walkTo(win.homeX, false, sleepAfter ? (() => sleep()) : (() => sit()))
    }
    function goNap() { if (mode !== "sleeping") goHome(true) }
    function sleep() { mode = "sleeping"; setAnim("sleep") }
    function wake() { mode = "stretching"; setAnim("stretch"); later.go(1600, () => sit()) }

    function purr() {
        if (mode === "chasing" || mode === "eating") return
        const wasAsleep = mode === "sleeping"
        mode = "purring"
        setAnim("purr")
        if (!focusing) sound("purr")
        later.go(focusing ? 1800 : 4200, () => { if (focusing || (wasAsleep && userIdle)) sleep(); else sit() })
    }
    function pounce() {
        if (mode !== "idle" || focusing) return
        mode = "pouncing"
        setAnim("jump")
        later.go(700, () => sit())
    }
    function celebrate() {          // a focus round just ended
        mode = "stretching"
        setAnim("stretch")
        later.go(1800, () => purr())
    }

    Process { id: offProc; command: [root.home + "/.local/bin/desk-sam", "off"] }
    function act(a) {
        if (a === "feed") feed()
        else if (a === "ball" || a === "yarn") throwToy(a)
        else if (a === "treat") treat()
        else if (a === "home") goHome(focusing)
        else if (a === "off") offProc.running = true
    }

    function refuse() {
        bubble.say("zZ… after your break")
        return "focus: Sam is napping until your break"
    }
    function throwToy(kind) {
        if (focusing) return refuse()
        walkAnim.stop()
        toy = kind
        hits = 0
        toyItem.x = cat.x > win.width * 0.75 ? root.rand(win.width * 0.45, win.width * 0.62) : root.rand(win.width * 0.8, win.width - 80)
        toyItem.vx = root.rand(-160, 160)
        mode = "chasing"
        return "threw the " + kind
    }
    function bat() {
        mode = "pouncing"
        cat.faceLeft = toyItem.x + toyItem.width / 2 < cat.x + cat.width / 2
        setAnim("play")
        later.go(420, () => {
            hits++
            const away = cat.faceLeft ? -1 : 1
            toyItem.vx = away * root.rand(toy === "yarn" ? 260 : 420, toy === "yarn" ? 420 : 760)
            if (hits >= 5) { mode = "idle"; later.go(1600, () => { toy = ""; purr() }) }
            else mode = "chasing"
        })
    }
    function feed() {
        if (focusing) return refuse()
        bowl.full = true
        bowl.x = cat.x > win.width * 0.75 ? root.rand(win.width * 0.5, win.width * 0.65) : root.rand(win.width * 0.8, win.width - 140)
        bowl.opacity = 1
        bowl.visible = true
        mode = "walking"
        walkTo(bowl.x + bowl.width / 2 - cat.width / 2 + (cat.x < bowl.x ? -10 : 10), true, () => {
            mode = "eating"
            cat.faceLeft = bowl.x + bowl.width / 2 < cat.x + cat.width / 2
            setAnim("eat")
            later.go(6000, () => {
                bowl.full = false
                purr()
                fade.go(3500, () => { bowl.opacity = 0; fade2.go(700, () => bowl.visible = false) })
            })
        })
        return "dinner is served"
    }
    function treat() {
        if (focusing) return refuse()
        treatItem.x = root.rand(win.width * 0.5, win.width - 120)
        treatItem.visible = true
        treatFall.restart()
        mode = "walking"
        walkTo(treatItem.x - cat.width / 2, true, () => {
            mode = "pouncing"
            setAnim("jump")
            later.go(450, () => {
                treatItem.visible = false
                mode = "eating"
                setAnim("eat")
                later.go(1500, () => purr())
            })
        })
        return "treat!"
    }
    Timer { id: fade; property var fn: null; function go(ms, f) { fn = f; interval = ms; restart() } onTriggered: { const f = fn; fn = null; if (f) f() } }
    Timer { id: fade2; property var fn: null; function go(ms, f) { fn = f; interval = ms; restart() } onTriggered: { const f = fn; fn = null; if (f) f() } }
}
