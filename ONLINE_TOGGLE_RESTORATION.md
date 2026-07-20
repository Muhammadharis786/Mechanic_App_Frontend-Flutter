# ✅ ONLINE/OFFLINE TOGGLE BUTTON - RESTORED

## 📍 **Location:**
**AppBar** of Mechanic Dashboard (top-right, before notification bell)

---

## 🎨 **UI Design:**

### **Online State:**
```
┌─────────────────────────┐
│ ● Online               │  ← Green dot + "Online" text
└─────────────────────────┘
   Green border & background
```

### **Offline State:**
```
┌─────────────────────────┐
│ ● Offline              │  ← Gray dot + "Offline" text
└─────────────────────────┘
   Gray border & background
```

### **Loading State:**
```
┌─────────────────────────┐
│ ● Online ⟳            │  ← Spinner while toggling
└─────────────────────────┘
```

---

## 🔧 **Implementation:**

### **State Variables Added:**
```dart
bool _isOnline = false;              // Current online status for AppBar button
bool _isTogglingOnlineStatus = false; // Loading state during toggle
```

### **Functions:**

#### **1. _toggleOnlineStatus() - Button Handler**
```dart
Future<void> _toggleOnlineStatus() async {
  if (_isTogglingOnlineStatus) return;
  
  setState(() => _isTogglingOnlineStatus = true);
  
  // Toggle the status
  final newStatus = !_isOnline;
  
  await _updateOnlineStatus(newStatus, showSnack: true);
  
  if (mounted) {
    setState(() => _isTogglingOnlineStatus = false);
  }
}
```

#### **2. _updateOnlineStatus(bool value) - API Call**
```dart
Future<void> _updateOnlineStatus(bool value, {bool showSnack = true}) async {
  // Calls MechanicPresenceService.instance.updateOnlineStatus()
  // Updates backend isActive field via API
  // Starts/stops heartbeat based on status
  // Starts/stops live location tracking
}
```

---

## 🌐 **Backend API Integration:**

### **API Called:**
```
PUT /api/mechanic/status
Authorization: Bearer <token>

Request Body:
{
  "isActive": true/false
}

Response:
{
  "message": "Status updated successfully"
}
```

### **On Dashboard Load:**
```
GET /api/mechanic/dashboard

Response includes:
{
  "isonline": true/false,
  ...other fields
}
```

The `isonline` field syncs with `_isOnline` state variable.

---

## ⚙️ **Behavior:**

### **When Toggle to ONLINE:**
1. ✅ API call: `PUT /mechanic/status` with `isActive=true`
2. ✅ Start heartbeat (WebSocket ping every N seconds)
3. ✅ Start live location tracking (if in active request)
4. ✅ WebSocket **stays connected** (for incoming requests)
5. ✅ Show snackbar: "You are now online"

### **When Toggle to OFFLINE:**
1. ✅ API call: `PUT /mechanic/status` with `isActive=false`
2. ✅ Stop heartbeat (no more pings)
3. ✅ Stop live location tracking
4. ✅ WebSocket **stays connected** (can still receive emergency requests)
5. ✅ Show snackbar: "You are now offline"

---

## 🔄 **State Synchronization:**

### **Variables Synced:**
```dart
isOnline          // Backend state (from dashboard API)
_isOnline         // AppBar button state
```

Both stay in sync:
- On dashboard load: `_isOnline = isOnline`
- On toggle success: `_isOnline = newValue`

---

## 🎯 **Code Locations:**

### **AppBar (Line ~827):**
```dart
actions: [
  // Online/Offline Toggle
  Padding(
    padding: const EdgeInsets.only(right: 8.0),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isTogglingOnlineStatus ? null : _toggleOnlineStatus,
        child: Container(
          // ... toggle button UI
        ),
      ),
    ),
  ),
  // ... notification bell
]
```

### **State Variables (Line ~52):**
```dart
bool _isOnline = false;
bool _isTogglingOnlineStatus = false;
```

### **Toggle Function (Line ~609):**
```dart
Future<void> _toggleOnlineStatus() async { ... }
```

### **Update Function (Line ~624):**
```dart
Future<void> _updateOnlineStatus(bool value, {bool showSnack = true}) async { ... }
```

### **Dashboard Load Sync (Line ~543):**
```dart
if (data['isonline'] != null) {
  final onlineStatus = data['isonline'];
  isOnline = ...;
  _isOnline = isOnline;  // ← Sync AppBar state
}
```

---

## ✅ **Testing Checklist:**

### **Test 1: Toggle Online → Offline**
1. ✅ Mechanic dashboard open
2. ✅ Button shows "Online" (green)
3. ✅ Click button
4. ✅ Spinner shows during API call
5. ✅ Button changes to "Offline" (gray)
6. ✅ Snackbar: "You are now offline"
7. ✅ Terminal: "🔴 Mechanic went OFFLINE - Stopping heartbeat"

### **Test 2: Toggle Offline → Online**
1. ✅ Button shows "Offline" (gray)
2. ✅ Click button
3. ✅ Spinner shows during API call
4. ✅ Button changes to "Online" (green)
5. ✅ Snackbar: "You are now online"
6. ✅ Terminal: "🟢 Mechanic went ONLINE - Starting heartbeat"

### **Test 3: State Persists After App Restart**
1. ✅ Set status to "Offline"
2. ✅ Close app completely
3. ✅ Reopen app
4. ✅ Dashboard loads
5. ✅ Button shows "Offline" (matches backend state)

### **Test 4: Backend Sync**
1. ✅ Toggle to "Online" in app
2. ✅ Check backend database: `isActive = true`
3. ✅ Toggle to "Offline" in app
4. ✅ Check backend database: `isActive = false`

---

## 🐛 **Debugging:**

### **If button doesn't show:**
```dart
debugPrint('_isOnline: $_isOnline, _isTogglingOnlineStatus: $_isTogglingOnlineStatus');
```

### **If API fails:**
```dart
// Check MechanicPresenceService.instance.updateOnlineStatus() response
// Check backend logs for PUT /mechanic/status
```

### **If state doesn't sync:**
```dart
// Check dashboard API response has "isonline" field
debugPrint('Dashboard data: ${data['isonline']}');
```

---

## 🎉 **Result:**

```
✅ Online/Offline toggle button visible in AppBar
✅ Syncs with backend isActive field
✅ Starts/stops heartbeat correctly
✅ Starts/stops live location tracking
✅ WebSocket stays connected (for emergency requests)
✅ Clean UI with loading states
✅ Snackbar feedback to user
```

---

**Date:** July 18, 2026  
**Status:** ✅ COMPLETE - Toggle button restored with full functionality
