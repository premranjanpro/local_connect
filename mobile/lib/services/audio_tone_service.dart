import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

/// Synthesized offline chime & audio tone generator for task & order creation.
/// Generates pleasant, rich bell-chimes in pure Dart (0ms network delay, 100% offline).
class AudioToneService {
  static final AudioPlayer _player = AudioPlayer();

  /// Play a joyful ascending 4-note bell chime when an Order/Task is created!
  /// Notes: C5 -> E5 -> G5 -> C6 with smooth exponential envelope.
  static Future<void> playOrderCreatedTone() async {
    try {
      HapticFeedback.mediumImpact();
      final wavBytes = _generateArpeggioWav(
        frequencies: [523.25, 659.25, 783.99, 1046.50], // C5, E5, G5, C6
        noteDurationSec: 0.12,
        sampleRate: 22050,
      );
      await _player.play(BytesSource(wavBytes));
    } catch (_) {
      // Fallback to system sound and vibration
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Play a crisp notification ping when status updates (e.g. Driver Arrived, Picked Up).
  static Future<void> playStatusUpdateTone() async {
    try {
      HapticFeedback.lightImpact();
      final wavBytes = _generateSingleChimeWav(
        frequency: 880.0, // A5
        durationSec: 0.25,
        sampleRate: 22050,
      );
      await _player.play(BytesSource(wavBytes));
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Play a celebration triumph tone when an order is completed or rating submitted.
  static Future<void> playCelebrationTone() async {
    try {
      HapticFeedback.heavyImpact();
      final wavBytes = _generateArpeggioWav(
        frequencies: [587.33, 739.99, 880.00, 1174.66], // D5, F#5, A5, D6
        noteDurationSec: 0.14,
        sampleRate: 22050,
      );
      await _player.play(BytesSource(wavBytes));
    } catch (_) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Synthesizes an arpeggio chord into a standard 16-bit PCM WAV byte array.
  static Uint8List _generateArpeggioWav({
    required List<double> frequencies,
    required double noteDurationSec,
    int sampleRate = 22050,
  }) {
    final noteSamples = (noteDurationSec * sampleRate).toInt();
    final totalSamples = noteSamples * frequencies.length;
    final pcmBytes = Uint8List(totalSamples * 2);
    final byteData = ByteData.view(pcmBytes.buffer);

    for (int n = 0; n < frequencies.length; n++) {
      final freq = frequencies[n];
      final offsetSamples = n * noteSamples;

      for (int i = 0; i < noteSamples; i++) {
        final t = i / sampleRate;
        // Bell-like harmonic rich tone (fundamental + 2nd harmonic)
        final envelope = math.exp(-3.5 * (i / noteSamples));
        final sampleVal = (math.sin(2 * math.pi * freq * t) * 0.7 +
                           math.sin(4 * math.pi * freq * t) * 0.3) * envelope;

        final clamped = (sampleVal * 28000).clamp(-32768, 32767).toInt();
        final byteIdx = (offsetSamples + i) * 2;
        byteData.setInt16(byteIdx, clamped, Endian.little);
      }
    }

    return _buildWavHeader(pcmBytes, sampleRate);
  }

  /// Synthesizes a single bell chime with natural exponential decay.
  static Uint8List _generateSingleChimeWav({
    required double frequency,
    required double durationSec,
    int sampleRate = 22050,
  }) {
    final totalSamples = (durationSec * sampleRate).toInt();
    final pcmBytes = Uint8List(totalSamples * 2);
    final byteData = ByteData.view(pcmBytes.buffer);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final envelope = math.exp(-5.0 * (i / totalSamples));
      final sampleVal = (math.sin(2 * math.pi * frequency * t) * 0.75 +
                         math.sin(3 * math.pi * frequency * t) * 0.25) * envelope;

      final clamped = (sampleVal * 28000).clamp(-32768, 32767).toInt();
      byteData.setInt16(i * 2, clamped, Endian.little);
    }

    return _buildWavHeader(pcmBytes, sampleRate);
  }

  /// Appends 44-byte standard RIFF/WAVE header to PCM audio data.
  static Uint8List _buildWavHeader(Uint8List pcmData, int sampleRate) {
    final numChannels = 1;
    final bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    final subchunk2Size = pcmData.length;
    final chunkSize = 36 + subchunk2Size;

    final header = Uint8List(44);
    final b = ByteData.view(header.buffer);

    // RIFF chunk
    header.setRange(0, 4, 'RIFF'.codeUnits);
    b.setUint32(4, chunkSize, Endian.little);
    header.setRange(8, 12, 'WAVE'.codeUnits);

    // fmt subchunk
    header.setRange(12, 16, 'fmt '.codeUnits);
    b.setUint32(16, 16, Endian.little); // Subchunk1Size for PCM
    b.setUint16(20, 1, Endian.little);  // AudioFormat 1 = PCM
    b.setUint16(22, numChannels, Endian.little);
    b.setUint32(24, sampleRate, Endian.little);
    b.setUint32(28, byteRate, Endian.little);
    b.setUint16(32, blockAlign, Endian.little);
    b.setUint16(34, bitsPerSample, Endian.little);

    // data subchunk
    header.setRange(36, 40, 'data'.codeUnits);
    b.setUint32(40, subchunk2Size, Endian.little);

    final out = Uint8List(44 + pcmData.length);
    out.setRange(0, 44, header);
    out.setRange(44, out.length, pcmData);
    return out;
  }
}
