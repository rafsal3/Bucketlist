# Network Error Fix - TMDB Movie Fetching

## Error Identified

**Error Message:** `ClientException with SocketFailed host lookup: 'api.themoviedb.org'`

**What it means:** Your device cannot connect to the TMDB API server. This is a DNS/network connectivity issue.

## Solutions to Try

### Solution 1: Check Internet Connection ✅
1. **Verify your device has internet access**
   - Open a web browser on your phone
   - Try visiting any website (e.g., google.com)
   - If websites don't load, fix your internet connection first

2. **Switch networks**
   - Try switching from WiFi to Mobile Data (or vice versa)
   - If on WiFi, try a different WiFi network

### Solution 2: Change DNS Settings 🔧
Your device might be using a DNS server that blocks or cannot resolve `api.themoviedb.org`.

**On Android (POCO M2 Pro):**
1. Go to **Settings** → **WiFi**
2. Long press on your connected WiFi network
3. Select **Modify Network** or **Advanced Options**
4. Change **IP Settings** to **Static**
5. Set DNS servers to:
   - **DNS 1:** `8.8.8.8` (Google DNS)
   - **DNS 2:** `8.8.4.4` (Google DNS alternate)
6. Save and reconnect

**Alternative DNS options:**
- Cloudflare: `1.1.1.1` and `1.0.0.1`
- OpenDNS: `208.67.222.222` and `208.67.220.220`

### Solution 3: Use Mobile Data 📱
If WiFi isn't working:
1. Turn off WiFi
2. Enable Mobile Data
3. Try searching for movies again

### Solution 4: Check Firewall/VPN 🛡️
1. If you're using a VPN, try disabling it
2. If you have any firewall apps, check if they're blocking the connection
3. Some corporate or school networks block certain domains

### Solution 5: Test API Access 🧪
Test if you can access the TMDB API from your device:
1. Open a web browser on your phone
2. Visit this URL (replace with actual search):
   ```
   https://api.themoviedb.org/3/search/movie?api_key=cb90429b2fa956590feb66a96a30b763&query=inception
   ```
3. If you see JSON data, the API is accessible
4. If you get an error, the issue is with your network/DNS

### Solution 6: Restart Device 🔄
Sometimes a simple restart fixes network issues:
1. Restart your phone
2. Reconnect to WiFi/Mobile Data
3. Try the app again

## What I've Fixed in the Code

I've updated the error handling to:
- ✅ Detect network/DNS errors specifically
- ✅ Show user-friendly error messages
- ✅ Provide clear guidance when network issues occur
- ✅ Add timeout handling (10 seconds)

## Testing After Fix

1. **Hot reload the app** (press 'r' in the terminal)
2. Try searching for a movie again
3. You should now see a clearer error message:
   - "Network error: Unable to connect to TMDB. Please check your internet connection and try again."

## Still Not Working?

If none of the above solutions work, the issue might be:

1. **API Key Issue** - The TMDB API key might be blocked or expired
   - Get a new API key from https://www.themoviedb.org/
   - Replace the key in `lib/services/tmdb_service.dart`

2. **Regional Restrictions** - Some regions might block TMDB
   - Try using a VPN to a different country
   - Or use mobile data instead of WiFi

3. **App Permissions** - Ensure the app has internet permission
   - Already set in `AndroidManifest.xml` ✅

## Quick Test Checklist

- [ ] Device has internet access (test in browser)
- [ ] Can access other websites/apps
- [ ] Tried both WiFi and Mobile Data
- [ ] Changed DNS to 8.8.8.8
- [ ] Disabled VPN/Firewall
- [ ] Restarted device
- [ ] Can access TMDB API in browser

## Next Steps

1. **Try Solution 2 (Change DNS)** - This is the most likely fix
2. **Test with Mobile Data** - If WiFi DNS is the issue
3. **Let me know the results** - I can help further if needed

The error is now being caught properly and will show you a helpful message!
