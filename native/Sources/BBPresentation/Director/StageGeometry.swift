import Foundation

// 무대 좌표(장면 픽셀 480×270, 위→아래) ↔ 화면 좌표(보이는 무대 뷰 안 0..1, 위→아래).
// 화면 출력(BBRender blitFS · 웹 FS_BLIT)과 같은 식: 세로 크롭(cameraX · visibleWidth) 다음 줌 펀치(zoom · zoomCenter).
//   blit: uv.x = (camX + vx·VW)/W → 장면 u = (uv − zc)/zoom + zc
// HUD(피해 숫자 · 말풍선 · 만화 글자)를 무대 위 제자리에 올릴 때와 터치를 무대 좌표로 바꿀 때 쓴다.

public struct StageView: Sendable, Equatable {
    /// 장면 내부 해상도
    public var sceneWidth: Double = 480, sceneHeight: Double = 270
    /// 세로 화면에서 보이는 폭(웹 VW = H·4/3 = 360)과 그 왼쪽 끝(웹 CAMX)
    public var visibleWidth: Double = 360, cameraX: Double = 0
    /// 줌 펀치 배율(1 = 없음) · 중심(장면 비율, 위→아래)
    public var zoom: Double = 1
    public var zoomCenter: SIMD2<Double> = [0.5, 0.5]
    /// 화면 기울기(라디안 · 네이티브 받아치기 · 치명 펀치인의 더치 틸트 — 0 = 웹 그대로). 뷰 가운데를 축으로 무대 그림만 돈다(HUD 패스는 안 돈다)
    public var roll: Double = 0
    public init() {}
    public init(sceneWidth: Double = 480, sceneHeight: Double = 270, visibleWidth: Double, cameraX: Double, zoom: Double = 1, zoomCenter: SIMD2<Double> = [0.5, 0.5]) {
        self.sceneWidth = sceneWidth; self.sceneHeight = sceneHeight; self.visibleWidth = visibleWidth; self.cameraX = cameraX
        self.zoom = zoom; self.zoomCenter = zoomCenter
    }

    /// 화면이 보여 줘야 하는 가로세로 비(4:3)
    public var aspect: Double { visibleWidth / sceneHeight }

    /// 장면 픽셀 → 뷰 안 비율(0..1, 위→아래). 화면 밖이면 0..1 을 벗어난다
    public func toView(_ p: SIMD2<Double>) -> SIMD2<Double> {
        let z = max(zoom, 1)
        let ux = (p.x / sceneWidth - zoomCenter.x) * z + zoomCenter.x
        let uy = (p.y / sceneHeight - zoomCenter.y) * z + zoomCenter.y
        let v: SIMD2<Double> = [(ux * sceneWidth - cameraX) / visibleWidth, uy]
        return roll == 0 ? v : rotate(v, -roll)
    }
    /// 뷰 가운데를 축으로 돌리기(뷰 비율 좌표 — 가로세로 비를 맞춰 돈다). 화면 출력(blitFS)은 뷰 점 p 에 rotate(p, roll) 자리 그림을 놓는다
    func rotate(_ v: SIMD2<Double>, _ a: Double) -> SIMD2<Double> {
        let dx = (v.x - 0.5) * visibleWidth, dy = (v.y - 0.5) * sceneHeight, c = cos(a), s = sin(a)
        return [0.5 + (c * dx - s * dy) / visibleWidth, 0.5 + (s * dx + c * dy) / sceneHeight]
    }
    /// 뷰 안 비율 → 장면 픽셀
    public func toScene(_ v: SIMD2<Double>) -> SIMD2<Double> {
        let z = max(zoom, 1)
        let v = roll == 0 ? v : rotate(v, roll)
        let uvx = (cameraX + v.x * visibleWidth) / sceneWidth
        return [((uvx - zoomCenter.x) / z + zoomCenter.x) * sceneWidth, ((v.y - zoomCenter.y) / z + zoomCenter.y) * sceneHeight]
    }
    /// 장면 픽셀 → 뷰 점(포인트). size = 무대 뷰 크기
    public func toView(_ p: SIMD2<Double>, size: SIMD2<Double>) -> SIMD2<Double> { toView(p) * size }
    /// 장면 1픽셀이 뷰에서 몇 포인트인가(가로)
    public func pointsPerPixel(viewWidth: Double) -> Double { viewWidth / visibleWidth * max(zoom, 1) }
}
