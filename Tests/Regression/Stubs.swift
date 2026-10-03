import Foundation
import AVFoundation
struct Track: Codable { let id: Int; var name: String { "Track \(id)" }; var duration: Double { 60 }; func playability(privilege: Int?, isLoggedIn: Bool, vipType: Int) -> (reason: String?, unused: Int) { (nil,0) } }
struct ParsedLyrics {}
enum LyricsParser { static func parse(_ input: Int) -> ParsedLyrics { ParsedLyrics() } }
struct UserProfile { var userId: Int; var vipType = 0 }
struct PlaylistSummary { var creator: UserProfile?; var isLikedSongsList = false }
struct AlbumSummary {}
struct ArtistSummary {}
final class NeteaseClient { static let shared = NeteaseClient(); var isLoggedIn = true; func clearAuthCookies() { isLoggedIn = false } }
enum NeteaseAPIError: Error { case needLogin }
enum AudioQuality: String { case standard }
final class SettingsManager { static let shared = SettingsManager(); var audioQuality = AudioQuality.standard; var enableUnblock = false }
@MainActor final class NowPlayingManager { static let shared = NowPlayingManager(); func attach(to: PlayerService) {}; func updateMetadata(for: Track, duration: Double, isPlaying: Bool) {}; func updateElapsed(_ elapsed: Double, rate: Double, force: Bool = true) {} }
enum UnblockService { struct Resolved { var url: URL; var source: String }; static func resolve(_ track: Track) async -> Resolved? { nil } }
struct PlayRecordItem { var song: Track }
struct CloudSongItem { var simpleSong: Track? }
struct CloudResponse { var data: [CloudSongItem]?; var size: Int? = nil; var maxSize: Int? = nil }
struct SongURL { var url: String?; var level: String? = nil; var freeTrialInfo: Int? = nil; var time: Int? = nil }
enum TestError: Error { case failed }
@MainActor enum NeteaseAPI {
 static var songWaiters: [Int: [CheckedContinuation<[SongURL], Error>]] = [:]
 static var fmWaiters: [CheckedContinuation<[Track], Error>] = []
 static var fmCalls = 0
 static var likeWaiters: [CheckedContinuation<Void, Error>] = []
 static var likeCalls = 0
 static var dailyWaiters: [CheckedContinuation<[Track], Error>] = []
 static var recentWaiters: [CheckedContinuation<[PlayRecordItem], Error>] = []
 static var cloudWaiters: [CheckedContinuation<CloudResponse, Error>] = []
 static func dailyRecommendSongs() async throws -> [Track] { try await withCheckedThrowingContinuation { dailyWaiters.append($0) } }
 static func playRecords(uid: Int, week: Bool) async throws -> [PlayRecordItem] { try await withCheckedThrowingContinuation { recentWaiters.append($0) } }
 static func cloudSongs() async throws -> CloudResponse { try await withCheckedThrowingContinuation { cloudWaiters.append($0) } }
 static var accountID = 1
 static func songURL(ids: [Int], level: String) async throws -> [SongURL] {
  try await withCheckedThrowingContinuation { songWaiters[ids[0], default: []].append($0) }
 }
 static func finishSong(_ id: Int) {
  songWaiters[id]!.removeFirst().resume(returning: [SongURL(url: "file:///private/tmp/vibease-regression-silence.wav")])
 }
 static func personalFM() async throws -> [Track] { fmCalls += 1; return try await withCheckedThrowingContinuation { fmWaiters.append($0) } }
 static func fmTrash(id: Int) async throws {}
 static func lyric(id: Int) async throws -> Int? { nil }
 static func scrobble(trackID: Int, sourceID: Int, seconds: Int) async {}
 static func userAccount() async throws -> UserProfile? { UserProfile(userId: accountID) }
 static func userPlaylists(uid: Int) async throws -> [PlaylistSummary] { [] }
 static func likedTrackIDs(uid: Int) async throws -> [Int] { [] }
 static func likedAlbums() async throws -> [AlbumSummary] { [] }
 static func likedArtists() async throws -> [ArtistSummary] { [] }
 static func likeTrack(id: Int, like: Bool) async throws { likeCalls += 1; try await withCheckedThrowingContinuation { likeWaiters.append($0) } }
 static func logout() async {}
 static func refreshLogin() async {}
}
