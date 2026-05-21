//  VoodooTimer is owned by Kevin Herro.

import ActivityKit
import AlarmKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class VoodooTimerModel {
  enum Mode: Equatable, Sendable {
    case setup
    case running
    case paused
    case finished
  }

  enum SeekDirection: Sendable {
    case backward
    case forward
  }

  struct Adjustment: Equatable, Sendable {
    let amount: Int
    let id = UUID()

    var label: String {
      amount >= 0 ? "+\(amount)s" : "\(amount)s"
    }
  }

  var mode: Mode = .setup
  var selectedDuration: TimeInterval = 90 * 60
  var endDate: Date?
  var pausedRemaining: TimeInterval?
  var adjustment: Adjustment?
  var increaseFeedbackTrigger = 0
  var decreaseFeedbackTrigger = 0
  var pauseResumeFeedbackTrigger = 0
  var finishFeedbackTrigger = 0

  private let alarms = VoodooTimerAlarmScheduler()
  private var lastTapDate: Date?
  private var tapStreak = 0
  private var finishTask: Task<Void, Never>?
  private var alarmTask: Task<Void, Never>?

  func remaining(at date: Date = .now) -> TimeInterval {
    switch mode {
    case .setup:
      selectedDuration
    case .running:
      max(0, (endDate ?? date).timeIntervalSince(date))
    case .paused:
      max(0, pausedRemaining ?? selectedDuration)
    case .finished:
      0
    }
  }

  func displayedSeconds(at date: Date = .now) -> Int {
    max(0, Int(ceil(min(remaining(at: date), selectedDuration))))
  }

  func start(at date: Date = .now) {
    let duration = max(1, selectedDuration)
    selectedDuration = duration
    mode = .running
    clearTapCadence()
    run(for: duration, at: date)
  }

  func reset() {
    mode = .setup
    endDate = nil
    pausedRemaining = nil
    adjustment = nil
    clearTapCadence()
    cancelLocalFinish()
    cancelAlarm()
  }

  func clear() {
    reset()
    selectedDuration = 0
  }

  func addThirtySeconds(at date: Date = .now) {
    adjustTime(by: 30, at: date)
  }

  func seek(_ direction: SeekDirection, at date: Date = .now) {
    guard mode != .finished else { return }
    let amount = seekAmount(at: date)

    switch direction {
    case .backward:
      adjustTime(by: -amount, at: date)
    case .forward:
      adjustTime(by: amount, at: date)
    }
  }

  func primaryAction(at date: Date = .now) {
    switch mode {
    case .setup:
      guard selectedDuration > 0 else { return }
      start(at: date)
    case .running, .paused:
      togglePause(at: date)
    case .finished:
      reset()
    }
  }

  func togglePause(at date: Date = .now) {
    switch mode {
    case .running:
      pausedRemaining = remaining(at: date)
      endDate = nil
      mode = .paused
      pauseResumeFeedbackTrigger += 1
      clearTapCadence()
      cancelLocalFinish()
      cancelAlarm()
    case .paused:
      let duration = max(1, pausedRemaining ?? selectedDuration)
      mode = .running
      pauseResumeFeedbackTrigger += 1
      clearTapCadence()
      run(for: duration, at: date)
    case .setup, .finished:
      break
    }
  }

  func completeIfNeeded(at date: Date = .now) {
    guard mode == .running, remaining(at: date) <= 0 else { return }
    finish()
  }

  private func adjustTime(by seconds: Int, at date: Date) {
    guard mode != .finished else { return }

    let newRemaining = remaining(at: date) + TimeInterval(seconds)

    if mode == .setup {
      selectedDuration = clamp(newRemaining, min: 0, max: 99 * 60)
      showAdjustment(seconds)
      return
    }

    if newRemaining <= 0 {
      decreaseFeedbackTrigger += 1
      finish()
      return
    }

    selectedDuration = newRemaining

    switch mode {
    case .running:
      run(for: newRemaining, at: date)
    case .paused:
      endDate = nil
      pausedRemaining = newRemaining
      cancelLocalFinish()
      cancelAlarm()
    case .setup, .finished:
      break
    }

    showAdjustment(seconds)
  }

  private func run(for duration: TimeInterval, at date: Date) {
    endDate = date.addingTimeInterval(duration)
    pausedRemaining = nil
    scheduleLocalFinish(after: duration)
    scheduleAlarm(at: date.addingTimeInterval(duration))
  }

  private func finish() {
    mode = .finished
    endDate = nil
    pausedRemaining = nil
    adjustment = nil
    clearTapCadence()
    cancelLocalFinish()
    finishFeedbackTrigger += 1
  }

  private func showAdjustment(_ seconds: Int) {
    adjustment = Adjustment(amount: seconds)
    dismissAdjustment(after: adjustment?.id)

    if seconds >= 0 {
      increaseFeedbackTrigger += 1
    } else {
      decreaseFeedbackTrigger += 1
    }
  }

  private func scheduleLocalFinish(after interval: TimeInterval) {
    cancelLocalFinish()

    finishTask = Task { @MainActor [weak self] in
      do {
        try await Task.sleep(for: .milliseconds(Int(max(0, interval) * 1_000)))
      } catch {
        return
      }

      self?.completeIfNeeded()
    }
  }

  private func cancelLocalFinish() {
    finishTask?.cancel()
    finishTask = nil
  }

  private func scheduleAlarm(at date: Date) {
    alarmTask?.cancel()
    alarms.cancelVoodooTimerFinished()

    alarmTask = Task { [alarms] in
      await alarms.scheduleVoodooTimerFinished(at: date)
    }
  }

  private func cancelAlarm() {
    alarmTask?.cancel()
    alarmTask = nil
    alarms.cancelVoodooTimerFinished()
  }

  private func seekAmount(at date: Date) -> Int {
    if let lastTapDate, date.timeIntervalSince(lastTapDate) <= 0.55 {
      tapStreak += 1
    } else {
      tapStreak = 1
    }

    lastTapDate = date
    return min(tapStreak, 6) * 10
  }

  private func clearTapCadence() {
    lastTapDate = nil
    tapStreak = 0
  }

  private func dismissAdjustment(after id: UUID?) {
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(700))
      guard self?.adjustment?.id == id else { return }
      self?.adjustment = nil
    }
  }

  private func clamp(
    _ value: TimeInterval, min minValue: TimeInterval,
    max maxValue: TimeInterval
  ) -> TimeInterval {
    min(max(value, minValue), maxValue)
  }
}

