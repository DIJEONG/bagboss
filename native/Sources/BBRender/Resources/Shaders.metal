// BAG BOSS 렌더러 셰이더 — 웹 원본(web/src/12-webgl.js · 19-lab-nodes.js 프리셋 6)을 1:1로 옮긴 것.
//
// 좌표 규칙(가장 중요):
//   웹 셰이더 수식은 GL 창 좌표(원점 왼쪽 아래, y 위로)로 쓰여 있다. 디더(베이어) 위상 · 해시 · 반사 축 같은 픽셀 단위 수식을
//   그대로 지키기 위해, 여기서도 수식은 GL 좌표 `PX` 로 계산하고 **렌더 타깃을 읽고 쓸 때만** 위아래를 뒤집는다.
//   - 렌더 타깃(G-버퍼 · 합성 · 블룸 · 후처리): Metal 은 행 0 이 위 → GL 행 = H-1-Metal 행. rtRead / rtSample 이 뒤집는다.
//   - CPU 에서 올린 텍스처(아틀라스 · 팔레트): 웹도 데이터 행 0 을 texel y=0 으로 읽는다 → 뒤집지 않는다.
// GLSL 과 다른 점: mod(음수에서 다름) → glslMod · 3D 깊이(GL NDC z -1..1 → Metal 0..1) · 빠른 수학 끔(호스트에서 설정)
//   · flat 값: GL ES 는 삼각형의 '마지막' 정점, Metal 은 '첫' 정점에서 가져온다 → flat 값은 정점 셰이더가 직접 마지막 정점에서 읽는다.
#include <metal_stdlib>
using namespace metal;

constant int NMAT = 80;

inline float glslMod(float x, float y) { return x - y * floor(x / y); }
inline float2 glslMod(float2 x, float y) { return x - y * floor(x / y); }

// GL 좌표 → 렌더 타깃 읽기
inline float4 rtRead(texture2d<float> t, int2 q, int H) { return t.read(uint2(uint(q.x), uint(H - 1 - q.y))); }
inline float4 rtSample(texture2d<float> t, sampler s, float2 uvGL) { return t.sample(s, float2(uvGL.x, 1.0 - uvGL.y)); }
// Metal 프래그먼트 위치 → GL 창 좌표(정수 픽셀)
inline int2 glPX(float4 pos, int H) { return int2(int(pos.x), H - 1 - int(pos.y)); }

// ============================================================ 1. G-버퍼: 스프라이트
struct SpriteU {
    float4 resShake;   // uRes.xy · uShake.xy
    float4 misc;       // uTime · uFix · uShadow · uWin
};
struct SpriteV {
    float4 pos [[position]];
    float2 uv;
    float2 f [[flat]];     // aF: (좌우 반전, 번쩍임)
    float d [[flat]];      // 깊이(0 가까움 ~ 1 하늘)
    float r [[flat]];      // 팔레트 스왑 세트
    float p [[flat]];      // 파츠 번호(캐릭터 선)
};
struct GOut { float4 o0 [[color(0)]]; float4 o1 [[color(1)]]; };

// 정점 9개 float: aPos.xy · aUV.xy · aF.xy · aD · aR · aP (웹 quad() 와 같은 배치)
vertex SpriteV spriteVS(uint vid [[vertex_id]], const device float* v [[buffer(0)]], constant SpriteU& U [[buffer(1)]]) {
    const device float* a = v + vid * 9;
    const device float* z = v + ((vid / 3) * 3 + 2) * 9;   // flat 값은 삼각형 마지막 정점(GL 규칙)
    float2 p = float2(a[0], a[1]) + U.resShake.zw;
    SpriteV o;
    o.pos = float4(p.x / U.resShake.x * 2.0 - 1.0, 1.0 - p.y / U.resShake.y * 2.0, 0.0, 1.0);
    o.uv = float2(a[2], a[3]); o.f = float2(z[4], z[5]); o.d = z[6]; o.r = z[7]; o.p = z[8];
    return o;
}

inline float2 h22(float2 p) { p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3))); return fract(sin(p) * 43758.5453); }
inline float cellEdge(float2 q, float time) {
    float2 i = floor(q), f = fract(q); float d1 = 9.0, d2 = 9.0;
    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
        float2 g = float2(float(x), float(y)); float2 o = h22(i + g);
        o = 0.5 + 0.42 * sin(time * 0.7 + 6.2831 * o); float2 r = g + o - f; float d = dot(r, r);
        if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
    }
    return sqrt(d2) - sqrt(d1);
}

fragment GOut spriteFS(SpriteV in [[stage_in]], constant SpriteU& U [[buffer(0)]], constant float* remap [[buffer(1)]],
                       texture2d<float> atlasA [[texture(0)]], texture2d<float> atlasN [[texture(1)]]) {
    int2 t = int2(floor(in.uv));
    float4 a = atlasA.read(uint2(t));
    if (a.a < 0.5) discard_fragment();
    GOut o;
    if (U.misc.z > 0.5) { o.o0 = float4(1.0, 0.55, 1.0, 1.0); o.o1 = float4(1.0); return o; }   // 그림자: 톤에 곱하기(블렌드)
    float4 n = atlasN.read(uint2(t));
    float2 nn = n.rg * 2.0 - 1.0;
    if (in.f.x > 0.5 && U.misc.y > 0.5) nn.x = -nn.x;
    float mat = floor(a.r * 255.0 + 0.5); float tone = a.g; float emit = a.b; float mask = n.b;
    if (in.r > 0.5) { int k = (int(in.r + 0.5) - 1) * 6; float m0 = mat;
        for (int j = 0; j < 3; j++) { if (remap[k + j * 2] > 0.5 && abs(m0 - remap[k + j * 2]) < 0.5) { mat = remap[k + j * 2 + 1]; break; } } }
    if (abs(mat - 14.0) < 0.5) {   // 물
        float2 wp = float2(floor(in.pos.x), floor(in.pos.y)) - U.resShake.zw;   // = (floor(fc.x), floor(uRes.y - fc.y)) - uShake
        float phase = wp.y * 0.6 + U.misc.x * 2.2;
        float2 q = float2(wp.x + 1.5 * sin(phase), wp.y);
        float e = cellEdge(q / float2(12.0, 5.0), U.misc.x);
        bool dotOn = glslMod(wp.x + wp.y, 2.0) < 0.5;
        if (e < 0.075 && dotOn) { tone = 0.9; emit = 0.22; nn = float2(0.0, 0.6); }
        else { tone = 0.38 + 0.04 * step(0.5, fract(wp.y * 0.5)); }
    }
    if (abs(mat - 31.0) < 0.5) { if (U.misc.w > 0.001 && emit < U.misc.w) { emit = 0.85; } else { mat = 19.0; emit = 0.0; } }
    if (in.f.y > 0.5) { mat = 13.0; tone = 1.0; emit = 1.0; }
    if (in.p > 0.5 && mask > 0.75) mask = 0.78 + in.p / 64.0;
    o.o0 = float4(mat / 255.0, tone, emit, mask);
    o.o1 = float4(nn * 0.5 + 0.5, in.d, n.a);
    return o;
}

