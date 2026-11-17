import AVFoundation
import Foundation

struct RecordedVoice {
    let url: URL
    let data: Data
    let duration: Int
}

/// Запись голосового сообщения в m4a/AAC. Один рекордер на экран; файл живёт
/// во временном каталоге до загрузки.
final class VoiceRecorder {
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?
    private var startedAt: Date?

    var isRecording: Bool { recorder?.isRecording == true }

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start() -> Bool {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-recordings", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let url = directory.appendingPathComponent("voice_\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64_000
            ]
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            guard recorder.record() else { return false }
            self.recorder = recorder
            fileURL = url
            startedAt = Date()
            return true
        } catch {
            cancel()
            return false
        }
    }

    func stop() -> RecordedVoice? {
        guard let recorder, let url = fileURL else { return nil }
        let duration = Int(Date().timeIntervalSince(startedAt ?? Date()))
        recorder.stop()
        self.recorder = nil
        fileURL = nil
        startedAt = nil

        guard duration >= 1,
              let data = try? Data(contentsOf: url),
              !data.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return RecordedVoice(url: url, data: data, duration: duration)
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        fileURL = nil
        startedAt = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
