yada is a dictation app. Currently, there is a macOS app in (yada/).
The basic UX is user holds a keystroke then says something (which is recorded with the laptop mic).
Then the recording is transcribed with a ASR/STT model to get raw text. The raw text is improved with an LLM.
The LLM is responsible fixing grammar and punctuation, and errors in the STT output to make a transcribed text.
The transcribed text is then inserted at the users cursor position.

Here's a guide to the directory structure here:
yada/ holds the Xcode project and sources for the macOS app.
assets/ contain assets, such as images, and SVGs used in the macOS app.
builds/ contains the .zip packaged apps for distribution.
The zips are made using scripts/package_release_zip.sh
research/ contains notes and scripts for research in automated speech recognition to improve yada.
It's not part of the macOS app development
docs/ contains valuable info about the project, how to develop, and how to use it. It's a collection of markdown files.
Technical info should go here. As you work on yada, you may discover things that are valuable to remember. Document them
here.
The README.md is an intro and quickstart for new (non-technical) users.

If you are working on the yada macOS app (anything under yada/), first read docs/macos-contributing.md to learn about common development commands.

