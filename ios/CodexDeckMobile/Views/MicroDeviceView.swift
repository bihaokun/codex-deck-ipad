import SwiftUI

/// Side length of one square Micro key, derived from the enclosure width so
/// four columns always fill it edge to edge like the hardware.
private struct MicroKeySideKey: EnvironmentKey {
  static let defaultValue: CGFloat = 66
}

extension EnvironmentValues {
  fileprivate var microKeySide: CGFloat {
    get { self[MicroKeySideKey.self] }
    set { self[MicroKeySideKey.self] = newValue }
  }
}

struct ActiveChatsView: View {
  @Environment(DashboardStore.self) private var store

  var body: some View {
    VStack(spacing: 10) {
      SectionLabel("Selected chats", detail: "Open on each computer")
      CodexGlassGroup(spacing: 10) { chatCards }
    }
  }

  @ViewBuilder
  private var chatCards: some View {
    VStack(spacing: 10) {
      if store.activeChats.isEmpty {
        HStack(spacing: 10) {
          Circle().fill(CodexTheme.secondary.opacity(0.35)).frame(width: 8, height: 8)
          Text("No selected chat reported yet")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(CodexTheme.secondary)
          Spacer()
        }
        .padding(14)
        .codexGlassSurface(cornerRadius: 18, tint: .white.opacity(0.06))
      } else {
        ForEach(store.activeChats) { chat in
          HStack(spacing: 12) {
            Text(chat.host.platform.shortLabel)
              .font(.caption2.weight(.black))
              .foregroundStyle(.white)
              .frame(width: 27, height: 27)
              .background(CodexTheme.control, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
              Text(chat.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
              Text(chat.host.hostName)
                .font(.caption2)
                .foregroundStyle(CodexTheme.secondary)
            }
            Spacer()
            Circle().fill(CodexTheme.statusColor(chat.status)).frame(width: 9, height: 9)
          }
          .padding(14)
          .codexGlassSurface(cornerRadius: 18, tint: .white.opacity(0.06))
        }
      }
    }
  }
}

struct CodexMicroDeviceView: View {
  @Environment(DashboardStore.self) private var store
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  let placements: [MobileAgentPlacement]
  let editKey: (DeviceKeySlot) -> Void
  let showAgent: (AgentReference) -> Void

  var body: some View {
    let connectedCount = store.connectedCount
    let agents = placements.compactMap(\.agent)
    VStack(spacing: 0) {
      GeometryReader { proxy in
        let hPad: CGFloat = verticalSizeClass == .compact ? 34 : 40
        let spacing: CGFloat = 9
        let keySide = (proxy.size.width - hPad * 2 - spacing * 3) / 4
        ZStack {
          DeviceEnclosure(
            glow: ambientGlow(for: agents), connected: connectedCount > 0,
            listening: store.micListening || store.localDictating)

          VStack(spacing: spacing) {
            HStack(spacing: spacing) {
              ReasoningDial()
              MicroAgentKey(placement: placement(0), showAgent: showAgent)
              MicroAgentKey(placement: placement(1), showAgent: showAgent)
              JoystickControl()
            }
            HStack(spacing: spacing) {
              MicroAgentKey(placement: placement(2), showAgent: showAgent)
              MicroAgentKey(placement: placement(3), showAgent: showAgent)
              MicroAgentKey(placement: placement(4), showAgent: showAgent)
              MicroAgentKey(placement: placement(5), showAgent: showAgent)
            }
            HStack(spacing: spacing) {
              ConfigurableDeviceKey(slot: .action1, editKey: editKey)
              ConfigurableDeviceKey(slot: .action2, editKey: editKey)
              ConfigurableDeviceKey(slot: .action3, editKey: editKey)
              ConfigurableDeviceKey(slot: .action4, editKey: editKey)
            }
            HStack(spacing: spacing) {
              SignalCluster(
                agents: agents, connectedCount: connectedCount, expectedCount: store.expectedCount
              )
              .frame(width: keySide)
              ConfigurableDeviceKey(slot: .wide, editKey: editKey)
              ConfigurableDeviceKey(slot: .corner, editKey: editKey)
              .frame(width: keySide)
            }
          }
          .environment(\.microKeySide, keySide)
          .padding(.horizontal, hPad)

          DeviceDetails(size: proxy.size)
          DeviceScrews().padding(verticalSizeClass == .compact ? 18 : 17)
        }
      }
      .aspectRatio(1.0, contentMode: .fit)
    }
  }

  private func placement(_ index: Int) -> MobileAgentPlacement {
    placements.first(where: { $0.position == index })
      ?? MobileAgentPlacement(position: index, reference: nil, agent: nil)
  }

