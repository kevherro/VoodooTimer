//  VoodooTimer is owned by Kevin Herro.

import MediaPlayer
import Observation
import UIKit

@Observable
final class MusicPlaybackModel {
  private enum PlaybackCommand: Sendable {
    case togglePlayback
    case previousItem
    case nextItem
  }

  var authorizationStatus = MPMediaLibrary.authorizationStatus()
  var playbackState: MPMusicPlaybackState = .stopped
  var title = "Apple Music"
  var subtitle = "Not Playing"
  var artwork: UIImage?

  private let player = MPMusicPlayerController.systemMusicPlayer
  private var observers: [NSObjectProtocol] = []

  var isPlaying: Bool {
    playbackState == .playing
  }

  init() {
    refresh()
    player.beginGeneratingPlaybackNotifications()

    observers = [
      NotificationCenter.default.addObserver(
        forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in
          self?.refresh()
        }
      },
      NotificationCenter.default.addObserver(
        forName: .MPMusicPlayerControllerPlaybackStateDidChange,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in
          self?.refresh()
        }
      },
    ]
  }

  func refreshFromForeground() {
    refresh()

    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(350))
      refresh()
    }
  }

  func refresh() {
    authorizationStatus = MPMediaLibrary.authorizationStatus()
    playbackState = player.playbackState

    guard authorizationStatus == .authorized else {
      title = "Apple Music"
      subtitle =
        authorizationStatus == .notDetermined ? "Tap Play" : "Access Off"
      artwork = nil
      return
    }

    guard let item = player.nowPlayingItem else {
      title = "Apple Music"
      subtitle = "Not Playing"
      artwork = nil
      return
    }

    title = item.title ?? "Unknown Title"
    subtitle = item.artist ?? item.albumTitle ?? "Apple Music"
    artwork = item.artwork?.image(at: CGSize(width: 96, height: 96))
  }

  func togglePlayback() {
    run(.togglePlayback)
  }

  func skipToPreviousItem() {
    run(.previousItem)
  }

  func skipToNextItem() {
    run(.nextItem)
  }

  private func run(_ command: PlaybackCommand) {
    switch authorizationStatus {
    case .authorized:
      perform(command)
    case .notDetermined:
      MPMediaLibrary.requestAuthorization { [weak self] status in
        Task { @MainActor in
          self?.authorizationStatus = status
          guard status == .authorized else {
            self?.refresh()
            return
          }

          self?.perform(command)
        }
      }
    case .denied, .restricted:
      refresh()
    @unknown default:
      refresh()
    }
  }

  private func perform(_ command: PlaybackCommand) {
    switch command {
    case .togglePlayback:
      if isPlaying {
        player.pause()
      } else {
        player.play()
      }

      refresh()
    case .previousItem:
      player.skipToPreviousItem()
      refreshAfterPlayerUpdate()
    case .nextItem:
      player.skipToNextItem()
      refreshAfterPlayerUpdate()
    }
  }

  private func refreshAfterPlayerUpdate() {
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(250))
      refresh()
    }
  }
}
