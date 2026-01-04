#!/bin/bash

# This script adds Google URL Scheme to the built Info.plist
PLIST="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

if [ ! -f "$PLIST" ]; then
    echo "⚠️  Info.plist not found at: $PLIST"
    exit 0
fi

echo "📝 Adding URL Scheme to: $PLIST"

# Add CFBundleURLTypes array if it doesn't exist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$PLIST" 2>/dev/null

# Add the first URL type dict
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$PLIST" 2>/dev/null

# Add CFBundleTypeRole
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleTypeRole string Editor" "$PLIST" 2>/dev/null

# Add CFBundleURLSchemes array
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$PLIST" 2>/dev/null

# Add the URL scheme
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string com.googleusercontent.apps.673837093726-u0gq3h8fr7dnea6b8bm917og4o6jut64" "$PLIST" 2>/dev/null

# Verify it was added
if /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes:0:CFBundleURLSchemes:0" "$PLIST" 2>/dev/null | grep -q "com.googleusercontent.apps"; then
    echo "✅ Google URL Scheme successfully added!"
else
    echo "❌ Failed to add URL Scheme"
fi
