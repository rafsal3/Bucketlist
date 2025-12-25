# Backend API Integration Guide

## 📋 Overview

The Flutter app now has a complete API service (`lib/services/api_service.dart`) that connects to the backend server. The authentication system has been updated to support both:
1. **Backend API** (primary) - Real authentication with JWT tokens
2. **Local fallback** (demo) - Hardcoded credentials when backend is unavailable

## 🔧 Files Created/Modified

### Created:
- **`lib/services/api_service.dart`** - Complete API service with all backend endpoints

### Modified:
- **`lib/providers/app_state.dart`** - Added API service import (ready for integration)
- **`lib/screens/login_screen.dart`** - Login UI
- **`lib/screens/register_screen.dart`** - Registration UI

## 🚀 Quick Start

### 1. Start the Backend Server

Make sure your backend server is running:
```bash
# Navigate to your backend directory
cd path/to/backend

# Start the server
npm start
# or
node server.js
```

The server should be running on `http://localhost:5000`

### 2. Configure Base URL

The API service is configured in `lib/services/api_service.dart`:

```dart
static const String baseUrl = kDebugMode
    ? 'http://10.0.2.2:5000/api/v1' // Android Emulator
    : 'http://localhost:5000/api/v1';
```

**Choose the right URL for your setup:**

| Platform | Base URL |
|----------|----------|
| Android Emulator | `http://10.0.2.2:5000/api/v1` |
| iOS Simulator | `http://localhost:5000/api/v1` |
| Physical Device | `http://YOUR_COMPUTER_IP:5000/api/v1` |

To find your computer's IP:
- **Windows**: Run `ipconfig` in Command Prompt
- **Mac/Linux**: Run `ifconfig` in Terminal

### 3. Update AppState to Use API

To fully integrate the backend, update the `login` and `register` methods in `app_state.dart`:

```dart
// Add these fields at the top of AppState class
String? _authToken;
final ApiService _apiService = ApiService();

// Update login method
Future<bool> login(String username, String password) async {
  try {
    // Try backend API first
    final response = await _apiService.login(
      email: username,
      password: password,
    );
    
    _isAuthenticated = true;
    _currentUser = response.email;
    _authToken = response.token;
    _apiService.setToken(_authToken);
    
    await _saveData();
    notifyListeners();
    return true;
  } on ApiException catch (e) {
    debugPrint('API login failed: $e');
    
    // Fallback to hardcoded credentials
    final validCredentials = {
      'demo@bucketlist.com': 'password123',
      'demo': 'password123',
    };
    
    if (validCredentials.containsKey(username) && 
        validCredentials[username] == password) {
      _isAuthenticated = true;
      _currentUser = username;
      await _saveData();
      notifyListeners();
      return true;
    }
    return false;
  }
}

// Update register method
Future<bool> register(String username, String password, {String? name}) async {
  try {
    final response = await _apiService.register(
      email: username,
      password: password,
      name: name ?? username.split('@').first,
    );
    
    _isAuthenticated = true;
    _currentUser = response.email;
    _authToken = response.token;
    _apiService.setToken(_authToken);
    
    await _saveData();
    notifyListeners();
    return true;
  } on ApiException catch (e) {
    debugPrint('API registration failed: $e');
    
    // Fallback to local registration
    if (username.isNotEmpty && password.length >= 6) {
      _isAuthenticated = true;
      _currentUser = username;
      await _saveData();
      notifyListeners();
      return true;
    }
    return false;
  }
}

// Update logout to clear token
Future<void> logout() async {
  _isAuthenticated = false;
  _currentUser = '';
  _authToken = null;
  _apiService.setToken(null);
  await _saveData();
  notifyListeners();
}

// Add getter for API service
ApiService get apiService => _apiService;
```

### 4. Save Token in SharedPreferences

Update `_saveData()` method to persist the auth token:

```dart
Future<void> _saveData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // ... existing code ...
    
    // Save authentication state
    await prefs.setBool('isAuthenticated', _isAuthenticated);
    await prefs.setString('currentUser', _currentUser);
    if (_authToken != null) {
      await prefs.setString('authToken', _authToken!);
    }
  } catch (e) {
    debugPrint('Error saving data: $e');
  }
}
```