// ============================================================ 1-b. G-버퍼: 3D 리그
struct MeshV {
    float4 pos [[position]];
    float2 n [[flat]]; float t [[flat]]; float m [[flat]]; float k [[flat]]; float d [[flat]]; float e [[flat]];
};
// 정점 10개 float: aP.xyz · aN.xy · aT · aM · aK · aD · aE
vertex MeshV meshVS(uint vid [[vertex_id]], const device float* v [[buffer(0)]], constant SpriteU& U [[buffer(1)]]) {
    const device float* a = v + vid * 10;
    const device float* z = v + ((vid / 3) * 3 + 2) * 10;  // flat 값은 삼각형 마지막 정점(GL 규칙)
    float2 p = float2(a[0], a[1]) + U.resShake.zw;
    MeshV o;
    o.pos = float4(p.x / U.resShake.x * 2.0 - 1.0, 1.0 - p.y / U.resShake.y * 2.0, (a[2] + 1.0) * 0.5, 1.0);   // GL 깊이 범위 맞춤
    o.n = float2(z[3], z[4]); o.t = z[5]; o.m = z[6]; o.k = z[7]; o.d = z[8]; o.e = z[9];
    return o;
}
fragment GOut meshFS(MeshV in [[stage_in]]) {
    GOut o;
    // 네이티브 무대 픽셀(부위 번호 음수 — 지붕 구멍 등 NativeRiseArt): 배경 스프라이트와 같은 G-버퍼 값(마스크 0.5 · 층 깊이는 b). 웹 정점엔 없는 갈래
    if (in.k < -0.5) { o.o0 = float4(in.m / 255.0, in.t, in.e, 0.5); o.o1 = float4(in.n * 0.5 + 0.5, in.d, 0.0); return o; }
    o.o0 = float4(in.m / 255.0, in.t, in.e, 0.78 + in.k / 64.0);
    o.o1 = float4(in.n * 0.5 + 0.5, 0.0, in.d);
    return o;
}

// ============================================================ 전체 화면 삼각형
struct FullV { float4 pos [[position]]; };
vertex FullV fullVS(uint vid [[vertex_id]]) {
    float2 p = float2(float((vid << 1) & 2), float(vid & 2));
    FullV o; o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0); return o;
}

// ============================================================ 2. 합성(조명 · 팔레트) — PRELUDE + 프리셋 6 "느와르 · 부드러운 빛"
struct CompU {
    float4 resTimeLN;   // uRes.xy · uTime · uLN
    float4 ambEmit;     // uAmb · uEmitK · uSun.xy
    float4 LP[8];       // 광원 위치 x · y · z · 반경
    float4 LC[8];       // 색 rgb · 세기
    float4 LD[8];       // 스폿 방향 xy · 원뿔(cos) 또는 층 깊이 · 종류(0 점 · 1 스폿 · 2 방향)
    float4 p2;          // u2_amb · u2_gain · u3_str · -
    float4 p7;          // u7_pal · u7_tintAmt · u7_dith · -
    float4 p9;          // u9_pal · u9_outer · u9_inner · u9_sel
    float4 tint;        // u9_tint.rgb · (네이티브) 눈 바닥 램프 내림
    float4 RX[2];       // 네이티브 림 2색: (광원 쪽 색 곱 rgb · 반대쪽 세기) · (반대쪽 색 곱 rgb · 색 켬)
    float4 OL;          // 네이티브 인물 가독성: 세기 · 어두운 배경 문턱(밝기) · 밝힘 · - (0 = 웹 그대로)
};

struct Comp {
    texture2d<float> info, norm, pal;
    constant CompU& U;
    int2 PX; int W, H;

    float4 gInfo(int2 o) const { int2 q = clamp(PX + o, int2(0), int2(W, H) - 1); return rtRead(info, q, H); }
    float4 normAt(int2 q) const { return rtRead(norm, q, H); }
    float3 gNormal() const { float2 e = normAt(PX).rg * 2.0 - 1.0; return float3(e, sqrt(max(0.0, 1.0 - dot(e, e)))); }
    float gDepth() const { return normAt(PX).b; }
    float3 palC(float p, float m, float s) const { return pal.read(uint2(uint(int(s)), uint(int(p) * NMAT + int(m)))).rgb; }
    static float luma(float3 c) { return dot(c, float3(0.299, 0.587, 0.114)); }
    float2 pxPos() const { return float2(float(PX.x) + 0.5, float(H) - (float(PX.y) + 0.5)); }

