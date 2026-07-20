# 🔍 TOGGLE API DEBUG LOGS - Tracking

## 📝 **Debug Logs Added:**

### **Location 1: Toggle Button Click**
**File:** `lib/screens/mechanic/mechanic_dashboard.dart`

```dart
Future<void> _toggleOnlineStatus() async {
  debugPrint('🔘 TOGGLE CLICKED: Current status = $_isOnline');
  
  // ... toggle logic
  
  debugPrint('🔘 TOGGLE: Calling API with new status = $newStatus');
  await _updateOnlineStatus(newStatus, showSnack: true);
  
  debugPrint('🔘 TOGGLE COMPLETE: New status = $_isOnline');
}
```

---

### **Location 2: API Call**
**File:** `lib/services/mechanic_presence_service.dart`

```dart
Future<bool> updateOnlineStatus(bool value, {...}) async {
  debugPrint('🌐 API CALL START: updateOnlineStatus(value=$value, ...)');
  
  // Auth check
  if (headers.isEmpty) {
    debugPrint('❌ API CALL FAILED: No auth headers');
    return false;
  }
  
  // Before API call
  debugPrint('🌐 API CALL: POST $_isActiveUrl');
  debugPrint('🌐 API BODY: $body');
  
  // After API response
  debugPrint('🌐 API RESPONSE: Status=${response.statusCode}, Body=${response.body}');
  
  // Success
  if (response.statusCode == 200 || response.statusCode == 201) {
    debugPrint('✅ API SUCCESS: Status updated to $value');
    return true;
  }
  
  // Failure
  debugPrint('❌ API FAILED: Unexpected status code ${response.statusCode}');
  
  // Error
  debugPrint('❌ API ERROR: $e');
}
```

---

## 🎯 **Expected Terminal Logs:**

### **When Toggle OFFLINE → ONLINE:**
```
🔘 TOGGLE CLICKED: Current status = false
🔘 TOGGLE: Calling API with new status = true
🌐 API CALL START: updateOnlineStatus(value=true, activeRequestId=null)
🌐 API CALL: POST https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/isactive
🌐 API BODY: {"isonline":"true"}
🌐 API RESPONSE: Status=200, Body={"message":"Status updated successfully"}
✅ API SUCCESS: Status updated to true
🟢 Mechanic went ONLINE - Reconnecting WebSocket & starting heartbeat
🚀 MechanicNotificationController: Initializing for mechanic ID: 38
💓 Starting heartbeat for mechanic ID: 38
💚 Heartbeat sent for mechanic ID: 38
🔘 TOGGLE COMPLETE: New status = true
```

---

### **When Toggle ONLINE → OFFLINE:**
```
🔘 TOGGLE CLICKED: Current status = true
🔘 TOGGLE: Calling API with new status = false
🌐 API CALL START: updateOnlineStatus(value=false, activeRequestId=null)
🌐 API CALL: POST https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/isactive
🌐 API BODY: {"isonline":"false"}
🌐 API RESPONSE: Status=200, Body={"message":"Status updated successfully"}
✅ API SUCCESS: Status updated to false
🔴 Mechanic went OFFLINE - Stopping heartbeat & disconnecting WebSocket
🔴 disconnectCompletely - Stopping heartbeat & disconnecting WebSocket
💔 Stopping heartbeat for mechanic ID: 38
🔘 TOGGLE COMPLETE: New status = false
```

---

## 🐛 **Debugging Issues:**

### **Issue 1: API Not Hitting**
**Symptoms:**
```
🔘 TOGGLE CLICKED: Current status = true
🔘 TOGGLE: Calling API with new status = false
(No API logs after this)
```

**Possible Causes:**
1. ❌ No auth headers (check: `❌ API CALL FAILED: No auth headers`)
2. ❌ Network error (check: `❌ API ERROR: ...`)
3. ❌ Timeout (8 seconds default)

**Solutions:**
- Check UserSession().getAuthHeader() returns valid token
- Check internet connection
- Check backend server is running
- Increase timeout if needed

---

### **Issue 2: API Hits But Fails**
**Symptoms:**
```
🌐 API RESPONSE: Status=401, Body={"error":"Unauthorized"}
❌ API FAILED: Unexpected status code 401
```

**Possible Causes:**
1. ❌ Invalid/expired token
2. ❌ Backend authentication issue

**Solutions:**
- Re-login to get fresh token
- Check backend logs for authentication error
- Verify token format in headers

---

### **Issue 3: Button Doesn't Respond**
**Symptoms:**
- Click button, no logs appear at all

**Possible Causes:**
1. ❌ `_isTogglingOnlineStatus` is stuck as `true`
2. ❌ Button disabled
3. ❌ UI not rebuilding

**Solutions:**
- Check: `debugPrint('_isTogglingOnlineStatus: $_isTogglingOnlineStatus');`
- Hot restart the app
- Check if setState() is being called

---

## 📊 **API Endpoint:**

```
POST /api/mechanic/isactive
Authorization: Bearer <token>
Content-Type: application/json

Request Body:
{
  "isonline": "true"  // or "false"
}

Response (Success):
{
  "message": "Status updated successfully"
}
Status: 200 or 201

Response (Error):
{
  "error": "Error message"
}
Status: 4xx or 5xx
```

---

## ✅ **Verification Checklist:**

### **Frontend:**
1. ✅ Click toggle button
2. ✅ See `🔘 TOGGLE CLICKED` log
3. ✅ See `🌐 API CALL START` log
4. ✅ See `🌐 API CALL: POST ...` log
5. ✅ See `🌐 API RESPONSE: Status=200` log
6. ✅ See `✅ API SUCCESS` log
7. ✅ See `🔘 TOGGLE COMPLETE` log

### **Backend:**
1. ✅ Check backend logs for POST `/api/mechanic/isactive`
2. ✅ Check database: mechanic's `isonline` field updated
3. ✅ Check response: 200/201 status code

### **UI:**
1. ✅ Button color changes (green ↔ gray)
2. ✅ Button text changes ("Online" ↔ "Offline")
3. ✅ Snackbar appears ("You are now online/offline")
4. ✅ Loading spinner shows briefly during API call

---

## 🎉 **Result:**

```
✅ Click button → API hits immediately
✅ No delays or timers
✅ Complete visibility via logs
✅ Easy to debug any issues
✅ Backend receives isActive update
✅ Frontend syncs with backend
```

---

**Date:** July 18, 2026  
**Status:** ✅ COMPLETE - Toggle button with full debug logging
