# API Configuration Guide

This guide explains how to switch between different ADS-B data providers in Eddie's Flight Tracker.

## Quick Start

Edit `FlightTracker/Config.swift` and change the provider:

```swift
static var provider: ADSBProvider = .opensky  // Current provider
```

## Available Providers

### 1. OpenSky Network (Default)
```swift
static var provider: ADSBProvider = .opensky
```

**Features:**
- ✅ Global flight coverage
- ✅ Historical flight tracks (yellow path lines)
- ✅ Optional authentication for higher rate limits
- ⏱️ Rate limit: 60 seconds between updates (anonymous)

**Best for:** Viewing flights worldwide, seeing flight paths

---

### 2. adsb.lol
```swift
static var provider: ADSBProvider = .adsbLol
```

**Features:**
- ✅ Fast updates (1 second)
- ✅ No authentication needed
- ❌ Geographic region only (250 NM radius)
- ❌ No historical flight tracks

**Configuration Required:**
```swift
static var defaultLatitude: Double = 37.7749   // San Francisco
static var defaultLongitude: Double = -122.4194
static var defaultRadius: Double = 250.0
```

**Best for:** Real-time tracking in a specific region

---

### 3. adsb.fi
```swift
static var provider: ADSBProvider = .adsbFi
```

**Features:**
- ✅ Fast updates (1 second)
- ✅ No authentication needed
- ❌ Geographic region only (250 NM radius)
- ❌ No historical flight tracks
- ⚠️ Personal, non-commercial use only

**Configuration Required:** (same as adsb.lol)
```swift
static var defaultLatitude: Double = 40.7128   // New York
static var defaultLongitude: Double = -74.0060
static var defaultRadius: Double = 250.0
```

**Best for:** Personal use in a specific region

---

### 4. Airplanes.live
```swift
static var provider: ADSBProvider = .airplanesLive
```

**Features:**
- ✅ Fast updates (1 second)
- ✅ Community-driven
- ✅ No authentication needed
- ❌ Geographic region only (250 NM radius)
- ❌ No historical flight tracks

**Configuration Required:** (same as above)
```swift
static var defaultLatitude: Double = 51.5074   // London
static var defaultLongitude: Double = -0.1278
static var defaultRadius: Double = 250.0
```

**Best for:** Community-supported regional tracking

---

## Geographic Coordinates for Popular Regions

Copy these into `Config.swift` when using regional APIs:

```swift
// United States (Center)
static var defaultLatitude: Double = 39.8283
static var defaultLongitude: Double = -98.5795

// Los Angeles
static var defaultLatitude: Double = 34.0522
static var defaultLongitude: Double = -118.2437

// New York
static var defaultLatitude: Double = 40.7128
static var defaultLongitude: Double = -74.0060

// London
static var defaultLatitude: Double = 51.5074
static var defaultLongitude: Double = -0.1278

// Tokyo
static var defaultLatitude: Double = 35.6762
static var defaultLongitude: Double = 139.6503

// Sydney
static var defaultLatitude: Double = -33.8688
static var defaultLongitude: Double = 151.2093
```

## OpenSky Authentication (Optional)

To get higher rate limits with OpenSky, add credentials to `Secrets.swift`:

```swift
enum Secrets {
    static let clientId = "your-client-id"
    static let clientSecret = "your-client-secret"
}
```

Get credentials at: https://opensky-network.org/

## Feature Comparison

| Feature | OpenSky | adsb.lol | adsb.fi | Airplanes.live |
|---------|---------|----------|---------|----------------|
| Global Coverage | ✅ | ❌ | ❌ | ❌ |
| Regional (250 NM) | N/A | ✅ | ✅ | ✅ |
| Flight Tracks | ✅ | ❌ | ❌ | ❌ |
| Update Frequency | 60s | 1s | 1s | 1s |
| Authentication | Optional | No | No | No |
| Commercial Use | ✅ | ✅ | ❌ | ✅ |

## Troubleshooting

**"Rate limit exceeded"**: Increase `refreshInterval` in Config.swift or switch providers

**"No flights showing"**: For regional APIs, verify your lat/lon coordinates are correct

**"Flight selection not working"**: Only OpenSky supports flight tracks - disable selection for other providers

**Build errors**: Make sure Config.swift is added to your Xcode project target
