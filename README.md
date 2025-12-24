# Eddie's Flight Tracker

A beautiful, real-time flight tracking application for Apple TV, built with SwiftUI and MapKit.

## Features

- **Real-Time Flight Data**: Fetches live flight information from the OpenSky Network API
- **Interactive 3D Map**: Stunning hybrid map view with realistic elevation
- **Flight Details**: Select any flight to view:
  - Callsign and origin country
  - Altitude, speed, and heading
  - Vertical rate (climbing/descending)
  - Flight path visualization
- **Optimized Performance**: Fast data loading with efficient JSON parsing
- **Elegant UI**: Minimalist glassmorphism design optimized for the TV viewing experience

## Requirements

- Xcode 15.0+
- tvOS 17.0+
- Apple TV 4K (recommended)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/bluevisor/FlightTracker.git
   ```

2. Open `FlightTracker.xcodeproj` in Xcode

3. Select your Apple TV simulator or device

4. Build and run (⌘R)

## Usage

- **Navigate**: Use the Siri Remote to pan and zoom around the map
- **Select Flight**: Click on any airplane icon to view detailed information
- **View Flight Path**: Selected flights display their recent trajectory with a gradient trail
- **Deselect**: Click elsewhere on the map to clear the selection

## Data Source

Flight data is provided by the [OpenSky Network](https://opensky-network.org/), a free, community-based receiver network for air traffic control data.

**Note**: The OpenSky API has rate limits. If you encounter errors, please wait a moment before retrying.

## Architecture

- **FlightData.swift**: Data models and network service
- **FlightViewModel.swift**: State management and business logic
- **ContentView.swift**: Main UI implementation with Map and overlays

## License

MIT License - feel free to use this project for learning or personal use.

## Acknowledgments

- OpenSky Network for providing free ADS-B data
- Apple for the amazing MapKit and SwiftUI frameworks