    float3 lightSum(float3 n) const {
        float2 p = pxPos(); float3 acc = float3(0.0); int LN = int(U.resTimeLN.w);
        for (int i = 0; i < 8; i++) {
            if (i >= LN) break;
            float4 lp = U.LP[i], lc = U.LC[i], ld = U.LD[i];
            float3 L = float3(lp.x - p.x, -(lp.y - p.y), lp.z);
            float att; float nd;
            if (ld.w > 1.5) { acc += lc.rgb * lc.a * max(dot(n, normalize(ld.xyz)), 0.0); continue; }
            if (ld.w > 0.5) {
                float2 v = normalize(p - lp.xy + 1e-4);
                float dd = clamp(length(p - lp.xy) / lp.w, 0.0, 1.0);
                att = smoothstep(ld.z, ld.z + (1.0 - ld.z) * 0.55, dot(v, ld.xy)) * (1.0 - dd) * (1.0 - dd * 0.5);
                nd = max(dot(n, normalize(float3(0.0, 0.45, 1.0))), 0.0);
            } else {
                att = clamp(1.0 - length(L) / lp.w, 0.0, 1.0); att *= att;
                att *= exp(-max(0.0, gDepth() - ld.z - 0.02) * 18.0);
                nd = max(dot(n, normalize(L)), 0.0);
            }
            acc += lc.rgb * lc.a * att * nd;
        }
        return acc;
    }
    float rimSum(float3 n) const {
        float t = length(n.xy); if (t < 0.3) return 0.0;
        float2 nd = n.xy / t; float2 p = pxPos(); float r = 0.0; int LN = int(U.resTimeLN.w);
        for (int i = 0; i < 8; i++) {
            if (i >= LN) break;
            if (U.LD[i].w > 0.5) continue;
            float4 lp = U.LP[i], lc = U.LC[i];
            float3 L = float3(lp.x - p.x, -(lp.y - p.y), lp.z);
            float att = clamp(1.0 - length(L) / lp.w, 0.0, 1.0); att *= att;
            r += smoothstep(0.3, 0.9, t) * max(dot(nd, normalize(L.xy + 1e-4)), 0.0) * att * lc.a * luma(lc.rgb);
        }
        return r;
    }
    float thr0() const {   // thr(0.0): 베이어 4×4
        constexpr float B4[16] = {0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.};
        int2 r = PX & 3; return (B4[r.y * 4 + r.x] + 0.5) / 16.0;
    }
    static float partOf(float4 i) { return (i.a > 0.77 && i.a < 0.985) ? floor((i.a - 0.78) * 64.0 + 0.5) : -1.0; }
    float4 selOut(float s) const {
        if (gInfo(int2(0)).a > 0.75) return float4(0.0);
        const int2 O[4] = {int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1)};
        for (int k = 0; k < 4; k++) { float4 q = gInfo(O[k]); if (partOf(q) >= 0.0) return float4(palC(0.0, floor(q.r * 255.0 + 0.5), s) * 0.85, 1.0); }
        return float4(0.0);
    }
    // 네이티브 깊이 · 조명(무도장 — docs/10 §10): 인물 픽셀의 광원 쪽 바깥 이웃이 비었으면 램프를 한 단(1/6) 올린다 · 반대쪽 반 단 · 위쪽 1/3 단
    bool isOut(int2 o) const { float4 q = gInfo(o); return partOf(q) < 0.0 && q.a < 0.75; }
    float edgeLift(float k, float side, float opp, thread float& code) const {
        code = 0.0;
        if (partOf(gInfo(int2(0))) < 0.0) return 0.0;
        int s = side < 0.0 ? -1 : 1;
        if (isOut(int2(s, 0))) { code = 1.0; return k / 6.0; }
        if (opp > 0.0 && isOut(int2(-s, 0))) { code = -1.0; return k * opp / 6.0; }
        if (isOut(int2(0, 1))) { code = 0.5; return k * 0.35 / 6.0; }
        return 0.0;
    }
    float innerLine() const {
        float p = partOf(gInfo(int2(0))); if (p < 0.0) return 0.0; float dm = normAt(PX).a;
        const int2 O[4] = {int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1)};
        for (int k = 0; k < 4; k++) {
            float q = partOf(gInfo(O[k])); if (q < 0.0 || abs(q - p) < 0.5) continue;
            float dq = normAt(clamp(PX + O[k], int2(0), int2(W, H) - 1)).a;
            if (dm > 0.01 || dq > 0.01) { if (dq > dm + 0.012) return 1.0; }
            else if (q > p + 0.5) return 1.0;
        }
        return 0.0;
    }
};

