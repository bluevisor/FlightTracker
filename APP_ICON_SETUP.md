# Apple TV App Icon Setup Guide

## Why Your Icon Isn't Showing

Apple TV apps require **layered icons** (not flat images like iOS). The icon has 3 layers:
- **Front layer**: Main icon artwork
- **Middle layer**: Optional depth element
- **Back layer**: Background

Currently, your icon layers are empty, which is why no icon appears.

## Quick Fix: Add a Simple Icon

### Option 1: Using SF Symbols (Fastest)

Since you're using the airplane symbol throughout the app, create a simple icon:

1. **Open Xcode**
2. **Navigate to**: `FlightTracker/Assets.xcassets/App Icon & Top Shelf Image.brandassets`
3. **Select**: `App Icon.imagestack`
4. **Click**: `Front.imagestacklayer` → `Content.imageset`

5. **Create a simple icon image:**

   **Using macOS Preview or any graphics app:**
   - Create a 400x240 PNG image
   - Fill with transparent or dark background
   - Add airplane icon/symbol in center (white or blue)
   - Save as `AppIcon-Front.png`

6. **Drag the image** into the Content.imageset 1x slot

7. **Repeat for Back layer** (optional):
   - Click `Back.imagestacklayer` → `Content.imageset`
   - Create 400x240 PNG with gradient or solid color
   - This provides depth when icon tilts on Apple TV

### Option 2: Using Icon Generator Tools

**Recommended Tools:**
- **App Icon Maker**: https://appiconmaker.co
- **MakeAppIcon**: https://makeappicon.com
- **Figma** (free): Create layered design

**Steps:**
1. Create icon design (1024x1024 minimum)
2. Export for tvOS (these tools support tvOS)
3. They'll generate all required layers automatically
4. Import into Xcode

### Option 3: Manual Creation in Figma/Sketch

**Design Requirements:**
- **Front Layer**: 400x240 @ 1x (800x480 @ 2x)
- **Middle Layer**: 400x240 @ 1x (optional)
- **Back Layer**: 400x240 @ 1x
- **App Store**: 1280x768 @ 1x

**Design Tips for Flight Tracker:**
- Use airplane silhouette on Front layer
- Blue gradient or sky background on Back layer
- Optional clouds/contrails on Middle layer
- Keep it simple and recognizable at small sizes

## Required Sizes for tvOS

Your Assets catalog needs these layers filled:

### App Icon.imagestack (400x240)
```
├── Front.imagestacklayer
│   └── Content.imageset
│       ├── 1x: 400x240 px
│       └── 2x: 800x480 px
├── Middle.imagestacklayer (optional)
│   └── Content.imageset
│       ├── 1x: 400x240 px
│       └── 2x: 800x480 px
└── Back.imagestacklayer
    └── Content.imageset
        ├── 1x: 400x240 px
        └── 2x: 800x480 px
```

### App Icon - App Store.imagestack (1280x768)
- Same structure as above
- Used for App Store listing

### Top Shelf Images (Optional but Recommended)
- **Top Shelf Image**: 1920x720 px
- **Top Shelf Image Wide**: 2320x720 px
- Shows when app is highlighted on Apple TV home screen

## Quick Test Icon Creation

### Using SF Symbols (macOS built-in):

```bash
# Open SF Symbols app
open /System/Applications/SF\ Symbols.app

# Find "airplane" symbol
# Export at large size
# Then use Preview to:
# 1. Create new 400x240 blank image
# 2. Paste airplane symbol
# 3. Resize/center it
# 4. Export as PNG
```

### Using Python (if installed):

Create a simple icon programmatically:

```python
from PIL import Image, ImageDraw, ImageFont

# Create front layer
img = Image.new('RGBA', (400, 240), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Draw airplane shape (simple triangle)
draw.polygon([(200, 80), (240, 180), (160, 180)], fill=(255, 255, 255))

# Draw text
try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 36)
    draw.text((120, 190), "Flight Tracker", fill=(255, 255, 255), font=font)
except:
    pass

img.save("AppIcon-Front.png")
print("Created AppIcon-Front.png - drag this into Xcode")
```

## After Adding Images

1. **Clean Build Folder**: Xcode → Product → Clean Build Folder (⇧⌘K)
2. **Delete App from Apple TV**: Long press app icon → Delete
3. **Rebuild and Run**: ⌘R
4. **Icon should now appear**

## Temporary Workaround: App Icon Generator

If you need a quick placeholder:

1. Visit: https://www.canva.com/create/app-icons/
2. Search for "airplane" or "flight" templates
3. Customize with "Eddie's Flight Tracker" text
4. Download as PNG (1024x1024)
5. Use online tool to convert to tvOS layers:
   - https://appicon.co (supports tvOS)

## Verification

After adding images, check in Xcode:
- **Target**: FlightTracker
- **General tab** → **App Icons and Launch Screen**
- Should show: "App Icon & Top Shelf Image"
- Preview should display your icon

## Design Recommendations

For Eddie's Flight Tracker:
- **Front**: White/yellow airplane silhouette on transparent
- **Back**: Deep blue to light blue gradient (sky)
- **Middle**: Optional white clouds or flight path line
- **Style**: Clean, minimal, recognizable at distance

The parallax effect on Apple TV will make the layers move independently when tilted!
