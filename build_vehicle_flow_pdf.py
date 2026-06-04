from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
    PageBreak,
    ListFlowable,
    ListItem,
)


OUT = "Vehicle_Mechanic_Assistance_System_Complete_Flow.pdf"


styles = getSampleStyleSheet()
styles.add(
    ParagraphStyle(
        name="ReportTitle",
        parent=styles["Title"],
        fontName="Helvetica-Bold",
        fontSize=23,
        leading=28,
        textColor=colors.HexColor("#0B2545"),
        alignment=TA_CENTER,
        spaceAfter=8,
    )
)
styles.add(
    ParagraphStyle(
        name="Subtitle",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=12,
        leading=15,
        textColor=colors.HexColor("#555555"),
        alignment=TA_CENTER,
        spaceAfter=18,
    )
)
styles.add(
    ParagraphStyle(
        name="H1Custom",
        parent=styles["Heading1"],
        fontName="Helvetica-Bold",
        fontSize=16,
        leading=20,
        textColor=colors.HexColor("#2E74B5"),
        spaceBefore=14,
        spaceAfter=7,
    )
)
styles.add(
    ParagraphStyle(
        name="H2Custom",
        parent=styles["Heading2"],
        fontName="Helvetica-Bold",
        fontSize=12.5,
        leading=16,
        textColor=colors.HexColor("#2E74B5"),
        spaceBefore=10,
        spaceAfter=5,
    )
)
styles.add(
    ParagraphStyle(
        name="BodyCustom",
        parent=styles["BodyText"],
        fontName="Helvetica",
        fontSize=10,
        leading=13,
        alignment=TA_LEFT,
        spaceAfter=6,
    )
)
styles.add(
    ParagraphStyle(
        name="Small",
        parent=styles["BodyText"],
        fontName="Helvetica",
        fontSize=8.5,
        leading=11,
        spaceAfter=3,
    )
)


def p(text, style="BodyCustom"):
    return Paragraph(text, styles[style])


def h1(text):
    return Paragraph(text, styles["H1Custom"])


def h2(text):
    return Paragraph(text, styles["H2Custom"])


def bullets(items):
    return ListFlowable(
        [ListItem(p(item), leftIndent=12) for item in items],
        bulletType="bullet",
        leftIndent=18,
        bulletFontName="Helvetica",
        bulletFontSize=8,
    )


def numbers(items):
    return ListFlowable(
        [ListItem(p(item), leftIndent=12) for item in items],
        bulletType="1",
        leftIndent=18,
        bulletFontName="Helvetica",
        bulletFontSize=9,
    )


def safe_cell(value):
    return Paragraph(str(value), styles["Small"])


def table(headers, rows, widths):
    data = [[safe_cell(h) for h in headers]]
    data += [[safe_cell(c) for c in row] for row in rows]
    t = Table(data, colWidths=[w * inch for w in widths], repeatRows=1, hAlign="LEFT")
    t.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#F2F4F7")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.HexColor("#1F4D78")),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#C9D2DC")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 5),
                ("RIGHTPADDING", (0, 0), (-1, -1), 5),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    return t


def callout(title, body):
    t = Table(
        [[Paragraph(f"<b>{title}</b><br/>{body}", styles["Small"])]],
        colWidths=[6.5 * inch],
        hAlign="LEFT",
    )
    t.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F4F6F9")),
                ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#DADCE0")),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 7),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
            ]
        )
    )
    return t


story = []
story.append(p("Vehicle Mechanic Assistance System", "ReportTitle"))
story.append(p("Complete Appointment and Emergency Flow", "Subtitle"))
story.append(
    p(
        "Prepared from Flutter frontend code, WebSocket contracts, and attached backend snippets",
        "Subtitle",
    )
)