fragment float4 compositeNoirFS(FullV in [[stage_in]], constant CompU& U [[buffer(0)]],
                                texture2d<float> info [[texture(0)]], texture2d<float> norm [[texture(1)]], texture2d<float> pal [[texture(2)]]) {
    int W = int(U.resTimeLN.x), H = int(U.resTimeLN.y);
    Comp C{info, norm, pal, U, glPX(in.pos, H), W, H};
    // n1 gbuf
    float4 raw = C.gInfo(int2(0));
    float mat = floor(raw.r * 255.0 + 0.5);
    float tone = raw.g * 2.0;
    float emitV = raw.b * U.ambEmit.y;
    float3 normal = C.gNormal();
    // n2 lights · n3 rim
    float3 light = C.lightSum(normal) * U.p2.y + float3(U.p2.x) * U.ambEmit.x;
    float lum2 = dot(light, float3(0.3333));
    float3 tintL = light / max(max(light.r, max(light.g, light.b)), 1e-3);
    float rim = C.rimSum(normal) * U.p2.z;
    // n4~n6: (밝기 + 림) × 톤 + 발광
    float v = (lum2 + rim) * tone + emitV;
    // 네이티브 깊이 · 조명(무도장만 — 값 0 = 웹 그대로): 인물 1px 림 · 눈 바닥 한 단 내림
    float rimCode = 0.0;
    if (U.p2.w > 0.0) v += C.edgeLift(U.p2.w, U.p7.w, U.RX[0].w, rimCode);
    if (U.tint.w != 0.0 && mat > 63.5 && mat < 65.5) v -= U.tint.w;
    // n7 ramp: 6단 + 디더
    // 네이티브 눈 바닥(재질 64 · 65)· 해변 모래(67 · 68 — docs/12) — 웹 팔레트 빈 줄: 순한 디더 — 단 경계 둘레에서만 좁게 섞는다(docs/10)
    float dk = ((mat > 63.5 && mat < 65.5) || (mat > 66.5 && mat < 68.5)) ? 0.3 : 1.0;
    float lv = clamp(v, 0.0, 1.0) * 6.0 + (C.thr0() - 0.5) * U.p7.z * dk;
    float3 color = C.palC(U.p7.x, mat, clamp(floor(lv), 0.0, 5.0)) * mix(float3(1.0), tintL, U.p7.y);
    if (U.RX[1].w > 0.5 && rimCode != 0.0) color *= rimCode > 0.75 ? U.RX[0].rgb : rimCode < 0.0 ? U.RX[1].rgb : mix(float3(1.0), U.RX[1].rgb, 0.5);   // 2색 림(광원 쪽 · 반대쪽 · 위)
    // n9 charline
    float3 o = color;
    {
        float4 so = C.selOut(U.p9.x); float4 me = C.gInfo(int2(0)); bool sel = U.p9.w > 0.5;
        if (U.p9.y > 0.5 && so.a > 0.5) {
            o = sel ? mix(so.rgb, U.tint.rgb, 0.45) : so.rgb;
            // 네이티브 인물 가독성: 이 테 픽셀 자리의 배경이 어두우면 잉크 테 대신 배경을 밝힌 차가운 선(역광 분리선) — 밝은 배경은 잉크 그대로
            if (U.OL.x > 0.0) {
                float lb = Comp::luma(color), dk = 1.0 - smoothstep(U.OL.y * 0.45, U.OL.y, lb);
                o = mix(o, color * 1.3 + U.OL.z * float3(0.62, 0.7, 0.86), dk * U.OL.x);
            }
        }
        else if (U.p9.z > 0.5 && C.innerLine() > 0.5) {
            float3 d0 = C.palC(0.0, floor(me.r * 255.0 + 0.5), U.p9.x) * 0.9;
            o = sel ? mix(color * 0.5 + U.tint.rgb * 0.3, d0, 0.35) : d0;
        }
    }
    return float4(clamp(o, 0.0, 1.0), 1.0);
}

// ============================================================ 3. 후처리: 밝은 부분 → 블러 → 합치기
struct BrightU { float4 src; };   // uSrc.xy
fragment float4 brightFS(FullV in [[stage_in]], constant BrightU& U [[buffer(0)]],
                         texture2d<float> comp [[texture(0)]], texture2d<float> info [[texture(1)]]) {
    int SW = int(U.src.x), SH = int(U.src.y);
    int2 p = glPX(in.pos, SH >> 1) * 2; float3 c = float3(0.0);
    for (int y = 0; y < 2; y++) for (int x = 0; x < 2; x++) {
        int2 q = min(p + int2(x, y), int2(SW, SH) - 1);
        float3 s = rtRead(comp, q, SH).rgb; float em = rtRead(info, q, SH).b;
        float l = dot(s, float3(0.3, 0.59, 0.11)); c += s * (smoothstep(0.55, 1.0, l) * 0.7 + em * 1.4);
    }
    return float4(c * 0.25, 1.0);
}

struct BlurU { float4 dirSz; };   // uDir.xy · uSz.xy
fragment float4 blurFS(FullV in [[stage_in]], constant BlurU& U [[buffer(0)]], texture2d<float> t [[texture(0)]]) {
    constexpr sampler lin(filter::linear, address::clamp_to_edge);
    float2 sz = U.dirSz.zw, dir = U.dirSz.xy;
    float2 uv = float2(in.pos.x, sz.y - in.pos.y) / sz;   // gl_FragCoord.xy / uSz
    float3 c = rtSample(t, lin, uv).rgb * 0.227;
    c += (rtSample(t, lin, uv + dir * 1.385 / sz).rgb + rtSample(t, lin, uv - dir * 1.385 / sz).rgb) * 0.316;
    c += (rtSample(t, lin, uv + dir * 3.231 / sz).rgb + rtSample(t, lin, uv - dir * 3.231 / sz).rgb) * 0.07;
    return float4(c, 1.0);
}

// 네이티브 원경 흐림(무도장 — docs/10 §10): 반 해상도로 먼 층만 뽑기(rgb×w, w) → rgba 블러 2번 → postFS 가 깊이로 섞는다(24단 양자화 앞 = 픽셀 DOF)
struct FarU { float4 src; };   // 원본 W · H · 시작 깊이 d0 · -
fragment float4 farFS(FullV in [[stage_in]], constant FarU& U [[buffer(0)]],
                      texture2d<float> comp [[texture(0)]], texture2d<float> info [[texture(1)]], texture2d<float> norm [[texture(2)]]) {
    int SW = int(U.src.x), SH = int(U.src.y);
    int2 p = glPX(in.pos, SH >> 1) * 2; float4 acc = float4(0.0);
    for (int y = 0; y < 2; y++) for (int x = 0; x < 2; x++) {
        int2 q = min(p + int2(x, y), int2(SW, SH) - 1);
        float a = rtRead(info, q, SH).a, d = rtRead(norm, q, SH).b;
        if (a < 0.75 && d >= U.src.z) acc += float4(rtRead(comp, q, SH).rgb, 1.0);
    }
    return acc * 0.25;
}
fragment float4 blur4FS(FullV in [[stage_in]], constant BlurU& U [[buffer(0)]], texture2d<float> t [[texture(0)]]) {
    constexpr sampler lin(filter::linear, address::clamp_to_edge);
    float2 sz = U.dirSz.zw, dir = U.dirSz.xy;
    float2 uv = float2(in.pos.x, sz.y - in.pos.y) / sz;
    float4 c = rtSample(t, lin, uv) * 0.227;
    c += (rtSample(t, lin, uv + dir * 1.385 / sz) + rtSample(t, lin, uv - dir * 1.385 / sz)) * 0.316;
    c += (rtSample(t, lin, uv + dir * 3.231 / sz) + rtSample(t, lin, uv - dir * 3.231 / sz)) * 0.07;
    return c;
}

