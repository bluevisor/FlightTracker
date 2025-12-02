# Setup Instructions

## Location Permissions for tvOS

The app now uses your device location to show nearby flights. You need to add location permissions to the project:

### In Xcode:

1. Select **FlightTracker** target
2. Go to **Info** tab
3. Add the following keys under **Custom tvOS Target Properties**:

   - **Privacy - Location When In Use Usage Description**
     - Value: `Eddie's Flight Tracker uses your location to show nearby flights within 500 miles`

   - **Privacy - Location Always and When In Use Usage Description** (optional)
     - Value: `Eddie's Flight Tracker uses your location to show nearby flights`

### Alternative: Edit Info.plist directly

If you have an Info.plist file, add:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Eddie's Flight Tracker uses your location to show nearby flights within 500 miles</string>
```

## How Location Works

### tvOS Location Limitations

**Important**: Apple TV doesn't have GPS or continuous location services like iPhone/iPad. The app handles this by:

1. **On First Launch**: App requests location permission
2. **Location Detection**:
   - Tries to use Apple TV's approximate location (from network/IP)
   - Falls back to center of US (39.8283, -98.5795) if unavailable
   - You can manually set your region in `Config.swift`
3. **Fetch Radius**: 500 statute miles (~434 nautical miles, capped at 250 NM for API limits)
4. **Dynamic Updates**: As you pan the map, the app can fetch flights for the visible region

### Setting Your Location Manually

Edit `Config.swift` to set your home location:

```swift
static var defaultLatitude: Double = 37.7749   // Your latitude
static var defaultLongitude: Double = -122.4194 // Your longitude
static var defaultRadius: Double = 500.0        // 500 miles
```

**Popular Cities:**
- San Francisco: `37.7749, -122.4194`
- New York: `40.7128, -74.0060`
- Los Angeles: `34.0522, -118.2437`
- Chicago: `41.8781, -87.6298`
- London: `51.5074, -0.1278`
- Tokyo: `35.6762, 139.6503`

## API Provider

The default API is now `adsb.lol` which provides:
- Fast 1-second updates
- Regional coverage (250 NM radius)
- No authentication required

To change back to OpenSky or use other providers, edit `Config.swift`:
```swift
static var provider: ADSBProvider = .adsbLol  // Change to .opensky, .adsbFi, or .airplanesLive
```

## Testing Without Location

If you're testing on simulator without location:
1. In Simulator menu: **Features > Location > Custom Location**
2. Enter coordinates (e.g., 37.7749, -122.4194 for San Francisco)
3. Or set default coordinates in `Config.swift`
