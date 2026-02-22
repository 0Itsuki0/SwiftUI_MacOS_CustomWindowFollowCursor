import SwiftUI

@Observable class WindowFollowCursorManager {
    
    var cursorLocation: NSPoint = .init(x: NSEvent.mouseLocation.x + offset, y: screenHeight - NSEvent.mouseLocation.y + offset)

    private var initialized: Bool = false    
    
    private static let offset: CGFloat = 100
    private static let screenHeight = NSScreen.main?.frame.height ?? 800    
        
    init() {
        NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved],
            handler: { [weak self] event in
                guard let self else {
                    return
                }
                self.updateCursorPoint(event)
            }
        )

        // required for both global and local
        // if local one is not added, the window will not focus the cursor when the app is in focus.
        NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved],
            handler: { [weak self] event in
                guard let self else {
                    return event
                }
                self.updateCursorPoint(event)
                return event
            }
        )
    }
    
    private func updateCursorPoint(_ event: NSEvent) {
        self.cursorLocation = .init(x: event.locationInWindow.x + Self.offset, y: Self.screenHeight - event.locationInWindow.y + Self.offset)
    }
    
    func reOpenWindowIfNeeded(openWindow: OpenWindowAction, dismissWindow: DismissWindowAction, windowId: String) {
        print(#function)
        guard !self.initialized else {
            return
        }
        dismissWindow(id: windowId)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            openWindow(id: windowId)
            self.initialized = true
        }
    }
}

struct WindowFollowCursor: View {
    static let id = "WindowFollowCursor"
    
    @Environment(WindowFollowCursorManager.self) private var windowFollowCursorManager
    
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack {
            Image(systemName: "star.circle")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(width: 200)
                .position(x: windowFollowCursorManager.cursorLocation.x, y: windowFollowCursorManager.cursorLocation.y)
        }
        .frame(width: NSScreen.main?.frame.width, height: NSScreen.main?.frame.height)
        .onAppear {
            guard let window = NSApplication.shared.windows.first(where: {$0.identifier?.rawValue == Self.id}) else {
                return
            }
            
            window.setFrameOrigin(.zero)

            window.level = .screenSaver // popUpMenu will also work

            // remove title and buttons
            window.styleMask.remove(.titled)
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true

            // so that the window can follow the virtual desktop
            window.collectionBehavior.insert(.canJoinAllSpaces)

            // set it clear here so the configuration in UtilityWindowView will be reflected as it is
            window.backgroundColor = .clear
            
            window.isMovableByWindowBackground = false
            
            // required to apply frame changes
            self.windowFollowCursorManager.reOpenWindowIfNeeded(openWindow: self.openWindow, dismissWindow: self.dismissWindow, windowId: Self.id)

        }
    }
}

@main
struct MacOSDemo4App: App {
    private let windowFollowCursorManager = WindowFollowCursorManager()
    var body: some Scene {
        Window("", id: WindowFollowCursor.id) {
            WindowFollowCursor()
                .environment(windowFollowCursorManager)
        }
        
        // to prevent the app from quiting
        MenuBarExtra("I", content: {})
    }
}