struct PostU {
    float4 grade;      // uGrade.rgb · uSat
    float4 expoWin;    // uExpo · uWinR · uWinY.xy
    float4 pressTime;  // uPress · uTime · uBloomK · uReflY
    float4 rainVig;    // uRain · uVig · uFog · uInv
    float4 fogC;       // uFogC.rgb
    float4 resN;       // uRes.xy · uVN · uSWN
    float4 wet;        // uWetA · uWetB · uWetC
    float4 VP[6]; float4 VC[6]; float4 VD[6];
    float4 SW[4]; float4 SWb[4];
    float4 SM;         // 방향 번짐 x · y · 방향×간격 · 반경
    float4 SMk;        // 세기
    // 네이티브 깊이 · 조명(무도장 — 전부 0 = 웹 그대로)
    float4 DF[4];      // (원경 섞기 · 시작 깊이 · 끝 깊이 · 안개) · (안개 rgb · 명도 낮춤) · (채도 낮춤 · 반사 줄기 · 줄기 윗선 y · 줄기 폭) · (흐림에서 뺄 원 x · y · 반지름 · -)
    float4 FG[3];      // 전경 층 자리 (왼쪽 x · 위 y · 폭 · 높이) · (흐림 반경 · 알파 · - · 큰 눈송이 알파) · (시간 · 카메라 x · 보이는 폭 · -)
    // 배경별 덧(무도장 — 0 = 끔): [0] 긴 그림자(땅 y · 높이→길이 · 기울기 · 세기) [1] (해 x · y · 렌즈 반짝 · 역광 먼지) [2] (화면 가운데 x · y · 땅 반짝 · -)
    //   [3] 건널목 경보등 붉은빛(x · y · 세기 · 반경) [4] 달빛 창살(바닥 세기 · 먼지 · 바닥 y · 창살 칸) [5] 반사 줄기 깊이 띠(켬 · d0 · d1 · -) [6] 창 x 범위 둘 [7] (창 y0 · y1 · 빛 방향 xy)
    float4 EX[8];
};
inline float hash21(float2 v) { return fract(sin(dot(v, float2(12.9898, 78.233))) * 43758.5453); }
inline float bayer4(int2 p) { constexpr int m[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5}; return float(m[(p.y & 3) * 4 + (p.x & 3)]) / 16.0; }