  private func ambientGlow(for agents: [RoutedAgent]) -> Color {
    let statuses = agents.map(\.status)
    if statuses.contains("error") { return CodexTheme.red }
    if statuses.contains(where: {
      ["approval", "awaiting-approval", "awaiting-response"].contains($0)
    }) { return CodexTheme.orange }
    if statuses.contains(where: { ["working", "thinking"].contains($0) }) {
      return CodexTheme.blue
    }
    if statuses.contains(where: {
      ["unread", "complete", "completed", "done"].contains($0)
    }) { return CodexTheme.green }
    return store.connectedCount > 0
      ? Color(red: 0.42, green: 0.86, blue: 0.69)
      : CodexTheme.secondary
  }

}

private struct DeviceEnclosure: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var breath = false
  let glow: Color
  let connected: Bool
  var listening = false

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 48, style: .continuous)
        .fill(
          LinearGradient(
            colors: colorScheme == .dark
              ? [
                Color(red: 0.10, green: 0.12, blue: 0.15),
                glow.opacity(connected ? 0.22 : 0.08),
                Color(red: 0.045, green: 0.055, blue: 0.075),
              ]
              : [
                .white.opacity(0.92),
                glow.opacity(connected ? 0.2 : 0.07),
                glow.opacity(connected ? 0.14 : 0.05),
              ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing))
        .overlay {
          RoundedRectangle(cornerRadius: 48, style: .continuous)
            .stroke(.white.opacity(colorScheme == .dark ? 0.2 : 0.9), lineWidth: 3)
        }
        .overlay {
          // Idle ambience under the frosted rim, like the hardware's ambient
          // ring. Swapped for the rainbow chase while dictating.
          if !listening {
            EnclosureAmbientFlow(glow: glow, connected: connected)
          }
        }
        .overlay {
          if listening {
            EnclosureLightChase()
          }
        }
        .shadow(
          color: glow.opacity(connected ? (breath ? 0.5 : 0.24) : 0.12),
          radius: breath ? 20 : 12, y: 9)
        .onAppear {
          withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            breath = true
          }
        }

      RoundedRectangle(cornerRadius: 34, style: .continuous)
        .fill(
          LinearGradient(
            colors: colorScheme == .dark
              ? [Color(red: 0.16, green: 0.18, blue: 0.21), Color(red: 0.075, green: 0.09, blue: 0.115)]
              : [Color.white.opacity(0.9), CodexTheme.panel.opacity(0.88)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing))
        .overlay {
          RoundedRectangle(cornerRadius: 34, style: .continuous)
            .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.16), lineWidth: 1)
            .padding(1)
        }
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        .padding(18)
    }
  }
}

/// Idle rim ambience: two soft pools of the status color drift slowly around
/// the enclosure while the whole ring breathes — flowing light under frosted
/// glass rather than a static pulse.
private struct EnclosureAmbientFlow: View {
  @State private var angle: Double = 0
  @State private var breath = false
  let glow: Color
  let connected: Bool

  var body: some View {
    AngularGradient(
      gradient: Gradient(stops: [
        .init(color: glow.opacity(0.05), location: 0),
        .init(color: glow, location: 0.18),
        .init(color: glow.opacity(0.1), location: 0.42),
        .init(color: glow.opacity(0.9), location: 0.65),
        .init(color: glow.opacity(0.08), location: 0.88),
        .init(color: glow.opacity(0.05), location: 1),
      ]),
      center: .center)
      .scaleEffect(1.5)
      .rotationEffect(.degrees(angle))
      .mask(
        RoundedRectangle(cornerRadius: 46, style: .continuous)
          .strokeBorder(lineWidth: 9)
          .padding(2.5))
      .blur(radius: 8)
      .opacity(connected ? (breath ? 0.95 : 0.35) : (breath ? 0.3 : 0.1))
      .allowsHitTesting(false)
      .onAppear {
        withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
          angle = 360
        }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
          breath = true
        }
      }
  }
}

/// Full-perimeter RGB chase under the frosted enclosure rim while dictation is
/// live — a rainbow sweep orbiting the whole deck, like the hardware's
/// push-to-talk light show.
private struct EnclosureLightChase: View {
  @State private var angle: Double = 0

  var body: some View {
    AngularGradient(
      gradient: Gradient(colors: [
        Color(red: 1.0, green: 0.35, blue: 0.35),
        Color(red: 1.0, green: 0.65, blue: 0.2),
        Color(red: 0.4, green: 0.9, blue: 0.45),
        Color(red: 0.25, green: 0.75, blue: 1.0),
        Color(red: 0.6, green: 0.45, blue: 1.0),
        Color(red: 1.0, green: 0.4, blue: 0.75),
        Color(red: 1.0, green: 0.35, blue: 0.35),
      ]),
      center: .center)
      .scaleEffect(1.5)
      .rotationEffect(.degrees(angle))
      .mask(
        RoundedRectangle(cornerRadius: 46, style: .continuous)
          .strokeBorder(lineWidth: 10)
          .padding(2))
      .blur(radius: 6)
      .allowsHitTesting(false)
      .onAppear {
        withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
          angle = 360
        }
      }
  }
}

private struct DeviceDetails: View {
  let size: CGSize

