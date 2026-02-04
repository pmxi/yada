# yada: yet another dictation app.

Most modern operating systems, such as iOS and macOS include speech-to-text functionality.

This performance can be drastically improved by using an SotA STT model, with an LLM rewrite step.

Existing dictation tools are at least one of the following
- closed source
- ugly UI
- low code quality (vibe coded junk)

[OpenSuperWhisper](https://github.com/Starmel/OpenSuperWhisper) has native UI but no LLM rewrite.
[Wispr Flow](https://wisprflow.ai/) is subscription based and has potential privacy problems.
Apple Dictation is limited, old guard of tech.


Design principles.
- Use Swift for a native UI
- minimal
- non-shit ui/ux
- works out of the box.
- modern code.
- performant


Simplicity is of utmost importance.
This app should have very limited features and UI. Here's what the MVP will implement.
One page UI with options to configure OpenAI API key, choose microphone input.
Use gpt-4o-transcribe to transcribe and use gpt-5-mini to rewrite and then paste at cursor location.
User triggers dictation with Option+Cmd+S to start and stop.

UI should be absolutely minimal.
code should be well architectured and engineered.
do not ever use hacks to make shit work, do it right.
direct download (not App Store)