story.append(h1("What The App Does"))
story.append(
    p(
        "This application is a vehicle mechanic assistance platform that connects users with nearby mechanics for two main service paths: scheduled appointments and emergency roadside assistance. Users can select their location, choose a service type such as bike mechanic, car mechanic, or puncture repair, submit problem details, track the mechanic, receive real-time status updates, approve or pay charges, and submit feedback. Mechanics receive requests through real-time notifications, accept or reject work, navigate to the customer, update job progress, send charges, confirm cash payment, and complete the job."
    )
)
story.append(
    callout(
        "Source note",
        "The Flutter frontend project was available in the workspace. Backend behavior is described from the attached backend snippets and from the API endpoints, payloads, statuses, and WebSocket topics used by the frontend.",
    )
)
story.append(Spacer(1, 8))

story.append(h1("Main Actors And System Parts"))
story.append(
    bullets(
        [
            "User: books appointments, creates emergency requests, tracks mechanics, approves charges, pays cash, and reviews service.",
            "Mechanic: receives appointment and emergency requests, accepts or rejects them, navigates to the user, updates job status, sends charges, and confirms payment.",
            "Backend API: stores users, mechanics, appointments, service requests, notifications, statuses, prices, payments, earnings, and reviews.",
            "WebSocket/STOMP layer: pushes real-time appointment, emergency, live-location, cancellation, payment, and completion events.",
            "Firebase/FCM layer: supports app notification setup, while the active workflows mostly rely on backend WebSocket topics.",
        ]
    )
)

story.append(h1("Appointment Flow"))
story.append(h2("1. User Creates An Appointment"))
story.append(
    numbers(
        [
            "The user opens the appointment booking screen and selects or picks a location on the map.",
            "The app sends the location to POST /api/user/bookappointment/nearbymechanics to fetch nearby mechanics.",
            "The user selects a service type: All, Puncher, Bike Mechanic, or Car Mechanic.",
            "The user selects appointment date and time, enters address and problem details.",
            "Auto assignment calls POST /api/user/auto/bookappointment.",
            "Manual mechanic selection calls POST /api/user/manual/bookappointment with the mechanic id.",
            "The backend creates an appointment, usually starting at PENDING, and returns appointment details or an appointment id.",
            "The app shows a booking confirmation screen with appointment id, service type, date, time, address, problem, and mechanic information if available.",
        ]
    )
)
story.append(h2("2. Mechanic Receives And Accepts Appointment"))
story.append(
    numbers(
        [
            "The mechanic dashboard initializes the mechanic WebSocket using the logged-in mechanic id.",
            "The mechanic subscribes to /topic/bookappointment/nearbymechanics/{mechanicId}.",
            "When a new appointment arrives, the mechanic gets an overlay or appointment notification.",
            "Appointment Requests fetches GET /api/mechanic/appointments/showmechanicappointments.",
            "PENDING appointments appear under Booking Requests with Accept and Reject actions.",
            "Accept calls GET /api/user/appointment/acceptappointment/{appointmentId}. Backend marks ACCEPTED and notifies the user.",
            "Reject calls GET /api/mechanic/appointment/rejectappointment/{appointmentId}. Backend marks the appointment rejected or unavailable.",
        ]
    )
)
story.append(h2("3. Travel, Arrival, Work, Charges, And Payment"))
story.append(
    numbers(
        [
            "Start Appointment calls GET /api/mechanic/appointment/startappointment/{appointmentId}, moving the appointment to ON_THE_WAY.",
            "The user receives /topic/appointment/on-the-way/{userId} and sees the on-the-way banner.",
            "I Have Arrived calls GET /api/mechanic/appointment/arrived/{appointmentId}. The attached backend code verifies mechanic ownership and only allows this after ON_THE_WAY, then sets ARRIVED.",
            "Start Work calls GET /api/mechanic/appointment/startwork/{appointmentId}. The backend only allows this after ARRIVED and sets IN_PROGRESS.",
            "Work Completed calls GET /api/mechanic/appointment/completework/{appointmentId}. The backend only allows this after IN_PROGRESS and sets WORK_COMPLETED.",
            "Send Charges posts to /api/mechanic/appointment/sencharges/{appointmentId} with appid and finalPrice. Backend sets repairAmount, total amount, paymentStatus = PENDING, and status = PAYMENT_PROCESS.",
            "The user sees visiting charges, repair amount, total amount, and Pay Now.",
            "Cash payment calls GET /api/mechanic/appointment/paynow/{appointmentId}. Backend sets paymentStatus = PAID, status = COMPLETED, paymentMethod = CASH, updates mechanic job count and earnings, and notifies the mechanic.",
            "After payment, the user opens ServiceReviewScreen with serviceType = APPOINTMENT.",
        ]
    )
)

