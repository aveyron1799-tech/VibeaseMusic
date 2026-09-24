import AVFoundation
import Foundation
import Observation

enum RepeatMode: String, CaseIterable {
    case off, all, one

    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}

/// Where the current queue came from — used for scrobbling and UI affordances.
enum PlaySource: Equatable, Codable {
    case playlist(Int)
    case album(Int)
    case artist(Int)
    case daily
    case cloud
    case none

    var sourceID: Int {
        switch self {
        case .playlist(let id), .album(let id), .artist(let id): return id
        default: return 0
        }
    }
}

enum RightPanel {
    case lyrics, queue
}

/// The playback engine: queue, shuffle/repeat, personal FM, URL resolution,
/// lyrics, scrobbling. Modeled on YesPlayMusic's Player class, backed by AVPlayer.
@MainActor
@Observable
final class PlayerService {
    static let shared = PlayerService()

    // MARK: - Observable state

    private(set) var queue: [Track] = []
    private(set) var shuffledQueue: [Track] = []
    private(set) var playNextList: [Track] = []
    private(set) var currentIndex = -1
    private(set) var currentTrack: Track?
    private(set) var source: PlaySource = .none
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    private(set) var duration: TimeInterval = 0
    private(set) var servedQuality: String?
    private(set) var unblockSource: String?
    private(set) var isTrial = false
    var progress: TimeInterval = 0
    var repeatMode: RepeatMode = .off {
        didSet { UserDefaults.standard.set(repeatMode.rawValue, forKey: "player.repeat") }
    }

    private(set) var shuffleEnabled = false
    var volume: Float = 1 {
        didSet {
            engine.volume = volume
            UserDefaults.standard.set(volume, forKey: "player.volume")
        }
    }

    private(set) var isFMMode = false
    private(set) var fmUpcoming: [Track] = []
    private(set) var fmHistory: [Track] = []

    var fmPlayedTracks: [Track] {
        fmHistory.reversed().filter { $0.id != currentTrack?.id }
    }
    private(set) var lyrics: ParsedLyrics?
    var activePanel: RightPanel?
    var showNowPlaying = false

    /// The list the player is walking through (shuffled or ordered).
    var activeQueue: [Track] { shuffleEnabled ? shuffledQueue : queue }

    var upcomingTracks: [Track] {
        if isFMMode { return fmUpcoming }
        guard !activeQueue.isEmpty, currentIndex >= 0 else { return playNextList }
        let rest = activeQueue.suffix(from: min(currentIndex + 1, activeQueue.count))
        return playNextList + Array(rest.prefix(200))
    }

    var hasCurrentTrack: Bool { currentTrack != nil }

    // MARK: - Engine

    private let engine = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var itemFailureObserver: NSObjectProtocol?
    private var resolveGeneration = 0
    private var failureHandledGeneration: Int?
    private var consecutiveFailures = 0
    private var scrobbled = false
    private var resolveTask: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?
    private var fmTask: Task<Void, Never>?
    private var fmGeneration = 0
    private var fmSessionVersion: Int?
    private static let stateWriter = DispatchQueue(label: "com.vibease.music.player-state")

