//
//  main.swift
//  anydesk-macos-windows-remap
//  Author: dangphuc2470
//  Description: A complete, secure macOS EventTap daemon for AnyDesk that maps all Windows shortcuts
//               (Ctrl+C/V/Z/A, Ctrl+Backspace, Win+Shift+S, Win+L, Win+D, Win+Tab, Ctrl+Arrows, etc.)
//  Security: No network access, no disk logging, 100% local in-memory event modifier.
//

import Foundation
import CoreGraphics
import AppKit
import Darwin


func getAllAnyDeskPIDs() -> Set<pid_t> {
    var pids = Set<pid_t>()
    let bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
    if bufferSize > 0 {
        let count = Int(bufferSize) / MemoryLayout<pid_t>.stride
        var pidList = [pid_t](repeating: 0, count: count)
        let bytesReturned = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pidList, bufferSize)
        let actualCount = Int(bytesReturned) / MemoryLayout<pid_t>.stride
        for i in 0..<actualCount {
            let pid = pidList[i]
            if pid <= 0 { continue }
            var pathBuffer = [CChar](repeating: 0, count: 4096)
            let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
            if pathLength > 0 {
                let path = String(cString: pathBuffer)
                if path.lowercased().contains("anydesk") && !path.contains("anydesk_remap") && !path.contains("phucdnh_anydesk_remap") {
                    pids.insert(pid)
                }
            }
        }
    }
    return pids
}

var cachedAnyDeskPIDs = getAllAnyDeskPIDs()
var lastPIDCheck = Date()

func isAnyDeskEvent(_ event: CGEvent) -> Bool {
    if Date().timeIntervalSince(lastPIDCheck) > 3.0 {
        cachedAnyDeskPIDs = getAllAnyDeskPIDs()
        lastPIDCheck = Date()
    }
    
    let sourcePID = pid_t(event.getIntegerValueField(.eventSourceUnixProcessID))
    if sourcePID != 0 && cachedAnyDeskPIDs.contains(sourcePID) {
        return true
    }
    return false
}

// macOS US-layout keyCode table for ASCII printable characters.
// AnyDesk injects all keys as kc=0 + unicode string.
// QEMU-based emulators (qemu-system-aarch64, etc.) ignore the unicode field
// and use only the macOS keyCode — so kc=0 always means 'a'.
// We translate kc=0 + unicode -> correct keyCode before passing to QEMU.
let unicodeToKeyCode: [Character: Int64] = [
    "a": 0,  "b": 11, "c": 8,  "d": 2,  "e": 14, "f": 3,  "g": 5,
    "h": 4,  "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45,
    "o": 31, "p": 35, "q": 12, "r": 15, "s": 1,  "t": 17, "u": 32,
    "v": 9,  "w": 13, "x": 7,  "y": 16, "z": 6,
    "A": 0,  "B": 11, "C": 8,  "D": 2,  "E": 14, "F": 3,  "G": 5,
    "H": 4,  "I": 34, "J": 38, "K": 40, "L": 37, "M": 46, "N": 45,
    "O": 31, "P": 35, "Q": 12, "R": 15, "S": 1,  "T": 17, "U": 32,
    "V": 9,  "W": 13, "X": 7,  "Y": 16, "Z": 6,
    "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
    "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,
    "!": 18, "@": 19, "#": 20, "$": 21, "%": 23,
    "^": 22, "&": 26, "*": 28, "(": 25, ")": 29,
    " ": 49, "\r": 36, "\n": 36, "\t": 48,
    "-": 27, "_": 27, "=": 24, "+": 24,
    "[": 33, "{": 33, "]": 30, "}": 30,
    "\\": 42, "|": 42, ";": 41, ":": 41,
    "'": 39, "\"": 39, ",": 43, "<": 43,
    ".": 47, ">": 47, "/": 44, "?": 44,
    "`": 50, "~": 50,
]

// Characters that require Shift on a US keyboard layout.
let shiftRequiredChars: Set<Character> = [
    "A","B","C","D","E","F","G","H","I","J","K","L","M",
    "N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
    "!","@","#","$","%","^","&","*","(",")",
    "_","+","{","}","|",":","\"","<",">","?","~"
]

// Returns true for QEMU-based Android emulators.
// These processes have no macOS bundle ID and use raw macOS keyCodes
// (not the unicode field), so kc=0 events must be remapped to correct keyCodes.
func isFrontmostAppQEMU() -> Bool {
    guard let app = NSWorkspace.shared.frontmostApplication else { return false }
    let name = app.localizedName?.lowercased() ?? ""
    return name.contains("qemu") ||
           name.contains("emulator") ||
           name.contains("bluestacks") ||
           name.contains("genymotion") ||
           name.contains("noxplayer") ||
           name.contains("ldplayer")
}

