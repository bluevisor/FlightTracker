# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Eddie's Flight Tracker is a real-time flight tracking application for Apple TV built with SwiftUI and MapKit. It displays live flight data from the OpenSky Network API on an interactive 3D map.

## Build and Run

- **Build**: Open `FlightTracker.xcodeproj` in Xcode and press ⌘B
- **Run**: Select an Apple TV simulator or device, then press ⌘R
- **Requirements**: Xcode 15.0+, tvOS 17.0+

## Architecture

The app follows MVVM architecture with three core files:

### FlightData.swift
- **Models**: `Flight` struct with computed properties for formatted display (altitude in feet, velocity in knots)
- **Network Service**: `FlightService` handles OpenSky Network API communication
  - OAuth2 token management with automatic refresh (60s buffer before expiration)
  - Falls back to anonymous API access if credentials missing
  - Primary endpoint: `/api/states/all` for all active flights
  - Track endpoint: `/api/tracks/all?icao24={id}&time=0` for flight paths
  - Rate limit handling (429 errors)

### FlightViewModel.swift
- **State Management**: ObservableObject managing flights array, selection state, and camera position
- **Auto-refresh**: Timer-based polling every 60 seconds to respect API rate limits
- **Flight Filtering**: Filters for active flights (altitude > 0, velocity > 0) and search results
- **Camera Control**: Animates to selected flight with 500km altitude, pitch 45°, heading matching flight track
- **Map Interaction**:
  - `panMap(direction:amount:)`: Pans map by percentage of current span (default 20%, 5% for continuous)
  - `adjustZoom(multiplier:)`: Zooms in/out with multiplier (0.95/1.05 for continuous, 0.8/1.25 for single)
  - `toggleControlMode()`: Switches between Pan and Zoom modes, shows indicator for 2 seconds
  - Uses linear animations (0.05s duration) for smooth continuous movement

### ContentView.swift
- **Map Display**: MapKit with hybrid elevation style showing 3D terrain. Default interactions disabled to allow custom remote control via `onMoveCommand`.
- **Annotations**: Custom `FlightAnnotationView` with airplane icons rotated by flight track
- **Flight Path**: Yellow gradient polyline for selected flight's historical trajectory
- **UI Overlay**: Glassmorphism design with header, flight details card, and stats footer
- **Map Control Mode**: Pan/Zoom toggle system with continuous movement on button hold
  - State tracking via `isInMapMode` flag (true when user enters map tab)
  - Center button (Play/Pause) toggles between Pan and Zoom modes
  - Direction buttons trigger continuous pan/zoom while held
  - Timer-based continuous movement (50ms intervals for smooth animation)
  - Back button exits map mode and returns to tab bar (Up button does NOT exit)

## API Configuration

The app supports multiple ADS-B data providers through `Config.swift`:

### Available Providers

1. **OpenSky Network** (default)
   - Global coverage with `/states/all` endpoint
   - Historical flight tracks support
   - Optional OAuth2 authentication (see Secrets.swift)
   - Rate limit: 60 seconds (anonymous) or lower with auth
   - Docs: https://openskynetwork.github.io/opensky-api/

2. **adsb.lol**
   - Geographic queries only (250 NM radius)
   - No authentication required
   - Rate limit: 1 request/second
   - Docs: https://api.adsb.lol/docs

3. **adsb.fi**
   - Geographic queries only (250 NM radius)
   - Personal use only license
   - No authentication required
   - Rate limit: 1 request/second
   - Docs: https://github.com/adsbfi/opendata

4. **Airplanes.live**
   - Geographic queries only (250 NM radius)
   - Community-driven
   - No authentication required
   - Rate limit: 1 request/second
   - Docs: https://airplanes.live/api-guide/

### Changing API Provider

Edit `Config.swift` and change:
```swift
static var provider: ADSBProvider = .opensky  // Change to .adsbLol, .adsbFi, or .airplanesLive
```

For non-global APIs, configure the geographic center:
```swift
static var defaultLatitude: Double = 39.8283   // Your region's center
static var defaultLongitude: Double = -98.5795
static var defaultRadius: Double = 250.0       // Nautical miles (max 250)
```

### OpenSky Authentication (Optional)