story.append(h2("Appointment Status Timeline"))
story.append(
    table(
        ["Status", "Who Triggers It", "Frontend Action", "Backend Meaning"],
        [
            ("PENDING", "User books appointment", "Shows in mechanic Booking Requests", "Waiting for mechanic decision"),
            ("ACCEPTED", "Mechanic accepts", "Start Appointment becomes available", "Mechanic assigned"),
            ("ON_THE_WAY", "Mechanic starts appointment", "User sees on-the-way; mechanic sees arrival button", "Mechanic travelling"),
            ("ARRIVED", "Mechanic taps arrived", "Mechanic sees Start Work", "Mechanic reached customer"),
            ("IN_PROGRESS", "Mechanic starts work", "Mechanic sees Work Completed", "Service in progress"),
            ("WORK_COMPLETED", "Mechanic completes work", "Mechanic sees Send Charges; user waits for bill", "Work done, charges pending"),
            ("PAYMENT_PROCESS", "Mechanic sends charges", "User sees amount and Pay Now", "Payment pending"),
            ("COMPLETED", "User pays cash", "Review opens; mechanic notified", "Job and payment complete"),
            ("CANCELLED/REJECTED/EXPIRED", "User, mechanic, or timeout", "Moved to Cancelled tab", "No longer active"),
        ],
        [1.25, 1.45, 2.05, 1.75],
    )
)

story.append(PageBreak())
story.append(h1("Emergency Roadside Assistance Flow"))
story.append(h2("1. User Creates Emergency Request"))
story.append(
    numbers(
        [
            "The user starts the emergency/service-request flow and chooses service category such as bike, car, puncture, or other.",
            "The user adds notes and accepts fixed inspection/visiting charges if required.",
            "The map screen resolves selected location and builds payload with serviceType, userNotes, isfixedchargeaccepted, user phone, latitude, longitude, and location name.",
            "The app calls POST /api/service-request/create.",
            "The backend creates a service request and returns requestId.",
            "The frontend stores active request id and subscribes to /topic/request/{requestId}.",
            "The app fetches nearby mechanics using /api/service-request/nearbymechanic and waits while mechanics are notified.",
        ]
    )
)
story.append(h2("2. Mechanic Accepts Emergency Request"))
story.append(
    numbers(
        [
            "Mechanic WebSocket listens to /topic/mechanic/requests/{mechanicId}.",
            "A payload with userLatitude and requestId opens MechanicRequestAlertScreen.",
            "The mechanic sees user information, service details, location, distance, timer, and accept action.",
            "Accept calls POST /api/service-request/accept/{requestId}.",
            "The backend assigns the request to that mechanic and returns merged request/mechanic/user data.",
            "The frontend saves active tracking state, opens MechanicUserMap, and starts live location sending.",
        ]
    )
)
story.append(h2("3. Live Tracking And Arrival Verification"))
story.append(
    numbers(
        [
            "Both sides listen to /topic/request/{requestId}.",
            "The mechanic map also listens to /topic/request/{requestId}/live-location for distance and ETA updates.",
            "The user map shows accepted mechanic, route, distance, ETA, and live movement.",
            "The mechanic taps Have Arrived.",
            "The frontend calls GET /api/service-request/isarrived/{requestId} with current lat/lng query parameters.",
            "The backend verifies physical arrival. If the mechanic is too far, the app shows the remaining distance.",
            "If arrival is accepted, the mechanic stops live tracking and can send charges.",
        ]
    )
)
story.append(h2("4. Charges Approval, Work Completion, Payment, Review"))
story.append(
    numbers(
        [
            "The mechanic enters inspection/final price and posts to /api/service-request/send-final-price with requestId and finalPrice.",
            "The backend sends FINAL_PRICE_SENT to the user request topic.",
            "The user reviews the price and approves it using POST /api/service-request/approve-payment-request.",
            "Approved status becomes APPROVED_PAYMENT_REQUEST or WORK_STARTED depending on backend naming.",
            "When work is finished, mechanic calls GET /api/service-request/work-completed/{requestId}.",
            "User receives WORK_COMPLETED or WAITING_FOR_PAYMENT and sees payment options.",
            "User starts cash payment using POST /api/service-request/paynow/{requestId} with paymentype = CASH.",
            "User screen enters PAYMENT_PENDING and asks user to hand over cash.",
            "Mechanic confirms cash using GET /api/service-request/completed/{requestId}.",
            "Backend completes the request, user receives PAYMENT_DONE/COMPLETED, and ServiceReviewScreen opens with serviceType = EMERGENCY.",
        ]
    )
)

