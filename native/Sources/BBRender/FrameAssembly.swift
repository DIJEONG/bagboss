import BBContent
import BBPresentation
import simd

// 연출 감독 출력(StageFrame) → 렌더러 입력(RenderFrame). 웹 render() 의 G-버퍼 그리기 순서:
//   배경 쿼드 → 그림자(DST_COLOR 곱하기 · G 채널만) → 인물 앞 2D(먼지) → 3D 인물(깊이 검사) → 앞 효과
// 광원: 장면 광원(+ 주인공 보조광) 뒤에 동적 광원을 붙여 8개까지 · 흔들림만큼 x 이동(웹 LP[i*4]+=SHK())
// 후처리 충격파 · 번짐(웹 GS.sw · GS.smear)은 HUD 상태에서 applyHUD 로 싣는다. HUD 그림은 OverlayRenderer(별도 패스).

extension RenderFrame {
    public init(stage f: StageFrame, atlas: [String: AtlasMeta.Sprite], width: Int = 480, height: Int = 270) {
        var comp = CompositeParams()
        comp.apply(f.scene.lighting, extraLights: f.extraLights, shake: f.shake)
        let post: PostParams? = f.post ? PostParams(scene: f.scene.post, impactInvert: false, shake: f.shake) : nil
        var blit = BlitParams(visibleWidth: Float(f.view.visibleWidth))
        blit.cameraX = Float(f.view.cameraX); blit.zoom = Float(f.view.zoom); blit.roll = Float(f.view.roll)
        blit.zoomCenter = SIMD2(Float(f.view.zoomCenter.x), Float(1 - f.view.zoomCenter.y))   // 블릿은 GL 방향(아래→위)
        self.init(width: width, height: height, time: Float(f.time), composite: comp, post: post, blit: blit)
        shake = SIMD2(Float(f.shake), 0)
        applyScene(f.scene)   // 창 불빛(uWin) 등 장면 값
        var b = SpriteBatch()
        b.append(f.scene.background, atlas: atlas); let n0 = b.vertexCount
        b.append(f.shadows, atlas: atlas); let n1 = b.vertexCount
        b.append(f.preMesh, atlas: atlas); let n2 = b.vertexCount
        b.append(f.front, atlas: atlas); let n3 = b.vertexCount
        spriteVertices = b.vertices
        meshVertices = f.backMesh.isEmpty ? f.mesh : f.backMesh + f.mesh
        let nb = f.backMesh.count / 10
        var g: [GBufferDraw] = [.sprite(first: 0, count: n0, shadow: false)]
        if nb > 0 { g.append(.mesh(first: 0, count: nb)) }   // 네이티브 무대 픽셀 배경(눈 승강장) — 그림자 · 먼지보다 먼저
        if n1 > n0 { g.append(.sprite(first: n0, count: n1 - n0, shadow: true)) }
        if n2 > n1 { g.append(.sprite(first: n1, count: n2 - n1, shadow: false)) }
        if !f.mesh.isEmpty { g.append(.mesh(first: nb, count: f.mesh.count / 10)) }
        if n3 > n2 { g.append(.sprite(first: n2, count: n3 - n2, shadow: false)) }
        gbuffer = g
        if let D = f.depth { applyDepth(D) }
        if f.readability > 0 { composite.outlineAdapt = SIMD4(Float(f.readability) * 0.8, 0.45, 0.2, 0) }   // 네이티브 인물 가독성(배경에 맞춘 바깥 테)
    }

