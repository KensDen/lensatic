import SwiftUI

/// The trailhead question (the redesign, R1; Main.dc.html; the welcome screen until build 6): one question and the five
/// trailheads. Since build 6 the app opens on Home, and the question comes over the tabs: full screen for the first pick
/// (isFirst), with Cancel beside the compass tile, so the screen is as tall as it was; and as a sheet for Change Path
/// (isChange), with the current trailhead outlined and Cancel.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    var isChange = false
    /// The first pick, over Home: Cancel shares the compass tile's row.
    var isFirst = false
    @State private var showStory = false

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                // five doors, the question and the footer fit 390 x 844 at the default size with nothing to scroll (R5)
                VStack(alignment: .leading, spacing: 12) {
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
                    // the compass opens the story of the name (R5, item 17): no new words on the screen itself
                    HStack(alignment: .top) {
                        Button { showStory = true } label: { MarkTile() }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Why Lensatic")
                            .accessibilityHint("Opens the story of the name")
                            .accessibilityIdentifier("welcome-story")
                        if isFirst {
                            Spacer()
                            Button { model.changingDoor = false } label: {
                                Text("Cancel").font(DS.link).foregroundStyle(Palette.link).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("welcome-cancel")
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Choose a trailhead")
                        Text(model.store.label("homeMapsTitle"))
                            .font(DS.welcomeTitle).foregroundStyle(Palette.fg)
                            .accessibilityAddTraits(.isHeader)
                        Text(model.store.label("welcomeLede"))
                            .font(DS.lede).foregroundStyle(Palette.fg2).lineSpacing(3)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 6) {
                        ForEach(Door.ID.welcomeOrder.compactMap { model.door($0) }, id: \.id) { door in
                            Button { model.choose(door.id) } label: {
                                ListRow(title: door.shortTitle,
                                        subtitle: keepDesignations(model.plan(door).welcomeLine()),
                                        icon: door.id.icon, iconColor: door.id.color,
                                        highlighted: isChange && model.progress.door == door.id,
                                        detail: model.plan(door).welcomeCount(labels: model.store.content.ui.labels), verticalPadding: 10)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("door-\(door.id.rawValue)")
                            .accessibilityAddTraits(isChange && model.progress.door == door.id ? .isSelected : [])
                        }
                    }
                    // directly under the five cards (build 6), where the eye is after reading them, not at the foot of the screen
                    Text("No account. Nothing leaves your phone.\nSwitch paths anytime from My Path.")
                        .font(DS.caption).foregroundStyle(Palette.fg2).lineSpacing(3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                        .accessibilityIdentifier("welcome-hint")
                }
                .padding(.horizontal, 20)
                .padding(.top, isChange ? 8 : 16)
                .padding(.bottom, 16)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(GridGround())
        .accessibilityIdentifier("welcome")
        .sheet(isPresented: $showStory) { StorySheet().environment(model).tint(Palette.link) }
    }
}

/// The app icon's compass on the Welcome screen (R6): the site's mark (the Mark image set, web/src/mark.svg), the same
/// drawing as the icon, at about 71% of the tile as hub/DESIGN.md sets it. Each appearance takes its icon look from the
/// existing tokens: in light the guides green on the paper surface, as the Light icon; in dark the tile's green on the
/// tile ground, as the Dark icon. A hairline edge keeps the tile's shape against the ground in both.
struct MarkTile: View {
    @Environment(\.colorScheme) private var scheme
    /// The tile's side: 64 points on the trailhead question, 44 in Home's header (build 6), the mark and the corner in
    /// proportion.
    var side: CGFloat = 64

    var body: some View {
        let dark = scheme == .dark
        let mark = side * 46 / 64, radius = side / 4
        Image("Mark")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: mark, height: mark)
            .foregroundStyle(dark ? Palette.tileFg : Palette.secGuides)
            .frame(width: side, height: side)
            .background(dark ? Palette.tileBg : Palette.bg2, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(dark ? Palette.lineStrong : Palette.line, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension Door.ID {
    /// The welcome screen's order, the brief's: the department, civilian agencies, contractors, then state and local
    /// governments and industry and academia (R5, where Everyone Else stood). The content keeps the web's order
    /// (civilian agencies first) for the map's own trailheads.
    static let welcomeOrder: [Door.ID] = [.dow, .federalCivilian, .defenseContractor, .stateLocal, .industryAcademia]

    /// Each trailhead's mark on the welcome screen, as the mockup draws it; the colours only mark, the name says it.
    var icon: IconName {
        switch self {
        case .dow: return .shield
        case .federalCivilian: return .building
        case .defenseContractor: return .briefcase
        case .stateLocal: return .landmark
        case .industryAcademia: return .globe
        }
    }

    var color: Color {
        switch self {
        case .dow: return Palette.secMaps
        case .federalCivilian: return Palette.accent
        case .defenseContractor: return Palette.secGuides
        case .stateLocal: return Palette.link
        case .industryAcademia: return Palette.secPurple
        }
    }
}