story.append(h2("Emergency Status Timeline"))
story.append(
    table(
        ["State/Status", "User Side", "Mechanic Side", "Backend/Event Meaning"],
        [
            ("CREATED / WAITING", "User waits for mechanic", "Mechanics receive alert", "Request is open and broadcasted"),
            ("ACCEPTED", "Accepted mechanic appears on map", "Mechanic opens navigation map", "Request assigned"),
            ("ARRIVED", "User waits for charges/work", "Mechanic can send price", "Mechanic reached customer"),
            ("FINAL_PRICE_SENT", "User reviews price", "Mechanic waits for approval", "Mechanic submitted charge"),
            ("APPROVED_PAYMENT_REQUEST", "User approved charges", "Mechanic starts work", "Price approval received"),
            ("WORK_COMPLETED", "User sees payment due", "Mechanic waits for payment", "Work finished"),
            ("PAYMENT_PENDING", "User selected cash", "Mechanic confirms cash", "Cash handover active"),
            ("COMPLETED / PAYMENT_DONE", "Review opens", "Mechanic returns to dashboard", "Request closed"),
            ("CANCELLED / EXPIRED", "User exits active flow", "Mechanic alert/map closes", "Request inactive"),
        ],
        [1.45, 1.75, 1.75, 1.55],
    )
)

story.append(PageBreak())
story.append(h1("Real-Time Notifications And Topics"))
story.append(
    table(
        ["Topic", "Receiver", "Purpose"],
        [
            ("/topic/bookappointment/nearbymechanics/{mechanicId}", "Mechanic", "New appointment request"),
            ("/topic/appointment/acceptappointment/{userId}", "User", "Appointment accepted"),
            ("/topic/appointment/final-reject/{userId}", "User", "Appointment rejected"),
            ("/topic/appointment/on-the-way/{userId}", "User", "Mechanic started travelling"),
            ("/topic/appointment/arrived/{userId}", "User", "Mechanic arrived"),
            ("/topic/appointment/in-progress/{userId}", "User", "Mechanic started work"),
            ("/topic/appointment/completework/{userId}", "User", "Work completed"),
            ("/topic/appointment/sendcharges/{userId}", "User", "Charges sent for appointment"),
            ("/topic/appointment/appointmentdone/{mechanicId}", "Mechanic", "Appointment payment completed"),
            ("/topic/mechanic/requests/{mechanicId}", "Mechanic", "Emergency request alert"),
            ("/topic/request/{requestId}", "User and mechanic", "Emergency status, price, approval, cancellation, payment"),
            ("/topic/request/{requestId}/live-location", "User and mechanic", "Live distance and ETA updates"),
        ],
        [3.1, 1.3, 2.1],
    )
)

