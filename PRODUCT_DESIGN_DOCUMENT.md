# Eddie's Flight Tracker - Product Design Document

## Executive Summary

Eddie's Flight Tracker is a real-time flight tracking application for Apple TV (tvOS) that displays live aircraft data from multiple ADS-B providers on an interactive 3D map using SwiftUI and MapKit.

**Current Status**: The application has critical UX issues that make it difficult or impossible to use with the Siri Remote. This document analyzes the current implementation, identifies design flaws, and proposes solutions.

---

## Critical UX Issues

### 1. **Navigation State Machine is Broken**

#### Issue: Conflicting Focus Models
The app tries to combine two incompatible focus paradigms:
- **Tab-based navigation** (standard tvOS TabView)
- **Manual "map mode" state** (custom `isInMapMode` flag)

**Current Flow (Broken)**:
```
User on Map tab → Presses Down → isInMapMode = true → Presses Back → isInMapMode = false → Still on Map tab but can't interact
```

**Problems**:
1. User must press Down to "enter map mode" before they can pan/zoom (ContentView.swift:442-450)
2. Pressing Back exits map mode but doesn't return to tab bar (ContentView.swift:181-186)
3. Up button doesn't exit map mode, creating asymmetric navigation
4. Flight list on left is not focusable - user cannot select flights from the list
5. Search results can be selected but lack proper focus management
6. No visual indicator showing current focus state or available actions

#### Root Cause
- Mixing SwiftUI's automatic focus system with manual state flags
- Using `.focusable()` on the entire map view instead of individual interactive elements
- `onMoveCommand` captures all directional input globally, preventing default focus behavior

---

### 2. **Flight List is Non-Interactive**

#### Issue: Display-Only Flight List
The left sidebar shows "Nearby Flights" but users cannot navigate or select them.

**Current Implementation** (ContentView.swift:228-264):
```swift
ScrollView {
    LazyVStack(spacing: 8) {
        ForEach(Array(viewModel.flights.prefix(15))) { flight in
            FlightListItem(flight: flight, isSelected: ...)
                .onTapGesture { selectFlight(flight) }  // ❌ Tap doesn't work on tvOS!
        }
    }
}
```

**Problems**:
1. `.onTapGesture` does nothing on tvOS - requires click on focused item
2. No `.focusable()` modifier on list items
3. No visual focus feedback (@Environment(\.isFocused))
4. List is positioned but never receives focus

---

### 3. **Map Controls Are Invisible and Unintuitive**

#### Issue: Hidden Control Scheme
Users must discover through trial and error that:
- Down = Enter map mode
- Play/Pause = Toggle pan/zoom mode
- Directional buttons = Pan or zoom (depending on mode)
- Back = Exit map mode

**Problems**:
1. No on-screen control hints or tutorial
2. Mode indicator appears only AFTER toggling (ContentView.swift:137-157)
3. No persistent UI showing available actions
4. Control mode toggle is never explained

---

### 4. **Search to Map Transition Loses Context**

#### Issue: Jarring Context Switch
When user selects flight from search (ContentView.swift:334-338):
```swift
.onTapGesture {
    searchSelection = flight.id
    selectFlight(flight)
    selectedTab = .map  // ❌ Switches tab, but map isn't ready
}
```

**Problems**:
1. Switches to map tab but doesn't enter map mode
2. Flight detail sheet opens, covering the map
3. User can't see the flight on the map they just selected
4. No smooth transition or animation

---

### 5. **Inconsistent State Management**

#### Issue: Scattered State Logic
Selection state is spread across multiple properties:
- `viewModel.selectedFlight` (FlightViewModel.swift:9-13)
- `showingFlightDetail` (ContentView.swift:7)
- `searchSelection` (ContentView.swift:8)
- `isInMapMode` (ContentView.swift:11)

**Problems**:
1. State can become desynchronized
2. Back button behavior differs by context
3. No single source of truth for navigation state

---

### 6. **Performance: Aggressive Refresh Rate**

#### Issue: 3-Second Polling Interval
Config.swift:100-102 sets refresh to 3 seconds, but:
- API providers have 1-60 second rate limits
- Map redraws 500 flight annotations every 3 seconds
- Network requests every 3 seconds drain bandwidth
- FlightViewModel.swift:116-120 timer doesn't respect rate limits

**Problems**:
1. Violates API rate limits (429 errors likely)
2. Unnecessary battery/bandwidth usage
3. Choppy UI updates due to frequent re-renders
4. No exponential backoff on errors

