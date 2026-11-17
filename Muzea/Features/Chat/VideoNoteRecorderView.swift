import AVFoundation
import SwiftUI

/// Слой превью камеры для записи кружка.
struct VideoNotePreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            guard let layer = layer as? AVCaptureVideoPreviewLayer else {
                fatalError("Expected AVCaptureVideoPreviewLayer")
            }
            return layer
        }
    }
}

/// Полноэкранная запись видео-кружка: фронтальная камера, лимит 60 секунд,
/// автоотправка после остановки.
struct VideoNoteRecorderSheet: View {
    let onRecorded: (RecordedVideoNote) -> Void

    @StateObject private var recorder = VideoNoteRecorder()
    @Environment(\.dismiss) private var dismiss
    @State private var didSend = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                    VideoNotePreviewView(session: recorder.session)
                        .clipShape(Circle())
                    if recorder.state == .preparing {
                        ProgressView().tint(.white)
                    }
                }
                .frame(width: 280, height: 280)

                switch recorder.state {
                case .recording(let seconds):
                    Text(DurationFormatter.mmss(seconds))
                        .font(.title3.monospacedDigit())
                        .foregroundColor(.white)
                case .failed(let message):
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                default:
                    Text("Видео-кружок · до 60 секунд")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                HStack(spacing: 44) {
                    Button {
                        recorder.cancel()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }

                    Button {
                        if case .recording = recorder.state {
                            recorder.stop()
                        } else {
                            Task { await recorder.start() }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 78, height: 78)
                            if case .recording = recorder.state {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.red)
                                    .frame(width: 30, height: 30)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 62, height: 62)
                            }
                        }
                    }
                    .disabled(recorder.state == .preparing)

                    Color.clear.frame(width: 56, height: 56)
                }
                .padding(.bottom, 28)
            }
        }
        .interactiveDismissDisabled()
        .task {
            await recorder.start()
        }
        .onChange(of: recorder.state) { state in
            guard state == .finished, !didSend, let note = recorder.recorded else { return }
            didSend = true
            onRecorded(note)
            dismiss()
        }
        .onDisappear {
            if !didSend { recorder.cancel() }
        }
    }
}
