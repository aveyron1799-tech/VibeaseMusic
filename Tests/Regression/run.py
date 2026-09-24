#!/usr/bin/env python3
"""Run deterministic regressions against current production methods.

No live API, account, media-center or user playback-state access. Production
PlayerService/AccountStore are compiled with fake external services. Private
visibility is relaxed only in temporary copies; page load methods are extracted
into probes. This checks async/state behavior, not SwiftUI rendering or HTTP.
"""
from pathlib import Path
import subprocess
import tempfile
import uuid
import wave

repo = Path(__file__).resolve().parents[2]
source = repo / 'Sources/VibeaseMusic'
tests = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix='vibease-regressions-') as tmp:
    temp = Path(tmp)
    state_path = str(temp / 'player-state.json')
    wav_path = str(temp / 'silence.wav')
    suite = 'VibeaseMusicRegressionTests.' + str(uuid.uuid4())
    for name, rel in [('PlayerService', 'Core/Player/PlayerService.swift'),
                      ('AccountStore', 'Core/Storage/AccountStore.swift')]:
        text = (source / rel).read_text().replace('private(set) ', '').replace('private ', '')
        text = text.replace('UserDefaults.standard', f'UserDefaults(suiteName: "{suite}")!')
        if name == 'PlayerService':
            start = text.index('    static var stateFileURL:')
            text = text[:start] + f'    static var stateFileURL: URL {{ URL(fileURLWithPath: "{state_path}") }}\n}}\n'
        (temp / (name + '.swift')).write_text(text)
    probes = 'import Foundation\n'
    for filename, name, fields, selector in [
        ('DailySongsView.swift', 'DailyProbe', 'var tracks: [Track] = []; var errorMessage: String?', 0),
        ('LibraryPages.swift', 'RecentProbe', 'var records: [PlayRecordItem] = []; var week = false', 0),
        ('LibraryPages.swift', 'CloudProbe', 'var items: [CloudSongItem] = []; var sizeInfo: String?', 1),
    ]:
        text = (source / 'Features/Pages' / filename).read_text()
        method = text.split('    private func load() async {')[selector + 1]
        depth = 1
        for i, char in enumerate(method):
            if char == '{': depth += 1
            elif char == '}': depth -= 1
            if depth == 0:
                method = method[:i+1]
                break
        probes += ('@MainActor final class ' + name + ' {\nlet account = AccountStore.shared\n'
                   'var isLoading = true\n' + fields + '\nfunc load() async {' + method + '\n}\n')
    (temp / 'PageProbes.swift').write_text(probes)
    (temp / 'Stubs.swift').write_text((tests / 'Stubs.swift').read_text().replace(
        '/private/tmp/vibease-regression-silence.wav', wav_path))
    checks = (tests / 'Checks.swift').read_text().replace(
        '  print("ALL 16 CHECKS PASSED")',
        f'  UserDefaults.standard.removePersistentDomain(forName: "{suite}")\n  print("ALL 16 CHECKS PASSED")')
    (temp / 'Checks.swift').write_text(checks)
    with wave.open(wav_path, 'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(8000)
        wav.writeframes(bytes(8000 * 2 * 60))
    files = ['Stubs', 'PlayerService', 'AccountStore', 'PageProbes', 'Checks']
    subprocess.run(['swiftc', '-swift-version', '5', '-module-cache-path', str(temp/'ModuleCache'),
                    *[str(temp / (f + '.swift')) for f in files], '-o', str(temp/'checks')], check=True)
    subprocess.run([str(temp/'checks')], check=True)
