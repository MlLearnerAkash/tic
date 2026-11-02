import Foundation
import Carbon.HIToolbox

private let ticHotKeySignature: OSType = 0x54494331 // "TIC1"

private func ticHotKeyHandler(_ nextHandler: EventHandlerCallRef?,
                              _ event: EventRef?,
                              _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let userData else { return noErr }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        manager.handle(id: hotKeyID.id)
    }
    return noErr
}

final class HotKeyManager {
    var onOpen: (() -> Void)?
    var onFocus: (() -> Void)?

    private var handlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private(set) var registered = true

    func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            ticHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )

        // ⌃⌥⌘T — open Tic from anywhere.
        let openID = EventHotKeyID(signature: ticHotKeySignature, id: 1)
        var openRef: EventHotKeyRef?
        let openStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_T),
            UInt32(controlKey | optionKey | cmdKey),
            openID,
            GetApplicationEventTarget(),
            0,
            &openRef
        )
        if openStatus == noErr, let openRef {
            hotKeyRefs.append(openRef)
        } else {
            registered = false
        }

        // ⇧⌘F — open Focus, ready to start.
        let focusID = EventHotKeyID(signature: ticHotKeySignature, id: 2)
        var focusRef: EventHotKeyRef?
        let focusStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_F),
            UInt32(shiftKey | cmdKey),
            focusID,
            GetApplicationEventTarget(),
            0,
            &focusRef
        )
        if focusStatus == noErr, let focusRef {
            hotKeyRefs.append(focusRef)
        } else {
            registered = false
        }
    }

    func handle(id: UInt32) {
        switch id {
        case 1: onOpen?()
        case 2: onFocus?()
        default: break
        }
    }

    deinit {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }
}
