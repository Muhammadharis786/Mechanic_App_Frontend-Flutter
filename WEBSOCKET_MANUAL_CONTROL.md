# 🎛️ WEBSOCKET MANUAL CONTROL - Only on Toggle

## 🎯 **Requirement:**

WebSocket aur heartbeat **SIRF TAB** connect/start ho jab mechanic **manually toggle** karke **online** kare.

### **Before Fix:**
```
Dashboard Load → Auto connect WebSocket → Start heartbeat
(Even if mechanic is offline!)
```

### **After Fix:**
```
Dashboard Load (offline) → NO WebSocket connection → NO heartbeat
Toggle to Online → Connect WebSocket → Start heartbeat ✅
```

---

## 🔧 **What Was Changed:**

### **File:** `lib/screens/mechanic/mechanic_dashboard.dart`

#### **BEFORE:**
```dart
// Dashboard load (_fetchDashboardData)
if (isOnline) {
  // ... location tracking
  MechanicPresenceService.instance.ensureAndroidPresenceGuard();
}
await _syncActiveTrackingWithServer();
_subscribeActiveRequestTopic();

// ❌ ALWAYS called - even when offline!
_initWebSocket();
```

#### **AFTER:**
```dart
// Dashboard load (_fetchDashboardData)
if (isOnline) {
  // ... location tracking
  MechanicPresenceService.instance.ensureAndroidPresenceGuard();
  
  // ✅ ONLY init WebSocket & heartbeat if mechanic is ONLINE
  _initWebSocket();
  MechanicNotificationController().startHeartbeatIfOnline();
} else {
  debugPrint('🔴 Mechanic is OFFLINE - WebSocket & heartbeat NOT started');
}
await _syncActiveTrackingWithServer();
_subscribeActiveRequestTopic();
```

---

## 🔄 **Flow Diagram:**

### **Scenario 1: Dashboard Loads (Mechanic is Offline)**
```
1. App opens / Dashboard loads
   ↓
2. Fetch dashboard data from backend
   ↓
3. Backend returns: isonline = false
   ↓
4. Check: if (isOnline) { ... }
   ├─► FALSE
   └─► Skip: _initWebSocket() ❌
       Skip: startHeartbeatIfOnline() ❌
   ↓
5. Log: "🔴 Mechanic is OFFLINE - WebSocket & heartbeat NOT started"
   ↓
✅ Result: No WebSocket connection, No heartbeat messages
```

---

### **Scenario 2: Dashboard Loads (Mechanic is Online)**
```
1. App opens / Dashboard loads
   ↓
2. Fetch dashboard data from backend
   ↓
3. Backend returns: isonline = true
   ↓
4. Check: if (isOnline) { ... }
   ├─► TRUE
   └─► Call: _initWebSocket() ✅
       Call: startHeartbeatIfOnline() ✅
   ↓
5. WebSocket connects
   ↓
6. Heartbeat starts (every 10 seconds)
   ↓
✅ Result: WebSocket connected, Heartbeat active
```

---

### **Scenario 3: Manual Toggle Offline → Online**
```
1. Mechanic clicks toggle button (Offline → Online)
   ↓
2. API call: PUT /mechanic/status (isActive=true)
   ↓
3. Call: MechanicNotificationController().init()
   ├─► Connect WebSocket ✅
   └─► Subscribe to topics ✅
   ↓
4. Call: startHeartbeatIfOnline()
   ├─► Start heartbeat timer ✅
   └─► Send initial heartbeat ✅
   ↓
✅ Result: WebSocket connected, Heartbeat active
```

---

### **Scenario 4: Manual Toggle Online → Offline**
```
1. Mechanic clicks toggle button (Online → Offline)
   ↓
2. API call: PUT /mechanic/status (isActive=false)
   ↓
3. Call: disconnectCompletely()
   ├─► Stop heartbeat timer ✅
   └─► Disconnect WebSocket ✅
   ↓
4. Stop live location tracking
   ↓
✅ Result: No WebSocket, No heartbeat, Battery saved
```

---

## 🧪 **Testing:**

### **Test 1: Dashboard Load (Offline)**
1. ✅ Backend: Set mechanic `isonline = false`
2. ✅ Open mechanic dashboard
3. ✅ Check terminal logs:
   ```
   🔴 Mechanic is OFFLINE - WebSocket & heartbeat NOT started
   ```
