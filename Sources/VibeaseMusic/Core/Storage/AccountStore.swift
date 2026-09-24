import Foundation
import Observation

/// Login state and the user's library: profile, liked track IDs, playlists.
@MainActor
@Observable
final class AccountStore {
    static let shared = AccountStore()

    var profile: UserProfile?
    var likedTrackIDs: Set<Int> = []
    var userPlaylists: [PlaylistSummary] = []
    var likedAlbums: [AlbumSummary] = []
    var likedArtists: [ArtistSummary] = []
    var isBootstrapped = false
    private(set) var sessionVersion = 0
    private var pendingLikes: Set<Int> = []
    private var likesRevision = 0

    var isLoggedIn: Bool { NeteaseClient.shared.isLoggedIn && profile != nil }
    var hasAuthCookie: Bool { NeteaseClient.shared.isLoggedIn }
    var vipType: Int { profile?.vipType ?? 0 }

    var likedSongsPlaylist: PlaylistSummary? {
        userPlaylists.first(where: \.isLikedSongsList) ?? userPlaylists.first
    }

    var createdPlaylists: [PlaylistSummary] {
        guard let uid = profile?.userId else { return [] }
        return userPlaylists.filter { $0.creator?.userId == uid && !$0.isLikedSongsList }
    }

    var subscribedPlaylists: [PlaylistSummary] {
        guard let uid = profile?.userId else { return [] }
        return userPlaylists.filter { $0.creator?.userId != uid }
    }

    private init() {}

    /// Called at launch and after login succeeds.
    func bootstrap() async {
        let requestVersion = sessionVersion
        defer {
            if sessionVersion == requestVersion {
                isBootstrapped = true
            }
        }
        guard hasAuthCookie else {
            if profile != nil { sessionVersion += 1 }
            profile = nil
            clearLibrary()
            return
        }
        refreshCookieIfNeeded()
        do {
            guard let loadedProfile = try await NeteaseAPI.userAccount(),
                  requestVersion == sessionVersion,
                  hasAuthCookie else { return }

            if profile?.userId != loadedProfile.userId {
                sessionVersion += 1
                clearLibrary()
            }
            profile = loadedProfile
            await refreshLibrary(for: loadedProfile.userId, version: sessionVersion)
        } catch {
            return
        }
    }

    func refreshLibrary() async {
        guard let uid = profile?.userId else { return }
        await refreshLibrary(for: uid, version: sessionVersion)
    }

    private func refreshLibrary(for uid: Int, version: Int) async {
        let revision = likesRevision
        async let playlists = try? NeteaseAPI.userPlaylists(uid: uid)
        async let liked = try? NeteaseAPI.likedTrackIDs(uid: uid)
        let loadedPlaylists = await playlists
        let loadedLiked = await liked
        guard version == sessionVersion, profile?.userId == uid, hasAuthCookie else { return }
        userPlaylists = loadedPlaylists ?? userPlaylists
        if let ids = loadedLiked, revision == likesRevision, pendingLikes.isEmpty {
            likedTrackIDs = Set(ids)
        }
    }

    func refreshSublists() async {
        let version = sessionVersion
        async let albums = try? NeteaseAPI.likedAlbums()
        async let artists = try? NeteaseAPI.likedArtists()
        let loadedAlbums = await albums
        let loadedArtists = await artists
        guard version == sessionVersion, hasAuthCookie else { return }
        likedAlbums = loadedAlbums ?? likedAlbums
        likedArtists = loadedArtists ?? likedArtists
    }

    func isLiked(_ trackID: Int) -> Bool {
        likedTrackIDs.contains(trackID)
    }

    func toggleLike(trackID: Int) async {
        guard isLoggedIn else {
            ToastCenter.shared.show(String(localized: "登录后即可收藏歌曲"))
            return
        }
        guard pendingLikes.insert(trackID).inserted else { return }
        let version = sessionVersion
        likesRevision += 1
        defer {
            if version == sessionVersion {
                pendingLikes.remove(trackID)
                likesRevision += 1
            }
        }
        let like = !likedTrackIDs.contains(trackID)
        // Optimistic update
        if like { likedTrackIDs.insert(trackID) } else { likedTrackIDs.remove(trackID) }
        do {
            try await NeteaseAPI.likeTrack(id: trackID, like: like)
        } catch {
            guard version == sessionVersion, isLoggedIn else { return }
            if like { likedTrackIDs.remove(trackID) } else { likedTrackIDs.insert(trackID) }
            ToastCenter.shared.show(error.localizedDescription)
        }
    }

    func logout() async {
        sessionVersion += 1
        isBootstrapped = false
        profile = nil
        clearLibrary()
        await NeteaseAPI.logout()
    }

    private func clearLibrary() {
        PlayerService.shared.accountSessionDidChange()
        pendingLikes = []
        likesRevision += 1
        likedTrackIDs = []
        userPlaylists = []
        likedAlbums = []
        likedArtists = []
    }

    /// Refresh the login cookie at most once per calendar day.
    private func refreshCookieIfNeeded() {
        let key = "auth.lastCookieRefresh"
        let today = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        guard UserDefaults.standard.double(forKey: key) < today else { return }
        UserDefaults.standard.set(today, forKey: key)
        Task { await NeteaseAPI.refreshLogin() }
    }
}

// MARK: - Toasts

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

@MainActor
@Observable
final class ToastCenter {
    static let shared = ToastCenter()

    var current: Toast?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ message: String) {
        current = Toast(message: message)
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            current = nil
        }
    }
}