fragment float4 postFS(FullV in [[stage_in]], constant PostU& U [[buffer(0)]],
                       texture2d<float> uC [[texture(0)]], texture2d<float> uBloom [[texture(1)]],
                       texture2d<float> uInfo [[texture(2)]], texture2d<float> uNorm [[texture(3)]], texture2d<float> uFar [[texture(4)]],
                       texture2d<float> uPass [[texture(5)]]) {
    constexpr sampler lin(filter::linear, address::clamp_to_edge);
    float2 uRes = U.resN.xy; int W = int(uRes.x), H = int(uRes.y);
    float uTime = U.pressTime.y;
    int2 px = glPX(in.pos, H); float2 uv = (float2(px) + 0.5) / uRes;
    // 투명 충격파
    float2 p0 = float2(float(px.x) + 0.5, uRes.y - float(px.y) - 0.5), swOff = float2(0.0); float swDk = 0.0;
    int SWN = int(U.resN.w);
    for (int i = 0; i < 4; i++) { if (i >= SWN) break; float2 v = p0 - U.SW[i].xy; float d = length(v), r = U.SW[i].z, x = (d - r) / U.SWb[i].x;
        if (abs(x) < 1.0) { float pr = 1.0 - x * x; swOff += (v / max(d, 0.001)) * U.SW[i].w * pr; swDk += U.SWb[i].y * (x > 0.0 ? 1.1 : 0.6) * pr; }
        if (d < r) swDk += U.SWb[i].y * (0.35 + 0.65 * d / max(r, 1.0)); }
    int2 ro = int2(floor(swOff + 0.5)), sp = clamp(px + int2(-ro.x, ro.y), int2(0), int2(W, H) - 1);
    float3 c = rtRead(uC, sp, H).rgb;
    if (U.SMk.x > 0.0) { float dm = length(p0 - U.SM.xy); if (dm < U.SM.w) { float3 acc = c;
        for (int j = 1; j < 4; j++) acc += rtRead(uC, clamp(sp + int2(int(U.SM.z) * j, 0), int2(0), int2(W, H) - 1), H).rgb;
        c = mix(c, acc * 0.25, U.SMk.x * (1.0 - dm / U.SM.w)); } }
    c *= 1.0 - min(swDk, 0.35);
    // 차창 반사
    float uWinR = U.expoWin.y; float2 uWinY = U.expoWin.zw;
    if (uWinR > 0.0) { float ysw = uRes.y - float(px.y) - 0.5; float dep = rtRead(uNorm, px, H).b;
        if (dep > 0.7 && ysw >= uWinY.x && ysw < uWinY.y && px.x > 8 && px.x < W - 8) {
            float outL = dot(c, float3(.3, .59, .11)), dark = 1.0 - smoothstep(0.12, 0.45, outL);
            float3 seat = rtRead(uC, int2(px.x + 2, int(uRes.y - (2.0 * uWinY.y - ysw))), H).rgb;
            float3 lamp = rtRead(uC, int2(px.x, int(uRes.y - (2.0 * uWinY.x - ysw))), H).rgb;
            float tw = 1.0 - smoothstep(uWinY.x, uWinY.x + 7.0, ysw);
            c += (seat * 0.55 + lamp * 0.8 * tw) * uWinR * dark; } }
    float4 info = rtRead(uInfo, px, H); float mat = floor(info.r * 255.0 + 0.5);
    float ys = uRes.y - float(px.y) - 0.5; float2 p = float2(float(px.x) + 0.5, ys);
    // 네이티브 원경 흐림 + 대기 안개 · 명도 · 채도(먼 층 깊이만 — 인물 · 승강장 · 소품은 또렷)
    if (U.DF[0].x > 0.0 && info.a < 0.75) { float d = rtRead(uNorm, sp, H).b;
        bool inKeep = U.DF[3].z > 0.0 && length(float2(float(sp.x) + 0.5, uRes.y - float(sp.y) - 0.5) - U.DF[3].xy) < U.DF[3].z;   // 해 원판 · 디더 고리는 또렷하게
        if (d >= U.DF[0].y && !inKeep) { float a = clamp((d - U.DF[0].y) / max(U.DF[0].z - U.DF[0].y, 1e-3), 0.0, 1.0);
            float4 fb = rtSample(uFar, lin, (float2(sp) + 0.5) / uRes);
            if (fb.a > 0.01) c = mix(c, fb.rgb / fb.a, a * U.DF[0].x);
            float keep = 1.0 - 0.55 * smoothstep(0.45, 0.8, dot(c, float3(.299, .587, .114)));   // 불 켜진 창 · 해는 덜 덮는다
            float hz = a * U.DF[0].w * keep * (d > 0.975 ? 0.55 : 1.0);
            c = mix(c, U.DF[1].rgb, hz); c *= 1.0 - U.DF[1].w * a;
            float g = dot(c, float3(.299, .587, .114)); c = mix(float3(g), c, 1.0 - U.DF[2].x * hz); } }
    // 젖은 바닥 반사
    float uReflY = U.pressTime.w;
    float refl = abs(mat - U.wet.x) < 0.5 ? (info.g > 0.7 ? 0.95 : 0.42) : abs(mat - U.wet.y) < 0.5 ? 0.16 : 0.0;
    if (refl > 0.0 && info.a < 0.75) { float yr = 2.0 * uReflY - ys;
        if (yr > 1.0) { float wob = sin(ys * 0.9 + uTime * 2.3) * (info.g > 0.7 ? 0.6 : 1.4);
            float3 r = rtSample(uC, lin, float2(p.x + wob, uRes.y - yr) / uRes).rgb;
            float fade = exp(-(ys - uReflY) / 70.0); c += r * refl * fade; } }
    int VN = int(U.resN.z);
    // 네이티브 눈 바닥 반사 줄기(가로등 · 가판대 빛이 다져진 눈에 세로로 번진다)
    float dHere = rtRead(uNorm, px, H).b;
    bool streakOn = U.EX[5].x > 0.5 ? (dHere > U.EX[5].y && dHere < U.EX[5].z) : (abs(mat - 64.0) < 0.5 || abs(mat - 65.0) < 0.5);
    if (U.DF[2].y > 0.0 && info.a < 0.75 && streakOn && ys > U.DF[2].z) {
        for (int i = 0; i < 6; i++) { if (i >= VN) break; if (U.VP[i].y >= U.DF[2].z) continue;
            float dx = (p.x - U.VP[i].x) / U.DF[2].w, dy = (ys - U.DF[2].z - 2.0) / 46.0;
            c += U.VC[i].rgb * min(U.VC[i].a, 1.0) * exp(-dx * dx - dy * dy) * (0.75 + 0.25 * sin(ys * 1.7)) * U.DF[2].y; } }
    // 네이티브 긴 그림자(건널목 — 역광 해에서 카메라 쪽으로): 땅 픽셀에서 해 반대쪽으로 거슬러 올라가 인물 픽셀이면 그늘 · 탭 셋으로 부드럽게
    if (U.EX[0].w > 0.0 && info.a < 0.75 && ys > U.EX[0].x && dHere > 0.18 && dHere < 0.36) {
        float h = (ys - U.EX[0].x) / U.EX[0].y, sh = U.EX[0].z * sign(p.x - U.EX[1].x), cov = 0.0;
        for (int j = -1; j <= 1; j++) {
            float2 s2 = float2(p.x - sh * h + float(j) * (0.8 + h * 0.05), U.EX[0].x - h);
            int2 q = int2(int(floor(s2.x)), int(floor(uRes.y - s2.y)));
            if (q.x >= 0 && q.x < W && q.y >= 0 && q.y < H) { float qa = rtRead(uInfo, q, H).a; if (qa > 0.77 && qa < 0.985) cov += 1.0 / 3.0; } }
        c *= 1.0 - U.EX[0].w * cov * clamp(1.0 - h / 80.0, 0.0, 1.0); }
    // 네이티브 달빛(무도장): 창(장지) 사각형을 빛 방향으로 바닥에 옮긴 밝은 자리 + 창살 그늘 · 빛기둥 안 먼지
    if (U.EX[4].x > 0.0 || U.EX[4].y > 0.0) {
        float2 dir = normalize(U.EX[7].zw); float wy0 = U.EX[7].x, wy1 = U.EX[7].y, fy = U.EX[4].z, cell = U.EX[4].w;
        float3 moon = float3(0.55, 0.68, 1.0);
        if (ys > fy && info.a < 0.75 && dHere > 0.2 && dHere < 0.36) {
            float u = clamp((ys - fy) / (uRes.y - fy), 0.0, 1.0), wy = wy1 - u * (wy1 - wy0), wx = p.x - dir.x * (ys - wy) / dir.y;
            for (int k = 0; k < 2; k++) { float x0 = U.EX[6][k * 2], x1 = U.EX[6][k * 2 + 1];
                if (wx > x0 && wx < x1) { bool bar = fract((wx - x0) / cell) < 0.17 || fract((wy - wy0) / (cell * 0.8)) < 0.17;
                    float edge = smoothstep(0.0, 4.0, min(wx - x0, x1 - wx));
                    c += moon * U.EX[4].x * (bar ? 0.12 : 1.0) * edge * (1.0 - 0.45 * u); } } }
        if (U.EX[4].y > 0.0 && ys > wy0 && ys < fy + 30.0) {
            float sB = (ys - wy0) / dir.y, sA = max(0.0, (ys - wy1) / dir.y), xa = p.x - dir.x * sB, xb = p.x - dir.x * sA, inB = 0.0;
            for (int k = 0; k < 2; k++) { float x0 = U.EX[6][k * 2], x1 = U.EX[6][k * 2 + 1]; if (min(xb, x1) - max(xa, x0) > 0.0) inB = 1.0; }
            if (inB > 0.0) { float2 cc = floor(p / 6.0); float hh = hash21(cc);
                if (hh > 0.8) { float2 mp = cc * 6.0 + 3.0 + float2(sin(uTime * 0.23 + hh * 31.0) * 2.4, sin(uTime * 0.17 + hh * 17.0) * 2.4);
                    float m = 1.0 - smoothstep(0.35, 0.95, length(p - mp));
                    c += moon * m * U.EX[4].y * (0.6 + 0.4 * sin(uTime * 1.3 + hh * 50.0)); } } } }
    // 볼류메트릭
    for (int i = 0; i < 6; i++) { if (i >= VN) break;
        float2 v = p - U.VP[i].xy; float d = length(v), along = dot(v, U.VP[i].zw);
        if (along > 0.0 && along < U.VD[i].y) { float ca = along / max(d, 0.001); float inside = smoothstep(U.VD[i].x, U.VD[i].x + (1.0 - U.VD[i].x) * 0.7, ca);
            float fall = pow(1.0 - along / U.VD[i].y, 1.5); float n = 0.82 + 0.18 * sin(p.x * 0.11 + p.y * 0.05 + uTime * 0.7);
            c += U.VC[i].rgb * U.VC[i].a * inside * fall * n * 0.2; }
        c += U.VC[i].rgb * U.VC[i].a * 0.08 / (1.0 + d * d / (U.VD[i].z * U.VD[i].z)); }
    // 네이티브 역광(건널목): 렌즈 반짝(해 → 화면 가운데 줄 위 육각 넷) · 공기 먼지 · 땅 반짝
    if (U.EX[1].z > 0.0) { float2 sun = U.EX[1].xy, dv = U.EX[2].xy - sun;
        const float T[4] = {0.42, 0.68, 1.12, 1.42}; const float R[4] = {2.2, 1.3, 3.4, 1.7}; const float A[4] = {0.26, 0.3, 0.14, 0.24};
        for (int i = 0; i < 4; i++) { float2 q2 = abs(p - (sun + dv * T[i])); float hx = max(q2.x * 0.866 + q2.y * 0.5, q2.y);
            c += float3(1.0, 0.78, 0.5) * (1.0 - smoothstep(R[i] - 0.5, R[i] + 0.5, hx)) * A[i] * U.EX[1].z; } }
    if (U.EX[1].w > 0.0 && ys < U.EX[0].x && ys > 40.0) { float2 cc = floor(p / 7.0); float hh = hash21(cc + 3.1);
        if (hh > 0.8) { float2 mp = cc * 7.0 + 3.5 + float2(sin(uTime * 0.37 + hh * 23.0) * 2.8, sin(uTime * 0.29 + hh * 11.0) * 2.8);
            float m = 1.0 - smoothstep(0.3, 0.9, length(p - mp)), back = exp(-abs(p.x - U.EX[1].x) / 130.0);
            c += float3(1.0, 0.8, 0.5) * m * U.EX[1].w * back * (0.55 + 0.45 * sin(uTime * 2.1 + hh * 40.0)); } }
    if (U.EX[2].z > 0.0 && ys > U.EX[0].x + 2.0 && info.a < 0.75) { float2 cc = floor(p / float2(5.0, 4.0)); float hh = hash21(cc + 7.7);
        if (hh > 0.9) { float tw = pow(max(0.0, sin(uTime * 2.6 + hh * 60.0)), 10.0);
            if (all(int2(p) == int2(cc * float2(5.0, 4.0) + float2(2.0, 1.0)))) c += float3(1.0, 0.82, 0.45) * tw * U.EX[2].z; } }
    // 네이티브 경보등 붉은빛(건널목 전차 — 땡땡 박자로 왼쪽 · 오른쪽 등이 번갈아): 인물의 등 쪽 면 · 땅을 물들인다
    if (U.EX[3].z > 0.0) { float2 v = U.EX[3].xy - p; float fall = clamp(1.0 - length(v) / U.EX[3].w, 0.0, 1.0);
        if (fall > 0.0) {
            if (info.a > 0.77 && info.a < 0.985) { float2 n = rtRead(uNorm, px, H).rg * 2.0 - 1.0;
                float f = max(0.0, dot(normalize(n + 1e-4), normalize(float2(v.x, -v.y))));
                c += float3(1.0, 0.12, 0.08) * U.EX[3].z * fall * (0.3 + 0.7 * f) * 0.55; }
            else if (ys > U.EX[0].x) c += float3(1.0, 0.1, 0.06) * U.EX[3].z * fall * fall * 0.3; } }
    // 안개
    c = mix(c, U.fogC.rgb, U.rainVig.z * smoothstep(uRes.y, 0.0, ys) * 0.6);
    // 노출 · 블룸
    float uExpo = U.expoWin.x;
    c *= uExpo;
    c += rtSample(uBloom, lin, uv).rgb * U.pressTime.z * max(1.0, uExpo);
    float uPress = U.pressTime.x;
    if (uPress > 0.0) { float2 q2 = uv - 0.5; c *= 1.0 - uPress * smoothstep(0.08, 0.5, dot(q2, q2) * 2.2); }
    // 비
    float uRain = U.rainVig.x;
    if (uRain > 0.0) { float sx = p.x + ys * 0.22; float col = floor(sx / 3.0); float h = fract(sin(col * 91.7) * 437.5);
        float len = 50.0 + h * 80.0, t = fract((ys - uTime * (260.0 + h * 140.0) + h * 500.0) / len);
        if (t < 0.07 && fract(h * 13.0) < uRain && glslMod(sx, 3.0) < 1.0) c += float3(0.32, 0.36, 0.42) * (t / 0.07) * 0.55; }
    // 네이티브 전경(무도장 이벤트): 카메라 앞 초점 밖 행인 실루엣 · 큰 눈송이 — 부호 거리로 부드럽게(블러 패스 없이) → 아래 24단 디더가 픽셀로 자른다
    if (U.FG[1].y > 0.0) {   // 행인 그림(무대 픽셀 — 미리 곱한 RGBA): 원판 탭 17개로 흐림(초점보다 가까움) → 아래 24단 디더
        float2 lo = U.FG[0].xy, sz = U.FG[0].zw; float R = U.FG[1].x;
        if (p.x > lo.x - R - 1.0 && p.x < lo.x + sz.x + R + 1.0 && ys > lo.y - R - 1.0 && ys < lo.y + sz.y + R + 1.0) {
            constexpr sampler z0(filter::linear, address::clamp_to_zero);
            float2 q = (float2(p.x, ys) - lo) / sz, k = R / sz;
            float4 acc = uPass.sample(z0, q);
            float4 e4 = uPass.sample(z0, q + float2(k.x, 0.0)) + uPass.sample(z0, q - float2(k.x, 0.0)) + uPass.sample(z0, q + float2(0.0, k.y)) + uPass.sample(z0, q - float2(0.0, k.y));
            if (acc.a + e4.a > 0.0) {   // 빈 자리는 건너뛴다(전경은 화면 가장자리 · 아래에만)
            for (int i = 0; i < 6; i++) { float a = float(i) * 1.0472 + 0.3; acc += uPass.sample(z0, q + float2(cos(a), sin(a)) * k * 0.5); }
            for (int i = 0; i < 10; i++) { float a = float(i) * 0.6283; acc += uPass.sample(z0, q + float2(cos(a), sin(a)) * k); }
            acc /= 17.0;
            c = c * (1.0 - acc.a * U.FG[1].y) + acc.rgb * U.FG[1].y; } } }
    if (U.FG[1].w > 0.0) { float t = U.FG[2].x;
        for (int i = 0; i < 7; i++) { float fi = float(i);
            float hx = fract(sin(fi * 12.9898 + 1.3) * 43758.5453), hy = fract(sin(fi * 78.233 + 4.1) * 43758.5453), hr = fract(sin(fi * 39.425) * 43758.5453);
            float2 fc = float2(U.FG[2].y + hx * U.FG[2].z + sin(t * 0.6 + fi) * 6.0, glslMod(hy * 300.0 + t * (14.0 + 8.0 * hr), 300.0) - 20.0);
            float r = 1.8 + 2.4 * hr, cv = 1.0 - smoothstep(r - 1.6, r + 1.6, length(p - float2(fc.x, fc.y)));
            c = mix(c, float3(0.78, 0.82, 0.95), cv * 0.42 * U.FG[1].w); } }
    // 색 보정 · 비네트 · 반전 · 24단 양자화
    c = mix(float3(dot(c, float3(.299, .587, .114))), c, U.grade.w) * U.grade.rgb;
    float2 q = uv - 0.5; c *= 1.0 - U.rainVig.y * dot(q, q) * 1.7;
    if (U.rainVig.w > 0.5) { float l = dot(c, float3(.3, .59, .11)); c = float3(1.0) - float3(l * 1.4); }
    c = floor(c * 24.0 + bayer4(px) + 0.0) / 24.0;
    return float4(c, 1.0);
}

