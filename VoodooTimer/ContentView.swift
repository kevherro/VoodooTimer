//  VoodooTimer is owned by Kevin Herro.

import SwiftUI
import UIKit

struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase

  @State private var timer = VoodooTimerModel()
  @State private var music = MusicPlaybackModel()
  @State private var durationInputText = ""
  @FocusState private var durationInputIsFocused: Bool

  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.2)) { context in
      GeometryReader { proxy in
        let isLandscape = proxy.size.width > proxy.size.height
        let readoutFontSize: CGFloat = isLandscape ? 152 : 76
        let timerHeight = readoutFontSize * 1.74
        let musicHeight: CGFloat = isLandscape ? 64 : 62
        let musicSpacing: CGFloat = isLandscape ? 24 : 18
        let showsMusic = music.isPlaying
        let visibleMusicHeight: CGFloat = showsMusic ? musicHeight : 0
        let visibleMusicSpacing: CGFloat = showsMusic ? musicSpacing : 0
        let groupHeight =
          timerHeight + visibleMusicSpacing + visibleMusicHeight
        let portraitLift = isLandscape ? 0 : min(120, proxy.size.height * 0.075)
        let centeredGroupY =
          proxy.size.height / 2
          + (visibleMusicHeight + visibleMusicSpacing) / 2
          - portraitLift
        let lowestGroupY = proxy.size.height - 18 - groupHeight / 2
        let groupY = min(centeredGroupY, max(groupHeight / 2, lowestGroupY))
        let durationEntryButtonX = min(
          proxy.size.width - (isLandscape ? 54 : 42),
          proxy.size.width / 2 + readoutFontSize * 2
        )
        let durationEntryButtonY =
          groupY + readoutFontSize * (isLandscape ? 0.54 : 0.62)

        ZStack {
          Theme.background
            .ignoresSafeArea()

          durationKeyboardInput
            .position(x: 1, y: 1)

          VStack(spacing: musicSpacing) {
            VoodooTimerFace(
              timer: timer, now: context.date, readoutFontSize: readoutFontSize
            )
            .frame(height: timerHeight)

            if showsMusic {
              Color.clear
                .frame(height: musicHeight)
            }
          }
          .padding(.horizontal, 28)
          .position(x: proxy.size.width / 2, y: groupY)

          InteractionLayer(size: proxy.size, timer: timer)
            .ignoresSafeArea()

          if timer.mode == .setup {
            DurationEntryButton(
              isActive: durationInputIsFocused,
              action: beginDurationEntry
            )
            .position(x: durationEntryButtonX, y: durationEntryButtonY)
          }

          if showsMusic {
            VStack(spacing: musicSpacing) {
              Color.clear
                .frame(height: timerHeight)
                .allowsHitTesting(false)

              MusicPlaybackControls(
                music: music, isLandscape: isLandscape, height: musicHeight)
            }
            .padding(.horizontal, 28)
            .position(x: proxy.size.width / 2, y: groupY)
            .transition(.opacity)
          }
        }
      }
      .onChange(of: context.date) { _, date in
        timer.completeIfNeeded(at: date)
      }
    }
    .sensoryFeedback(
      .impact(weight: .light, intensity: 1.0),
      trigger: timer.increaseFeedbackTrigger
    )
    .sensoryFeedback(
      .impact(weight: .light, intensity: 1.0),
      trigger: timer.decreaseFeedbackTrigger
    )
    .sensoryFeedback(
      .impact(weight: .medium, intensity: 1.0),
      trigger: timer.pauseResumeFeedbackTrigger
    )
    .sensoryFeedback(.success, trigger: timer.finishFeedbackTrigger)
    .onAppear {
      music.refresh()
      updateIdleTimer()
    }
    .onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
    }
    .onChange(of: timer.mode) {
      if timer.mode != .setup {
        finishDurationEntry()
      }

      updateIdleTimer()
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        music.refreshFromForeground()
      }

      updateIdleTimer()
    }
    .animation(.easeInOut(duration: 0.18), value: music.isPlaying)
    .toolbar {
      if durationInputIsFocused {
        ToolbarItemGroup(placement: .keyboard) {
          Button("Clear", action: clearDurationEntry)

          Spacer()

          Button("Done", action: finishDurationEntry)

          Button("Start", action: startDurationEntry)
            .disabled(timer.selectedDuration <= 0)
        }
      }
    }
  }

  private var durationKeyboardInput: some View {
    TextField("Duration", text: $durationInputText)
      .keyboardType(.numberPad)
      .textInputAutocapitalization(.never)
      .disableAutocorrection(true)
      .focused($durationInputIsFocused)
      .frame(width: 1, height: 1)
      .opacity(0.01)
      .accessibilityHidden(true)
      .onChange(of: durationInputText) { _, newValue in
        updateDurationInput(to: newValue)
      }
  }

  private func beginDurationEntry() {
    guard timer.mode == .setup else { return }

    if !durationInputIsFocused {
      durationInputText = ""
    }

    durationInputIsFocused = true
  }

  private func updateDurationInput(to newValue: String) {
    guard durationInputIsFocused else { return }

    let digits =
      newValue
      .compactMap(\.wholeNumberValue)
      .prefix(2)
      .map(String.init)
      .joined()

    guard durationInputText == digits else {
      durationInputText = digits
      return
    }

    timer.setSetupDuration(minutes: Int(digits) ?? 0)
  }

  private func clearDurationEntry() {
    durationInputText = ""
    timer.setSetupDuration(minutes: 0)
  }

  private func finishDurationEntry() {
    durationInputIsFocused = false
    durationInputText = ""
  }

  private func startDurationEntry() {
    finishDurationEntry()
    timer.primaryAction()
  }

  private func updateIdleTimer() {
    UIApplication.shared.isIdleTimerDisabled =
      scenePhase == .active && timer.mode == .running
  }
}