---

### 7. **Map Region Update Debouncing Issues**

#### Issue: Aggressive Re-Fetching
FlightViewModel.swift:125-157 debounces region updates, but:
- Triggers on every 0.1° movement (~7 miles)
- Triggers on 10% zoom change
- Cancels pending fetches, potentially starving data updates
- No coalescing of rapid movements

**Problems**:
1. Panning triggers repeated fetch attempts
2. 0.5s debounce is too short for smooth panning
3. No hysteresis - small movements trigger refetch

---

## Current Architecture Analysis

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                        ContentView                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Map Tab    │  │  Search Tab  │  │ Settings Tab │      │
│  │              │  │              │  │              │      │
│  │ • Map view   │  │ • TextField  │  │ • Unit pickers│     │
│  │ • Flight list│  │ • Result cards│ │ • Info rows  │     │
│  │ • Bottom bar │  │              │  │              │      │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┘      │
│         │                 │                                  │
│         └─────────┬───────┘                                  │
│                   ▼                                          │
│         ┌──────────────────┐                                 │
│         │ FlightViewModel  │                                 │
│         │                  │                                 │
│         │ • flights: [Flight]                               │
│         │ • selectedFlight: Flight?                          │
│         │ • searchText: String                               │
│         │ • cameraPosition: MapCameraPosition                │
│         │ • controlMode: ControlMode (.pan/.zoom/.select)    │
│         └─────────┬────────┘                                 │
│                   │                                          │
│                   ▼                                          │
│         ┌──────────────────┐                                 │
│         │  FlightService   │                                 │
│         │                  │                                 │
│         │ • fetchFlights() │                                 │
│         │ • fetchTrack()   │                                 │
│         │ • OAuth2 token   │                                 │
│         └─────────┬────────┘                                 │
│                   │                                          │
└───────────────────┼──────────────────────────────────────────┘
                    ▼
          ┌────────────────────┐
          │   ADS-B Provider   │
          │                    │
          │ • OpenSky Network  │
          │ • adsb.lol         │
          │ • adsb.fi          │
          │ • airplanes.live   │
          └────────────────────┘
```

### Navigation State Machine (Current - BROKEN)

```
                    ┌──────────────────────────────┐
                    │    App Launch / Tab Bar      │
                    │  (selectedTab: .map/.search) │
                    └──────────┬───────────────────┘
                               │
                ┌──────────────┼──────────────────┐
                │              │                   │
         ┌──────▼───────┐ ┌───▼────────┐ ┌───────▼────────┐
         │   Map Tab    │ │ Search Tab │ │  Settings Tab  │
         │ (isInMapMode │ │            │ │                │
         │   = false)   │ │            │ │                │
         └──────┬───────┘ └────────────┘ └────────────────┘
                │
         Press Down (!)
                │
         ┌──────▼────────┐
         │   Map Mode    │ ◄───────────────┐
         │ (isInMapMode  │                  │
         │   = true)     │                  │
         └───┬───────┬───┘                  │
             │       │                      │
    Play/Pause│      │ Directional      Press
      Toggle  │      │ Buttons          Play/Pause
      Mode    │      │ (Pan/Zoom)       (Toggle)
             │       │                      │
         ┌───▼───────▼───┐                  │
         │ Pan Mode or   │──────────────────┘
         │ Zoom Mode     │
         └───────┬───────┘
                 │
           Press Back
                 │
         ┌───────▼──────┐
         │  Exit Map    │
         │   Mode       │
         │ (Back to     │
         │ Map Tab but  │ ❌ USER STUCK HERE
         │ isInMapMode  │    Can't navigate!
         │  = false)    │
         └──────────────┘