    private init() {
        engine.actionAtItemEnd = .pause
        volume = UserDefaults.standard.object(forKey: "player.volume") as? Float ?? 0.8
        engine.volume = volume
        repeatMode = UserDefaults.standard.string(forKey: "player.repeat")
            .flatMap(RepeatMode.init) ?? .off

        timeObserver = engine.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, !self.isScrubbing else { return }
                let seconds = time.seconds
                if seconds.isFinite, abs(seconds - self.progress) > 0.05 {
                    self.progress = seconds
                    NowPlayingManager.shared.updateElapsed(seconds, rate: self.isPlaying ? 1 : 0, force: false)
                }
            }
        }

        statusObservation = engine.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                self?.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }

        NowPlayingManager.shared.attach(to: self)
        restoreState()
    }

    /// Set while the user drags the seek bar so the time observer doesn't fight the thumb.
    var isScrubbing = false

    // MARK: - Entry points

    func play(tracks: [Track], source: PlaySource, startAt track: Track? = nil) {
        guard !tracks.isEmpty else { return }
        invalidateFMRequests()
        isFMMode = false
        queue = tracks
        self.source = source
        playNextList.removeAll()
        let startTrack = track ?? tracks[0]
        if shuffleEnabled {
            reshuffle(keeping: startTrack)
            currentIndex = 0
        } else {
            currentIndex = tracks.firstIndex(where: { $0.id == startTrack.id }) ?? 0
        }
        startPlaying(activeQueue[currentIndex])
    }

    func playTrack(_ track: Track) {
        if let idx = activeQueue.firstIndex(where: { $0.id == track.id }) {
            currentIndex = idx
            startPlaying(track)
        } else {
            play(tracks: [track], source: .none)
        }
    }

    /// Insert a track right after the current one.
    func addToPlayNext(_ track: Track, playNow: Bool = false) {
        playNextList.append(track)
        persistState()
        if playNow || currentTrack == nil {
            advanceToNext(userInitiated: true)
        } else {
            ToastCenter.shared.show(String(localized: "已添加到下一首播放"))
        }
    }

    func togglePlayPause() {
        if isFMMode, fmTask != nil {
            if isPlaying { pause() }
            else { isPlaying = true }
            return
        }
        guard let track = currentTrack else { return }
        if isPlaying {
            engine.pause()
            isPlaying = false
        } else if engine.currentItem == nil {
            // Restored session: re-resolve the source.
            startPlaying(track, indexUnchanged: true)
            return
        } else {
            engine.play()
            isPlaying = true
        }
        NowPlayingManager.shared.updateElapsed(progress, rate: isPlaying ? 1 : 0)
    }

    func pause() {
        engine.pause()
        isPlaying = false
        NowPlayingManager.shared.updateElapsed(progress, rate: 0)
    }

    func next() {
        advanceToNext(userInitiated: true)
    }

    func previous() {
        if isFMMode { return }
        if progress > 4 || activeQueue.isEmpty {
            seek(to: 0)
            return
        }
        var idx = currentIndex - 1
        if idx < 0 {
            guard repeatMode == .all else {
                seek(to: 0)
                return
            }
            idx = activeQueue.count - 1
        }
        currentIndex = idx
        startPlaying(activeQueue[idx])
    }

    func seek(to seconds: TimeInterval) {
        progress = seconds
        engine.seek(to: CMTime(seconds: seconds, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
        NowPlayingManager.shared.updateElapsed(seconds, rate: isPlaying ? 1 : 0)
    }

    func toggleShuffle() {
        guard !isFMMode else { return }
        shuffleEnabled.toggle()
        defer { persistState() }
        guard let current = currentTrack else { return }
        if shuffleEnabled {
            reshuffle(keeping: current)
            currentIndex = 0
        } else {
            currentIndex = queue.firstIndex(where: { $0.id == current.id }) ?? 0
        }
    }

    func cycleRepeatMode() {
        guard !isFMMode else { return }
        repeatMode = repeatMode.next
        persistState()
    }

    /// Jump to a track in the upcoming list (queue panel click).
    func jumpTo(_ track: Track) {
        if isFMMode {
            guard fmSessionVersion == AccountStore.shared.sessionVersion else { return }
            if let index = fmUpcoming.firstIndex(where: { $0.id == track.id }) {
                fmUpcoming.removeSubrange(0...index)
            } else if !fmHistory.contains(where: { $0.id == track.id }) {
                return
            }
            // A pending recommendation must not replace the song selected by the user.
            fmGeneration += 1
            fmTask?.cancel()
            fmTask = nil
            rememberFMTrack(track)
            startPlaying(track, indexUnchanged: true)
            return
        }
        if let nextIdx = playNextList.firstIndex(where: { $0.id == track.id }) {
            playNextList.removeSubrange(0...nextIdx)
            startPlaying(track, indexUnchanged: true)
            return
        }
        if let idx = activeQueue.firstIndex(where: { $0.id == track.id }) {
            currentIndex = idx
            startPlaying(track)
        }
    }

    func removeFromUpcoming(_ track: Track) {
        if isFMMode {
            fmUpcoming.removeAll { $0.id == track.id }
            return
        }
        if let idx = playNextList.firstIndex(where: { $0.id == track.id }) {
            playNextList.remove(at: idx)
            persistState()
            return
        }
        if let idx = queue.firstIndex(where: { $0.id == track.id }), idx != currentIndex || shuffleEnabled {
            queue.remove(at: idx)
        }
        if let idx = shuffledQueue.firstIndex(where: { $0.id == track.id }) {
            shuffledQueue.remove(at: idx)
        }
        persistState()
    }

    // MARK: - Personal FM

    private func invalidateFMRequests() {
        fmGeneration += 1
        fmTask?.cancel()
        fmTask = nil
        fmUpcoming = []
        fmHistory = []
        fmSessionVersion = nil
    }

    /// Account transitions must invalidate requests even if the next session
    /// enters FM before an old response arrives.
    func accountSessionDidChange() {
        let wasFM = isFMMode
        invalidateFMRequests()
        if wasFM {
            isFMMode = false
            pause()
            resolveGeneration += 1
            resolveTask?.cancel()
            lyricsTask?.cancel()
            removeCurrentItemObservers()
            engine.replaceCurrentItem(with: nil)
        }
    }

    func startFM() {
        guard !isFMMode else {
            if !isPlaying { togglePlayPause() }
            return
        }
        invalidateFMRequests()
        isFMMode = true
        fmSessionVersion = AccountStore.shared.sessionVersion
        // Stop the previous source while the first FM batch is loading.
        pause()
        resolveGeneration += 1
        resolveTask?.cancel()
        lyricsTask?.cancel()
        removeCurrentItemObservers()
        engine.replaceCurrentItem(with: nil)
        shuffleEnabled = false
        repeatMode = .off
        queue = []
        shuffledQueue = []
        playNextList = []
        currentIndex = -1
        source = .none
        requestFMAdvance()
    }

    func fmNext() {
        requestFMAdvance()
    }

    func fmTrash() {
        guard isFMMode, fmTask == nil, let track = currentTrack else { return }
        let session = AccountStore.shared.sessionVersion
        requestFMAdvance()
        Task {
            guard session == AccountStore.shared.sessionVersion else { return }
            try? await NeteaseAPI.fmTrash(id: track.id)
        }
    }

    private func rememberFMTrack(_ track: Track) {
        fmHistory.removeAll { $0.id == track.id }
        fmHistory.append(track)
        if fmHistory.count > 200 { fmHistory.removeFirst(fmHistory.count - 200) }
    }

    private func requestFMAdvance() {
        guard isFMMode, fmTask == nil,
              fmSessionVersion == AccountStore.shared.sessionVersion else { return }
        let generation = fmGeneration
        let session = AccountStore.shared.sessionVersion
        isPlaying = true
        fmTask = Task {
            defer {
                if generation == fmGeneration { fmTask = nil }
            }
            await fmAdvance(generation: generation, session: session)
        }
    }

    private func fmAdvance(generation: Int, session: Int) async {
        func isCurrent() -> Bool {
            !Task.isCancelled && isFMMode && generation == fmGeneration
                && session == AccountStore.shared.sessionVersion
        }
        guard isCurrent() else { return }
        if fmUpcoming.isEmpty {
            for attempt in 0..<3 {
                let tracks = try? await NeteaseAPI.personalFM()
                guard isCurrent() else { return }
                if let tracks, !tracks.isEmpty {
                    fmUpcoming = tracks
                    break
                }
                if attempt == 2 {
                    pause()
                    ToastCenter.shared.show(String(localized: "获取私人漫游数据失败"))
                    return
                }
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
                guard isCurrent() else { return }
            }
        }
        guard isCurrent(), !fmUpcoming.isEmpty else { return }
        let track = fmUpcoming.removeFirst()
        rememberFMTrack(track)
        startPlaying(track, indexUnchanged: true, autoplay: isPlaying)
    }

    // MARK: - Advancing

    private func advanceToNext(userInitiated: Bool) {
        if isFMMode {
            requestFMAdvance()
            return
        }
        if !playNextList.isEmpty {
            let track = playNextList.removeFirst()
            startPlaying(track, indexUnchanged: true)
            return
        }
        guard !activeQueue.isEmpty else { return }
        var idx = currentIndex + 1
        if idx >= activeQueue.count {
            guard repeatMode == .all else {
                if userInitiated {
                    ToastCenter.shared.show(String(localized: "已经是最后一首了"))
                } else {
                    isPlaying = false
                    NowPlayingManager.shared.updateElapsed(progress, rate: 0)
                }
                return
            }
            idx = 0
        }
        currentIndex = idx
        startPlaying(activeQueue[idx])
    }

    private func handleItemEnded() {
        scrobbleIfNeeded(completed: true)
        if repeatMode == .one, !isFMMode {
            scrobbled = false
            seek(to: 0)
            engine.play()
            isPlaying = true
            return
        }
        advanceToNext(userInitiated: false)
    }

    // MARK: - Source resolution

    private func startPlaying(_ track: Track, indexUnchanged: Bool = false, autoplay: Bool = true) {
        scrobbleIfNeeded(completed: false)
        resolveTask?.cancel()
        lyricsTask?.cancel()
        removeCurrentItemObservers()
        engine.pause()
        engine.replaceCurrentItem(with: nil)
        currentTrack = track
        progress = 0
        duration = track.duration
        servedQuality = nil
        unblockSource = nil
        isTrial = false
        lyrics = nil
        scrobbled = false
        isPlaying = autoplay
        resolveGeneration += 1
        let generation = resolveGeneration

        NowPlayingManager.shared.updateMetadata(for: track, duration: track.duration, isPlaying: isPlaying)
        persistState()

        resolveTask = Task {
            await resolveAndLoad(track, generation: generation)
        }
        lyricsTask = Task {
            await loadLyrics(for: track, generation: generation)
        }
    }

    private func resolveAndLoad(_ track: Track, generation: Int) async {
        let quality = SettingsManager.shared.audioQuality.rawValue
        var data = try? await NeteaseAPI.songURL(ids: [track.id], level: quality).first
        guard !Task.isCancelled, generation == resolveGeneration else { return }
        if data?.url == nil, quality != AudioQuality.standard.rawValue {
            data = try? await NeteaseAPI.songURL(ids: [track.id], level: AudioQuality.standard.rawValue).first
        }
        guard !Task.isCancelled, generation == resolveGeneration else { return }

        var resolvedURL: URL?
        if let urlString = data?.url {
            resolvedURL = URL(string: urlString.replacingOccurrences(of: "http://", with: "https://"))
        }

        // NetEase refused — try third-party sources (UnblockNeteaseMusic-style).
        if resolvedURL == nil || data?.freeTrialInfo != nil, SettingsManager.shared.enableUnblock {
            if let unblocked = await UnblockService.resolve(track) {
                guard !Task.isCancelled, generation == resolveGeneration else { return }
                resolvedURL = unblocked.url
                unblockSource = unblocked.source
                data = nil
                ToastCenter.shared.show(String(localized: "已使用第三方音源：\(unblocked.source)"))
            }
        }
        guard !Task.isCancelled, generation == resolveGeneration else { return }

        guard let url = resolvedURL else {
            consecutiveFailures += 1
            let reason = track.playability(privilege: nil,
                                           isLoggedIn: AccountStore.shared.isLoggedIn,
                                           vipType: AccountStore.shared.vipType).reason
            ToastCenter.shared.show(String(localized: "《\(track.name)》无法播放\(reason.map { "：\($0)" } ?? "")"))
            let shouldAdvance = isPlaying && consecutiveFailures < 5
            isPlaying = false
            NowPlayingManager.shared.updateElapsed(progress, rate: 0)
            if shouldAdvance { advanceToNext(userInitiated: false) }
            return
        }

        servedQuality = data?.level
        if data?.freeTrialInfo != nil {
            isTrial = true
            ToastCenter.shared.show(String(localized: "VIP 歌曲，当前为试听片段"))
        }

        let item = AVPlayerItem(url: url)
        removeCurrentItemObservers()
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self, weak item] _ in
            Task { @MainActor in
                guard let self, let item, generation == self.resolveGeneration,
                      self.engine.currentItem === item, self.isPlaying else { return }
                self.handleItemEnded()
            }
        }
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak item] observedItem, _ in
            Task { @MainActor in
                guard let self, let item, observedItem === item,
                      generation == self.resolveGeneration, self.engine.currentItem === item else { return }
                switch item.status {
                case .readyToPlay:
                    self.consecutiveFailures = 0
                    self.isBuffering = false
                    let itemDuration = item.duration.seconds
                    if self.duration <= 0, itemDuration.isFinite, itemDuration > 0 {
                        self.duration = itemDuration
                        if let track = self.currentTrack {
                            NowPlayingManager.shared.updateMetadata(
                                for: track, duration: itemDuration, isPlaying: self.isPlaying
                            )
                        }
                    }
                case .failed:
                    self.handleItemFailure(item, generation: generation, error: item.error)
                default:
                    break
                }
            }
        }
        itemFailureObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self, weak item] _ in
            Task { @MainActor in
                guard let self, let item else { return }
                self.handleItemFailure(item, generation: generation, error: item.error)
            }
        }
        engine.replaceCurrentItem(with: item)
        // isPlaying represents the latest user intent while the URL resolves.
        // A pause during loading must survive completion of this request.
        if isPlaying { engine.play() }

        if let time = data?.time, time > 0 {
            duration = TimeInterval(time) / 1000
            NowPlayingManager.shared.updateMetadata(for: track, duration: duration, isPlaying: isPlaying)
        }
    }

    private func handleItemFailure(_ item: AVPlayerItem, generation: Int, error: Error?) {
        guard generation == resolveGeneration, engine.currentItem === item else { return }
        guard failureHandledGeneration != generation else { return }
        failureHandledGeneration = generation

        let shouldAdvance = isPlaying
        isBuffering = false
        engine.pause()
        isPlaying = false
        NowPlayingManager.shared.updateElapsed(progress, rate: 0)
        removeCurrentItemObservers()
        engine.replaceCurrentItem(with: nil)

        consecutiveFailures += 1
        let reason = error?.localizedDescription
        if shouldAdvance && consecutiveFailures < 5 {
            ToastCenter.shared.show(String(localized: "《\(currentTrack?.name ?? "歌曲")》播放失败，正在跳过"))
            advanceToNext(userInitiated: false)
        } else {
            ToastCenter.shared.show(reason.map { String(localized: "播放失败：\($0)") } ?? String(localized: "播放失败"))
        }
    }

    private func removeCurrentItemObservers() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        if let itemFailureObserver {
            NotificationCenter.default.removeObserver(itemFailureObserver)
            self.itemFailureObserver = nil
        }
    }

    private func loadLyrics(for track: Track, generation: Int) async {
        let response = try? await NeteaseAPI.lyric(id: track.id)
        guard !Task.isCancelled, generation == resolveGeneration else { return }
        // A nil response means the request failed or the song has no lyrics.
        // Keep nil only for the loading state; an empty value is terminal.
        lyrics = response.map(LyricsParser.parse) ?? ParsedLyrics()
    }

    // MARK: - Scrobble

    private func scrobbleIfNeeded(completed: Bool) {
        guard let track = currentTrack, !scrobbled, progress > 1 else { return }
        scrobbled = true
        let seconds = completed ? Int(duration) : Int(progress)
        let sourceID = source.sourceID
        Task.detached {
            await NeteaseAPI.scrobble(trackID: track.id, sourceID: sourceID, seconds: seconds)
        }
    }

    // MARK: - Shuffle helpers

    private func reshuffle(keeping first: Track) {
        var rest = queue.filter { $0.id != first.id }
        rest.shuffle()
        shuffledQueue = [first] + rest
    }

    // MARK: - Persistence

    private struct PersistedState: Codable {
        var queue: [Track]
        var playNext: [Track]?
        var currentID: Int?
        var repeatMode: String
        var shuffle: Bool
        // Optional additions retain compatibility with existing state files.
        var currentTrack: Track?
        var currentIndex: Int?
        var shuffledQueue: [Track]?
        var source: PlaySource?
    }

    private func persistState() {
        let state = PersistedState(
            queue: queue, playNext: playNextList,
            currentID: currentTrack?.id, repeatMode: repeatMode.rawValue,
            shuffle: shuffleEnabled, currentTrack: currentTrack,
            currentIndex: currentIndex, shuffledQueue: shuffledQueue, source: source
        )
        let url = Self.stateFileURL
        // Enqueue directly on one FIFO queue; independently scheduled Tasks can
        // reorder snapshots before they reach a writer actor.
        Self.stateWriter.async {
            guard let data = try? JSONEncoder().encode(state) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    func flushPendingStateWrites() {
        Self.stateWriter.sync {}
    }

    private func restoreState() {
        guard let data = try? Data(contentsOf: Self.stateFileURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else { return }
        queue = state.queue
        playNextList = state.playNext ?? []
        shuffleEnabled = state.shuffle
        repeatMode = RepeatMode(rawValue: state.repeatMode) ?? .off
        source = state.source ?? .none
        if shuffleEnabled {
            shuffledQueue = state.shuffledQueue ?? queue.shuffled()
        }
        if let savedIndex = state.currentIndex {
            currentIndex = activeQueue.indices.contains(savedIndex) ? savedIndex : -1
        } else if let id = state.currentID {
            currentIndex = activeQueue.firstIndex(where: { $0.id == id }) ?? -1
        }
        currentTrack = state.currentTrack
            ?? state.currentID.flatMap { id in activeQueue.first { $0.id == id } }
        if let track = currentTrack {
            duration = track.duration
            NowPlayingManager.shared.updateMetadata(for: track, duration: duration, isPlaying: false)
            let generation = resolveGeneration
            lyricsTask = Task {
                await loadLyrics(for: track, generation: generation)
            }
        }
    }

    private static var stateFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VibeaseMusic", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("player-state.json")
    }
}
