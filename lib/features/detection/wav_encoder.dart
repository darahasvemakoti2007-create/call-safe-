import 'dart:typed_data';

/// Pure-Dart audio container utility encoding raw linear PCM samples into
/// standard RIFF WAVE (`audio/wav`) containers for speech recognition providers.
class WavEncoder {
  /// Encodes raw 16-bit linear PCM byte samples into a valid RIFF WAVE audio container.
  ///
  /// Specification:
  /// - Sample rate: [sampleRate] (defaults to 16000 Hz, speech standard)
  /// - Channels: [numChannels] (defaults to 1, Mono)
  /// - Bit depth: [bitsPerSample] (defaults to 16 bits linear PCM)
  static Uint8List encodePcmToWav(
    List<int> pcmBytes, {
    int sampleRate = 16000,
    int numChannels = 1,
    int bitsPerSample = 16,
  }) {
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    final subChunk2Size = pcmBytes.length;
    final chunkSize = 36 + subChunk2Size;

    final header = ByteData(44);

    // "RIFF" chunk descriptor
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'

    // ChunkSize: 36 + SubChunk2Size
    header.setUint32(4, chunkSize, Endian.little);

    // "WAVE" format
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // "fmt " subchunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '

    // Subchunk1Size: 16 for standard linear PCM
    header.setUint32(16, 16, Endian.little);

    // AudioFormat: 1 for linear PCM
    header.setUint16(20, 1, Endian.little);

    // NumChannels
    header.setUint16(22, numChannels, Endian.little);

    // SampleRate
    header.setUint32(24, sampleRate, Endian.little);

    // ByteRate: SampleRate * NumChannels * BitsPerSample/8
    header.setUint32(28, byteRate, Endian.little);

    // BlockAlign: NumChannels * BitsPerSample/8
    header.setUint16(32, blockAlign, Endian.little);

    // BitsPerSample
    header.setUint16(34, bitsPerSample, Endian.little);

    // "data" subchunk header
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'

    // Subchunk2Size: Number of bytes in the data
    header.setUint32(40, subChunk2Size, Endian.little);

    final wav = Uint8List(44 + pcmBytes.length);
    wav.setRange(0, 44, header.buffer.asUint8List());
    wav.setRange(44, 44 + pcmBytes.length, pcmBytes);
    return wav;
  }

  /// Validates whether [bytes] begins with a valid 44-byte RIFF/WAVE header.
  static bool isValidWavHeader(List<int> bytes) {
    if (bytes.length < 44) return false;
    // Check "RIFF"
    if (bytes[0] != 0x52 || bytes[1] != 0x49 || bytes[2] != 0x46 || bytes[3] != 0x46) {
      return false;
    }
    // Check "WAVE"
    if (bytes[8] != 0x57 || bytes[9] != 0x41 || bytes[10] != 0x56 || bytes[11] != 0x45) {
      return false;
    }
    // Check "fmt "
    if (bytes[12] != 0x66 || bytes[13] != 0x6D || bytes[14] != 0x74 || bytes[15] != 0x20) {
      return false;
    }
    // Check "data"
    if (bytes[36] != 0x64 || bytes[37] != 0x61 || bytes[38] != 0x74 || bytes[39] != 0x61) {
      return false;
    }
    return true;
  }
}