  var body: some View {
    ZStack {
      Image(systemName: "arrow.up")
        .font(.system(size: 15, weight: .medium))
        .position(x: size.width / 2, y: 26)

      Text("WORK LOUDER  |  CODEX DECK  |  2026")
        .font(.system(size: 6.5, weight: .medium))
        .foregroundStyle(CodexTheme.ink.opacity(0.75))
        .rotationEffect(.degrees(-90))
        .position(x: 28, y: size.height / 2)

      Text("YOU CAN JUST BUILD THINGS")
        .font(.system(size: 6.5, weight: .medium))
        .foregroundStyle(CodexTheme.ink.opacity(0.75))
        .rotationEffect(.degrees(90))
        .position(x: size.width - 28, y: size.height / 2)

      Text("LET’S BUILD")
        .font(.system(size: 7, weight: .medium))
        .tracking(0.6)
        .foregroundStyle(CodexTheme.ink.opacity(0.62))
        .position(x: size.width / 2, y: size.height - 25)
    }
    .allowsHitTesting(false)
  }
}

private struct DeviceHostPicker: View {
  @Environment(DashboardStore.self) private var store

  var body: some View {
    let hosts = Dictionary(grouping: store.nodes.values.compactMap(\.host), by: \.hostId)
      .compactMap { $0.value.first }
      .sorted { $0.platform.rawValue < $1.platform.rawValue }
    HStack(spacing: 5) {
      ForEach(hosts, id: \.hostId) { host in
        Button {
          store.selectHost(host)
        } label: {
          Text(host.platform.shortLabel)
            .font(.caption2.weight(.black))
            .frame(width: 29, height: 29)
            .background(
              store.selectedHost?.hostId == host.hostId ? CodexTheme.control : CodexTheme.key,
              in: Circle())
            .foregroundStyle(store.selectedHost?.hostId == host.hostId ? .white : CodexTheme.ink)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Control \(host.hostName)")
      }
    }
  }
}

private struct MicroAgentKey: View {
  @Environment(DashboardStore.self) private var store
  @Environment(\.microKeySide) private var keySide
  @State private var pressing = false
  @State private var lastLongPressAt = Date.distantPast
  let placement: MobileAgentPlacement
  let showAgent: (AgentReference) -> Void

  private var agent: RoutedAgent? { placement.agent }
  private var reference: AgentReference? { placement.reference }
  private var hostState: NodeConnectionState {
    agent.map { store.connectionState(for: $0.host.hostId) } ?? .offline
  }
  private var hostConnected: Bool { hostState == .ready || hostState == .degraded }

  var body: some View {
    ZStack {
      if let agent {
        VStack(spacing: 2) {
          HStack(spacing: 3) {
            if let context = agent.contextUsedPercent, store.showContextRings {
              ContextUsageIndicator(
                percent: context, status: hostConnected ? agent.status : "offline",
                diameter: max(11, keySide * 0.14))
            } else {
              Circle().fill(
                hostConnected ? CodexTheme.statusColor(agent.status) : CodexTheme.secondary)
                .frame(width: max(5, keySide * 0.07), height: max(5, keySide * 0.07))
            }
            Spacer(minLength: 0)
            Text(agent.originPlatform.shortLabel)
              .font(.system(size: max(6.5, keySide * 0.09), weight: .black))
              .foregroundStyle(hostConnected ? CodexTheme.ink : CodexTheme.red)
          }
          Spacer(minLength: 0)
          Text(agent.title)
            .font(.system(size: max(7.1, keySide * 0.1), weight: .semibold))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .foregroundStyle(
              hostConnected
                ? CodexTheme.ink.opacity(agent.selected ? 0.92 : 0.68)
                : CodexTheme.secondary)
          Spacer(minLength: 0)
        }
      } else {
        Image(systemName: "plus")
          .font(.system(size: max(16, keySide * 0.22), weight: .semibold))
          .foregroundStyle(CodexTheme.secondary.opacity(0.42))
          .accessibilityHidden(true)
      }
    }
    .padding(max(7, keySide * 0.1))
    .modifier(
      DeviceKeySurface(
        selected: agent?.selected == true, status: agent?.status, agentKey: true,
        pressed: pressing))
    .overlay {
      if pressing, let agent {
        RoundedRectangle(cornerRadius: keySide * 0.19, style: .continuous)
          .stroke(CodexTheme.statusColor(agent.status), lineWidth: 2.2)
          .shadow(color: CodexTheme.statusColor(agent.status).opacity(0.65), radius: 8)
          .padding(1)
      }
    }
    .scaleEffect(pressing ? 1.035 : 1)
    .opacity(agent != nil && !hostConnected ? 0.62 : 1)
    .animation(.smooth(duration: 0.18), value: pressing)
    .contentShape(RoundedRectangle(cornerRadius: keySide * 0.19, style: .continuous))
    .onTapGesture {
      guard let agent, hostConnected, Date().timeIntervalSince(lastLongPressAt) > 0.35 else {
        return
      }
      Task { await store.activate(agent) }
    }
    .onLongPressGesture(
      minimumDuration: 0.48, maximumDistance: 20,
      pressing: { value in pressing = value }
    ) {
      guard let reference else { return }
      lastLongPressAt = .now
      showAgent(reference)
    }
    .allowsHitTesting(reference != nil)
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint("Tap to open this task. Touch and hold for task details.")
    .accessibilityAction(named: "Show task details") {
      if let reference { showAgent(reference) }
    }
  }

