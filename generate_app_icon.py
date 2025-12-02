#!/usr/bin/env python3
"""
Generate basic app icons for Eddie's Flight Tracker
Requires: pip install pillow
"""

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("❌ PIL/Pillow not installed. Run: pip3 install pillow")
    exit(1)

import os
import math

def create_gradient(width, height):
    """Create a blue sky gradient background"""
    img = Image.new('RGBA', (width, height))
    draw = ImageDraw.Draw(img)

    # Create gradient from dark blue (top) to light blue (bottom)
    for y in range(height):
        ratio = y / height
        # Sky blue gradient
        r = int(135 + (173 - 135) * ratio)
        g = int(206 + (216 - 206) * ratio)
        b = int(235 + (230 - 235) * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b, 255))

    return img

def draw_airplane(draw, center_x, center_y, size, color=(255, 255, 255)):
    """Draw a simple airplane icon"""
    # Main body (fuselage)
    body_points = [
        (center_x, center_y - size),  # nose
        (center_x + size//6, center_y + size//2),  # bottom right
        (center_x, center_y + size//3),  # bottom center
        (center_x - size//6, center_y + size//2),  # bottom left
    ]
    draw.polygon(body_points, fill=color)

    # Wings
    wing_points = [
        (center_x - size, center_y - size//4),  # left wing tip
        (center_x - size//3, center_y),  # left wing base
        (center_x + size//3, center_y),  # right wing base
        (center_x + size, center_y - size//4),  # right wing tip
    ]
    draw.polygon(wing_points, fill=color)

    # Tail
    tail_points = [
        (center_x - size//3, center_y + size//3),
        (center_x, center_y + size//2),
        (center_x + size//3, center_y + size//3),
    ]
    draw.polygon(tail_points, fill=color)

def create_front_layer(width, height):
    """Create front layer with airplane icon"""
    img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Draw airplane in center
    center_x = width // 2
    center_y = height // 2 - 20
    airplane_size = min(width, height) // 4

    # Draw airplane with slight shadow for depth
    draw_airplane(draw, center_x + 2, center_y + 2, airplane_size, (0, 0, 0, 100))
    draw_airplane(draw, center_x, center_y, airplane_size, (255, 255, 255, 255))

    # Add text
    try:
        # Try to find a system font
        font_paths = [
            "/System/Library/Fonts/Helvetica.ttc",
            "/System/Library/Fonts/SFCompact.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        ]
        font = None
        for font_path in font_paths:
            if os.path.exists(font_path):
                font = ImageFont.truetype(font_path, int(height * 0.12))
                break

        if font:
            text = "FLIGHT TRACKER"
            bbox = draw.textbbox((0, 0), text, font=font)
            text_width = bbox[2] - bbox[0]
            text_x = (width - text_width) // 2
            text_y = height - int(height * 0.2)

            # Text with shadow
            draw.text((text_x + 1, text_y + 1), text, fill=(0, 0, 0, 150), font=font)
            draw.text((text_x, text_y), text, fill=(255, 255, 255, 255), font=font)
    except Exception as e:
        print(f"⚠️  Could not add text: {e}")

    return img

def create_back_layer(width, height):
    """Create back layer with gradient"""
    return create_gradient(width, height)

def create_middle_layer(width, height):
    """Create optional middle layer with clouds"""
    img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Draw some simple cloud shapes
    cloud_color = (255, 255, 255, 80)

    # Left cloud
    draw.ellipse([width*0.1, height*0.3, width*0.3, height*0.5], fill=cloud_color)

    # Right cloud
    draw.ellipse([width*0.7, height*0.4, width*0.9, height*0.6], fill=cloud_color)

    return img

def save_imageset(img, base_path, name):
    """Save image to an imageset folder"""
    imageset_path = os.path.join(base_path, f"{name}.imageset")
    os.makedirs(imageset_path, exist_ok=True)

    # Save 1x
    img.save(os.path.join(imageset_path, f"{name}.png"))

    # Save 2x (doubled size)
    img_2x = img.resize((img.width * 2, img.height * 2), Image.LANCZOS)
    img_2x.save(os.path.join(imageset_path, f"{name}@2x.png"))

    # Create Contents.json
    contents = {
        "images": [
            {
                "filename": f"{name}.png",
                "idiom": "tv",
                "scale": "1x"
            },
            {
                "filename": f"{name}@2x.png",
                "idiom": "tv",
                "scale": "2x"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }

    import json
    with open(os.path.join(imageset_path, "Contents.json"), 'w') as f:
        json.dump(contents, f, indent=2)

    print(f"✅ Created {name} @ 1x and 2x")

def main():
    print("🎨 Generating App Icons for Eddie's Flight Tracker...")

    # Create output directory
    output_dir = "AppIconAssets"
    os.makedirs(output_dir, exist_ok=True)

    # Standard icon size (400x240)
    width, height = 400, 240

    # Generate layers
    print("\n📐 Generating 400x240 icon layers...")
    front = create_front_layer(width, height)
    back = create_back_layer(width, height)
    middle = create_middle_layer(width, height)

    # Save in current directory for easy viewing
    front.save(os.path.join(output_dir, "Front-preview.png"))
    back.save(os.path.join(output_dir, "Back-preview.png"))
    middle.save(os.path.join(output_dir, "Middle-preview.png"))
    print(f"✅ Preview images saved to {output_dir}/")

    # Generate App Store size (1280x768)
    print("\n📐 Generating 1280x768 App Store icon layers...")
    store_width, store_height = 1280, 768
    front_store = create_front_layer(store_width, store_height)
    back_store = create_back_layer(store_width, store_height)
    middle_store = create_middle_layer(store_width, store_height)

    front_store.save(os.path.join(output_dir, "Front-AppStore-preview.png"))
    back_store.save(os.path.join(output_dir, "Back-AppStore-preview.png"))
    middle_store.save(os.path.join(output_dir, "Middle-AppStore-preview.png"))

    print("\n✨ Done! Generated icon layers in 'AppIconAssets/' folder")
    print("\n📋 Next steps:")
    print("1. Open Xcode and navigate to:")
    print("   FlightTracker/Assets.xcassets/App Icon & Top Shelf Image.brandassets/")
    print("\n2. For 'App Icon.imagestack':")
    print("   - Front.imagestacklayer/Content.imageset: Drag Front-preview.png to 1x slot")
    print("   - Back.imagestacklayer/Content.imageset: Drag Back-preview.png to 1x slot")
    print("   - Middle.imagestacklayer/Content.imageset: Drag Middle-preview.png to 1x slot")
    print("\n3. For 'App Icon - App Store.imagestack':")
    print("   - Do the same with Front/Back/Middle-AppStore-preview.png files")
    print("\n4. Clean build (⇧⌘K) and rebuild")
    print("5. Delete app from Apple TV and reinstall")
    print("\n🎉 Your icon should now appear!")

if __name__ == "__main__":
    main()
