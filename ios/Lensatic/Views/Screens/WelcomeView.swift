import SwiftUI

/// The welcome screen (the redesign, R1; Main.dc.html): one question and the four trailheads. On first launch it is
/// the whole app; afterwards Change brings it back over the tabs, with the current trailhead outlined and Cancel.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    var isChange = false

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isChange {
                        HStack {
                            Spacer()
                            Button { model.changingDoor = false } label: {
                                Text("Cancel").font(DS.link).foregroundStyle(Palette.link).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("welcome-cancel")
                        }
                    }
                    MarkTile()
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Take a bearing")
                        Text("Which frameworks apply to you?")
                            .font(DS.welcomeTitle).foregroundStyle(Palette.fg)
                            .accessibilityAddTraits(.isHeader)
                        Text("Pick where you stand. Lensatic builds your path: what binds you, in what order, and by when.")
                            .font(DS.lede).foregroundStyle(Palette.fg2).lineSpacing(3)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 10) {
                        ForEach(Door.ID.welcomeOrder.compactMap { model.door($0) }, id: \.id) { door in
                            Button { model.choose(door.id) } label: {
                                ListRow(title: door.shortTitle,
                                        subtitle: model.plan(door).cardLine(today: Date(), labels: model.store.content.ui.labels),
                                        icon: door.id.icon, iconColor: door.id.color,
                                        highlighted: isChange && model.progress.door == door.id)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("door-\(door.id.rawValue)")
                            .accessibilityAddTraits(isChange && model.progress.door == door.id ? .isSelected : [])
                        }
                    }
                    Spacer(minLength: 16)
                    Text("No account. Nothing leaves your phone.\nYou can change this anytime.")
                        .font(DS.caption).foregroundStyle(Palette.fg2).lineSpacing(3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.top, isChange ? 8 : 25)
                .padding(.bottom, 28)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(GridGround())
        .accessibilityIdentifier("welcome")
    }
}

/// The compass in its dark tile (hub/DESIGN.md: --tile-bg, --tile-fg).
struct MarkTile: View {
    var body: some View {
        Icon(.compass, size: 38, color: Palette.tileFg, lineWidth: 1.8)
            .frame(width: 64, height: 64)
            .background(Palette.tileBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityHidden(true)
    }
}

extension Door.ID {
    /// The welcome screen's order, the brief's: the department, civilian agencies, contractors, everyone else. The
    /// content keeps the web's order (civilian agencies first) for the map's own trailheads.
    static let welcomeOrder: [Door.ID] = [.dow, .federalCivilian, .defenseContractor, .other]

    /// Each trailhead's mark on the welcome screen, as the mockup draws it; the colours only mark, the name says it.
    var icon: IconName {
        switch self {
        case .dow: return .shield
        case .federalCivilian: return .building
        case .defenseContractor: return .briefcase
        case .other: return .globe
        }
    }

    var color: Color {
        switch self {
        case .dow: return Palette.secMaps
        case .federalCivilian: return Palette.accent
        case .defenseContractor: return Palette.secGuides
        case .other: return Palette.secPurple
        }
    }
}