  private var accessibilityLabel: String {
    guard let agent else {
      return "Empty agent slot \(placement.position + 1)"
    }
    guard store.showContextRings, let context = agent.contextUsedPercent else {
      return "Agent \(placement.position + 1), \(agent.title)"
    }
    return "Agent \(placement.position + 1), \(agent.title), context usage \(Int(context.rounded())) percent"
  }
}

private struct ContextUsageIndicator: View {
  let percent: Double
  let status: String
  var diameter: CGFloat = 11

  var body: some View {
    ZStack {
      Circle()
        .stroke(CodexTheme.ink.opacity(0.12), lineWidth: diameter * 0.155)
      Circle()
        .trim(from: 0, to: max(0, min(1, percent / 100)))
        .stroke(signalColor, style: StrokeStyle(lineWidth: diameter * 0.155, lineCap: .round))
        .rotationEffect(.degrees(-90))
      Circle()
        .fill(CodexTheme.statusColor(status))
        .frame(width: diameter * 0.27, height: diameter * 0.27)
    }
    .frame(width: diameter, height: diameter)
  }

  private var signalColor: Color {
    if percent >= 92 { return CodexTheme.red }
    if percent >= 80 { return CodexTheme.orange }
    return CodexTheme.ink.opacity(0.62)
  }
}

private struct ConfigurableDeviceKey: View {
  @Environment(DashboardStore.self) private var store
  @Environment(\.microKeySide) private var keySide
  let slot: DeviceKeySlot
  let editKey: (DeviceKeySlot) -> Void

  var body: some View {
    let keycap = store.keycapDefinition(for: slot)
    let isMic = keycap.id == "MIC"
    let listening = isMic && store.micListening
    Button {} label: {
      Image(systemName: listening ? "waveform" : keycap.symbol)
        .font(.system(size: max(21, keySide * 0.3), weight: .medium))
        .foregroundStyle(listening ? CodexTheme.red : CodexTheme.ink)
        .symbolEffect(.variableColor.iterative.reversing, isActive: listening)
        .contentTransition(.symbolEffect(.replace))
    }
    .buttonStyle(DeviceKeyStyle())
    .overlay {
      if listening {
        ListeningRing()
      }
    }
    .simultaneousGesture(micGesture(isMic: isMic))
    .accessibilityLabel(listening ? "Stop dictation" : keycap.name)
    .accessibilityHint(
      isMic
        ? "Tap to start dictation on the computer, tap again to stop. Touch and hold to dictate on this iPad."
        : "Tap to run. Touch and hold to replace this key.")
    .accessibilityAction { Task { await store.pressDeviceKey(slot) } }
  }

  /// Mic key: tap toggles the Mac-side dictation, long press opens the local
  /// compose sheet (iPad dictation starts immediately). Its old long-press
  /// keycap picker fought with the toggle, so replacing the mic key now goes
  /// through the All Keys panel instead. Other keys keep hold-to-replace.
  private func micGesture(isMic: Bool) -> AnyGesture<Void> {
    if isMic {
      return AnyGesture(
        LongPressGesture(minimumDuration: 0.4)
          .exclusively(before: TapGesture())
          .onEnded { result in
            switch result {
            case .first:
              store.showingCompose = true
            case .second:
              Task { await store.pressDeviceKey(slot) }
            }
          }
          .map { _ in () })
    }
    return AnyGesture(
      LongPressGesture(minimumDuration: 0.45)
        .exclusively(before: TapGesture())
        .onEnded { result in
          switch result {
          case .first:
            editKey(slot)
          case .second:
            Task { await store.pressDeviceKey(slot) }
          }
        }
        .map { _ in () })
  }
}

/// Breathing red border shown while the Mac is dictating — the key stays lit
/// until the second tap stops the recording.
private struct ListeningRing: View {
  @Environment(\.microKeySide) private var keySide
  @State private var breath = false

  var body: some View {
    RoundedRectangle(cornerRadius: keySide * 0.19, style: .continuous)
      .strokeBorder(CodexTheme.red.opacity(breath ? 0.95 : 0.35), lineWidth: 2.6)
      .shadow(color: CodexTheme.red.opacity(breath ? 0.75 : 0.2), radius: breath ? 11 : 4)
      .onAppear {
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
          breath = true
        }
      }
  }
}

private struct DeviceKeyStyle: ButtonStyle {
  var selected = false
  var status: String?
  var agentKey = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .modifier(
        DeviceKeySurface(
          selected: selected, status: status, agentKey: agentKey,
          pressed: configuration.isPressed))
  }
}

