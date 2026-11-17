import AVFoundation
import Foundation
import UIKit

struct RecordedVideoNote {
    let url: URL
    let data: Data
    let thumbnail: Data?
    let duration: Int
    let width: Int?
    let height: Int?
    let fileName: String
}

enum VideoNoteLimits {
    static let maxDuration: TimeInterval = 60
    static let minDuration: TimeInterval = 1

    static func isValid(duration: TimeInterval) -> Bool {
        duration >= minDuration && duration <= maxDuration + 1
    }

    static func clampedDuration(_ duration: TimeInterval) -> TimeInterval {
        min(max(duration, 0), maxDuration)
    }
}

/// Запись видео-кружка фронтальной камерой. Сессия живёт только пока открыт
/// рекордер; файл и превью готовятся после остановки.
@MainActor
final class VideoNoteRecorder: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case preparing
        case recording(seconds: Int)
        case finished
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var recorded: RecordedVideoNote?

    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "muzea.video-note.session")
    private var timerTask: Task<Void, Never>?
    private var outputURL: URL?
    private var startedAt: Date?
    private var cancelled = false
    private var configured = false

    static func requestPermissions() async -> Bool {
        let video = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { continuation.resume(returning: $0) }
        }
        guard video else { return false }
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
        }
    }

    func start() async {
        guard state == .idle || isFailed else { return }
        state = .preparing
        recorded = nil
        cancelled = false

        guard await Self.requestPermissions() else {
            state = .failed("Нет доступа к камере и микрофону")
            return
        }

        do {
            try configureIfNeeded()
        } catch {
            state = .failed("Не удалось открыть камеру")
            return
        }

        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("video-note-\(UUID().uuidString).mp4")
        outputURL = url
        startedAt = Date()
        state = .recording(seconds: 0)
        startTimer()

        movieOutput.startRecording(to: url, recordingDelegate: self)
    }

    func stop() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
        timerTask?.cancel()
        timerTask = nil
    }

    func cancel() {
        cancelled = true
        timerTask?.cancel()
        timerTask = nil
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }
        stopSession()
        if let outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        outputURL = nil
        recorded = nil
        state = .idle
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    private func configureIfNeeded() throws {
        guard !configured else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .vga640x480

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) ?? AVCaptureDevice.default(for: .video) else {
            throw NSError(domain: "video-note", code: 1)
        }
        let videoInput = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(videoInput), session.canAddOutput(movieOutput) else {
            throw NSError(domain: "video-note", code: 2)
        }
        session.addInput(videoInput)

        if let mic = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }
        session.addOutput(movieOutput)

        if let connection = movieOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
        configured = true
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while !Task.isCancelled, movieOutput.isRecording {
                let elapsed = Date().timeIntervalSince(startedAt ?? Date())
                state = .recording(seconds: Int(elapsed))
                if elapsed >= VideoNoteLimits.maxDuration {
                    stop()
                    return
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    private func stopSession() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }
}

extension VideoNoteRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            self.finish(url: outputFileURL, error: error)
        }
    }

    private func finish(url: URL, error: Error?) {
        timerTask?.cancel()
        timerTask = nil
        stopSession()

        guard !cancelled else {
            try? FileManager.default.removeItem(at: url)
            state = .idle
            return
        }

        if let error {
            try? FileManager.default.removeItem(at: url)
            state = .failed("Не удалось записать видео: \(error.localizedDescription)")
            return
        }

        Task {
            do {
                let asset = AVURLAsset(url: url)
                let duration = try await asset.load(.duration).seconds
                guard VideoNoteLimits.isValid(duration: duration) else {
                    try? FileManager.default.removeItem(at: url)
                    state = .failed("Слишком короткая запись")
                    return
                }
                let data = try Data(contentsOf: url)
                let thumbnail = await Self.thumbnailData(for: asset)
                var size: CGSize?
                if let track = try? await asset.loadTracks(withMediaType: .video).first {
                    size = try? await track.load(.naturalSize)
                }
                let note = RecordedVideoNote(
                    url: url,
                    data: data,
                    thumbnail: thumbnail,
                    duration: Int(duration.rounded()),
                    width: size.map { Int($0.width) },
                    height: size.map { Int($0.height) },
                    fileName: url.lastPathComponent
                )
                recorded = note
                state = .finished
            } catch {
                try? FileManager.default.removeItem(at: url)
                state = .failed("Не удалось прочитать видео")
            }
        }
    }

    private static func thumbnailData(for asset: AVURLAsset) async -> Data? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        return await withCheckedContinuation { continuation in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) {
                _, image, _, _, _ in
                guard let image else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: UIImage(cgImage: image).jpegData(compressionQuality: 0.8))
            }
        }
    }
}
