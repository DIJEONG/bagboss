// 시뮬레이션 → 표현 이벤트 전달(docs/06 §3).
// 규칙은 이벤트를 쌓기만 하고, 한 틱이 끝나면 표현 계층이 한꺼번에 가져간다. 구독 콜백은 두지 않는다
// (규칙 실행 도중에 표현 코드가 끼어드는 일을 구조적으로 막기 위해).

public struct EventBuffer<Event: Sendable>: Sendable {
    public private(set) var items: [Event] = []
    public init() {}
    public mutating func emit(_ e: Event) { items.append(e) }
    /// 쌓인 이벤트를 꺼내고 비운다.
    public mutating func drain() -> [Event] {
        defer { items.removeAll(keepingCapacity: true) }
        return items
    }
    public var isEmpty: Bool { items.isEmpty }
}
