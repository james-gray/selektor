# Selektor

In the middle of a DJ set and at a loss for what track to play next? Selektor can help.

Selektor will carefully analyze your music collection, and if you tell it what track you're currently playing, will suggest a track for you to mix into. Basing its recommendation on feature such as track BPM, timbre, key, and loudness, the app is a great tool for aspiring or beginner DJs to get to know their track collection and to hone their track selection skills!

## Installation

This application requires Mac OS X 10.10 (Yosemite) or higher, and you must have Xcode 7 installed in order to build the project. To build, simply clone the repository, open Selektor.xcodeproj in Xcode and Build (<kbd>command</kbd>+<kbd>B</kbd>) or Run (<kbd>command</kbd>+<kbd>R</kbd>) the project to compile the code and build the application.

All dependencies are contained within the Selektor/Dependencies directory - no additional installation of dependencies is required.

## Core Application Structure

Important application files and directories are specified in the tree below.

```
.
├── Selektor
│   ├── AppDelegate.swift
│   ├── DataController.swift
│   ├── GrandSelektor.swift
│   ├── MetadataParser.swift
│   ├── Settings.plist
│   ├── Transformers.swift
│   ├── ViewController.swift
│   ├── Base.lproj
│   │   └── Main.storyboard
│   ├── Dependencies
│   │   ├── ffmpeg
│   │   ├── ffmpeg_src
│   │   └── marsyas
│   ├── Models
│   │   ├── SelektorObject.swift
│   │   ├── TimbreVectorEntity.swift
│   │   └── TrackEntity.swift
│   ├── Extensions
│   │   ├── SelektorAVMetadataItem.swift
│   │   └── SelektorArray.swift
│   └── Selektor.xcdatamodeld
├── SelektorTests
│   └── SelektorTests.swift
└── LICENSE
```

## License

This application's code is governed by the GNU General Public License version 3 (GPLv3). You are free to use and modify it subject to the terms in the license. See the LICENSE document for further details.
