import UIKit

/// 측정용 오버레이. 디버그 빌드는 처음부터 보이고, 릴리스는 세 손가락 두 번 탭으로 켠다.
/// - 탭: 한 줄 ↔ 자세히
/// - 끌기: 위치 옮기기(게임 HUD를 가리지 않게)
/// - 길게 누르기: 이번 세션 CSV 공유(에어드롭 · 파일 저장)
@MainActor
final class PerfHUD: UIView {
    private let label = UILabel()
    private weak var monitor: PerfMonitor?
    private var expanded = false
    var onShare: ((URL) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.62)
        layer.cornerRadius = 6
        layer.borderWidth = 1
        layer.borderColor = UIColor(white: 1, alpha: 0.18).cgColor
        isUserInteractionEnabled = true
        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        label.textColor = UIColor(red: 0.62, green: 1, blue: 0.62, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggle)))
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(drag(_:))))
        let press = UILongPressGestureRecognizer(target: self, action: #selector(share(_:)))
        press.minimumPressDuration = 0.6
        addGestureRecognizer(press)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 미사용") }

    func attach(to host: UIView, monitor: PerfMonitor) {
        self.monitor = monitor
        translatesAutoresizingMaskIntoConstraints = true
        host.addSubview(self)
        frame = CGRect(x: 8, y: 60, width: 150, height: 20)   // 임시 — 안전 영역을 안 뒤 GameViewController가 옮긴다
        monitor.onUpdate = { [weak self] in self?.refresh() }
        refresh()
    }

    func refresh() {
        guard let m = monitor, !isHidden else { return }
        let l = m.live
        label.text = expanded
            ? m.summaryText()
            : String(format: "FPS %.0f · p95 %.0fms · %@", l.fps, l.p95, m.thermalLabel)
        label.textColor = l.fps >= 55 ? UIColor(red: 0.62, green: 1, blue: 0.62, alpha: 1)
            : l.fps >= 45 ? UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 1)
            : UIColor(red: 1, green: 0.45, blue: 0.4, alpha: 1)
        let size = label.sizeThatFits(CGSize(width: 260, height: 200))
        frame.size = CGSize(width: min(260, size.width + 12), height: size.height + 8)
    }

    @objc private func toggle() {
        expanded.toggle()
        refresh()
    }

    @objc private func drag(_ g: UIPanGestureRecognizer) {
        guard let host = superview else { return }
        let t = g.translation(in: host)
        center = CGPoint(x: center.x + t.x, y: center.y + t.y)
        g.setTranslation(.zero, in: host)
    }

    @objc private func share(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began, let url = monitor?.sessionURL else { return }
        onShare?(url)
    }
}