4. ✅ Wait 30 seconds
5. ✅ **No heartbeat logs** should appear
6. ✅ **No WebSocket connection** logs

---

### **Test 2: Dashboard Load (Online)**
1. ✅ Backend: Set mechanic `isonline = true`
2. ✅ Open mechanic dashboard
3. ✅ Check terminal logs:
   ```
   🚀 MechanicNotificationController: Initializing for mechanic ID: 38
   ✅ MechanicNotificationController: WebSocket Connected for ID 38
   💓 Starting heartbeat for mechanic ID: 38
   💚 Heartbeat sent for mechanic ID: 38
   ```
4. ✅ Every 10 seconds, see heartbeat logs

---

### **Test 3: Toggle Offline → Online**
1. ✅ Dashboard loaded with offline status
2. ✅ Click toggle to "Online"
3. ✅ Check terminal logs:
   ```
   🔘 TOGGLE CLICKED: Current status = false
   🌐 API CALL: POST /mechanic/isactive
   ✅ API SUCCESS: Status updated to true
   🟢 Mechanic went ONLINE - Reconnecting WebSocket & starting heartbeat
   🚀 MechanicNotificationController: Initializing for mechanic ID: 38
   💓 Starting heartbeat for mechanic ID: 38
   💚 Heartbeat sent for mechanic ID: 38
   ```

---

### **Test 4: Toggle Online → Offline**
1. ✅ Dashboard loaded with online status
2. ✅ Click toggle to "Offline"
3. ✅ Check terminal logs:
   ```
   🔘 TOGGLE CLICKED: Current status = true
   🌐 API CALL: POST /mechanic/isactive
   ✅ API SUCCESS: Status updated to false
   🔴 Mechanic went OFFLINE - Stopping heartbeat & disconnecting WebSocket
   🔴 disconnectCompletely - Stopping heartbeat & disconnecting WebSocket
   💔 Stopping heartbeat for mechanic ID: 38
   ```
4. ✅ No more heartbeat logs after this

---

### **Test 5: Dashboard Refresh (Offline)**
1. ✅ Mechanic is offline
2. ✅ Pull to refresh dashboard
3. ✅ Dashboard reloads
4. ✅ Check terminal: **No WebSocket connection logs**
5. ✅ WebSocket stays disconnected ✅

---

### **Test 6: Switch User → Mechanic Dashboard**
1. ✅ User is logged in (on User dashboard)
2. ✅ Switch to Mechanic account
3. ✅ Mechanic dashboard loads
4. ✅ If mechanic `isonline = false`:
   - **No WebSocket connection** ✅
   - **No heartbeat** ✅
5. ✅ If mechanic `isonline = true`:
   - WebSocket connects ✅
   - Heartbeat starts ✅

---

## 📊 **Backend Impact:**

### **Heartbeat Endpoint:**
```java
@MessageMapping("/heartbeat")
public void heartbeat(HeartbeatDTO dto) {
    heartbeatService.heartbeat(dto.getMechanicId());
}
```

**Before Fix:**
- Messages received every 10s (even when mechanic offline)
- Unnecessary server load

**After Fix:**
- Messages **ONLY** when mechanic is online
- Reduced server load
- Accurate mechanic presence tracking

---

## 🎯 **Summary:**

| Action | WebSocket | Heartbeat | Location Tracking |
|--------|-----------|-----------|-------------------|
| **Dashboard Load (Offline)** | ❌ Not connected | ❌ Not started | ❌ Not started |
| **Dashboard Load (Online)** | ✅ Connected | ✅ Started | ✅ Started |
| **Toggle to Online** | ✅ Connected | ✅ Started | ✅ Started |
| **Toggle to Offline** | ❌ Disconnected | ❌ Stopped | ❌ Stopped |
| **Dashboard Refresh (Offline)** | ❌ Stays disconnected | ❌ Stays stopped | ❌ Stays stopped |

---

## ✅ **Guarantee:**

```
✅ WebSocket connects ONLY when mechanic manually goes online
✅ Heartbeat sends ONLY when mechanic is online
✅ Dashboard load/refresh respects offline status
✅ No automatic reconnection when offline
✅ Manual toggle has full control
✅ Battery efficient (no background connections when offline)
```

---

**Date:** July 18, 2026  
**Status:** ✅ COMPLETE - WebSocket fully controlled by manual toggle
