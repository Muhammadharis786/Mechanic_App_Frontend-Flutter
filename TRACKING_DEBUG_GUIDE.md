# 🐛 TRACKING DEBUG GUIDE - Quick Reference

## 📱 **TERMINAL LOGS TO WATCH**

### **✅ HEALTHY LOGS**

#### **User Side:**
```
🔵 USER POLL: status=WAITING_USER_APPROVAL, type=FINAL_PRICE_SENT, finalPrice=500
🟢 USER: _applyTrackingWorkflow - status=WAITING_USER_APPROVAL, type=FINAL_PRICE_SENT, paymentApproved=false, isPriceReceived=false
🟢 USER: Showing price approval - status=WAITING_USER_APPROVAL, type=FINAL_PRICE_SENT, price=500.0
```

#### **Mechanic Side:**
```
🔵 MECHANIC: Polling API for requestId=510...
🔵 MECHANIC POLL: status=WAITING_FOR_USER_APPROVAL, type=FINAL_PRICE_SENT
🔵 MECHANIC STATE: hasSentPrice=true, workStarted=false, paymentPending=false, workCompleted=false
```

#### **Widget Dispose (Normal):**
```
🔴 USER: Skipping poll - widget disposed or request completed
🔴 MECHANIC: Skipping poll - widget disposed or job completed
```

---

### **🔴 PROBLEM LOGS**

#### **Problem 1: Polling After Dispose (FIXED)**
```
❌ BAD:
🔵 MECHANIC: Polling API for requestId=510...
🔴 MECHANIC: API failed - status=200, mounted=false  ← Widget disposed!
🔵 MECHANIC: Polling API for requestId=510...
🔴 MECHANIC: API failed - status=200, mounted=false  ← Still polling!
```

✅ **Should See Instead:**
```
🔴 MECHANIC: Skipping poll - widget disposed or job completed
(No more polling logs)
```

---

#### **Problem 2: Charge Approval Not Showing (FIXED)**
```
❌ BAD:
🔵 USER POLL: status=WAITING_USER_APPROVAL, type=, finalPrice=null  ← Type & price missing!
🟢 USER: Price=null, status=WAITING_USER_APPROVAL, shouldShowPrice=false  ← Not showing!
```

✅ **Should See Instead:**
```
🔵 USER POLL: status=WAITING_USER_APPROVAL, type=, finalPrice=null
🟢 USER: Showing price approval - status=WAITING_USER_APPROVAL, type=, price=null  ← Shows even without type/price!
```

---

#### **Problem 3: State Mismatch**
```
❌ BAD:
USER:     _isPriceReceived=false, _paymentApproved=false
MECHANIC: _hasSentPrice=true, _workStarted=false
Backend:  status=WAITING_USER_APPROVAL
```

✅ **Should See Instead:**
```
USER:     _isPriceReceived=true, _paymentApproved=false  ← User can approve
MECHANIC: _hasSentPrice=true, _workStarted=false        ← Mechanic waiting
Backend:  status=WAITING_USER_APPROVAL                  ← All synced!
```

---

## 🔍 **DEBUGGING CHECKLIST**

### **When Charge Approval Doesn't Show:**

1. **Check Backend Response:**
```dart
debugPrint('🔵 USER POLL: status=$status, type=$type, finalPrice=${data['finalPrice']}');
```
- ✅ Status should be `WAITING_USER_APPROVAL` OR `WAITING_FOR_USER_APPROVAL`
- ⚠️ Type can be empty (we handle it now)
- ⚠️ Price can be null (we fallback to cache)

2. **Check Frontend State:**
```dart
debugPrint('🟢 USER: _isPriceReceived=$_isPriceReceived, _paymentApproved=$_paymentApproved');
```
- ✅ `_isPriceReceived` should become `true`
- ✅ `_paymentApproved` should be `false`

3. **Check Workflow Application:**
```dart
debugPrint('🟢 USER: Showing price approval - status=$status, type=$type, price=$price');
```
- ✅ This log should appear when charges sent

---

### **When Polling Doesn't Stop:**

1. **Check Mounted Status:**
```dart
debugPrint('🔴 USER: mounted=$mounted, _cancelExitHandled=$_cancelExitHandled');
```
- ✅ Should be `false` after back button
- ✅ Should see "Skipping poll - widget disposed"

2. **Check Timer Cancellation:**
```dart
debugPrint('Timer cancelled: ${_statusPollTimer == null}');
```
- ✅ Timer should be `null` after widget dispose

---

## 🎯 **MANUAL TEST SCENARIOS**

### **Test 1: Normal Flow (Happy Path)**
```
1. User creates request
   → Expected: status=PENDING, polling starts

2. Mechanic accepts
   → Expected: status=ACCEPTED, user sees mechanic marker

3. Mechanic sends charges (Rs. 500)
   → Expected: User sees "Approve Charges: Rs. 500" card
   → Terminal: "🟢 USER: Showing price approval - status=WAITING_USER_APPROVAL"

4. User approves
   → Expected: status=APPROVED_PAYMENT_REQUEST, mechanic can start work

5. Mechanic completes work
   → Expected: User sees "Make Payment" button

6. User pays
   → Expected: Both navigate to review/dashboard
```

---

