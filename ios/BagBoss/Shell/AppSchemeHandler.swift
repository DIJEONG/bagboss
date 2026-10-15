import Foundation
import WebKit

/// 번들 안 Web/ 폴더를 app://game/… 으로 서빙한다.
/// file:// 대신 사용자 스킴을 쓰는 이유: 오리진이 고정되어 localStorage가 안정적이고,
/// fetch · 글꼴 · 이미지가 같은 오리진 규칙으로 동작한다(file:// 은 오리진이 null).
final class AppSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "app"
    static let host = "game"
    static var startURL: URL { URL(string: "\(scheme)://\(host)/index.html")! }

    private let root: URL

    init(root: URL) {
        self.root = root.standardizedFileURL
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            respond(urlSchemeTask, url: AppSchemeHandler.startURL, status: 400, data: Data(), mime: "text/plain")
            return
        }
        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.html" }
        let file = root.appendingPathComponent(String(path.dropFirst())).standardizedFileURL
        // 번들 Web/ 밖으로 나가는 경로(../)는 막는다
        guard file.path.hasPrefix(root.path + "/"), let data = try? Data(contentsOf: file) else {
            respond(urlSchemeTask, url: url, status: 404, data: Data(), mime: "text/plain")
            return
        }
        respond(urlSchemeTask, url: url, status: 200, data: data, mime: Self.mime(for: file.pathExtension))
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // 모든 응답을 start 안에서 동기로 끝내므로 따로 취소할 작업이 없다.
    }

    private func respond(_ task: WKURLSchemeTask, url: URL, status: Int, data: Data, mime: String) {
        let headers = [
            "Content-Type": mime,
            "Content-Length": String(data.count),
            "Cache-Control": "no-cache",
        ]
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else { return }
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    static func mime(for ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js", "mjs": return "text/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "json": return "application/json"
        case "woff2": return "font/woff2"
        case "woff": return "font/woff"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "webp": return "image/webp"
        case "svg": return "image/svg+xml"
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "wav": return "audio/wav"
        case "txt": return "text/plain; charset=utf-8"
        default: return "application/octet-stream"
        }
    }
}