private struct DeviceKeySurface: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.microKeySide) private var keySide
  var selected = false
  var status: String?
  var agentKey = false
  var pressed = false

  /// How far the top face sinks when the key is pressed.
  private var travel: CGFloat { max(4, keySide * 0.045) }
  private var faceRadius: CGFloat { keySide * 0.17 }
  private var baseRadius: CGFloat { keySide * 0.19 }

  func body(content: Content) -> some View {
    content
      .foregroundStyle(CodexTheme.ink)
      .frame(maxWidth: .infinity)
      .frame(height: keySide - travel)
      .background(agentKey ? AnyView(frostedFace) : AnyView(solidFace))
      .offset(y: pressed ? travel - 1 : 0)
      .frame(height: keySide, alignment: .top)
      .background(baseWall)
      .compositingGroup()
      .shadow(
        color: hasStatusLight
          ? statusTint.opacity(0.7)
          : selected
            ? CodexTheme.selection.opacity(0.3)
            : .black.opacity(pressed ? 0.1 : 0.22),
        radius: hasStatusLight ? 14 : pressed ? 2 : 5,
        y: pressed ? 1 : 4)
      .animation(.snappy(duration: 0.14), value: pressed)
  }

  /// Agent keycap: frosted translucent glass with the RGB switch glowing
  /// through from underneath, like the hardware's clear caps.
  private var frostedFace: some View {
    RoundedRectangle(cornerRadius: faceRadius, style: .continuous)
      .fill(.ultraThinMaterial)
      .overlay {
        // The switch body + LED seen through the frosted cap. Idle stays a
        // faint hardware-purple ember; a live status floods the whole cap.
        Circle()
          .fill(hasStatusLight ? statusTint : Color(red: 0.48, green: 0.42, blue: 0.95))
          .frame(
            width: keySide * (hasStatusLight ? 0.34 : 0.18),
            height: keySide * (hasStatusLight ? 0.34 : 0.18))
          .blur(radius: keySide * (hasStatusLight ? 0.12 : 0.07))
          .opacity(hasStatusLight ? 1 : 0.3)
      }
      .overlay {
        if hasStatusLight {
          RoundedRectangle(cornerRadius: faceRadius, style: .continuous)
            .fill(statusTint.opacity(pressed ? 0.12 : 0.18))
        }
      }
      .overlay {
        RoundedRectangle(cornerRadius: faceRadius, style: .continuous)
          .fill(
            LinearGradient(
              colors: colorScheme == .dark
                ? [.white.opacity(0.10), .white.opacity(0.02)]
                : [.white.opacity(0.55), .white.opacity(0.18)],
              startPoint: .top,
              endPoint: .bottom))
      }
      .overlay {
        RoundedRectangle(cornerRadius: faceRadius, style: .continuous)
          .strokeBorder(
            .white.opacity(colorScheme == .dark ? 0.22 : 0.85),
            lineWidth: 1.2)
      }
      .overlay {
        if hasStatusLight {
          RoundedRectangle(cornerRadius: faceRadius, style: .continuous)
            .strokeBorder(statusTint.opacity(0.9), lineWidth: 1.8)
        } else if selected {
          RoundedRectangle(cornerRadius: faceRadius, style: .continuous)
            .strokeBorder(CodexTheme.selection.opacity(0.9), lineWidth: 1.8)
        }
      }
      .padding(.horizontal, 2.5)
  }

  /// Opaque command keycap: top-lit plastic like the hardware's white keys.
  private var solidFace: some View {
    RoundedRectangle(cornerRadius: faceRadius, style: .continuous)
      .fill(
        LinearGradient(
          colors: colorScheme == .dark
            ? [Color(red: 0.27, green: 0.30, blue: 0.34), Color(red: 0.17, green: 0.19, blue: 0.22)]
            : [Color(white: 0.995), Color(red: 0.90, green: 0.905, blue: 0.90)],
          startPoint: .top,
          endPoint: .bottom))
      .overlay {
        RoundedRectangle(cornerRadius: faceRadius, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: colorScheme == .dark
                ? [.white.opacity(0.26), .white.opacity(0.05)]
                : [.white, .black.opacity(0.07)],
              startPoint: .top,
              endPoint: .bottom),
            lineWidth: 1.2)
      }
      .overlay {
        if selected {
          RoundedRectangle(cornerRadius: faceRadius, style: .continuous)
            .strokeBorder(CodexTheme.selection.opacity(0.85), lineWidth: 1.6)
        }
      }
      .padding(.horizontal, 2.5)
  }

  /// Keycap side wall: the darker skirt that stays put while the face travels.
  private var baseWall: some View {
    RoundedRectangle(cornerRadius: baseRadius, style: .continuous)
      .fill(
        LinearGradient(
          colors: colorScheme == .dark
            ? [Color(red: 0.10, green: 0.11, blue: 0.13), Color(red: 0.05, green: 0.055, blue: 0.07)]
            : [Color(red: 0.74, green: 0.75, blue: 0.755), Color(red: 0.62, green: 0.635, blue: 0.645)],
          startPoint: .top,
          endPoint: .bottom))
      .overlay {
        if isWorking {
          // A comet of light chasing clockwise around the key edge — the
          // "this agent is busy" animation.
          WorkingLightRing(cornerRadius: baseRadius, tint: statusTint)
        } else if hasStatusLight {
          // RGB under-glow leaking out from beneath the keycap, like the
          // hardware's per-key light ring.
          RoundedRectangle(cornerRadius: baseRadius, style: .continuous)
            .stroke(statusTint, lineWidth: 3.5)
            .blur(radius: 4)
        }
      }
  }

  private var hasStatusLight: Bool {
    agentKey && !["idle", "off", "empty"].contains(status ?? "idle")
  }

  private var isWorking: Bool {
    agentKey && ["working", "thinking"].contains(status ?? "")
  }

  private var statusTint: Color { CodexTheme.statusColor(status ?? "idle") }
}

