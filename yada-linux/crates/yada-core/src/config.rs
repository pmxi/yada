use std::path::{Path, PathBuf};

use directories::ProjectDirs;
use serde::{Deserialize, Serialize};

use crate::{DEFAULT_REWRITE_MODEL, DEFAULT_REWRITE_PROMPT, DEFAULT_TRANSCRIBE_MODEL};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    #[serde(default = "default_openai_base_url")]
    pub openai_base_url: String,

    #[serde(default = "default_transcribe_model")]
    pub transcribe_model: String,

    #[serde(default = "default_rewrite_model")]
    pub rewrite_model: String,

    #[serde(default = "default_rewrite_prompt")]
    pub rewrite_prompt: String,
}

fn default_openai_base_url() -> String {
    "https://api.openai.com".to_string()
}

fn default_transcribe_model() -> String {
    DEFAULT_TRANSCRIBE_MODEL.to_string()
}

fn default_rewrite_model() -> String {
    DEFAULT_REWRITE_MODEL.to_string()
}

fn default_rewrite_prompt() -> String {
    DEFAULT_REWRITE_PROMPT.to_string()
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            openai_base_url: default_openai_base_url(),
            transcribe_model: default_transcribe_model(),
            rewrite_model: default_rewrite_model(),
            rewrite_prompt: default_rewrite_prompt(),
        }
    }
}

pub fn config_dir() -> anyhow::Result<PathBuf> {
    let proj = ProjectDirs::from("dev", "yada", "yada-linux")
        .ok_or_else(|| anyhow::anyhow!("unable to determine XDG config dir"))?;
    Ok(proj.config_dir().to_path_buf())
}

pub fn config_path() -> anyhow::Result<PathBuf> {
    Ok(config_dir()?.join("config.toml"))
}

pub fn load_from_path(path: &Path) -> anyhow::Result<AppConfig> {
    let s = std::fs::read_to_string(path)?;
    Ok(toml::from_str(&s)?)
}

pub fn load_or_default() -> anyhow::Result<(PathBuf, AppConfig)> {
    let path = config_path()?;
    match load_from_path(&path) {
        Ok(cfg) => Ok((path, cfg)),
        Err(e) if e.downcast_ref::<std::io::Error>().is_some() => Ok((path, AppConfig::default())),
        Err(e) => Err(e),
    }
}