```

**Key Problem**: The state machine has a dead state where user is on Map tab but not in map mode, with no way to navigate back to tab bar.

---

## Proposed Design Solutions

### Solution 1: Remove Manual "Map Mode" State

**Approach**: Let SwiftUI's focus system handle navigation naturally.

**Changes**:
1. Remove `isInMapMode` flag entirely
2. Make flight list items focusable with proper focus feedback
3. Add focusable control buttons on the right side of the screen
4. Let default tab bar navigation work (swipe left/right changes tabs)
5. Use focus sections to organize map view

**Benefits**:
- Standard tvOS navigation patterns
- No hidden states
- Discoverable interface
- Matches user expectations

---

### Solution 2: Three-Section Map Layout

**Proposed Layout**:
```
┌─────────────────────────────────────────────────────────────┐
│                     Top Status Bar                          │
│  Eddie's Flight Tracker │  127 Flights │ Updating...        │
└─────────────────────────────────────────────────────────────┘
│                                                              │
│  ┌─────────────┐  ┌───────────────────────┐ ┌────────────┐│
│  │   Flight    │  │                       │ │   Map      ││
│  │   List      │  │        Map            │ │  Controls  ││
│  │             │  │                       │ │            ││
│  │ [Flight 1]  │  │    [Flight Icons]     │ │  [ + ]     ││
│  │ [Flight 2]  │  │                       │ │  Zoom In   ││
│  │ [Flight 3]  │  │                       │ │            ││
│  │ [Flight 4]  │  │                       │ │  [ - ]     ││
│  │ [Flight 5]  │  │                       │ │  Zoom Out  ││
│  │    ...      │  │                       │ │            ││
│  │             │  │                       │ │  [Reset]   ││
│  │             │  │                       │ │  Center    ││
│  └─────────────┘  └───────────────────────┘ └────────────┘│
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Focus Groups**:
1. **Left**: Flight list (vertical navigation)
2. **Center**: Map (read-only, updates when flight selected)
3. **Right**: Controls (vertical navigation: Zoom In, Zoom Out, Reset View)

**Navigation**:
- Swipe **Left/Right**: Move between focus groups or switch tabs
- Swipe **Up/Down**: Navigate within focus group
- **Click**: Select item (flight or control)
- **Back**: Return to tab bar

---

### Solution 3: Smart Flight Selection

**Behavior**:
1. User focuses on flight in left list
2. Flight highlights on map automatically (no selection needed)
3. User clicks to see full details (modal overlay)
4. Back button closes details, focus returns to list

**Benefits**:
- Preview-on-hover behavior (standard tvOS pattern)
- Smooth feedback
- No mode switching

---

### Solution 4: Reduce Refresh Rate

**Proposed Config**:
```swift
static var refreshInterval: TimeInterval {
    switch provider {
    case .opensky:
        return 60.0  // Respect 60s anonymous limit
    case .adsbLol, .adsbFi, .airplanesLive:
        return 5.0   // Conservative 5s for 1 req/sec APIs
    }
}
```

**Additional**:
- Add visual "last updated" timestamp
- Show loading indicator during fetch
- Cache flight data for offline viewing
- Exponential backoff on 429 errors

---

### Solution 5: Unified Navigation State

**Single Source of Truth**:
```swift
enum AppNavigationState {
    case tabBar(selectedTab: Tab)
    case flightDetail(flight: Flight, returnTab: Tab)
}
```

**Benefits**:
- Clear state transitions
- Back button behavior is deterministic
- Easy to add breadcrumb navigation
- Testable state machine

---

## Specific Code Issues to Fix

### ContentView.swift

| Line | Issue | Fix |
|------|-------|-----|
| 11-14 | Manual map mode flags | Remove, use focus sections |
| 180-186 | `.focusable()` on entire map | Remove, make list items focusable |
| 244-252 | `.onTapGesture` on list items | Replace with `.focusable() + .onTapGesture` |
| 438-463 | `handleMoveCommand` captures all input | Remove, use default focus navigation |
| 442-450 | "Enter map mode" with Down button | Remove this interaction pattern |

### FlightViewModel.swift

| Line | Issue | Fix |
|------|-------|-----|
| 30-34 | Four control modes (pan/zoom/select/search) | Simplify to no modes - use focus |
| 116-120 | Timer ignores rate limits | Use provider-specific intervals |
| 159-178 | Aggressive region change detection | Increase thresholds (0.5° center, 50% zoom) |
| 318-333 | `toggleControlMode()` complexity | Remove - no longer needed |

### Config.swift

| Line | Issue | Fix |
|------|-------|-----|
| 100-102 | 3-second refresh hardcoded | Use provider.rateLimit |
| 111-112 | Wrong secret check | Fix to check "YOUR_CLIENT_SECRET_HERE" |

---

## Redesigned User Flows

### Flow 1: Browse and Select Flight

```
1. User opens app → Map tab shown by default
2. Focus is on first flight in left list (visual highlight)
3. Map shows highlighted flight with yellow outline
4. User presses Down → Focus moves to next flight
5. Map updates to highlight new flight
6. User clicks Select → Flight detail modal opens
7. User presses Back → Modal closes, focus returns to list
```