/// Clockwise LED chase around a keycap border: a static ring of dim tint with
/// a bright comet segment orbiting it, driven by a rotating angular gradient
/// behind a fixed border mask so the corners never distort.
private struct WorkingLightRing: View {
  let cornerRadius: CGFloat
  let tint: Color
  @State private var angle: Double = 0

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .stroke(tint.opacity(0.35), lineWidth: 3)
      AngularGradient(
        gradient: Gradient(stops: [
          .init(color: .clear, location: 0),
          .init(color: .clear, location: 0.62),
          .init(color: tint.opacity(0.85), location: 0.86),
          .init(color: .white.opacity(0.95), location: 0.97),
          .init(color: .clear, location: 1),
        ]),
        center: .center)
        .scaleEffect(1.7)
        .rotationEffect(.degrees(angle))
        .mask(
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(lineWidth: 4.5))
    }
    .blur(radius: 2.2)
    .onAppear {
      withAnimation(.linear(duration: 1.7).repeatForever(autoreverses: false)) {
        angle = 360
      }
    }
  }
}

private struct ReasoningDial: View {
  @Environment(DashboardStore.self) private var store
  @Environment(\.microKeySide) private var keySide
  @State private var rotation: Double = -45
  @State private var lastStep = 0

  var body: some View {
    ZStack {
      Circle()
        .fill(Color.black.opacity(0.1))
        .frame(width: 65, height: 65)
        .offset(y: 3)
        .blur(radius: 1.2)

      Circle()
        .fill(
          AngularGradient(
            colors: [
              .white,
              Color(red: 0.72, green: 0.75, blue: 0.75),
              Color(red: 0.94, green: 0.95, blue: 0.94),
              Color(red: 0.61, green: 0.65, blue: 0.65),
              .white,
            ], center: .center, angle: .degrees(-35)))
        .frame(width: 64, height: 64)
        .overlay {
          Circle().stroke(.white.opacity(0.82), lineWidth: 1.5).padding(1)
          Circle().stroke(Color.black.opacity(0.09), lineWidth: 1).padding(4)
        }
        .shadow(color: .black.opacity(0.2), radius: 4, y: 3)

      Circle()
        .fill(.white.opacity(0.16))
        .frame(width: 43, height: 23)
        .blur(radius: 5)
        .offset(x: -7, y: -13)

      ZStack {
        Capsule()
          .fill(Color.black.opacity(0.22))
          .frame(width: 11, height: 43)
          .offset(x: 1.5, y: -2)
        Capsule()
          .fill(
            LinearGradient(
              colors: [Color(red: 0.39, green: 0.43, blue: 0.44), Color(red: 0.23, green: 0.26, blue: 0.27)],
              startPoint: .leading,
              endPoint: .trailing))
          .frame(width: 9, height: 41)
          .offset(y: -4)
          .overlay(alignment: .leading) {
            Capsule().fill(.white.opacity(0.2)).frame(width: 2, height: 34).offset(x: 2, y: -4)
          }
      }
      .rotationEffect(.degrees(rotation))
    }
    .scaleEffect(keySide / 66)
    .frame(maxWidth: .infinity, minHeight: keySide, maxHeight: keySide)
    .contentShape(Rectangle())
    .onTapGesture { Task { await store.pressEncoder() } }
    .gesture(
      DragGesture(minimumDistance: 10)
        .onChanged { value in
          let step = Int(value.translation.width / 24)
          guard step != lastStep else { return }
          let direction = step > lastStep ? "increase" : "decrease"
          lastStep = step
          rotation += direction == "increase" ? 24 : -24
          Task { await store.trigger(.reasoning(direction: direction)) }
        }
        .onEnded { _ in lastStep = 0 })
    .accessibilityLabel("Reasoning dial")
    .accessibilityHint("Drag to change reasoning, tap to press the encoder")
  }
}

