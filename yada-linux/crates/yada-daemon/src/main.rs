use std::sync::{mpsc, Arc, Mutex};

use zbus::interface;

use yada_core::{
    audio::encode_wav_pcm16_mono,
    audio_capture,
    config,
    openai::OpenAIClient,
};

struct CapturedAudio {
    sample_rate_hz: u32,
    samples_pcm16_mono: Vec<i16>,
}

enum CaptureCommand {
    Start { resp: mpsc::Sender<Result<(), String>> },
    Stop { resp: mpsc::Sender<Result<CapturedAudio, String>> },
}

#[derive(Default)]
struct SharedCaptureError {
    last: Mutex<Option<String>>,
}

impl SharedCaptureError {
    fn set(&self, s: impl Into<String>) {
        let mut g = self.last.lock().unwrap();
        *g = Some(s.into());
    }

    fn take(&self) -> Option<String> {
        let mut g = self.last.lock().unwrap();
        g.take()
    }
}

fn spawn_capture_thread(capture_err: Arc<SharedCaptureError>) -> mpsc::Sender<CaptureCommand> {
    let (tx, rx) = mpsc::channel::<CaptureCommand>();

    std::thread::Builder::new()
        .name("yada-capture".to_string())
        .spawn(move || {
            let mut handle: Option<audio_capture::CaptureHandle> = None;

            while let Ok(cmd) = rx.recv() {
                match cmd {
                    CaptureCommand::Start { resp } => {
                        if handle.is_some() {
                            let _ = resp.send(Ok(()));
                            continue;
                        }

                        match audio_capture::start_capture() {
                            Ok(h) => {
                                handle = Some(h);
                                let _ = resp.send(Ok(()));
                            }
                            Err(e) => {
                                capture_err.set(format!("capture start failed: {e}"));
                                let _ = resp.send(Err(e.to_string()));
                            }
                        }
                    }
                    CaptureCommand::Stop { resp } => {
                        let Some(h) = handle.take() else {
                            let _ = resp.send(Ok(CapturedAudio {
                                sample_rate_hz: 16_000,
                                samples_pcm16_mono: Vec::new(),
                            }));
                            continue;
                        };

                        let sample_rate_hz = h.format().sample_rate_hz;
                        let samples_pcm16_mono = h.stop_and_take();
                        if samples_pcm16_mono.is_empty() {
                            if let Some(e) = capture_err.take() {
                                let _ = resp.send(Err(e));
                                continue;
                            }
                        }
                        let _ = resp.send(Ok(CapturedAudio {
                            sample_rate_hz,
                            samples_pcm16_mono,
                        }));
                    }
                }
            }
        })
        .expect("failed to spawn capture thread");

    tx
}

struct YadaLinux {
    state: Arc<Mutex<bool>>,
    capture_tx: mpsc::Sender<CaptureCommand>,
}

#[interface(name = "dev.yada.Linux")]
impl YadaLinux {
    async fn start(&self) -> zbus::fdo::Result<()> {
        {
            let mut recording = self.state.lock().unwrap();
            if *recording {
                return Ok(());
            }
            *recording = true;
        }

        let capture_tx = self.capture_tx.clone();
        tokio::task::spawn_blocking(move || {
            let (resp_tx, resp_rx) = mpsc::channel();
            capture_tx
                .send(CaptureCommand::Start { resp: resp_tx })
                .map_err(|e| anyhow::anyhow!(e.to_string()))?;
            resp_rx
                .recv()
                .map_err(|e| anyhow::anyhow!(e.to_string()))?
                .map_err(|e| anyhow::anyhow!(e))?;
            Ok::<_, anyhow::Error>(())
        })
        .await
        .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?
        .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        Ok(())
    }

    async fn stop(&self) -> zbus::fdo::Result<String> {
        {
            let mut recording = self.state.lock().unwrap();
            *recording = false;
        }

        let capture_tx = self.capture_tx.clone();
        let audio = tokio::task::spawn_blocking(move || {
            let (resp_tx, resp_rx) = mpsc::channel();
            capture_tx
                .send(CaptureCommand::Stop { resp: resp_tx })
                .map_err(|e| anyhow::anyhow!(e.to_string()))?;
            resp_rx
                .recv()
                .map_err(|e| anyhow::anyhow!(e.to_string()))?
                .map_err(|e| anyhow::anyhow!(e))
        })
        .await
        .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?
        .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        if audio.samples_pcm16_mono.is_empty() {
            return Ok(String::new());
        }

        let wav = encode_wav_pcm16_mono(&audio.samples_pcm16_mono, audio.sample_rate_hz);

        let (_cfg_path, cfg) = config::load_or_default()
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        let api_key = std::env::var("YADA_OPENAI_API_KEY")
            .map_err(|_| zbus::fdo::Error::Failed("missing YADA_OPENAI_API_KEY (settings UI/keyring not implemented yet)".to_string()))?;

        let client = OpenAIClient::new(cfg.openai_base_url, api_key)
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;
        let raw = client
            .transcribe_wav_bytes(wav, &cfg.transcribe_model)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;
        let rewritten = client
            .rewrite_text(&raw, &cfg.rewrite_model, &cfg.rewrite_prompt)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        Ok(rewritten)
    }

    fn ping(&self) -> zbus::fdo::Result<String> {
        Ok("pong".to_string())
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let state = Arc::new(Mutex::new(false));
    let capture_err = Arc::new(SharedCaptureError::default());
    let capture_tx = spawn_capture_thread(Arc::clone(&capture_err));
    let svc = YadaLinux { state, capture_tx };

    let _conn = zbus::ConnectionBuilder::session()?
        .name("dev.yada.Linux")?
        .serve_at("/dev/yada/Linux", svc)?
        .build()
        .await?;

    // Run until SIGINT/SIGTERM.
    let mut sigterm = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())?;
    tokio::select! {
        _ = tokio::signal::ctrl_c() => {},
        _ = sigterm.recv() => {},
    }

    Ok(())
}
