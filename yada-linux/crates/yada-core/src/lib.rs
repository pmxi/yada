pub mod audio;
pub mod audio_capture;
pub mod config;
pub mod openai;

pub const DEFAULT_TRANSCRIBE_MODEL: &str = "gpt-4o-transcribe";
pub const DEFAULT_REWRITE_MODEL: &str = "gpt-5-mini";
pub const DEFAULT_REWRITE_PROMPT: &str =
    "Rewrite the text with correct punctuation and capitalization. Preserve meaning. Return plain text only.";
