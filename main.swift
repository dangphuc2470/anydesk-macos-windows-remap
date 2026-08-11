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

// Target AnyDesk Bundle Identifiers
let anydeskBundleIDs = [
    "com.philandro.anydesk",
    "com.anydesk.anydesk"
]

func getAnyDeskPIDs() -> Set<pid_t> {
    var pids = Set<pid_t>()
    for bundleID in anydeskBundleIDs {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        for app in apps {
            pids.insert(app.processIdentifier)
        }
    }
    
    let allApps = NSWorkspace.shared.runningApplications
    for app in allApps {
        if let name = app.localizedName, name.lowercased().contains("anydesk") {
            pids.insert(app.processIdentifier)
        }
    }
    return pids
}

var cachedAnyDeskPIDs = getAnyDeskPIDs()
var lastPIDCheck = Date()

func isAnyDeskEvent(_ event: CGEvent) -> Bool {
    if Date().timeIntervalSince(lastPIDCheck) > 5.0 {
        cachedAnyDeskPIDs = getAnyDeskPIDs()
        lastPIDCheck = Date()
    }
    
    let sourcePID = pid_t(event.getIntegerValueField(.eventSourceUnixProcessID))
    if sourcePID != 0 && cachedAnyDeskPIDs.contains(sourcePID) {
        return true
    }
    return false
}

func getFrontmostAppBundleID() -> String? {
    return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
}

func eventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    // Only modify events originating from AnyDesk processes
    guard isAnyDeskEvent(event) else {
        return Unmanaged.passUnretained(event)
    }
    
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    var flags = event.flags
    
    let hasCtrl = flags.contains(.maskControl)
    let hasCmd = flags.contains(.maskCommand)
    let hasAlt = flags.contains(.maskAlternate)
    let hasShift = flags.contains(.maskShift)
    
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
    // 2. Key Combinations (keyDown & keyUp)
    // ----------------------------------------------------
    if type == .keyDown || type == .keyUp {
        
        // --- Windows Shortcut: Win + Shift + S -> macOS Area Screenshot (Cmd + Shift + 4) ---
        if keyCode == 1 && hasCmd && hasShift { // 's' with Cmd + Shift
            event.setIntegerValueField(.keyboardEventKeycode, value: 21) // '4'
            flags.insert(.maskCommand)
            flags.insert(.maskShift)
            flags.remove(.maskControl)
            event.flags = flags
            return Unmanaged.passUnretained(event)
        }
        
        // --- Windows Shortcut: Win + L -> Lock Screen (Ctrl + Cmd + Q) ---
        if keyCode == 37 && hasCmd && !hasCtrl && !hasAlt && !hasShift { // 'l' with Cmd
            event.setIntegerValueField(.keyboardEventKeycode, value: 12) // 'q'
            flags.insert(.maskControl)
            flags.insert(.maskCommand)
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
            let frontmostID = getFrontmostAppBundleID() ?? ""
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

print("[phucdnh] AnyDesk Remap Daemon starting...")

let eventMask = (1 << CGEventType.keyDown.rawValue) |
                (1 << CGEventType.keyUp.rawValue) |
                (1 << CGEventType.flagsChanged.rawValue)

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
    print("[phucdnh] ERROR: Failed to create CGEventTap. Please grant Accessibility permissions in System Settings -> Privacy & Security -> Accessibility.")
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("[phucdnh] AnyDesk Remap Daemon is ACTIVE.")
CFRunLoopRun()
