import Foundation

/// PCM16 → WAV conversion (Android: `InvoiceExtractionViewModel.pcmToWav`).
enum PcmWav {
    static let sampleRate = 16_000
    static let channels = 1
    static let bitsPerSample = 16

    /// Wraps raw little-endian PCM16 mono 16 kHz samples in a 44-byte WAV header.
    static func wrap(pcm: Data) -> Data {
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = pcm.count
        let headerSize = 44

        var wav = Data(capacity: headerSize + dataSize)
        wav.append(contentsOf: Array("RIFF".utf8))
        wav.append(le32(UInt32(truncatingIfNeeded: headerSize + dataSize - 8)))
        wav.append(contentsOf: Array("WAVE".utf8))
        wav.append(contentsOf: Array("fmt ".utf8))
        wav.append(le32(16))
        wav.append(le16(1))  // PCM
        wav.append(le16(UInt16(channels)))
        wav.append(le32(UInt32(sampleRate)))
        wav.append(le32(UInt32(byteRate)))
        wav.append(le16(UInt16(blockAlign)))
        wav.append(le16(UInt16(bitsPerSample)))
        wav.append(contentsOf: Array("data".utf8))
        wav.append(le32(UInt32(truncatingIfNeeded: dataSize)))
        wav.append(pcm)
        return wav
    }

    private static func le32(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    private static func le16(_ value: UInt16) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }
}
