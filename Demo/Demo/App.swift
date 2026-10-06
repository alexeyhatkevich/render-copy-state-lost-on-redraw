import UIKit
import RenderCopyState

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: DemoViewController())
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

/// Hosts the library's consent page model in real UIKit views.
///
/// The views are rebuilt from `page.renderedChildren` after every model change,
/// exactly like a declarative framework would: whatever the render copies say is
/// what you see. Flip the switch ON, then tap "Toggle hint" to force a redraw.
final class DemoViewController: UIViewController {

    private enum Mode: Int, CaseIterable {
        case naive, writeThrough, fixed

        var title: String {
            switch self {
            case .naive: return "Naive"
            case .writeThrough: return "Write-through"
            case .fixed: return "Fixed"
            }
        }

        var toggleClass: RCToggle.Type {
            switch self {
            case .naive: return RCNaiveToggle.self
            case .writeThrough: return RCWriteThroughToggle.self
            case .fixed: return RCFixedToggle.self
            }
        }

        var explanation: String {
            switch self {
            case .naive:
                return "Naive: the tap is stored on the render copy only. Turn \"I agree\" ON, then tap Toggle hint. The redraw rebuilds the copies from the sources, so the switch snaps back to OFF while Next stays enabled. The UI and the logic now disagree."
            case .writeThrough:
                return "Write-through: the tap is also stored on the source, so it survives Toggle hint. Now turn it ON and tap Leave & come back. The page model is cached, so the switch is already ON on the next visit even though nobody tapped it."
            case .fixed:
                return "Fixed: write-through plus a reset to the authored value on every fresh presentation. The switch survives any number of redraws, and Leave & come back starts from OFF again."
            }
        }
    }

    private var mode: Mode = .naive
    private var cache = RCPageCache()
    private var page: RCConsentPage!
    private var hintHidden = false

    private let modeControl = UISegmentedControl(items: Mode.allCases.map(\.title))
    private let explanationLabel = UILabel()
    private let screenStack = UIStackView()       // the "rendered" consent screen
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Render-copy state"
        view.backgroundColor = .systemGroupedBackground

        modeControl.selectedSegmentIndex = mode.rawValue
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        modeControl.accessibilityIdentifier = "mode"

        explanationLabel.numberOfLines = 0
        explanationLabel.font = .preferredFont(forTextStyle: .footnote)
        explanationLabel.textColor = .secondaryLabel

        screenStack.axis = .vertical
        screenStack.spacing = 12
        screenStack.isLayoutMarginsRelativeArrangement = true
        screenStack.directionalLayoutMargins = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
        screenStack.backgroundColor = .secondarySystemGroupedBackground
        screenStack.layer.cornerRadius = 12

        statusLabel.numberOfLines = 0
        statusLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)

        let redrawButton = UIButton(configuration: .bordered(), primaryAction: UIAction(title: "Toggle hint (redraw)") { [weak self] _ in
            self?.toggleHint()
        })
        let revisitButton = UIButton(configuration: .bordered(), primaryAction: UIAction(title: "Leave & come back") { [weak self] _ in
            self?.revisit()
        })
        let buttons = UIStackView(arrangedSubviews: [redrawButton, revisitButton])
        buttons.axis = .horizontal
        buttons.spacing = 12
        buttons.distribution = .fillEqually

        let root = UIStackView(arrangedSubviews: [modeControl, explanationLabel, screenStack, buttons, statusLabel])
        root.axis = .vertical
        root.spacing = 16
        root.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(root)
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            root.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            root.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            root.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
        ])

        // Launch arguments for scripted runs: `-mode naive|writethrough|fixed` picks the
        // segment, `-autorun 1` turns "I agree" ON and then taps Toggle hint once.
        let defaults = UserDefaults.standard
        switch defaults.string(forKey: "mode")?.lowercased() {
        case "writethrough", "write-through": mode = .writeThrough
        case "fixed": mode = .fixed
        default: break
        }
        modeControl.selectedSegmentIndex = mode.rawValue
        startMode()
        if defaults.bool(forKey: "autorun") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                self.page.renderedToggle.userDidToggle(true)
                self.render()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.toggleHint() }
            }
        }
    }

    // MARK: - Actions

    @objc private func modeChanged() {
        mode = Mode(rawValue: modeControl.selectedSegmentIndex) ?? .naive
        startMode()
    }

    private func startMode() {
        cache = RCPageCache()       // a fresh cache per mode, so modes don't share models
        hintHidden = false
        explanationLabel.text = mode.explanation
        presentPage()
    }

    /// Navigation in: fetch the (cached) model and present it freshly.
    private func presentPage() {
        let toggleClass = mode.toggleClass
        page = cache.page(named: "consent") { RCConsentPage(toggleClass: toggleClass) }
        page.setHintHidden(hintHidden)
        page.present()
        render()
    }

    private func toggleHint() {
        hintHidden.toggle()
        page.setHintHidden(hintHidden)   // sibling visibility change -> redraw
        render()
    }

    private func revisit() {
        presentPage()                    // same cached model, fresh presentation
    }

    @objc private func switchChanged(_ sender: UISwitch) {
        page.renderedToggle.userDidToggle(sender.isOn)   // lands on the render copy
        render()
    }

    // MARK: - Rendering

    /// Rebuilds every view from the current render copies.
    private func render() {
        screenStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for element in page.renderedChildren where !element.isCollapsed {
            switch element.identifier {
            case "hint":
                let hint = UILabel()
                hint.text = "Please read the terms before continuing."
                hint.numberOfLines = 0
                hint.textColor = .secondaryLabel
                screenStack.addArrangedSubview(hint)
            case "agree":
                guard let toggle = element as? RCToggle else { continue }
                let label = UILabel()
                label.text = "I agree"
                let control = UISwitch()
                control.isOn = toggle.isSelected
                control.accessibilityIdentifier = "agree"
                control.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
                let row = UIStackView(arrangedSubviews: [label, control])
                row.axis = .horizontal
                screenStack.addArrangedSubview(row)
            case "next":
                var config = UIButton.Configuration.filled()
                config.title = "Next"
                let next = UIButton(configuration: config)
                next.isEnabled = page.nextEnabled
                next.accessibilityIdentifier = "next"
                screenStack.addArrangedSubview(next)
            default:
                break
            }
        }

        let switchOn = page.renderedToggle.isSelected
        let consistent = switchOn == page.nextEnabled
        statusLabel.text = """
        switch (render copy): \(switchOn ? "ON" : "OFF")
        source toggle:        \(page.sourceToggle.isSelected ? "ON" : "OFF")
        Next enabled:         \(page.nextEnabled ? "YES" : "NO")
        redraws: \(page.redrawCount)   visits: \(page.presentationCount)
        \(consistent ? "UI and logic agree" : "DESYNC: switch and Next disagree")
        """
        statusLabel.textColor = consistent ? .label : .systemRed
    }
}
