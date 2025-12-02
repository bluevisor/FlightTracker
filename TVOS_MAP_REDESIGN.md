# Flight Tracker - tvOS HIG-Compliant Map Redesign

## Executive Summary

Redesigning the flight tracker from a complex three-panel layout to a simple, focus-driven map interface that follows Apple's tvOS Human Interface Guidelines.

**Key Changes:**
- ❌ Remove nearby flight list (left panel)
- ❌ Remove search tab
- ❌ Remove settings tab
- ❌ Remove explicit zoom in/out buttons (no such buttons on Siri Remote)
- ✅ Full-screen map as primary interface
- ✅ Focusable flight annotations
- ✅ Bottom toolbar with 4 essential actions
- ✅ Play/Pause button for zoom control

---

## tvOS Design Principles Applied

### 1. Focus-Driven Interface
**One focused item at a time** - User's attention is always clear and obvious

### 2. Indirect Manipulation
Users don't touch content directly - they navigate spatially using swipes and select with clicks

### 3. 10-Foot Experience
Content must be readable and interactive from across the room (minimum 38pt text, high contrast)

### 4. Siri Remote Constraints
- **Swipe gestures:** Navigate between focusable items
- **Click:** Select focused item
- **Menu button:** Go back / Exit
- **Play/Pause button:** Primary action (we'll use for zoom)
- **NO zoom buttons:** Must use alternative pattern

---

## New Interface Design

```
┌──────────────────────────────────────────────────────────────┐
│                                                               │
│                                                               │
│                     FULL-SCREEN MAP                           │
│                                                               │
│         ✈︎ (focused - scaled 2x, yellow, glowing)            │
│                                                               │
│    ✈︎     ✈︎         ✈︎      ✈︎          ✈︎                    │
│                                                               │
│                                                               │
│  ┌─────────────────────────────────────────────────┐         │
│  │ UAL523 · United Airlines · 35,000 ft · 450 kts │         │
│  │ ▲ Climbing 1,200 ft/min                        │         │
│  └─────────────────────────────────────────────────┘         │
│                                                               │
│  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐            │
│  │ Reset  │  │  Info  │  │  Sort  │  │ Filter │            │
│  │  View  │  │ Card   │  │ Flights│  │ (Off)  │            │
│  └────────┘  └────────┘  └────────┘  └────────┘            │
└──────────────────────────────────────────────────────────────┘
```

---

## Component Breakdown

### 1. Full-Screen Map
- **MapKit hybrid satellite view** with 3D terrain
- No manual pan/zoom controls
- Annotations are the primary interaction
- Map auto-centers on selected flight

### 2. Flight Annotations (Focusable)
Each flight icon is a focusable element:

**Default State:**
- 32pt airplane icon
- White color
- Rotated to heading
- Subtle drop shadow

**Focused State (with swipe navigation):**
- **56pt icon** (1.75x scale)
- **Yellow color**
- **Pulsing glow effect**
- **Label appears:** Callsign + Altitude above icon

**Selected State (after click):**
- **64pt icon** (2x scale)
- Yellow with white stroke
- Info card appears at bottom
- Flight path (yellow line) if available

**Focus Navigation:**
- Swipe Up/Down/Left/Right → Focus moves to nearest flight in that direction
- Natural spatial navigation (no list scrolling)

### 3. Flight Info Card (Bottom Overlay)
Appears when flight is selected (clicked):

```
┌─────────────────────────────────────────────────────┐
│ UAL523 · United Airlines                            │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                     │
│  🌍 United States    ✈️  Boeing 737-800            │
│  📍 35,000 ft MSL    🧭  Heading 245°               │
│  ⚡ 450 kts          ▲  Climbing 1,200 ft/min      │
│                                                     │
│              [×  Close  ·  Menu to dismiss]         │
└─────────────────────────────────────────────────────┘
```

**Styling:**
- 80% screen width, centered
- Ultra-thin material background
- 24pt corner radius
- Heavy shadow for depth
- Slide up transition from bottom

### 4. Bottom Toolbar (Always Visible)
Four large, focusable buttons:

#### Button 1: Reset View
- **Icon:** `location.circle.fill`
- **Label:** "Reset View"
- **Action:** Return map to initial region (user location or default)

#### Button 2: Info Card
- **Icon:** `info.circle.fill`
- **Label:** "Info Card"
- **Action:** Toggle info card for selected flight (or prompt to select one)

#### Button 3: Sort Flights
- **Icon:** `arrow.up.arrow.down.circle`
- **Label:** "Sort Flights"
- **Action:** Opens overlay menu:
  - By Distance (nearest first) - affects focus order
  - By Altitude (highest first)
  - By Speed (fastest first)
  - Alphabetical (A-Z)

#### Button 4: Filter
- **Icon:** `line.3.horizontal.decrease.circle`
- **Label:** "Filter (Off)" / "Filter (On)"
- **Action:** Opens overlay menu:
  - Show All (default)
  - By Country → submenu
  - By Airline → submenu
  - By Altitude Range → submenu

**Toolbar Styling:**
- 280pt button width, 120pt height
- Vertical icon above label
- Ultra-thin material background
- Strong focus feedback (1.15x scale, bright glow)
- 24pt spacing between buttons
- 60pt bottom padding (safe area)

---

## Zoom Control (No Physical Buttons)

Since Siri Remote has no zoom buttons, use **Play/Pause button**:

### Implementation: Zoom Level Toggle

**Three preset zoom levels:**
1. **Close** (1° span) - See individual flights clearly, ~20-30 visible
2. **Medium** (5° span) - Default view, ~100-200 flights
3. **Wide** (20° span) - Regional overview, ~300-500 flights

**Behavior:**
- Press Play/Pause → Cycle: Medium → Close → Wide → Medium → ...
- Animated zoom transition (0.6s ease-in-out)
- HUD appears for 2 seconds showing: "Zoom: Close 🔍"

**Visual Feedback:**
```
┌──────────────────┐
│  Zoom: Close 🔍  │
│  ━━━●━━━━━━━━━━  │
└──────────────────┘
```

---

## User Flows

### Flow 1: Browse and Select Flight

```
User launches app
    ↓
Map appears, bottom toolbar focused by default
    ↓
User swipes UP
    ↓
Focus jumps to nearest flight annotation
(Icon scales to 56pt, turns yellow, pulses)
    ↓
User swipes LEFT/RIGHT/UP/DOWN
    ↓
Focus moves to adjacent flights spatially
    ↓
User clicks on focused flight
    ↓
Flight info card slides up from bottom
Selected flight scales to 64pt, path appears
    ↓
User presses Menu button
    ↓
Info card dismisses, focus returns to flight
```

### Flow 2: Change Zoom Level

```
User anywhere on map
    ↓
Presses Play/Pause button
    ↓
Map animates to "Close" zoom (1° span)
HUD shows "Zoom: Close 🔍" for 2s
Fewer flights visible but larger
    ↓
Presses Play/Pause again
    ↓
Map animates to "Wide" zoom (20° span)
HUD shows "Zoom: Wide 🌍"
More flights visible but smaller
    ↓
Presses Play/Pause again
    ↓
Map returns to "Medium" zoom (5° span)
```

### Flow 3: Sort by Altitude

```
User on map, toolbar focused
    ↓
Navigates to "Sort Flights" button
    ↓
Clicks
    ↓
Overlay menu appears:
  • By Distance
  • By Altitude ← highlighted
  • By Speed
  • Alphabetical
    ↓
Clicks "By Altitude"
    ↓
Menu dismisses
Flights re-sort in focus order
    ↓
User swipes UP
    ↓
Focus moves to HIGHEST altitude flight first
(Can navigate down through flights in altitude order)
```

### Flow 4: Filter by Airline

```
User on toolbar
    ↓
Navigates to "Filter" button
    ↓
Clicks
    ↓
Menu appears:
  • Show All
  • By Country →
  • By Airline →
  • By Altitude Range →
    ↓
Selects "By Airline"
    ↓
Submenu shows active airlines (e.g., UAL, DAL, SWA...)
    ↓
Selects "UAL"
    ↓
Map updates to show only United flights
Filter button shows "Filter (On)"
    ↓
User returns to filter, selects "Show All"
    ↓
All flights visible again
```

---

## Implementation Details

### SwiftUI Structure

```swift
struct ContentView: View {
    @StateObject private var viewModel = FlightViewModel()
    @FocusState private var focusedSection: FocusSection?
    @State private var focusedFlightID: String?
    @State private var showingFlightDetail = false
    @State private var zoomLevel: ZoomLevel = .medium

    enum FocusSection {
        case toolbar
        case map  // When any flight is focused
    }

    enum ZoomLevel {
        case close   // 1° span
        case medium  // 5° span
        case wide    // 20° span

        var span: Double {
            switch self {
            case .close: return 1.0
            case .medium: return 5.0
            case .wide: return 20.0
            }
        }

        var label: String {
            switch self {
            case .close: return "Close 🔍"
            case .medium: return "Medium 🗺️"
            case .wide: return "Wide 🌍"
            }
        }
    }

    var body: some View {
        ZStack {
            // Full-screen map
            Map(position: $viewModel.cameraPosition, interactionModes: []) {
                ForEach(viewModel.flights) { flight in
                    Annotation(flight.formattedCallsign, coordinate: flight.coordinate) {
                        FlightAnnotation(
                            flight: flight,
                            isFocused: focusedFlightID == flight.id,
                            isSelected: viewModel.selectedFlight?.id == flight.id
                        )
                        .focusable()
                        .onTapGesture {
                            selectFlight(flight)
                        }
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .ignoresSafeArea()

            // Flight info card overlay
            if showingFlightDetail, let flight = viewModel.selectedFlight {
                VStack {
                    Spacer()
                    FlightInfoCard(flight: flight)
                        .transition(.move(edge: .bottom))
                        .padding(.bottom, 200) // Above toolbar
                }
            }

            // Bottom toolbar
            VStack {
                Spacer()
                BottomToolbar(
                    onReset: resetMapView,
                    onInfo: toggleFlightInfo,
                    onSort: showSortMenu,
                    onFilter: showFilterMenu
                )
            }
        }
        .onPlayPauseCommand {
            cycleZoomLevel()
        }
    }
}
```

### Flight Annotation View

```swift
struct FlightAnnotation: View {
    let flight: Flight
    let isFocused: Bool
    let isSelected: Bool

    @State private var isPulsing = false

    var iconSize: CGFloat {
        if isSelected { return 64 }
        if isFocused { return 56 }
        return 32
    }

    var iconColor: Color {
        (isFocused || isSelected) ? .yellow : .white
    }

    var body: some View {
        VStack(spacing: 8) {
            // Label (only when focused)
            if isFocused {
                VStack(spacing: 2) {
                    Text(flight.formattedCallsign)
                        .font(.system(size: 28, weight: .bold))
                    Text(flight.formattedAltitude)
                        .font(.system(size: 22, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .shadow(radius: 10)
            }

            // Airplane icon
            Image(systemName: "airplane")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .rotationEffect(.degrees(flight.track ?? 0))
                .foregroundStyle(iconColor)
                .shadow(
                    color: isFocused ? .yellow.opacity(0.8) : .black,
                    radius: isFocused ? 20 : 4
                )
                .scaleEffect(isPulsing && isFocused ? 1.1 : 1.0)
                .animation(
                    isFocused ?
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true) :
                        .default,
                    value: isPulsing
                )
        }
        .onChange(of: isFocused) { _, newValue in
            isPulsing = newValue
        }
    }
}
```

### Bottom Toolbar

```swift
struct BottomToolbar: View {
    let onReset: () -> Void
    let onInfo: () -> Void
    let onSort: () -> Void
    let onFilter: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            ToolbarButton(
                icon: "location.circle.fill",
                label: "Reset View",
                action: onReset
            )

            ToolbarButton(
                icon: "info.circle.fill",
                label: "Info Card",
                action: onInfo
            )

            ToolbarButton(
                icon: "arrow.up.arrow.down.circle",
                label: "Sort Flights",
                action: onSort
            )

            ToolbarButton(
                icon: "line.3.horizontal.decrease.circle",
                label: "Filter",
                action: onFilter
            )
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
        .background(.ultraThinMaterial)
        .ignoresSafeArea(edges: .bottom)
    }
}

struct ToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @Environment(\.isFocused) var isFocused

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                Text(label)
                    .font(.system(size: 24, weight: .semibold))
            }
            .frame(width: 280, height: 120)
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isFocused ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isFocused ? .white : .clear, lineWidth: 3)
        )
        .scaleEffect(isFocused ? 1.15 : 1.0)
        .shadow(radius: isFocused ? 30 : 10)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
```

### Zoom Level Cycling

```swift
func cycleZoomLevel() {
    withAnimation(.easeInOut(duration: 0.6)) {
        switch zoomLevel {
        case .medium:
            zoomLevel = .close
        case .close:
            zoomLevel = .wide
        case .wide:
            zoomLevel = .medium
        }

        // Update map region
        guard let region = viewModel.currentViewRegion else { return }
        let newSpan = MKCoordinateSpan(
            latitudeDelta: zoomLevel.span,
            longitudeDelta: zoomLevel.span
        )
        let newRegion = MKCoordinateRegion(center: region.center, span: newSpan)
        viewModel.cameraPosition = .region(newRegion)
    }

    // Show HUD
    showZoomHUD = true
    Task {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        showZoomHUD = false
    }
}
```

---

## Accessibility

### VoiceOver Labels

```swift
FlightAnnotation()
    .accessibilityLabel("""
        \(flight.formattedCallsign), \
        \(flight.originCountry), \
        altitude \(flight.formattedAltitude), \
        speed \(flight.formattedGroundSpeed), \
        heading \(Int(flight.track ?? 0)) degrees
    """)
    .accessibilityHint("Double-tap to view flight details")
```

### Reduce Motion

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

var pulsAnimation: Animation? {
    if reduceMotion {
        return nil  // No pulsing
    } else {
        return .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
    }
}
```

### High Contrast Mode

Increase stroke widths and use solid colors when high contrast is enabled.

---

## Performance Optimizations

### Limit Visible Flights
```swift
let visibleFlights = viewModel.flights.prefix(100)  // Max 100 annotations for smooth focus
```

### Lazy Loading Annotations
```swift
ForEach(visibleFlights) { flight in
    // Only render flights in viewport
}
```

### Debounce Focus Changes
Prevent rapid focus switching from causing stutters

---

## Testing Checklist

### Critical Paths
- [ ] Can see flights on map from 10 feet away
- [ ] Can focus on a flight with swipe gestures
- [ ] Focused flight is clearly distinguishable (yellow, large, glowing)
- [ ] Can navigate between flights spatially
- [ ] Can select flight and see detail card
- [ ] Can dismiss detail card with Menu button
- [ ] Can cycle zoom levels with Play/Pause button
- [ ] Toolbar buttons are focusable and work
- [ ] No dead ends in focus navigation

### Siri Remote Gestures
- [ ] Swipe Up → Focus moves to nearest flight above
- [ ] Swipe Down → Focus moves to nearest flight below (or toolbar)
- [ ] Swipe Left → Focus moves to flight on left
- [ ] Swipe Right → Focus moves to flight on right
- [ ] Click → Selects focused flight
- [ ] Menu → Dismisses detail / Returns to toolbar
- [ ] Play/Pause → Cycles zoom levels

### Edge Cases
- [ ] No flights → Shows message
- [ ] Only one flight → Focus works
- [ ] 500 flights → Performance acceptable
- [ ] Selected flight flies away → Handle gracefully
- [ ] Network error → Clear error message

---

## Success Metrics

- **Time to select flight:** < 5 seconds
- **Focus navigation errors:** 0 dead ends
- **Frame rate:** 60fps during zoom transitions
- **VoiceOver coverage:** 100% of interactive elements

---

## Files to Modify

1. **ContentView.swift** - Complete rebuild
   - Remove TabView
   - Remove flight list panel
   - Remove search view
   - Remove settings view
   - Remove map controls panel
   - Add full-screen map
   - Add focusable flight annotations
   - Add bottom toolbar
   - Add Play/Pause zoom cycling

2. **FlightViewModel.swift** - Simplify
   - Remove control mode (pan/zoom toggle not needed)
   - Keep zoom function
   - Add sort/filter functions

3. **Config.swift** - Add zoom presets
   - Add `ZoomLevel` enum

4. **CLAUDE.md** - Update docs

---

## Migration Steps

### Phase 1: Simplification (Destructive Changes)
1. ✅ Remove nearby flight list (left panel)
2. ✅ Remove search tab
3. ✅ Remove settings tab
4. ✅ Remove map controls panel (right side)
5. ✅ Remove TabView entirely

### Phase 2: Core Map Interface
6. ⬜ Make map full-screen
7. ⬜ Make flight annotations focusable
8. ⬜ Add focus visual feedback (scale, color, glow, label)
9. ⬜ Test spatial focus navigation

### Phase 3: Toolbar & Actions
10. ⬜ Add bottom toolbar with 4 buttons
11. ⬜ Implement Reset View
12. ⬜ Implement Info Card toggle
13. ⬜ Implement Sort menu
14. ⬜ Implement Filter menu

### Phase 4: Zoom Control
15. ⬜ Add Play/Pause zoom cycling
16. ⬜ Add zoom level HUD indicator
17. ⬜ Test zoom transitions

### Phase 5: Polish
18. ⬜ VoiceOver labels
19. ⬜ Reduce motion support
20. ⬜ Performance testing with 500 flights

---

## Conclusion

This redesign transforms the app from a cluttered three-panel interface into a clean, focus-driven map experience that embraces tvOS conventions:

✅ **Focus-driven** - Clear visual hierarchy, one focused item
✅ **Spatial** - Navigate flights naturally with swipes
✅ **Discoverable** - Bottom toolbar shows available actions
✅ **10-foot optimized** - Large text, high contrast, simple layout
✅ **Siri Remote native** - Uses Play/Pause for zoom, no phantom buttons
✅ **Accessible** - VoiceOver, reduce motion, high contrast support

The map becomes the app. Flights are the content. Everything else supports that core experience.
