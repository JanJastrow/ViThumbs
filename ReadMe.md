# ViThumbs

Create tiled video thumbnail images with metadata

## About

I was looking for a simple tool to create video thumbnail files, like I created years ago with "Media Player Classic".
In my research I found a few tools for Windows, but only few for macOS and even less (none?) open source.

Instead I found a zsh/bash script from [@zmwangx](https://github.com/zmwangx) and the fork of [@romanwarlock](https://github.com/romanwarlock) which were looking promising.
Since I'm no expert in FFmpeg nor shell scripting I had some trouble adapting the script to my needs initially, but improved eventually.

## Example
![Example image generated from "Spring"](https://datenkeller.ministeriumfuerinternet.de/projects/Spring%20-%20Blender%20Open%20Movie.mp4_thumbs.jpg)
Example generated from [Spring](https://studio.blender.org/films/spring/) by Blender Studio

## Requirements
- [FFmpeg](https://www.ffmpeg.org/)
- FFprobe (comes with FFmpeg)

## Sources
- [Original gist](https://gist.github.com/zmwangx/11275000)
- [Forked project](https://github.com/romanwarlock/thumbnails)