// ============================================================ 4. 화면 출력: sharp-bilinear · 세로 크롭 · 줌 펀치
struct BlitU {
    float4 srcDst;     // uSrc.xy · uDst.xy
    float4 zoom;       // uZoom · uZC.xy · uCamX
    float4 vw;         // uVW · 기울기(네이티브 — 0 = 웹 그대로)
};
fragment float4 blitFS(FullV in [[stage_in]], constant BlitU& U [[buffer(0)]], texture2d<float> uT [[texture(0)]]) {
    constexpr sampler lin(filter::linear, address::clamp_to_edge);
    float2 uSrc = U.srcDst.xy, uDst = U.srcDst.zw; float uVW = U.vw.x;
    float2 pp = in.pos.xy;
    if (U.vw.y != 0.0) { float2 c = uDst * 0.5, d = pp - c; float cs = cos(U.vw.y), sn = sin(U.vw.y); pp = c + float2(cs * d.x - sn * d.y, sn * d.x + cs * d.y); }   // 네이티브 더치 틸트: 뷰 가운데 축
    float2 vUV = float2(pp.x / uDst.x, 1.0 - pp.y / uDst.y);   // GL vUV(아래→위)
    float2 uv = float2((U.zoom.w + vUV.x * uVW) / uSrc.x, vUV.y);
    float2 tx = clamp(((uv - U.zoom.yz) / max(U.zoom.x, 1.0) + U.zoom.yz) * uSrc, float2(0.0), uSrc - float2(0.001));
    float2 sc = max(uDst / float2(uVW, uSrc.y), float2(1.0));
    float2 fl = floor(tx); float2 cd = fract(tx) - 0.5; float2 rr = 0.5 - 0.5 / sc;
    float2 f = (cd - clamp(cd, -rr, rr)) * sc + 0.5;
    return rtSample(uT, lin, (fl + f) / uSrc);
}
