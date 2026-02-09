# Windows contributing

This repo now includes a Windows app scaffold in `yada-windows/`.

## Project layout

- `yada-windows/Yada.Windows.sln`: solution file.
- `yada-windows/Yada.Windows/`: WinUI 3 app project (`net8.0-windows10.0.19041.0`).
- `yada-windows/Yada.Windows/ViewModels/MainViewModel.cs`: app state machine (idle -> recording -> transcribing -> rewriting -> inserting -> error).
- `yada-windows/Yada.Windows/Services/GroqClient.cs`: Groq pipeline implementation.

## Prerequisites (Windows machine)

1. Windows 10/11.
2. Visual Studio 2022 with:
   - .NET desktop development
   - Windows App SDK / WinUI workload
3. .NET SDK 8+ (9 also works).

## Build

From repo root in PowerShell:

```powershell
cd yada-windows

dotnet restore .\Yada.Windows.sln
dotnet build .\Yada.Windows.sln -c Debug
```

Or open `yada-windows/Yada.Windows.sln` in Visual Studio and run `Yada.Windows`.

## Current MVP scope

- Global hotkey trigger: fixed `Ctrl+Shift+Space`.
- Hotkey modes: toggle + hold.
- Mic capture: in-memory PCM (`16kHz`, `16-bit`, mono).
- Pipeline:
  - Transcribe: `whisper-large-v3` via `https://api.groq.com/openai/v1/audio/transcriptions`
  - Rewrite: `moonshotai/kimi-k2-instruct` via `https://api.groq.com/openai/v1/chat/completions`
- Text insertion: clipboard + synthetic `Ctrl+V`.

## Settings

Settings are saved to:

- `%LocalAppData%\yada-windows\settings.json`

For MVP, the Groq API key is stored there in plain text by design.
