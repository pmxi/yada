pub fn encode_wav_pcm16_mono(samples: &[i16], sample_rate_hz: u32) -> Vec<u8> {
    // RIFF/WAVE PCM 16-bit mono.
    // Layout: RIFF header + fmt chunk + data chunk.
    //
    // References:
    // - https://ccrma.stanford.edu/courses/422-winter-2014/projects/WaveFormat/
    let num_channels: u16 = 1;
    let bits_per_sample: u16 = 16;
    let bytes_per_sample = (bits_per_sample / 8) as u32;

    let byte_rate = sample_rate_hz
        .saturating_mul(num_channels as u32)
        .saturating_mul(bytes_per_sample);
    let block_align: u16 = (num_channels as u32 * bytes_per_sample) as u16;

    let data_len_bytes: u32 = (samples.len() as u32).saturating_mul(bytes_per_sample);
    let riff_len_minus_8: u32 = 4 /*WAVE*/
        + (8 + 16) /*fmt*/
        + (8 + data_len_bytes) /*data*/;

    let mut out = Vec::with_capacity((8 + riff_len_minus_8) as usize);

    // RIFF header
    out.extend_from_slice(b"RIFF");
    out.extend_from_slice(&riff_len_minus_8.to_le_bytes());
    out.extend_from_slice(b"WAVE");

    // fmt chunk
    out.extend_from_slice(b"fmt ");
    out.extend_from_slice(&16u32.to_le_bytes()); // PCM fmt chunk size
    out.extend_from_slice(&1u16.to_le_bytes()); // audio format 1=PCM
    out.extend_from_slice(&num_channels.to_le_bytes());
    out.extend_from_slice(&sample_rate_hz.to_le_bytes());
    out.extend_from_slice(&byte_rate.to_le_bytes());
    out.extend_from_slice(&block_align.to_le_bytes());
    out.extend_from_slice(&bits_per_sample.to_le_bytes());

    // data chunk
    out.extend_from_slice(b"data");
    out.extend_from_slice(&data_len_bytes.to_le_bytes());
    for s in samples {
        out.extend_from_slice(&s.to_le_bytes());
    }

    out
}