private struct JoystickControl: View {
  @Environment(DashboardStore.self) private var store
  @Environment(\.microKeySide) private var keySide
  @GestureState private var translation: CGSize = .zero

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: keySide * 0.19, style: .continuous)
        .fill(
          LinearGradient(
            colors: [Color(red: 0.16, green: 0.18, blue: 0.19), .black.opacity(0.96)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing))
        .overlay {
          RoundedRectangle(cornerRadius: keySide * 0.19, style: .continuous)
            .stroke(style: StrokeStyle(lineWidth: 1.35, dash: [4, 3]))
            .foregroundStyle(CodexTheme.ink.opacity(0.72))
        }
        .overlay {
          RoundedRectangle(cornerRadius: keySide * 0.15, style: .continuous)
            .stroke(.white.opacity(0.09), lineWidth: 1)
            .padding(4)
        }

      ForEach(JoystickDirection.allCases) { direction in
        Image(systemName: direction.symbol)
          .font(.system(size: keySide * 0.085, weight: .black))
          .foregroundStyle(.white.opacity(0.28))
          .offset(direction.offset(keySide * 0.37))
      }

      Circle()
        .fill(
          RadialGradient(
            colors: [Color(red: 0.30, green: 0.32, blue: 0.33), Color(red: 0.055, green: 0.06, blue: 0.065)],
            center: UnitPoint(x: 0.34, y: 0.26),
            startRadius: 1,
            endRadius: keySide * 0.46))
        .frame(width: keySide * 0.64, height: keySide * 0.64)
        .offset(limitedOffset)
        .overlay {
          Circle().stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
          Capsule()
            .fill(.white.opacity(0.22))
            .frame(width: keySide * 0.18, height: 2)
            .rotationEffect(.degrees(-42))
            .offset(x: keySide * 0.14, y: keySide * 0.15)
        }
        .shadow(color: .black.opacity(0.48), radius: 5, y: 3)
    }
    .frame(maxWidth: .infinity, minHeight: keySide, maxHeight: keySide)
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 7)
        .updating($translation) { value, state, _ in state = value.translation }
        .onEnded { value in
          guard let direction = direction(for: value.translation) else { return }
          Task { await store.pressJoystick(direction) }
        })
    .accessibilityLabel("Codex Micro joystick")
    .accessibilityHint("Drag up, down, left, or right")
  }

  private var limitedOffset: CGSize {
    let length = max(hypot(translation.width, translation.height), 1)
    let scale = min(10 / length, 1)
    return CGSize(width: translation.width * scale, height: translation.height * scale)
  }

  private func direction(for value: CGSize) -> String? {
    guard max(abs(value.width), abs(value.height)) >= 7 else { return nil }
    if abs(value.width) > abs(value.height) { return value.width > 0 ? "right" : "left" }
    return value.height > 0 ? "down" : "up"
  }
}

private enum JoystickDirection: CaseIterable, Identifiable {
  case up, right, down, left
  var id: Self { self }
  var symbol: String {
    switch self {
    case .up: "chevron.up"
    case .right: "chevron.right"
    case .down: "chevron.down"
    case .left: "chevron.left"
    }
  }
  func offset(_ distance: CGFloat) -> CGSize {
    switch self {
    case .up: CGSize(width: 0, height: -distance)
    case .right: CGSize(width: distance, height: 0)
    case .down: CGSize(width: 0, height: distance)
    case .left: CGSize(width: -distance, height: 0)
    }
  }
}

private struct SignalCluster: View {
  @Environment(\.microKeySide) private var keySide
  let agents: [RoutedAgent]
  let connectedCount: Int
  let expectedCount: Int

  var body: some View {
    HStack(spacing: 5) {
      VStack(spacing: 3) {
        Capsule().fill(connectionColor).frame(width: 12, height: 4)
        Capsule().fill(attentionColor).frame(width: 12, height: 4)
        Capsule().fill(activityColor).frame(width: 12, height: 4)
      }
      ZStack {
        Circle()
          .fill(
            RadialGradient(
              colors: [stateColor.opacity(0.9), CodexTheme.control],
              center: .topLeading,
              startRadius: 0,
              endRadius: 29))
        Circle().stroke(.white.opacity(0.3), lineWidth: 1).padding(2)
        Text(connectedCount > 0 ? "\(connectedCount)" : "–")
          .font(.system(size: 11, weight: .black, design: .rounded))
          .foregroundStyle(.white.opacity(0.9))
          .monospacedDigit()
      }
      .frame(width: 37, height: 37)
      .shadow(color: stateColor.opacity(connectedCount > 0 ? 0.42 : 0.12), radius: 6, y: 2)
    }
    .scaleEffect(keySide / 66)
    .frame(maxWidth: .infinity, minHeight: keySide, maxHeight: keySide)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Codex status lens")
    .accessibilityValue("\(connectedCount) of \(expectedCount) computers connected, \(stateTitle)")
  }

  private var statuses: [String] { agents.map(\.status) }
  private var hasAttention: Bool {
    statuses.contains { ["approval", "awaiting-approval", "awaiting-response", "error", "unread"].contains($0) }
  }
  private var hasActivity: Bool {
    statuses.contains { ["working", "thinking"].contains($0) }
  }
  private var stateColor: Color {
    if statuses.contains("error") { return CodexTheme.red }
    if hasAttention { return CodexTheme.orange }
    if hasActivity { return CodexTheme.blue }
    if connectedCount > 0 { return CodexTheme.green }
    return CodexTheme.secondary
  }
  private var stateTitle: String {
    if statuses.contains("error") { return "error" }
    if hasAttention { return "attention required" }
    if hasActivity { return "agent working" }
    return connectedCount > 0 ? "ready" : "offline"
  }
  private var connectionColor: Color {
    connectedCount == expectedCount && connectedCount > 0
      ? CodexTheme.green : connectedCount > 0 ? CodexTheme.orange : CodexTheme.secondary.opacity(0.25)
  }
  private var attentionColor: Color {
    hasAttention ? CodexTheme.orange : CodexTheme.secondary.opacity(0.18)
  }
  private var activityColor: Color {
    hasActivity ? CodexTheme.blue : CodexTheme.secondary.opacity(0.18)
  }
}

private struct DeviceScrews: View {
  var body: some View {
    VStack {
      HStack { Screw(); Spacer(); Screw() }
      Spacer()
      HStack { Screw(); Spacer(); Screw() }
    }
    .padding(10)
  }
}

