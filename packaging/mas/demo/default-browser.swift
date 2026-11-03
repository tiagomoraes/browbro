// Read or set the system default browser, for staging the App Review recording.
//
//   swift default-browser.swift get
//   swift default-browser.swift set /Applications/Google\ Chrome.app
//
// `LSSetDefaultHandlerForURLScheme` is a no-op on macOS 27; NSWorkspace is the only
// path left, and it always raises the system "Use … / Keep …" panel. `set` waits for
// that answer, then reports what the default actually is — a click on "Keep" is not
// an error from NSWorkspace's point of view.
import AppKit

let probe = URL(string: "https://example.com")!

func current() -> String {
    NSWorkspace.shared.urlForApplication(toOpen: probe)?.path ?? ""
}

let args = CommandLine.arguments.dropFirst()
switch (args.first, args.dropFirst().first) {
case ("get", nil):
    print(current())
case ("set", let path?):
    let app = URL(fileURLWithPath: path)
    Task {
        do {
            try await NSWorkspace.shared.setDefaultApplication(at: app, toOpenURLsWithScheme: "https")
            try await NSWorkspace.shared.setDefaultApplication(at: app, toOpenURLsWithScheme: "http")
        } catch {
            FileHandle.standardError.write("setDefaultApplication: \(error.localizedDescription)\n".data(using: .utf8)!)
        }
        print(current())
        exit(current() == app.path ? 0 : 1)
    }
    RunLoop.main.run()
default:
    FileHandle.standardError.write("usage: default-browser.swift get | set <path/to/App.app>\n".data(using: .utf8)!)
    exit(2)
}
