# Security and Privacy

## Data handling
- Audio is captured in memory and never written to disk by the app.
- Transcripts and rewrites are held in memory and inserted immediately.
- No local logging of audio or text content.

## Clipboard fallback
If Accessibility insertion fails, the app:
1) Writes the text to the system pasteboard.
2) Sends a synthetic Cmd+V to paste.
3) Restores the previous clipboard contents shortly after.

Note: The system clipboard can be observed by clipboard managers or other apps with access. The text only lives there briefly, but it is still visible to the OS during that window.

## Secrets
- OpenAI API key is stored in macOS Keychain under:
  - service: `dev.yada`
  - account: `openai-api-key`
- This can trigger a Keychain unlock prompt if the login keychain is locked.

## Permissions
- Microphone: required to capture audio.
- Accessibility: required to insert text at the cursor.
- Input Monitoring: may be requested to allow synthetic key events (Cmd+V).

## Network
- OpenAI endpoints used:
  - `/v1/audio/transcriptions` (audio -> text)
  - `/v1/responses` (text rewrite)