private struct VoodooTimerFace: View {
  let timer: VoodooTimerModel
  let now: Date
  let readoutFontSize: CGFloat

  var body: some View {
    let displayedSeconds = timer.displayedSeconds(at: now)
    let finishedFlashIsOn =
      timer.mode == .finished
      && Int(now.timeIntervalSinceReferenceDate) % 2 == 0
    let readoutColor = timer.mode == .running ? Theme.ink : Theme.paper

    ZStack {
      ZStack {
        if timer.mode == .finished {
          RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(finishedFlashIsOn ? Theme.ink : .clear)
            .frame(height: readoutFontSize * 1.24)
            .transaction { transaction in
              transaction.animation = nil
            }
        }

        VoodooTimerReadout(
          displayedSeconds: displayedSeconds,
          rollDistance: readoutFontSize * 1.16
        )
        .font(AppFont.medium(readoutFontSize))
        .minimumScaleFactor(0.45)
        .lineLimit(1)
        .foregroundStyle(readoutColor)
        .padding(.horizontal, 18)
      }
      .fixedSize(horizontal: true, vertical: false)

      if let adjustment = timer.adjustment {
        Text(adjustment.label)
          .font(AppFont.semiBold(18))
          .foregroundStyle(Theme.adjustment)
          .offset(y: -readoutFontSize * 0.97)
          .transition(.opacity.combined(with: .move(edge: .top)))
          .id(adjustment.id)
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: readoutFontSize * 1.74)
  }
}

private struct VoodooTimerReadout: View {
  let displayedSeconds: Int
  let rollDistance: CGFloat

  @State private var previousGlyphs: [String]
  @State private var currentGlyphs: [String]
  @State private var rollPhase = 1.0

  init(displayedSeconds: Int, rollDistance: CGFloat) {
    let glyphs = Self.glyphs(for: displayedSeconds)
    self.displayedSeconds = displayedSeconds
    self.rollDistance = rollDistance
    _previousGlyphs = State(initialValue: glyphs)
    _currentGlyphs = State(initialValue: glyphs)
  }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(currentGlyphs.indices, id: \.self) { index in
        AnalogGlyph(
          previous: previousGlyphs[safe: index],
          current: currentGlyphs[index],
          phase: rollPhase,
          rollDistance: rollDistance
        )
      }
    }
    .onChange(of: displayedSeconds) { _, newValue in
      roll(to: Self.glyphs(for: newValue))
    }
  }

  private func roll(to glyphs: [String]) {
    var transaction = Transaction(animation: nil)
    transaction.disablesAnimations = true

    withTransaction(transaction) {
      previousGlyphs = currentGlyphs
      currentGlyphs = glyphs
      rollPhase = 0
    }

    withAnimation(.linear(duration: 0.18)) {
      rollPhase = 1
    }
  }

  private static func glyphs(for totalSeconds: Int) -> [String] {
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    let text = String(format: "%02d:%02d", minutes, seconds)

    return text.map(String.init)
  }
}

private struct MusicPlaybackControls: View {
  @State private var feedbackTrigger = 0

  let music: MusicPlaybackModel
  let isLandscape: Bool
  let height: CGFloat

  private var artworkSize: CGFloat {
    isLandscape ? 48 : 42
  }

  private var maxWidth: CGFloat {
    isLandscape ? 430 : 360
  }

  private var buttonSize: CGFloat {
    isLandscape ? 42 : 38
  }