story.append(h1("Important Backend Endpoints Used By The App"))
story.append(
    table(
        ["Area", "Method", "Endpoint", "Purpose"],
        [
            ("Appointment", "POST", "/api/user/bookappointment/nearbymechanics", "Find nearby mechanics"),
            ("Appointment", "POST", "/api/user/auto/bookappointment", "Create auto appointment"),
            ("Appointment", "POST", "/api/user/manual/bookappointment", "Create manual appointment"),
            ("Appointment", "GET", "/api/user/appointment/acceptappointment/{appointmentId}", "Accept appointment"),
            ("Appointment", "GET", "/api/mechanic/appointment/rejectappointment/{appointmentId}", "Reject appointment"),
            ("Appointment", "GET", "/api/mechanic/appointment/startappointment/{appointmentId}", "Move to ON_THE_WAY"),
            ("Appointment", "GET", "/api/mechanic/appointment/arrived/{appointmentId}", "Move to ARRIVED"),
            ("Appointment", "GET", "/api/mechanic/appointment/startwork/{appointmentId}", "Move to IN_PROGRESS"),
            ("Appointment", "GET", "/api/mechanic/appointment/completework/{appointmentId}", "Move to WORK_COMPLETED"),
            ("Appointment", "POST", "/api/mechanic/appointment/sencharges/{appointmentId}", "Send charges"),
            ("Appointment", "GET", "/api/mechanic/appointment/paynow/{appointmentId}", "Cash payment"),
            ("Emergency", "POST", "/api/service-request/create", "Create emergency request"),
            ("Emergency", "POST", "/api/service-request/accept/{requestId}", "Accept emergency request"),
            ("Emergency", "GET", "/api/service-request/isarrived/{requestId}", "Verify arrival"),
            ("Emergency", "POST", "/api/service-request/send-final-price", "Send final price"),
            ("Emergency", "POST", "/api/service-request/approve-payment-request", "Approve charges"),
            ("Emergency", "GET", "/api/service-request/work-completed/{requestId}", "Mark work completed"),
            ("Emergency", "POST", "/api/service-request/paynow/{requestId}", "Start cash payment"),
            ("Emergency", "GET", "/api/service-request/completed/{requestId}", "Confirm cash and close"),
            ("Review", "POST", "/api/service-request/review/submit", "Submit review"),
        ],
        [0.95, 0.65, 3.0, 1.9],
    )
)

story.append(h1("Key Difference Between Appointment And Emergency"))
story.append(
    bullets(
        [
            "Appointments are scheduled, include date and time, and progress through PENDING, ACCEPTED, ON_THE_WAY, ARRIVED, IN_PROGRESS, WORK_COMPLETED, PAYMENT_PROCESS, and COMPLETED.",
            "Emergency requests are immediate, map-centered, use live mechanic tracking, verify arrival by coordinates, and require user approval of charges before work continues.",
            "Appointment billing uses visitingCharge plus repairAmount. Emergency billing uses arrival/visiting price plus final inspection or service price.",
            "Appointment payment completes from appointment history and notifies the mechanic on appointmentdone. Emergency payment is a cash handover flow where user starts payment and mechanic confirms cash received.",
            "Both flows end with ServiceReviewScreen. Appointment review sends serviceType = APPOINTMENT and appointmentId. Emergency review sends serviceType = EMERGENCY and serviceId.",
        ]
    )
)

story.append(h1("End-To-End Summary"))
story.append(
    p(
        "In the appointment journey, the user schedules a service, the mechanic accepts it, travels, arrives, starts and completes the work, sends charges, receives payment, and the user submits a review. In the emergency journey, the user creates an immediate roadside request, a mechanic accepts and is tracked live, arrival is verified by location, charges are sent and approved, work is completed, cash payment is confirmed, and the user submits a review. The whole system depends on synchronized backend statuses and WebSocket topics so both user and mechanic screens update in near real time."
    )
)


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#666666"))
    canvas.drawCentredString(
        letter[0] / 2,
        0.45 * inch,
        f"Vehicle Mechanic Assistance System - Complete Flow - Page {doc.page}",
    )
    canvas.restoreState()


doc = SimpleDocTemplate(
    OUT,
    pagesize=letter,
    rightMargin=1 * inch,
    leftMargin=1 * inch,
    topMargin=0.85 * inch,
    bottomMargin=0.75 * inch,
)
doc.build(story, onFirstPage=footer, onLaterPages=footer)
print(OUT)