### Flow 2: Search for Flight

```
1. User swipes right → Search tab
2. Focus automatically on search field
3. User types "UAL" → Results appear below
4. User swipes down → Focus on first result card
5. Card scales up (focus effect)
6. User clicks → Flight detail modal opens on search tab
7. Optional: "View on Map" button switches to map tab with flight centered
```

### Flow 3: Zoom Map

```
1. User on Map tab, flight list focused
2. User swipes right → Focus moves to control panel
3. User highlights "Zoom In" button
4. User clicks → Map zooms in 25%
5. User holds Select → Map continuously zooms while held
6. User releases → Zoom stops
```

### Flow 4: Change Settings

```
1. User swipes right → Settings tab
2. Focus on "Speed Unit" picker
3. User clicks → Picker expands
4. User selects "MPH" → Map updates immediately
5. Focus returns to picker (now showing MPH)
```

---

## Implementation Priority

### Phase 1: Critical Fixes (Blocking Issues)
1. ✅ Remove `isInMapMode` state and `handleMoveCommand`
2. ✅ Make flight list items focusable with visual feedback
3. ✅ Add map control buttons (Zoom In/Out/Reset) to right panel
4. ✅ Fix refresh interval to respect API rate limits
5. ✅ Fix secret check in Config.swift

### Phase 2: Navigation Polish
6. ⬜ Add focus sections (left list, right controls)
7. ⬜ Implement highlight-on-focus for flights
8. ⬜ Add "View on Map" button to search results
9. ⬜ Unify navigation state machine

### Phase 3: Performance & UX
10. ⬜ Increase region change thresholds
11. ⬜ Add last updated timestamp
12. ⬜ Add on-screen control hints
13. ⬜ Smooth search-to-map transitions
14. ⬜ Add unit tests for state machine

---

## Design Patterns to Follow

### tvOS Human Interface Guidelines

1. **Focus-Driven Design**
   - All interactive elements must be focusable
   - Visual feedback for focus state (scale, brightness, border)
   - Smooth animations (0.2-0.3s ease-in-out)

2. **Generous Touch Targets**
   - Minimum 250pt width for buttons
   - Adequate spacing (20-40pt) between focusable items

3. **Readable from Distance**
   - Body text: 29-38pt
   - Headlines: 48-76pt
   - High contrast (WCAG AA minimum)

4. **Predictable Navigation**
   - Back button always returns to previous screen
   - Swipe gestures for lateral navigation
   - No hidden modes or gestures

5. **Immediate Feedback**
   - Loading states visible within 0.1s
   - Confirm actions with subtle animations
   - Error messages dismissible with Back

---

## Accessibility Considerations

1. **VoiceOver Support**
   - Add `.accessibilityLabel()` to all interactive elements
   - Announce flight callsign, altitude, speed when focused
   - Announce control mode changes

2. **Reduce Motion**
   - Respect `UIAccessibility.isReduceMotionEnabled`
   - Use crossfade instead of scale for focus changes

3. **High Contrast**
   - Ensure 4.5:1 contrast ratio for text
   - Use stroke on map icons for visibility

---

## Testing Checklist

### Manual Testing
- [ ] Can navigate entire app using only Siri Remote
- [ ] Every interactive element is reachable via focus
- [ ] Back button behavior is consistent across all screens
- [ ] Flight selection works from both list and search
- [ ] Map controls respond correctly
- [ ] Settings changes apply immediately
- [ ] App handles no flights gracefully
- [ ] App handles network errors gracefully
- [ ] App respects API rate limits (no 429 errors)

### Automated Testing
- [ ] Unit tests for FlightViewModel state transitions
- [ ] Unit tests for region change debouncing
- [ ] Integration tests for API provider switching
- [ ] UI tests for navigation flows
- [ ] Performance tests for 500 flight rendering

---

## Conclusion

The current implementation suffers from a fundamental mismatch between SwiftUI's automatic focus management and manual state tracking. By removing the custom "map mode" state and embracing standard tvOS navigation patterns, the app will become:

1. **Intuitive**: Users can navigate without hidden gestures
2. **Reliable**: No dead states or navigation traps
3. **Performant**: Respects API limits and reduces unnecessary renders
4. **Accessible**: Works with VoiceOver and standard input methods

The redesigned three-section layout with focusable flight list and explicit control buttons will provide a polished, professional tvOS experience that matches user expectations from other TV apps.
