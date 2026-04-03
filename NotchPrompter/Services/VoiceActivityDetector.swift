import Foundation
import AVFoundation
import Accelerate

class VoiceActivityDetector: ObservableObject {
    @Published var isSpeaking = false
    @Published var isRunning = false

    private var audioEngine: AVAudioEngine?
    private let silenceThresholdDB: Float = -35.0
    private let speechOnsetFrames = 2
    private let silenceOnsetFrames = 6

    private var consecutiveSpeechFrames = 0
    private var consecutiveSilenceFrames = 0

    func start() {
        guard !isRunning else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0 else { return }

        let sampleRate = Float(format.sampleRate)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            let db = self.speechBandEnergy(buffer: buffer, sampleRate: sampleRate)

            DispatchQueue.main.async {
                if db > self.silenceThresholdDB {
                    self.consecutiveSpeechFrames += 1
                    self.consecutiveSilenceFrames = 0
                    if self.consecutiveSpeechFrames >= self.speechOnsetFrames && !self.isSpeaking {
                        self.isSpeaking = true
                    }
                } else {
                    self.consecutiveSilenceFrames += 1
                    self.consecutiveSpeechFrames = 0
                    if self.consecutiveSilenceFrames >= self.silenceOnsetFrames && self.isSpeaking {
                        self.isSpeaking = false
                    }
                }
            }
        }

        do {
            try engine.start()
            audioEngine = engine
            DispatchQueue.main.async {
                self.isRunning = true
            }
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func stop() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        DispatchQueue.main.async {
            self.isRunning = false
            self.isSpeaking = false
        }
        consecutiveSpeechFrames = 0
        consecutiveSilenceFrames = 0
    }

    /// Compute energy only in the speech frequency band (300Hz–3kHz)
    /// using a real FFT. This ignores low-frequency hums, fans, and
    /// high-frequency beeps/clicks that aren't speech.
    private func speechBandEnergy(buffer: AVAudioPCMBuffer, sampleRate: Float) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return -160 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return -160 }

        let fftSize = 1024
        let n = min(count, fftSize)
        let log2n = vDSP_Length(log2(Float(fftSize)))

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return -160
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Apply Hann window
        var windowed = [Float](repeating: 0, count: fftSize)
        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        vDSP_vmul(channelData, 1, window, 1, &windowed, 1, vDSP_Length(n))

        // Split complex FFT
        let halfN = fftSize / 2
        var realp = [Float](repeating: 0, count: halfN)
        var imagp = [Float](repeating: 0, count: halfN)

        realp.withUnsafeMutableBufferPointer { realBuf in
            imagp.withUnsafeMutableBufferPointer { imagBuf in
                var splitComplex = DSPSplitComplex(
                    realp: realBuf.baseAddress!,
                    imagp: imagBuf.baseAddress!
                )

                windowed.withUnsafeBufferPointer { ptr in
                    ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfN))
                    }
                }

                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&splitComplex, 1, realBuf.baseAddress!, 1, vDSP_Length(halfN))
            }
        }

        // realp now contains magnitude squared values
        let freqResolution = sampleRate / Float(fftSize)
        let lowBin = max(1, Int(300.0 / freqResolution))
        let highBin = min(halfN - 1, Int(3000.0 / freqResolution))

        guard highBin > lowBin else { return -160 }

        // Sum energy in speech band
        var bandEnergy: Float = 0
        let binCount = highBin - lowBin + 1
        realp.withUnsafeBufferPointer { buf in
            vDSP_sve(buf.baseAddress! + lowBin, 1, &bandEnergy, vDSP_Length(binCount))
        }

        let rms = sqrt(bandEnergy / Float(fftSize * fftSize))
        return rms > 0 ? 20 * log10(rms) : -160
    }
}