- Credentials stored in `Secrets.swift` (clientId and clientSecret)
- Token automatically fetched and refreshed by `FlightService.getValidToken()`
- If credentials are placeholder values or auth fails, falls back to anonymous access

## Data Flow

1. **Location Setup**: `FlightViewModel.setupLocationManager()` requests user location permission
2. **Initial Fetch**: `startFetching()` initiates first fetch with provider-specific rate limit timer
3. **API Call**: `FlightService.fetchFlights(lat:lon:radius:)` calls provider-specific endpoint:
   - Uses user location if available, otherwise current map view region, or falls back to config defaults
   - OpenSky: `/states/all` for global coverage (ignores location params)
   - Regional APIs: `/lat/{lat}/lon/{lon}/dist/{radius}` centered on user/viewport
4. **Response Parsing**: Based on provider format:
   - OpenSky: Array-based format (stateArray)
   - ADSBExchange v2: JSON objects with "ac" array (adsb.lol, adsb.fi, airplanes.live)
5. **Filtering**: Active flights only (altitude > 0, velocity > 0), limited to 500 max for performance
6. **Map Updates**: SwiftUI bindings update Map with annotations and flight path polyline
7. **Viewport Tracking**: `onChange(of: mapCameraPosition)` extracts region for potential re-fetch
8. **Selection**: In Select mode, tapping annotation triggers `fetchTrack(for:)` (OpenSky only)

## UI Architecture (tvOS HIG Compliant)

### Tab-Based Navigation
The app uses tvOS TabView with 3 main sections:

1. **Map Tab**: Main flight tracking view with focus-based navigation
   - Nearby Flights List (left, focusable items)
   - Map Controls (right, focusable buttons for zoom/reset)
   - Selected Flight Overlay (modal detail view)

2. **Search Tab**: Dedicated search interface
   - Auto-focused search field
   - Large, focusable result cards
   - Tapping result switches to Map tab with flight centered

3. **Settings Tab**: Configuration viewer
   - Focusable setting rows
   - Shows current API provider, refresh rate, location

### Focus-Based Interaction (ContentView.swift)
All UI elements follow tvOS focus system:
- `.focusable()` modifier on interactive elements
- `@Environment(\.isFocused)` for visual feedback
- Scale (1.05x) and brightness changes when focused
- Smooth animations (0.2s ease-in-out)

### Siri Remote Navigation

#### Tab Bar (Default State)
- **Swipe Left/Right**: Switch between tabs
- **Click/Down on Map tab**: Enter map mode
- **Click/Down on Search tab**: Enter search mode
- **Click/Down on Settings tab**: Enter settings mode

#### Map Mode (After entering Map tab)
- **Direction Buttons (Hold)**: Continuous pan or zoom (based on current mode)
  - In Pan Mode: Up/Down/Left/Right moves the map
  - In Zoom Mode: Up/Right zooms in, Down/Left zooms out
- **Center Button (Play/Pause)**: Toggle between Pan and Zoom modes
  - Shows mode indicator for 2 seconds after toggle
- **Back Button (Menu)**: Exit map mode, return to tab bar
  - Note: Up button does NOT exit map mode (only pans)
- **Direction Button Release**: Immediately stops panning/zooming
- **Click on flight**: Open flight detail view

#### Flight Detail View
- **Back Button**: Close detail view, return to map
- **X Button**: Alternative way to close detail view

#### Search Mode
- **Type**: Search flights by callsign, country, or airline
- **Click on result**: Select flight and switch to Map tab with flight centered

### Typography & Spacing (Distance-Optimized)
- **Titles**: 48pt bold (readable from 10 feet)
- **Headers**: 32pt heavy
- **Body**: Title2/Headline
- **Margins**: 60pt (TV-safe areas)
- **Padding**: 24-40pt (generous touch targets)

### Location-Based Features
- **Initial View**: Centers on user location with 5-degree span
- **Viewport Updates**: Map tracks current region for optimized fetching (0.5s debounce)
- **Radius**: 500 statute miles (~250 NM for API limit)
- **tvOS Limitation**: Apple TV doesn't have GPS, uses network-based approximate location or Config.swift defaults
- **Fallback**: Uses center of US (39.8283, -98.5795) if location unavailable
- **Manual Override**: Set `defaultLatitude`/`defaultLongitude` in Config.swift for your region
