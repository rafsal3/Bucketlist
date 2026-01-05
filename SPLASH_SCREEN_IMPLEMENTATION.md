# Splash Screen Implementation

## Overview
Added a minimalistic animated splash screen to the Flutter Bucket List app that displays on app launch.

## Changes Made

### 1. Created `splash_screen.dart`
**Location:** `lib/screens/splash_screen.dart`

**Features:**
- **Fade-in Animation**: Logo smoothly fades in over 900ms
- **Scale Animation**: Logo scales from 0.5x to 1.0x with an elastic bounce effect
- **Theme-Aware**: Adapts background color based on dark/light mode
- **Smooth Transition**: Fades to HomeScreen after 2.5 seconds
- **Minimalistic Design**: Clean, modern aesthetic with subtle shadow effects

**Animation Details:**
- Duration: 1500ms for animations
- Total splash time: 2500ms
- Fade animation: 0-60% of animation timeline
- Scale animation: 0-80% of animation timeline with elastic curve
- Transition to home: 500ms fade transition

**Visual Elements:**
- App logo (120x120) with rounded corners (30px radius)
- Glowing shadow effect using theme primary color
- App name: "Bucket List" (28px, bold, letter-spacing: 1.2)
- Tagline: "Make every moment count" (14px, subtle color)

### 2. Updated `main.dart`
**Changes:**
- Changed import from `home_screen.dart` to `splash_screen.dart`
- Updated `home` widget to show `SplashScreen()` instead of `HomeScreen()`
- SplashScreen automatically navigates to HomeScreen after animation

## How It Works

1. **App Launch**: SplashScreen is shown as the initial route
2. **Animation**: Logo fades in and scales up with a subtle bounce
3. **Auto-Navigation**: After 2.5 seconds, smoothly transitions to HomeScreen
4. **Theme Support**: Background color adapts to user's theme preference

## Testing

To see the splash screen:
1. **Hot Restart** the app (press 'R' in the Flutter terminal, not 'r')
   - Hot reload ('r') won't show the splash screen as it preserves navigation state
   - Hot restart ('R') will restart the app from scratch
2. Or close and reopen the app completely

## Design Philosophy

The splash screen follows modern minimalistic design principles:
- **Clean**: No clutter, just the essentials
- **Smooth**: Fluid animations with proper easing curves
- **Fast**: Quick 2.5s total time to avoid user frustration
- **Branded**: Showcases the app logo with subtle effects
- **Responsive**: Adapts to theme changes seamlessly

## Future Enhancements (Optional)

If you want to enhance the splash screen further, consider:
- Add a loading progress indicator for initial data loading
- Implement Lottie animation for the logo
- Add app version number at the bottom
- Include a "Skip" button for returning users
- Add particle effects or gradient backgrounds

## Files Modified
- ✅ `lib/screens/splash_screen.dart` (NEW)
- ✅ `lib/main.dart` (MODIFIED)

## Dependencies Used
- Flutter's built-in animation framework
- No additional packages required