// Returns true for apps that should receive all key events 100% untouched:
// - AnyDesk nested session (Mac -> another PC via AnyDesk)
// - VM apps (VMware Fusion, Parallels, VirtualBox)
// Note: QEMU/Android emulators are handled separately by isFrontmostAppQEMU()
// because they need keyCode correction, not just a plain pass-through.
func isFrontmostAppPassThrough() -> Bool {
    guard let app = NSWorkspace.shared.frontmostApplication else { return false }
    let bundleID = app.bundleIdentifier ?? ""
    let name = app.localizedName?.lowercased() ?? ""

    // AnyDesk nested session to another PC
    if bundleID.contains("anydesk") || bundleID.contains("philandro") { return true }
    if name.contains("anydesk") { return true }

    // Virtual machines that support unicode via Accessibility
    if bundleID.contains("vmware") || bundleID.contains("parallels") || bundleID.contains("virtualbox") { return true }
    if name.contains("vmware") || name.contains("parallels") || name.contains("virtualbox") { return true }

    return false
}

// AnyDesk injects all character keys as kc=0 + unicode string.
// Apps that capture raw hardware keyCodes (like QEMU or AnyDesk nested sessions connecting
// to a remote Windows PC) see kc=0 and interpret it as 'a' (kVK_ANSI_A).
// This translates kc=0 + unicode -> correct macOS keyCode.
func fixAnyDeskZeroKeyCode(event: CGEvent, type: CGEventType) {
    guard type == .keyDown || type == .keyUp else { return }
    let kc = event.getIntegerValueField(.keyboardEventKeycode)
    guard kc == 0 else { return }
    var ucLen: Int = 0
    var ucBuf = [UniChar](repeating: 0, count: 4)
    event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &ucLen, unicodeString: &ucBuf)
    guard ucLen > 0 else { return }
    let ucStr = String(decoding: ucBuf.prefix(ucLen), as: UTF16.self)
    guard let ch = ucStr.first, let correctKC = unicodeToKeyCode[ch] else { return }
    if correctKC != 0 {
        event.setIntegerValueField(.keyboardEventKeycode, value: correctKC)
    }
    if shiftRequiredChars.contains(ch) && !event.flags.contains(.maskShift) {
        var fl = event.flags
        fl.insert(.maskShift)
        event.flags = fl
    }
}

var isCtrlSpaceActive = false

func eventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    // Only modify events originating from AnyDesk processes
    guard isAnyDeskEvent(event) else {
        return Unmanaged.passUnretained(event)
    }

    // Fix AnyDesk kc=0 bug for all injected key events
    fixAnyDeskZeroKeyCode(event: event, type: type)

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    var flags = event.flags
    
    let hasCtrl = flags.contains(.maskControl)
    let hasCmd = flags.contains(.maskCommand)
    let hasAlt = flags.contains(.maskAlternate)
    let hasShift = flags.contains(.maskShift)

    // --- Windows Shortcut: Ctrl + Space -> Enter ---
    if type == .keyDown {
        if keyCode == 49 && hasCtrl && !hasAlt {
            isCtrlSpaceActive = true
            event.setIntegerValueField(.keyboardEventKeycode, value: 36)
            flags.remove(.maskControl)
            flags.remove(.maskCommand)
            if !hasShift {
                flags.remove(.maskShift)
            }
            event.flags = flags
            var enterChar: [UniChar] = [13]
            event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &enterChar)
            return Unmanaged.passUnretained(event)
        }
    } else if type == .keyUp {
        if isCtrlSpaceActive && (keyCode == 49 || keyCode == 36) {
            isCtrlSpaceActive = false
            event.setIntegerValueField(.keyboardEventKeycode, value: 36)
            flags.remove(.maskControl)
            flags.remove(.maskCommand)
            if !hasShift {
                flags.remove(.maskShift)
            }
            event.flags = flags
            var enterChar: [UniChar] = [13]
            event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &enterChar)
            return Unmanaged.passUnretained(event)
        }
    }

    // --- Pass-through for QEMU/Android emulators, AnyDesk nested sessions, and VMs ---
    // These apps manage their own shortcuts or forward keys to a remote/guest OS,
    // so we bypass Mac shortcut remapping (Cmd <-> Ctrl, etc.) while passing the corrected keyCode.
    if isFrontmostAppQEMU() || isFrontmostAppPassThrough() {
        return Unmanaged.passUnretained(event)
    }
    
    // ----------------------------------------------------
    // 1. Modifier Key State Changes (flagsChanged)
    // ----------------------------------------------------
    if type == .flagsChanged {
        // Swap Left Control (59) <-> Left Command (55)
        if keyCode == 59 {
            event.setIntegerValueField(.keyboardEventKeycode, value: 55)
            if flags.contains(.maskControl) {
                flags.remove(.maskControl)
                flags.insert(.maskCommand)
            } else {
                flags.remove(.maskCommand)
            }
            event.flags = flags
        } else if keyCode == 55 {
            event.setIntegerValueField(.keyboardEventKeycode, value: 59)
            if flags.contains(.maskCommand) {
                flags.remove(.maskCommand)
                flags.insert(.maskControl)
            } else {
                flags.remove(.maskControl)
            }
            event.flags = flags
        }
        // Swap Right Control (62) <-> Right Command (54)
        else if keyCode == 62 {
            event.setIntegerValueField(.keyboardEventKeycode, value: 54)
            if flags.contains(.maskControl) {
                flags.remove(.maskControl)
                flags.insert(.maskCommand)
            } else {
                flags.remove(.maskCommand)
            }
            event.flags = flags
        } else if keyCode == 54 {
            event.setIntegerValueField(.keyboardEventKeycode, value: 62)
            if flags.contains(.maskCommand) {
                flags.remove(.maskCommand)
                flags.insert(.maskControl)
            } else {
                flags.remove(.maskControl)
            }
            event.flags = flags
        }
        return Unmanaged.passUnretained(event)
    }
    
    // ----------------------------------------------------
    // 2. Scroll Wheel Events (scrollWheel)
    // ----------------------------------------------------
    if type == .scrollWheel {
        if hasCtrl != hasCmd {
            if hasCtrl {
                flags.remove(.maskControl)
                flags.insert(.maskCommand)
            } else if hasCmd {
                flags.remove(.maskCommand)
                flags.insert(.maskControl)
            }
            event.flags = flags
        }
        return Unmanaged.passUnretained(event)
    }
    
    // ----------------------------------------------------
    // 3. Key Combinations (keyDown & keyUp)
    // ----------------------------------------------------
    if type == .keyDown || type == .keyUp {
        
        // --- Windows Shortcut: Win + Shift + S -> macOS Area Screenshot to Clipboard (Ctrl + Cmd + Shift + 4) ---
        if keyCode == 1 && hasCmd && hasShift { // 's' with Cmd + Shift
            event.setIntegerValueField(.keyboardEventKeycode, value: 21) // '4'
            flags.insert(.maskControl)
            flags.insert(.maskCommand)
            flags.insert(.maskShift)
            event.flags = flags
            return Unmanaged.passUnretained(event)
        }
        
        // --- Windows Shortcut: Win + L / Win + Shift + L / Ctrl + Alt + L -> Lock Screen (Ctrl + Cmd + Q) ---
        if keyCode == 37 && (hasCmd || (hasCtrl && hasAlt)) { // 'l' with Win, Win+Shift, or Ctrl+Alt
            event.setIntegerValueField(.keyboardEventKeycode, value: 12) // 'q'
            flags.insert(.maskControl)
            flags.insert(.maskCommand)
            flags.remove(.maskShift)
            flags.remove(.maskAlternate)
            event.flags = flags
            return Unmanaged.passUnretained(event)
        }
        
        // --- Windows Shortcut: Win + D -> Show Desktop (F11) ---
        if keyCode == 2 && hasCmd && !hasCtrl && !hasAlt && !hasShift { // 'd' with Cmd
            event.setIntegerValueField(.keyboardEventKeycode, value: 103) // F11
            flags.remove(.maskCommand)
            flags.remove(.maskControl)
            event.flags = flags
            return Unmanaged.passUnretained(event)
        }
        
        // --- Windows Shortcut: Win + Tab -> Mission Control (Ctrl + Up Arrow) ---
        if keyCode == 48 && hasCmd && !hasCtrl && !hasAlt && !hasShift { // Tab with Cmd
            event.setIntegerValueField(.keyboardEventKeycode, value: 126) // Up Arrow
            flags.remove(.maskCommand)
            flags.insert(.maskControl)
            event.flags = flags
            return Unmanaged.passUnretained(event)
        }
        
        // --- Windows Shortcut: Ctrl + Backspace -> Option + Backspace (Delete word backward) ---
        if keyCode == 51 && hasCtrl && !hasCmd && !hasAlt && !hasShift { // Backspace with Ctrl
            flags.remove(.maskControl)
            flags.insert(.maskAlternate) // Option
            event.flags = flags
            return Unmanaged.passUnretained(event)
        }
        
        // --- Windows Shortcut: Ctrl + Delete -> Option + Delete (Delete word forward) ---
        if keyCode == 117 && hasCtrl && !hasCmd && !hasAlt && !hasShift { // Forward Delete with Ctrl
            flags.remove(.maskControl)
            flags.insert(.maskAlternate) // Option
            event.flags = flags
            return Unmanaged.passUnretained(event)
        }
        
        // --- Windows Shortcut: Option + Backspace (Alt+Bksp) -> Cmd + Backspace (Delete line to start) ---
        if keyCode == 51 && hasAlt && !hasCtrl && !hasCmd && !hasShift {
            flags.remove(.maskAlternate)
            flags.insert(.maskCommand)
            event.flags = flags
            return Unmanaged.passUnretained(event)
        }
        
        // --- Windows Shortcut: Ctrl + Left/Right Arrow -> Option + Left/Right Arrow (Move word by word) ---
        if (keyCode == 123 || keyCode == 124) && hasCtrl && !hasCmd && !hasAlt && !hasShift {
            flags.remove(.maskControl)
            flags.insert(.maskAlternate) // Option
            event.flags = flags
            return Unmanaged.passUnretained(event)
        }
        
        // --- Windows Shortcut: Ctrl + Shift + Left/Right Arrow -> Option + Shift + Left/Right Arrow (Select word by word) ---
        if (keyCode == 123 || keyCode == 124) && hasCtrl && hasShift && !hasCmd && !hasAlt {
            flags.remove(.maskControl)
            flags.insert(.maskAlternate) // Option
            event.flags = flags
            return Unmanaged.passUnretained(event)
        }
        
        // --- Windows Shortcut: Option + Shift + Left/Right Arrow -> Cmd + Shift + Left/Right Arrow (Select line by line) ---
        if (keyCode == 123 || keyCode == 124) && hasAlt && hasShift && !hasCtrl && !hasCmd {
            flags.remove(.maskAlternate)
            flags.insert(.maskCommand)
            event.flags = flags
            return Unmanaged.passUnretained(event)
        }
        
        // --- Windows Shortcut: Ctrl + J -> Option + Cmd + L (Downloads) ---
        if keyCode == 38 && hasCtrl && !hasCmd && !hasAlt && !hasShift { // 'j' with Ctrl
            event.setIntegerValueField(.keyboardEventKeycode, value: 37) // 'l'
            flags.remove(.maskControl)
            flags.insert(.maskAlternate)
            flags.insert(.maskCommand)
            event.flags = flags
            return Unmanaged.passUnretained(event)
        }
        
        // --- Windows Shortcut: Ctrl + H -> Replace / History (Avoid hiding app) ---
        if keyCode == 4 && hasCtrl && !hasCmd && !hasAlt && !hasShift { // 'h' with Ctrl
            let frontmostID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
            if frontmostID.contains("edgemac") || frontmostID.contains("Chrome") || frontmostID.contains("Safari") || frontmostID.contains("Browser") {
                // Browser History (Cmd + Y)
                event.setIntegerValueField(.keyboardEventKeycode, value: 16) // 'y'
                flags.remove(.maskControl)
                flags.insert(.maskCommand)
            } else {
                // Editor Find & Replace (Option + Cmd + F)
                event.setIntegerValueField(.keyboardEventKeycode, value: 3) // 'f'
                flags.remove(.maskControl)
                flags.insert(.maskAlternate)
                flags.insert(.maskCommand)
            }
            event.flags = flags
            return Unmanaged.passUnretained(event)
        }
        
        // --- Default: Swap Control <-> Command for all other shortcuts (Ctrl+C/V/Z/A/S/F/etc.) ---
        if hasCtrl != hasCmd {
            if hasCtrl {
                flags.remove(.maskControl)
                flags.insert(.maskCommand)
            } else if hasCmd {
                flags.remove(.maskCommand)
                flags.insert(.maskControl)
            }
            event.flags = flags
        }
    }
    
    return Unmanaged.passUnretained(event)
}

print("[dangphuc2470] AnyDesk Remap Daemon starting...")

let eventMask = (1 << CGEventType.keyDown.rawValue) |
                (1 << CGEventType.keyUp.rawValue) |
                (1 << CGEventType.flagsChanged.rawValue) |
                (1 << CGEventType.scrollWheel.rawValue)

var eventTap: CFMachPort? = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: eventCallback,
    userInfo: nil
)

if eventTap == nil {
    eventTap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: eventCallback,
        userInfo: nil
    )
}

guard let tap = eventTap else {
    print("[dangphuc2470] ERROR: Failed to create CGEventTap. Please grant Accessibility permissions.")
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("[dangphuc2470] AnyDesk Remap Daemon is ACTIVE. Intercepting all AnyDesk processes safely.")
CFRunLoopRun()
