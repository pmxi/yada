use anyhow::Context;
use reqwest::multipart;
use serde_json::Value;

#[derive(Clone)]
pub struct OpenAIClient {
    http: reqwest::Client,
    base_url: String,
    api_key: String,
}

impl OpenAIClient {
    pub fn new(base_url: impl Into<String>, api_key: impl Into<String>) -> anyhow::Result<Self> {
        let http = reqwest::Client::builder().build()?;
        Ok(Self {
            http,
            base_url: base_url.into().trim_end_matches('/').to_string(),
            api_key: api_key.into(),
        })
    }

    pub async fn transcribe_wav_bytes(
        &self,
        wav_bytes: Vec<u8>,
        model: &str,
    ) -> anyhow::Result<String> {
        let url = format!("{}/v1/audio/transcriptions", self.base_url);

        let file_part = multipart::Part::bytes(wav_bytes)
            .file_name("audio.wav")
            .mime_str("audio/wav")?;

        let form = multipart::Form::new()
            .text("model", model.to_string())
            .part("file", file_part);

        let resp = self
            .http
            .post(url)
            .bearer_auth(&self.api_key)
            .multipart(form)
            .send()
            .await
            .context("openai transcribe request failed")?;

        let status = resp.status();
        let body = resp
            .text()
            .await
            .context("openai transcribe response read failed")?;
        if !status.is_success() {
            anyhow::bail!("openai transcribe failed: {}: {}", status, body);
        }

        let v: Value = serde_json::from_str(&body).context("openai transcribe JSON parse failed")?;
        let text = v
            .get("text")
            .and_then(|x| x.as_str())
            .unwrap_or_default()
            .to_string();
        Ok(text)
    }

    pub async fn rewrite_text(&self, text: &str, model: &str, prompt: &str) -> anyhow::Result<String> {
        let url = format!("{}/v1/responses", self.base_url);

        // Keep request structure conservative: a basic role/message array.
        let payload = serde_json::json!({
            "model": model,
            "input": [
                {"role": "system", "content": prompt},
                {"role": "user", "content": text}
            ]
        });

        let resp = self
            .http
            .post(url)
            .bearer_auth(&self.api_key)
            .json(&payload)
            .send()
            .await
            .context("openai rewrite request failed")?;

        let status = resp.status();
        let body = resp
            .text()
            .await
            .context("openai rewrite response read failed")?;
        if !status.is_success() {
            anyhow::bail!("openai rewrite failed: {}: {}", status, body);
        }

        let v: Value = serde_json::from_str(&body).context("openai rewrite JSON parse failed")?;
        if let Some(s) = v.get("output_text").and_then(|x| x.as_str()) {
            return Ok(s.to_string());
        }

        // Fallback: traverse output[...].content[...].text
        let mut acc = String::new();
        if let Some(outputs) = v.get("output").and_then(|x| x.as_array()) {
            for o in outputs {
                if let Some(contents) = o.get("content").and_then(|x| x.as_array()) {
                    for c in contents {
                        if let Some(t) = c.get("text").and_then(|x| x.as_str()) {
                            acc.push_str(t);
                        }
                    }
                }
            }
        }

        Ok(acc)
    }
}
