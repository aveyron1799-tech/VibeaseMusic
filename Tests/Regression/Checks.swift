import Foundation
@main struct Checks {
 @MainActor static func settle() async { for _ in 0..<20 { await Task.yield() } }
 @MainActor static func main() async throws {
  let url = PlayerService.stateFileURL
  try? FileManager.default.removeItem(at: url)
  let p = PlayerService()
  p.play(tracks: [Track(id: 1)], source: .none)
  await settle(); p.pause(); NeteaseAPI.finishSong(1); await settle()
  assert(!p.isPlaying && p.engine.rate == 0, "Paused resolution must not autoplay")
  print("PASS pause during URL resolution")

  p.play(tracks: [Track(id: 2)], source: .none); await settle()
  p.play(tracks: [Track(id: 3)], source: .none); await settle()
  NeteaseAPI.finishSong(2); await settle()
  assert(p.currentTrack?.id == 3 && p.engine.currentItem == nil)
  p.pause(); NeteaseAPI.finishSong(3); await settle()
  print("PASS stale song response ignored")

  p.startFM(); await settle(); let calls = NeteaseAPI.fmCalls
  p.fmNext(); p.fmNext(); await settle(); assert(NeteaseAPI.fmCalls == calls)
  p.play(tracks: [Track(id: 4)], source: .none); await settle()
  NeteaseAPI.fmWaiters.removeFirst().resume(returning: [Track(id: 99)])
  await settle(); assert(p.currentTrack?.id == 4 && !p.isFMMode && p.fmUpcoming.isEmpty)
  print("PASS FM deduplication and leaving FM during pending response")
  p.pause(); NeteaseAPI.finishSong(4); await settle()

  p.startFM(); await settle(); p.pause()
  NeteaseAPI.fmWaiters.removeFirst().resume(returning: [Track(id: 5)])
  await settle(); assert(p.currentTrack?.id == 5 && !p.isPlaying)
  NeteaseAPI.finishSong(5); await settle(); assert(p.engine.rate == 0)
  print("PASS pause during first FM batch")

  p.fmNext(); await settle()
  NeteaseAPI.fmWaiters.removeFirst().resume(returning: [Track(id: 6), Track(id: 7)])
  await settle()
  assert(p.fmPlayedTracks.map(\.id) == [5] && p.upcomingTracks.map(\.id) == [7])
  p.jumpTo(Track(id: 5)); await settle()
  assert(p.currentTrack?.id == 5 && p.isFMMode && p.fmPlayedTracks.map(\.id) == [6])
  assert(p.upcomingTracks.map(\.id) == [7])
  p.fmNext(); await settle(); assert(p.currentTrack?.id == 7)
  print("PASS FM history replay preserves upcoming recommendations")
  p.fmNext(); await settle()
  p.jumpTo(Track(id: 6)); await settle()
  NeteaseAPI.fmWaiters.removeFirst().resume(returning: [Track(id: 8)])
  await settle()
  assert(p.currentTrack?.id == 6 && p.isFMMode && p.fmUpcoming.isEmpty)
  assert(Set(p.fmHistory.map(\.id)).count == p.fmHistory.count)
  print("PASS FM history selection rejects pending batch and avoids duplicates")

  p.play(tracks: [Track(id: 10),Track(id: 11)], source: .playlist(123))
  assert(p.fmHistory.isEmpty && p.fmPlayedTracks.isEmpty)
  p.addToPlayNext(Track(id: 90), playNow: true)
  p.pause(); p.flushPendingStateWrites()
  let restored = PlayerService()
  assert(restored.currentTrack?.id == 90 && restored.currentIndex == 0)
  assert(restored.source == .playlist(123) && !restored.isPlaying)
  restored.next(); assert(restored.currentTrack?.id == 11)
  restored.pause(); restored.flushPendingStateWrites()
  print("PASS inserted track roundtrip and original queue continuation")

  for i in 100..<150 { p.queue = [Track(id: i)]; p.currentTrack = Track(id: i); p.currentIndex = 0; p.persistState() }
  p.flushPendingStateWrites()
  let latest = try JSONDecoder().decode(PlayerService.PersistedState.self, from: Data(contentsOf: url))
  assert(latest.currentID == 149)
  print("PASS FIFO persistence: newest of 50 snapshots wins")

  let empty = PlayerService.PersistedState(queue: [], playNext: [Track(id: 71)], currentID: 70, repeatMode: "off", shuffle: false, currentTrack: Track(id: 70), currentIndex: -1)
  try JSONEncoder().encode(empty).write(to: url)
  let standalone = PlayerService()
  assert(standalone.currentTrack?.id == 70 && standalone.playNextList.first?.id == 71)
  print("PASS empty main queue with current and upcoming tracks")

  let legacy = "{\"queue\":[{\"id\":42}],\"currentID\":42,\"repeatMode\":\"all\",\"shuffle\":false}"
  try Data(legacy.utf8).write(to: url)
  let old = PlayerService()
  assert(old.currentTrack?.id == 42 && old.repeatMode == .all)
  print("PASS legacy state migration")

  let shuffled = PlayerService.PersistedState(queue: [Track(id: 1),Track(id: 2)], playNext: [], currentID: 2, repeatMode: "one", shuffle: true, currentTrack: Track(id: 2), currentIndex: 0, shuffledQueue: [Track(id: 2),Track(id: 1)], source: .album(77))
  try JSONEncoder().encode(shuffled).write(to: url)
  let ordered = PlayerService()
  assert(ordered.activeQueue.map(\.id) == [2,1] && ordered.currentIndex == 0 && ordered.source == .album(77))
  print("PASS shuffle order and source restoration")

  let account = AccountStore.shared
  account.profile = UserProfile(userId: 1)
  account.likedTrackIDs = [888]
  let pending = Task { await account.toggleLike(trackID: 888) }
  await settle(); let likeCount = NeteaseAPI.likeCalls
  await account.toggleLike(trackID: 888); assert(NeteaseAPI.likeCalls == likeCount)
  await account.logout(); account.profile = UserProfile(userId: 2)
  NeteaseAPI.likeWaiters.removeFirst().resume(throwing: TestError.failed)
  await pending.value
  assert(account.likedTrackIDs.isEmpty)
  print("PASS duplicate favorite coalescing and cross-session rollback isolation")

  p.startFM(); await settle()
  await account.logout()
  NeteaseAPI.fmWaiters.removeFirst().resume(returning: [Track(id: 999)])
  await settle(); assert(p.currentTrack?.id != 999)
  print("PASS account change rejects old FM response")
  p.pause(); restored.pause(); p.flushPendingStateWrites()
  account.profile = UserProfile(userId: 3)
  let daily = DailyProbe(); let dailyTask = Task { await daily.load() }; await settle()
  await account.logout(); account.profile = UserProfile(userId: 4)
  daily.tracks = [Track(id: 444)]
  NeteaseAPI.dailyWaiters.removeFirst().resume(returning: [Track(id: 333)])
  await dailyTask.value; assert(daily.tracks.first?.id == 444)
  print("PASS daily recommendations reject old account response")

  let recent = RecentProbe(); let recentTask = Task { await recent.load() }; await settle()
  recent.week = true; recent.records = [PlayRecordItem(song: Track(id: 555))]
  NeteaseAPI.recentWaiters.removeFirst().resume(returning: [PlayRecordItem(song: Track(id: 333))])
  await recentTask.value; assert(recent.records.first?.song.id == 555)
  print("PASS recent history rejects old time range response")

  let cloud = CloudProbe(); let cloudTask = Task { await cloud.load() }; await settle()
  await account.logout(); account.profile = UserProfile(userId: 5)
  cloud.items = [CloudSongItem(simpleSong: Track(id: 666))]
  NeteaseAPI.cloudWaiters.removeFirst().resume(returning: CloudResponse(data: [CloudSongItem(simpleSong: Track(id: 333))]))
  await cloudTask.value; assert(cloud.items.first?.simpleSong?.id == 666)
  print("PASS cloud songs reject old account response")
  print("ALL 16 CHECKS PASSED")
 }
}