  var body: some View {
    HStack(spacing: isLandscape ? 14 : 10) {
      artwork

      VStack(alignment: .leading, spacing: 3) {
        Text(music.title)
          .font(AppFont.semiBold(isLandscape ? 15 : 13))
          .foregroundStyle(Theme.ink)
          .lineLimit(1)
          .truncationMode(.tail)

        Text(music.subtitle)
          .font(AppFont.medium(isLandscape ? 11 : 10))
          .foregroundStyle(Theme.secondaryInk)
          .lineLimit(1)
          .truncationMode(.tail)
      }

      Spacer(minLength: 10)

      HStack(spacing: isLandscape ? 8 : 4) {
        musicButton(
          "backward.fill", "Previous", action: music.skipToPreviousItem)
        musicButton(
          music.isPlaying ? "pause.fill" : "play.fill",
          music.isPlaying ? "Pause" : "Play", action: music.togglePlayback)
        musicButton("forward.fill", "Next", action: music.skipToNextItem)
      }
    }
    .padding(.leading, isLandscape ? 10 : 8)
    .padding(.trailing, isLandscape ? 10 : 8)
    .frame(maxWidth: maxWidth)
    .frame(height: height)
    .background {
      Rectangle()
        .fill(Theme.paper)
    }
    .overlay {
      Rectangle()
        .stroke(Theme.ink.opacity(0.2), lineWidth: 1)
    }
    .onAppear {
      music.refresh()
    }
    .sensoryFeedback(
      .impact(weight: .light, intensity: 1.0),
      trigger: feedbackTrigger
    )
  }

  @ViewBuilder
  private var artwork: some View {
    if let image = music.artwork {
      Image(uiImage: image)
        .resizable()
        .scaledToFill()
        .frame(width: artworkSize, height: artworkSize)
        .clipped()
    } else {
      Rectangle()
        .fill(Theme.ink.opacity(0.08))
        .frame(width: artworkSize, height: artworkSize)
        .overlay {
          Image(systemName: "music.note")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.secondaryInk)
        }
    }
  }

  private func musicButton(
    _ systemName: String, _ label: String, action: @escaping () -> Void
  ) -> some View {
    Button {
      feedbackTrigger += 1
      action()
    } label: {
      Image(systemName: systemName)
        .font(.system(size: isLandscape ? 17 : 15, weight: .semibold))
        .foregroundStyle(Theme.ink)
        .frame(width: buttonSize, height: buttonSize)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}

private struct DurationEntryButton: View {
  let isActive: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "keyboard")
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(isActive ? Theme.paper : Theme.ink)
        .frame(width: 42, height: 36)
        .background {
          Rectangle()
            .fill(isActive ? Theme.ink : Theme.paper.opacity(0.86))
        }
        .overlay {
          Rectangle()
            .stroke(Theme.ink.opacity(isActive ? 1 : 0.2), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Enter Duration")
  }
}

private struct AnalogGlyph: View {
  let previous: String?
  let current: String
  let phase: Double
  let rollDistance: CGFloat

  var body: some View {
    if shouldRoll, let previous {
      ZStack {
        Text(previous)
          .offset(y: phase * rollDistance)

        Text(current)
          .offset(y: (phase - 1) * rollDistance)
      }
      .frame(height: rollDistance)
      .clipped()
    } else {
      Text(current)
        .frame(height: rollDistance)
    }
  }

  private var shouldRoll: Bool {
    previous != current && previous?.isSingleDigit == true
      && current.isSingleDigit
  }
}

extension Array {
  fileprivate subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

extension String {
  fileprivate var isSingleDigit: Bool {
    count == 1 && unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains)
  }
}

private struct InteractionLayer: View {
  let size: CGSize
  let timer: VoodooTimerModel

  var body: some View {
    Rectangle()
      .fill(.clear)
      .contentShape(Rectangle())
      .gesture(tapGesture)
      .simultaneousGesture(swipeGesture)
      .simultaneousGesture(resetGesture)
      .accessibilityHidden(true)
  }

  private var tapGesture: some Gesture {
    SpatialTapGesture(coordinateSpace: .local)
      .onEnded { value in
        let leftEdge = size.width / 3
        let rightEdge = size.width * 2 / 3

        if value.location.x < leftEdge {
          timer.seek(.backward)
        } else if value.location.x > rightEdge {
          timer.seek(.forward)
        } else {
          timer.primaryAction()
        }
      }
  }

  private var swipeGesture: some Gesture {
    DragGesture(minimumDistance: 24, coordinateSpace: .local)
      .onEnded { value in
        guard value.translation.height < -44, abs(value.translation.width) < 120
        else { return }
        timer.addThirtySeconds()
      }
  }

  private var resetGesture: some Gesture {
    LongPressGesture(minimumDuration: 0.75)
      .onEnded { _ in
        timer.clear()
      }
  }
}

private enum Theme {
  static let background = Color(white: 0.90)
  static let paper = Color(white: 0.98)
  static let ink = Color(white: 0.03)
  static let secondaryInk = Color(white: 0.34)
  static let adjustment = Color(white: 0.03)
}

#Preview {
  ContentView()
}