And load it in `_loadData()`:

```dart
Future<void> _loadData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // ... existing code ...
    
    // Load authentication state
    _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    _currentUser = prefs.getString('currentUser') ?? '';
    _authToken = prefs.getString('authToken');
    
    // Set token in API service
    if (_authToken != null) {
      _apiService.setToken(_authToken);
    }
    
    // ... rest of the code ...
  }
}
```

## 📚 API Service Usage Examples

### Authentication

```dart
final apiService = ApiService();

// Register
try {
  final response = await apiService.register(
    email: 'user@example.com',
    password: 'password123',
    name: 'John Doe',
  );
  print('Token: ${response.token}');
} on ApiException catch (e) {
  print('Error: ${e.message}');
}

// Login
final response = await apiService.login(
  email: 'user@example.com',
  password: 'password123',
);
```

### Spaces

```dart
// Get all spaces
final spaces = await apiService.getSpaces();

// Create space
final newSpace = await apiService.createSpace(
  name: 'Travel Plans',
  icon: '✈️',
);

// Get single space with categories
final space = await apiService.getSpace('space_123');
```

### Categories

```dart
// Get categories for a space
final categories = await apiService.getCategories('space_123');

// Create category
final category = await apiService.createCategory(
  spaceId: 'space_123',
  name: 'Restaurants',
  icon: '🍽️',
);
```

### Items

```dart
// Create item
final item = await apiService.createItem(
  spaceId: 'space_123',
  text: 'Visit Tokyo',
  categoryId: 'default_places',
  imageUrl: 'https://example.com/tokyo.jpg',
  description: 'Experience cherry blossoms',
);

// Toggle item completion
await apiService.toggleItem('space_123', 'item_123');

// Delete item
await apiService.deleteItem('space_123', 'item_123');
```

### External APIs

```dart
// Search movies
final movies = await apiService.searchMovies('inception');

// Search books
final books = await apiService.searchBooks('1984');
```

## 🔐 Authentication Flow

1. **User logs in/registers** → App calls `apiService.login()` or `apiService.register()`
2. **Backend returns JWT token** → Token is saved in `_authToken` and SharedPreferences
3. **Token is set in API service** → `apiService.setToken(token)`
4. **All subsequent requests** → Automatically include `Authorization: Bearer <token>` header
5. **User logs out** → Token is cleared from memory and SharedPreferences

## 🎯 Testing

### Test with Backend Running

1. Start backend server
2. Run Flutter app
3. Try registering a new account
4. Login with the account
5. Check console for API responses

### Test with Backend Offline

1. Stop backend server
2. Run Flutter app
3. Try logging in with demo credentials:
   - Email: `demo@bucketlist.com`
   - Password: `password123`
4. App should fallback to local authentication

## 🐛 Troubleshooting

### "Connection refused" error

**Problem**: Can't connect to backend

**Solutions**:
1. Make sure backend server is running
2. Check the base URL in `api_service.dart`
3. For Android Emulator, use `10.0.2.2` instead of `localhost`
4. For physical device, use your computer's IP address

### "Unauthorized" error

**Problem**: Token is invalid or expired

**Solutions**:
1. Logout and login again
2. Clear app data
3. Check if backend is using the same secret key

### API calls not working

**Problem**: Requests fail silently

**Solutions**:
1. Check console for error messages
2. Enable debug mode to see API logs
3. Verify backend endpoints match the API service

## 📖 API Documentation

For complete API documentation, refer to:
- **`api-endpoints.json`** - Complete API reference
- **`postman-collection.json`** - Postman collection for testing
- **`api-usage-guide.txt`** - Quick reference guide

## 🔄 Next Steps

1. **Sync Data with Backend**: Update all CRUD operations to use API service
2. **Offline Support**: Implement local caching with sync
3. **Error Handling**: Add better error messages and retry logic
4. **Loading States**: Show loading indicators during API calls
5. **Real-time Updates**: Consider WebSocket for live collaboration

## 📝 Notes

- The current implementation uses a **hybrid approach**: tries backend first, falls back to local
- This ensures the app works even without internet/backend
- For production, you should handle offline mode more gracefully
- Consider implementing proper error boundaries and retry mechanisms
