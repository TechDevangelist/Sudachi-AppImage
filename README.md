# Sudachi-AppImage

This repository makes builds for **x86_64_v3** & **znver2**. If your CPU is less than 10 years old use the x86_64_v3 build since it has a significant performance boost; if you are using a Steam Deck use the znver2 build.

* [Latest Stable Release](https://github.com/TechDevangelist/Sudachi-AppImage/releases/latest)

Compared to @Samueru-sama's work, this repo is rough. We are forced to use the built in ffmpeg instead of the packaged ffmpeg the original user (src/video_core/host1x/ffmpeg/ffmpeg.h uses internal headers to ffmpeg). 

Only UI works, the app will crash during game start up.
