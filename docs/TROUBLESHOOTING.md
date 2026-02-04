# Troubleshooting

## Keychain password prompt ("yada wants to access key 'dev.yada'")
- The app stores the API key in the macOS login keychain.
- If the login keychain password does not match your current macOS password, macOS will prompt and reject it.
- Fix options:
  - Unlock the login keychain in Keychain Access with the old password.
  - Change the login keychain password to your current macOS password (if you know the old one).
  - As a last resort, create a new login keychain (can lose locally stored secrets).

## Permissions keep prompting
- Verify in System Settings:
  - Privacy & Security -> Microphone
  - Privacy & Security -> Accessibility
  - Privacy & Security -> Input Monitoring
- If toggles are missing, quit the app and run it once more to re-trigger the prompt.

## Hotkey does not trigger
- Ensure the app is running in the foreground or background.
- Check for conflicts with existing shortcuts in other apps.
- Rebind the hotkey in the UI to a unique combination.
- In hold mode, some modifier-heavy hotkeys (e.g., Cmd alone) may behave oddly in certain apps due to Carbon API limitations.

## Text does not insert
- Make sure Accessibility permission is granted for `yada`.
- Some apps do not support direct AXValue edits; the clipboard fallback should still work.
- If clipboard managers interfere, temporarily disable them.

## Microphone is wrong or silent
- Use the Mic picker in the UI and ensure the correct device is selected.
- The app sets the selected mic as the system default input device.
- Verify in macOS Sound settings that the input device is active.

## Build fails in Xcode
- Open `yada/yada.xcodeproj`, not the repo root.
- Check that the selected Xcode is current and supports macOS 14.5 deployment target.