private struct Screw: View {
  @Environment(\.verticalSizeClass) private var verticalSizeClass

  var body: some View {
    Image(systemName: "hexagon.fill")
      .font(.system(size: verticalSizeClass == .compact ? 10 : 15, weight: .black))
      .foregroundStyle(Color(red: 0.16, green: 0.17, blue: 0.17))
      .overlay {
        Circle().fill(.black.opacity(0.82))
          .frame(
            width: verticalSizeClass == .compact ? 4.5 : 7,
            height: verticalSizeClass == .compact ? 4.5 : 7)
      }
      .shadow(color: .white.opacity(0.9), radius: 0, y: 1)
  }
}

struct AllKeysView: View {
  @Environment(DashboardStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var archiveConfirmation = false
  private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          HStack {
            Text("Commands target")
              .font(.caption)
              .foregroundStyle(CodexTheme.secondary)
            Spacer()
            DeviceHostPicker()
          }
          LazyVGrid(columns: columns, spacing: 12) {
            ForEach(KeycapCatalog.all) { keycap in
              Button {
                if keycap.id == "DEL" {
                  archiveConfirmation = true
                } else {
                  Task { await store.trigger(.keycap(id: keycap.id)) }
                }
              } label: {
                VStack(spacing: 9) {
                  Image(systemName: keycap.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(height: 27)
                  Text(keycap.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .top)
                  Text(keycap.id)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CodexTheme.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(CodexTheme.panel.opacity(0.75), in: Capsule())
                }
                .padding(13)
                .frame(maxWidth: .infinity, minHeight: 112)
              }
              .buttonStyle(LibraryKeyStyle())
              .accessibilityHint("Send to \(store.selectedHost?.hostName ?? "selected computer")")
            }
          }
        }
        .padding(18)
      }
      .background(CodexTheme.canvas)
      .navigationTitle("All Codex keys")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
      .confirmationDialog(
        "Archive the selected chat?", isPresented: $archiveConfirmation,
        titleVisibility: .visible
      ) {
        Button("Archive chat", role: .destructive) {
          Task { await store.trigger(.keycap(id: "DEL")) }
        }
      }
    }
  }
}

struct KeycapPickerView: View {
  @Environment(DashboardStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let slot: DeviceKeySlot
  private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          VStack(spacing: 5) {
            Text("Choose what this physical key does")
              .font(.headline)
            Text("Tap still runs the key. Touch and hold it again whenever you want to swap it.")
              .font(.caption)
              .foregroundStyle(CodexTheme.secondary)
              .multilineTextAlignment(.center)
          }
          .padding(.horizontal, 16)

          LazyVGrid(columns: columns, spacing: 12) {
            ForEach(KeycapCatalog.all) { keycap in
              Button {
                store.assignKeycap(keycap.id, to: slot)
                dismiss()
              } label: {
                ZStack(alignment: .topTrailing) {
                  KeycapPickerLabel(keycap: keycap)
                  if store.keycapID(for: slot) == keycap.id {
                    Image(systemName: "checkmark.circle.fill")
                      .font(.system(size: 17, weight: .semibold))
                      .foregroundStyle(CodexTheme.blue)
                      .padding(11)
                  }
                }
              }
              .buttonStyle(LibraryKeyStyle())
              .accessibilityLabel("Use (keycap.name) for (slot.displayName)")
            }
          }

          if store.isKeycapCustomized(slot) {
            Button {
              store.resetKeycap(slot)
              dismiss()
            } label: {
              Label("Reset to Codex layout", systemImage: "arrow.counterclockwise")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
            }
            .buttonStyle(.bordered)
          }
        }
        .padding(18)
      }
      .background(CodexTheme.canvas)
      .navigationTitle(slot.displayName)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      }
    }
  }
}

private struct KeycapPickerLabel: View {
  let keycap: KeycapDefinition

  var body: some View {
    VStack(spacing: 9) {
      Image(systemName: keycap.symbol)
        .font(.system(size: 22, weight: .semibold))
        .frame(height: 27)
      Text(keycap.name)
        .font(.caption.weight(.semibold))
        .lineLimit(2)
        .minimumScaleFactor(0.82)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .top)
      Text(keycap.id)
        .font(.system(size: 8, weight: .black, design: .monospaced))
        .foregroundStyle(CodexTheme.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(CodexTheme.panel.opacity(0.75), in: Capsule())
    }
    .padding(13)
    .frame(maxWidth: .infinity, minHeight: 112)
  }
}

private struct LibraryKeyStyle: ButtonStyle {
  @Environment(\.colorScheme) private var colorScheme
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(CodexTheme.ink)
      .background(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .fill(CodexTheme.key.opacity(configuration.isPressed ? 0.72 : 0.96))
          .shadow(
            color: .black.opacity(configuration.isPressed ? 0.06 : 0.11),
            radius: configuration.isPressed ? 1 : 5,
            y: configuration.isPressed ? 1 : 3))
      .overlay {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(.white.opacity(colorScheme == .dark ? 0.16 : 0.9), lineWidth: 1)
      }
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.snappy(duration: 0.14), value: configuration.isPressed)
  }
}
