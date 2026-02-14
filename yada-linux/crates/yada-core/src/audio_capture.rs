use std::sync::{Arc, Mutex};
use std::time::Duration;

use anyhow::Context;
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};

#[derive(Debug, Clone, Copy)]
pub struct CapturedAudioFormat {
    pub sample_rate_hz: u32,
}

pub struct CaptureHandle {
    stream: cpal::Stream,
    buf: Arc<Mutex<Vec<i16>>>,
    fmt: CapturedAudioFormat,
}

impl CaptureHandle {
    pub fn format(&self) -> CapturedAudioFormat {
        self.fmt
    }

    pub fn stop_and_take(self) -> Vec<i16> {
        // Drop stream to stop.
        drop(self.stream);
        let mut b = self.buf.lock().unwrap();
        std::mem::take(&mut *b)
    }
}

pub fn start_capture() -> anyhow::Result<CaptureHandle> {
    let host = cpal::default_host();
    let device = host
        .default_input_device()
        .ok_or_else(|| anyhow::anyhow!("no default input device"))?;

    let supported = device
        .default_input_config()
        .context("failed to get default input config")?;

    let sample_rate_hz = supported.sample_rate().0;
    let channels = supported.channels();
    let stream_cfg: cpal::StreamConfig = supported.clone().into();

    let fmt = CapturedAudioFormat { sample_rate_hz };

    let buf: Arc<Mutex<Vec<i16>>> = Arc::new(Mutex::new(Vec::new()));
    let buf2 = Arc::clone(&buf);

    let err_fn = |err| {
        // ALSA will sometimes emit spurious poll() errors; they can be transient.
        // We log them, but higher-level code should be resilient to short/empty captures.
        eprintln!("cpal stream error: {err}");
    };
    let timeout = Some(Duration::from_millis(100));

    let stream = match supported.sample_format() {
        cpal::SampleFormat::I16 => device.build_input_stream(
            &stream_cfg,
            move |data: &[i16], _info| push_interleaved_i16_mono(&buf2, data, channels),
            err_fn,
            timeout,
        )?,
        cpal::SampleFormat::U16 => device.build_input_stream(
            &stream_cfg,
            move |data: &[u16], _info| push_interleaved_u16_mono(&buf2, data, channels),
            err_fn,
            timeout,
        )?,
        cpal::SampleFormat::F32 => device.build_input_stream(
            &stream_cfg,
            move |data: &[f32], _info| push_interleaved_f32_mono(&buf2, data, channels),
            err_fn,
            timeout,
        )?,
        other => anyhow::bail!("unsupported sample format: {other:?}"),
    };

    stream.play().context("failed to start input stream")?;

    Ok(CaptureHandle { stream, buf, fmt })
}

fn push_interleaved_i16_mono(buf: &Arc<Mutex<Vec<i16>>>, data: &[i16], channels: u16) {
    let channels = channels.max(1) as usize;
    if channels == 1 {
        if let Ok(mut b) = buf.lock() {
            b.extend_from_slice(data);
        }
        return;
    }

    if let Ok(mut b) = buf.lock() {
        for frame in data.chunks_exact(channels) {
            let mut acc: i32 = 0;
            for &s in frame {
                acc += s as i32;
            }
            let avg = acc / channels as i32;
            b.push(avg.clamp(i16::MIN as i32, i16::MAX as i32) as i16);
        }
    }
}

fn push_interleaved_u16_mono(buf: &Arc<Mutex<Vec<i16>>>, data: &[u16], channels: u16) {
    let channels = channels.max(1) as usize;
    if let Ok(mut b) = buf.lock() {
        for frame in data.chunks_exact(channels) {
            let mut acc: f32 = 0.0;
            for &s in frame {
                // Map [0, 65535] to [-1, 1]
                let f = (s as f32 / 65535.0) * 2.0 - 1.0;
                acc += f;
            }
            let avg = (acc / channels as f32).clamp(-1.0, 1.0);
            b.push((avg * i16::MAX as f32) as i16);
        }
    }
}

fn push_interleaved_f32_mono(buf: &Arc<Mutex<Vec<i16>>>, data: &[f32], channels: u16) {
    let channels = channels.max(1) as usize;
    if let Ok(mut b) = buf.lock() {
        for frame in data.chunks_exact(channels) {
            let mut acc: f32 = 0.0;
            for &s in frame {
                acc += s;
            }
            let avg = (acc / channels as f32).clamp(-1.0, 1.0);
            b.push((avg * i16::MAX as f32) as i16);
        }
    }
}
