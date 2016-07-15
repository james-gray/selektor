# Selektor

In the middle of a DJ set and at a loss for what track to play next? Selektor can help.

Selektor will carefully analyze your music collection, and if you tell it what track you're currently playing, will suggest a track for you to mix into. Basing its recommendation on feature such as track BPM, timbre, key, and loudness, the app is a great tool for aspiring or beginner DJs to get to know their track collection and to hone their track selection skills!

## Installation

This application requires Mac OS X 10.10 (Yosemite) or higher, and you must have Xcode 7 installed in order to build the project. To build, simply clone the repository, open Selektor.xcodeproj in Xcode and Build (<kbd>command</kbd>+<kbd>B</kbd>) or Run (<kbd>command</kbd>+<kbd>R</kbd>) the project to compile the code and build the application.

All dependencies are contained within the Selektor/Dependencies directory - no additional installation of dependencies is required.

## Core Application Structure

Important application files and directories are specified and described in the tree below.

```aconf
.
├── Selektor
│   ├── AppDelegate.swift # Contains app initialization and setup logic.
│   ├── DataController.swift # Defines a class that acts as a mediator between the application and the Core Data store.
│   ├── GrandSelektor.swift # Contains next-track selection functionality.
│   ├── MetadataParser.swift # Parses metadata tags from user-supplied tracks and stores the metadata in track object properties.
│   ├── Settings.plist # Contains build-time configuration parameters, such as selection algorithm specification.
│   ├── Transformers.swift # Value transformer helpers for the GUI.
│   ├── ViewController.swift # The main point of contact and interaction between the UI and the data model.
│   ├── Base.lproj
│   │   └── Main.storyboard # Contains the GUI specification.
│   ├── Dependencies
│   │   ├── ffmpeg # Used to convert non-PCM-encoded tracks to WAV.
│   │   ├── ffmpeg_src # Supplied alongside ffmpeg binaries as per GPLv3.
│   │   └── marsyas # Used for audio feature extraction.
│   ├── Models
│   │   ├── SelektorObject.swift # Base class that other model objects subclass.
│   │   ├── TimbreVectorEntity.swift # Represents a single 16-dimensional timbre vector.
│   │   └── TrackEntity.swift # Represents a single track or song.
│   ├── Extensions # Useful extensions of primitive and AVFoundation types.
│   │   ├── SelektorAVMetadataItem.swift
│   │   └── SelektorArray.swift
│   └── Selektor.xcdatamodeld # Contains the data model specification.
├── SelektorTests
│   └── SelektorTests.swift # Contains unit tests.
└── LICENSE
```

## License

This application's code is governed by the GNU General Public License version 3 (GPLv3). You are free to use and modify it subject to the terms in the license. See the LICENSE document for further details.
