import AVFoundation
import Foundation

/// Волна голосового сообщения из реальных пиков аудиофайла. Анализ идёт один
/// раз на вложение, результат кэшируется в памяти; параллельные запросы одного
/// и того же файла переиспользуют одну задачу.
actor WaveformProvider {
    static let shared = WaveformProvider()

    private var cache: [String: [Double]] = [:]
    private var inFlight: [String: Task<[Double]?, Never>] = [:]

    func waveform(
        for attachment: ChatAttachment,
        repository: AttachmentRepository
    ) async -> [Double]? {
        let id = attachment.id
        if let cached = cache[id] { return cached }
        if let task = inFlight[id] { return await task.value }

        let task = Task<[Double]?, Never> { [attachment] in
            guard let uuid = attachment.attachmentUuid,
                  let url = await AttachmentFileCache.shared.localURL(
                    attachmentUuid: uuid,
                    fileName: attachment.fileName ?? "voice.m4a",
                    repository: repository
                  ) else { return nil }
            let samples = await Self.peakSamples(url: url)
            guard !samples.isEmpty else { return nil }
            return Waveform.downsample(samples)
        }
        inFlight[id] = task

        let result = await task.value
        inFlight[id] = nil
        if let result { cache[id] = result }
        return result
    }

    /// Пик по каждому буферу PCM. Буферы идут подряд, поэтому массив
    /// пропорционален длительности — этого достаточно для столбцов волны.
    nonisolated static func peakSamples(url: URL) async -> [Float] {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
              let reader = try? AVAssetReader(asset: asset) else { return [] }

        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: false
            ]
        )
        guard reader.canAdd(output) else { return [] }
        reader.add(output)
        guard reader.startReading() else { return [] }

        var samples: [Float] = []
        while let buffer = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            let floatCount = length / MemoryLayout<Float>.size
            guard floatCount > 0 else { continue }

            var values = [Float](repeating: 0, count: floatCount)
            let copied = values.withUnsafeMutableBytes { raw -> OSStatus in
                guard let base = raw.baseAddress else { return -1 }
                return CMBlockBufferCopyDataBytes(
                    block,
                    atOffset: 0,
                    dataLength: length,
                    destination: base
                )
            }
            guard copied == kCMBlockBufferNoErr else { continue }

            var peak: Float = 0
            for value in values where value.isFinite {
                peak = max(peak, abs(value))
            }
            samples.append(peak)
        }
        reader.cancelReading()
        return samples
    }
}