### **Test 2: Widget Dispose (Battery Test)**
```
1. User creates request
   → Polling starts (every 3s)

2. User presses BACK button
   → Expected: Widget disposed
   → Terminal: "🔴 USER: Skipping poll - widget disposed"
   → Expected: No more API calls in terminal

3. Wait 30 seconds
   → Expected: Still no API calls (battery saved!)
```

---

### **Test 3: Backend Type Missing (Edge Case)**
```
Backend Response:
{
  "status": "WAITING_USER_APPROVAL",
  "type": "",          ← Empty!
  "finalPrice": null   ← Null!
}

Expected Behavior:
✅ User still sees charge approval card
✅ Price shows "N/A" or cached value
✅ Terminal: "🟢 USER: Showing price approval - status=WAITING_USER_APPROVAL, type=, price=null"
```

---

### **Test 4: App Background/Restore (State Sync)**
```
1. User creates request → Mechanic sends charges
   → User sees approval card

2. User minimizes app (home button)
   → Polling paused (app backgrounded)

3. User reopens app after 2 minutes
   → Expected: Charge approval card STILL shows
   → Terminal: State restored from ActiveServiceRequestTracking
```

---

## 🛠️ **QUICK FIXES**

### **Issue: Polling not stopping after dispose**
```dart
// Check dispose method has this:
@override
void dispose() {
  _statusPollTimer?.cancel();  // ← Must be here!
  _statusPollTimer = null;
  super.dispose();
}
```

---

### **Issue: Charge approval not showing**
```dart
// Check _applyTrackingWorkflow has this:
final shouldShowPrice = _statusMeansWaitingForUserApproval(status) ||
    type == 'FINAL_PRICE_SENT' ||
    type == 'PRICE_SENT' ||
    type == 'ARRIVAL_PRICE_SENT';  // ← Multiple fallbacks!
```

---

### **Issue: State not syncing after restart**
```dart
// Check initState has this:
if (widget.resumedTracking != null) {
  _restoreTrackingSync(widget.resumedTracking!);  // ← Must restore!
}
```

---

## 📊 **STATUS → UI MAPPING**

| Backend Status | User UI | Mechanic UI |
|---------------|---------|-------------|
| `PENDING` | "Finding mechanic..." | N/A |
| `ACCEPTED` | "Mechanic on the way" | Show map + navigation |
| `ARRIVED` | Show mechanic at location | "Send Charges" button |
| `WAITING_USER_APPROVAL` | **"Approve Charges"** card | "Waiting for approval" |
| `APPROVED_PAYMENT_REQUEST` | "Work in progress" | "Start Work" button enabled |
| `WORK_STARTED` | "Work in progress" | "Complete Work" button |
| `WORK_COMPLETED` | "Make Payment" button | "Waiting for payment" |
| `PAYMENT_PENDING` | "Payment processing..." | "Payment processing..." |
| `COMPLETED` | Navigate to review | Navigate to dashboard |

---

## 🎨 **STATE FLAGS CHEATSHEET**

### **User Side:**
```dart
_isWaiting          // True after request sent
_isAccepted         // True after mechanic accepts
_isPriceReceived    // True when charges approval UI shown  ← KEY FLAG!
_paymentApproved    // True after user approves charges
_workCompleted      // True when mechanic completes work
_paymentPending     // True during payment processing
```

### **Mechanic Side:**
```dart
_hasArrived         // True after "I Have Arrived" clicked
_hasSentPrice       // True after charges sent  ← KEY FLAG!
_workStarted        // True after user approves charges
_workCompleted      // True after "Work Completed" clicked
_paymentPending     // True during payment processing
```

---

## ⚡ **PERFORMANCE METRICS**

### **Healthy App:**
```
✅ Polling frequency: Every 3 seconds (when widget mounted)
✅ Polling frequency: 0 (when widget disposed)
✅ WebSocket messages: Instant (0ms latency)
✅ State updates: <100ms after backend change
✅ Battery drain: <5% per hour
```

### **Problem App:**
```
❌ Polling frequency: Every 3 seconds (even after dispose!)  ← BAD!
❌ API calls after dispose: 100+ unnecessary calls
❌ Battery drain: >20% per hour
❌ Memory leaks: Growing over time
```

---

## 📞 **BACKEND API REFERENCE**

### **Tracking API:**
```
GET /api/service-request/tracking/{requestId}

Response:
{
  "requestId": 510,
  "status": "WAITING_USER_APPROVAL",  ← Primary field
  "type": "FINAL_PRICE_SENT",         ← Secondary field (optional)
  "finalPrice": 500.0,                ← Tertiary field (optional)
  "mechanicId": 38,
  "mechanicName": "Muhammad Haris",
  ...
}
```

### **Send Charges API:**
```
POST /api/service-request/send-final-price

Request:
{
  "requestId": 510,
  "finalPrice": 500
}

Response:
{
  "message": "Charges sent to customer"
}

WebSocket Broadcast:
Topic: /topic/request/510
{
  "type": "FINAL_PRICE_SENT",
  "status": "WAITING_USER_APPROVAL",
  "finalPrice": 500
}
```

---

**Last Updated:** July 17, 2026  
**Version:** 2.0 - Post Sync Fix
