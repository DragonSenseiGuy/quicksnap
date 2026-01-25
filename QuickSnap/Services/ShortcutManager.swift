import Carbon
import AppKit
import Combine

class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()
    
    @Published var shortcuts: [ShortcutAction: KeyboardShortcut] = [:]
    
    private var hotKeyRefs: [ShortcutAction: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var hotKeyIDMap: [UInt32: ShortcutAction] = [:]
    private var nextHotKeyID: UInt32 = 1
    
    var onShortcutTriggered: ((ShortcutAction) -> Void)?
    
    enum ShortcutAction: String, CaseIterable, Codable {
        case captureFullScreen
        case captureRegion
        case recordFullScreen
        case recordRegion
        case ocrCapture
        case stopRecording
    }
    
    struct KeyboardShortcut: Codable, Equatable {
        var keyCode: UInt32
        var modifiers: UInt32
        
        var displayString: String {
            var result = ""
            
            if modifiers & UInt32(controlKey) != 0 {
                result += "⌃"
            }
            if modifiers & UInt32(optionKey) != 0 {
                result += "⌥"
            }
            if modifiers & UInt32(shiftKey) != 0 {
                result += "⇧"
            }
            if modifiers & UInt32(cmdKey) != 0 {
                result += "⌘"
            }
            
            if let keyString = keyCodeToString(keyCode) {
                result += keyString
            }
            
            return result
        }
        
        private func keyCodeToString(_ keyCode: UInt32) -> String? {
            let keyCodeMap: [UInt32: String] = [
                0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
                8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
                16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
                23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
                30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↵",
                37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
                44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
                51: "⌫", 53: "⎋", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
                100: "F8", 101: "F9", 103: "F11", 105: "F13", 107: "F14",
                109: "F10", 111: "F12", 113: "F15", 118: "F4", 119: "F2",
                120: "F1", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
            ]
            return keyCodeMap[keyCode]
        }
        
        static let defaults: [ShortcutAction: KeyboardShortcut] = [
            .captureFullScreen: KeyboardShortcut(keyCode: 20, modifiers: UInt32(cmdKey | shiftKey)),
            .captureRegion: KeyboardShortcut(keyCode: 21, modifiers: UInt32(cmdKey | shiftKey)),
            .recordFullScreen: KeyboardShortcut(keyCode: 22, modifiers: UInt32(cmdKey | shiftKey)),
            .recordRegion: KeyboardShortcut(keyCode: 23, modifiers: UInt32(cmdKey | shiftKey)),
            .ocrCapture: KeyboardShortcut(keyCode: 25, modifiers: UInt32(cmdKey | shiftKey)),
            .stopRecording: KeyboardShortcut(keyCode: 53, modifiers: UInt32(cmdKey | shiftKey))
        ]
    }
    
    private init() {
        loadShortcuts()
        setupEventHandler()
    }
    
    deinit {
        unregisterAllShortcuts()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
    
    private func setupEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleHotKeyEvent(event: event)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        
        if status != noErr {
            print("Failed to install event handler: \(status)")
        }
    }
    
    private func handleHotKeyEvent(event: EventRef?) -> OSStatus {
        guard let event = event else { return OSStatus(eventNotHandledErr) }
        
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
        
        if let action = hotKeyIDMap[hotKeyID.id] {
            DispatchQueue.main.async { [weak self] in
                self?.onShortcutTriggered?(action)
            }
        }
        
        return noErr
    }
    
    func registerAllShortcuts() {
        for (action, shortcut) in shortcuts {
            registerHotKey(for: action, shortcut: shortcut)
        }
    }
    
    func unregisterAllShortcuts() {
        for (action, hotKeyRef) in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
            if let id = hotKeyIDMap.first(where: { $0.value == action })?.key {
                hotKeyIDMap.removeValue(forKey: id)
            }
        }
        hotKeyRefs.removeAll()
    }
    
    private func registerHotKey(for action: ShortcutAction, shortcut: KeyboardShortcut) {
        if let existingRef = hotKeyRefs[action] {
            UnregisterEventHotKey(existingRef)
            hotKeyRefs.removeValue(forKey: action)
        }
        
        let hotKeyID = nextHotKeyID
        nextHotKeyID += 1
        
        var eventHotKeyID = EventHotKeyID(signature: OSType(0x5153_4150), id: hotKeyID) // "QSAP"
        var hotKeyRef: EventHotKeyRef?
        
        let carbonModifiers = carbonModifierFlags(from: shortcut.modifiers)
        
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            carbonModifiers,
            eventHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr, let ref = hotKeyRef {
            hotKeyRefs[action] = ref
            hotKeyIDMap[hotKeyID] = action
        } else {
            print("Failed to register hot key for \(action): \(status)")
        }
    }
    
    private func carbonModifierFlags(from modifiers: UInt32) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        
        if modifiers & UInt32(cmdKey) != 0 {
            carbonModifiers |= UInt32(cmdKey)
        }
        if modifiers & UInt32(shiftKey) != 0 {
            carbonModifiers |= UInt32(shiftKey)
        }
        if modifiers & UInt32(optionKey) != 0 {
            carbonModifiers |= UInt32(optionKey)
        }
        if modifiers & UInt32(controlKey) != 0 {
            carbonModifiers |= UInt32(controlKey)
        }
        
        return carbonModifiers
    }
    
    func updateShortcut(_ action: ShortcutAction, to shortcut: KeyboardShortcut) {
        shortcuts[action] = shortcut
        registerHotKey(for: action, shortcut: shortcut)
        saveShortcuts()
    }
    
    func saveShortcuts() {
        let encoder = JSONEncoder()
        var shortcutData: [String: Data] = [:]
        
        for (action, shortcut) in shortcuts {
            if let data = try? encoder.encode(shortcut) {
                shortcutData[action.rawValue] = data
            }
        }
        
        UserDefaults.standard.set(shortcutData, forKey: "QuickSnapShortcuts")
    }
    
    func loadShortcuts() {
        let decoder = JSONDecoder()
        
        if let shortcutData = UserDefaults.standard.dictionary(forKey: "QuickSnapShortcuts") as? [String: Data] {
            for (actionRaw, data) in shortcutData {
                if let action = ShortcutAction(rawValue: actionRaw),
                   let shortcut = try? decoder.decode(KeyboardShortcut.self, from: data) {
                    shortcuts[action] = shortcut
                }
            }
        }
        
        for action in ShortcutAction.allCases {
            if shortcuts[action] == nil {
                shortcuts[action] = KeyboardShortcut.defaults[action]
            }
        }
    }
    
    func resetToDefaults() {
        unregisterAllShortcuts()
        shortcuts = KeyboardShortcut.defaults
        saveShortcuts()
        registerAllShortcuts()
    }
}