    /// 네이티브 깊이 · 조명(무도장 — docs/10 §10): 합성 림 · 눈 바닥 · 원경 흐림 · 반사 · 전경 층 · 배경별 덧
    mutating func applyDepth(_ D: DepthFX) {
        composite.edgeRim = Float(D.rimEdge); composite.edgeSide = Float(D.rimSide); composite.floorStep = Float(D.floorStep)
        let t = D.rimTint.count == 6 ? D.rimTint.map(Float.init) : [1, 1, 1, 1, 1, 1]
        composite.rimTint = [SIMD4(t[0], t[1], t[2], Float(D.rimOpp)), SIMD4(t[3], t[4], t[5], D.rimTint.count == 6 ? 1 : 0)]
        guard post != nil else { return }
        post!.depthFar = SIMD4(Float(D.farMix), Float(D.farD0), Float(D.farD1), Float(D.haze))
        post!.depthHaze = SIMD4(Float(D.hazeC[0]), Float(D.hazeC[1]), Float(D.hazeC[2]), Float(D.value))
        post!.depthMisc = SIMD4(Float(D.desat), Float(D.streak), Float(D.streakY), Float(D.streakW))
        post!.farBlur = Float(D.farBlur); post!.farKey = D.farKey
        if D.wetSnow { post!.wetMaterials = [-1, Float(NativePalette.SNOWF), -1] }   // 젖은 바닥 반사 갈래를 눈 바닥에(0.16 — 웅덩이 SNOWW 는 하얗게 떠서 뺀다)
        if let w = D.wetMats, w.count == 2 { post!.wetMaterials = [Float(w[0]), Float(w[1]), -1] }   // 해변: 밀려온 물(강하게) · 젖은 모래(약하게)
        post!.depthKeep = SIMD4(Float(D.keep[0]), Float(D.keep[1]), Float(D.keep[2]), 0)
        let on = D.fg != nil && D.fgSize[0] > 0
        post!.foreground = [SIMD4(Float(D.fgAt[0]), Float(D.fgAt[1]), Float(D.fgSize[0]), Float(D.fgSize[1])),
                            SIMD4(Float(D.fgBlur), on ? 1 : 0, 0, Float(D.flakes)),
                            SIMD4(Float(D.flakeT), Float(D.camX), Float(D.viewW), 0)]
        if on, let px = D.fg { post!.passer = px; post!.passerSize = SIMD2(D.fgSize[0], D.fgSize[1]); post!.passerVersion = D.fgVersion }
        let e = D.ex.map(Float.init)
        post!.depthExtra = (0..<8).map { SIMD4(e[$0 * 4], e[$0 * 4 + 1], e[$0 * 4 + 2], e[$0 * 4 + 3]) }
    }
}

extension PostParams {
    /// 웹 runPost 의 투명 충격파 · 방향 번짐(GS.sw · GS.smear — 게임 시계 기준). now = GS.time, shake = SHK()
    public mutating func applyHUD(shockwaves sws: [Shockwave], smear M0: Smear?, now: Double, shake: Double) {
        var out: [(SIMD4<Float>, SIMD4<Float>)] = []
        for q in sws where now < q.t0 + q.life && now > q.t0 - 1 {
            let uu = (now - q.t0) / q.life
            if uu < 0 || out.count >= 4 { continue }
            let e = 1 - pow(1 - uu, 2.2), dk = pow(1 - uu, 1.4)
            out.append((SIMD4(Float(q.x + shake), Float(q.y), Float(q.r0 + (q.r1 - q.r0) * e), Float(q.amp * dk)),
                        SIMD4(Float(q.w * (0.7 + 0.3 * e)), Float(q.dark * (1 - uu)), 0, 0)))
        }
        shockwaves = out
        if let M0 {
            let mu = (now - M0.t0) / M0.life
            if mu >= 0 && mu < 1 { smear = SIMD4(Float(M0.x + shake), Float(M0.y), Float(M0.f * 2), Float(M0.R)); smearAmount = Float(0.8 * (1 - mu)); return }
        }
        smear = .zero; smearAmount = 0
    }
}

extension RenderFrame {
    /// HUD 의 충격파 · 번짐을 후처리에 싣는다(지하철 · 타워 — 후처리가 있을 때만)
    public mutating func applyHUD(_ hud: HUDState, now: Double) {
        guard post != nil else { return }
        post!.applyHUD(shockwaves: hud.shockwaves, smear: hud.smear, now: now, shake: Double(shake.x))
    }
}