struct VoodooTimerAlarmMetadata: AlarmMetadata {}

struct VoodooTimerAlarmScheduler: Sendable {
  private let identifier = UUID(
    uuidString: "64C91961-9608-4E15-903E-8544D746C086")!

  func scheduleVoodooTimerFinished(at date: Date) async {
    let manager = AlarmManager.shared
    let state: AlarmManager.AuthorizationState

    if manager.authorizationState == .notDetermined {
      state = (try? await manager.requestAuthorization()) ?? .denied
    } else {
      state = manager.authorizationState
    }

    guard state == .authorized, !Task.isCancelled else { return }

    try? manager.cancel(id: identifier)

    let presentation = AlarmPresentation(
      alert: .init(title: "VoodooTimer"))
    let attributes = AlarmAttributes<VoodooTimerAlarmMetadata>(
      presentation: presentation, tintColor: .black)
    let configuration = AlarmManager.AlarmConfiguration.alarm(
      schedule: .fixed(max(date, .now.addingTimeInterval(1))),
      attributes: attributes,
      sound: .default)

    guard !Task.isCancelled else { return }
    _ = try? await manager.schedule(
      id: identifier, configuration: configuration)
  }

  func cancelVoodooTimerFinished() {
    let manager = AlarmManager.shared
    try? manager.stop(id: identifier)
    try? manager.cancel(id: identifier)
  }
}
