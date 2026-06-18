import '../services/app_state.dart';

/// Central translation class for the entire app.
/// Usage: AppStrings.t('key') — returns Urdu or English based on current language.
class AppStrings {
  static bool get isUrdu => appLanguageController.value.languageCode == 'ur';

  static String t(String key, [Map<String, dynamic>? args]) {
    String value = _all[isUrdu ? 'ur' : 'en']?[key] ?? key;
    if (args != null && args.isNotEmpty) {
      args.forEach((k, v) {
        value = value.replaceAll('{$k}', v.toString());
      });
    }
    return value;
  }

  static const Map<String, Map<String, String>> _all = {
    'en': {
      // ── App General ──
      'appName': 'ONFIX',
      'appTagline': 'Your Vehicle Our Priority',

      // ── Role Selection ──
      'continueAs': 'Continue As',
      'customer': 'Customer',
      'mechanic': 'Mechanic',

      // ── Onboarding ──
      'skip': 'Skip >',
      'next': 'Next',
      'getStarted': 'Get Started',
      'onboard1Title': 'Welcome to OnFix',
      'onboard1Desc': 'Find nearby mechanics easily when your vehicle breaks down.',
      'onboard2Title': 'Book Appointments',
      'onboard2Desc': 'Get a mechanic to service your vehicle at home or on the road.',
      'onboard3Title': 'Fast & Reliable Service',
      'onboard3Desc': 'Quick, reliable support from experts — no matter where you are.',
      'onboard4Title': 'Switch Roles Easily',
      'onboard4Desc': 'Seamlessly switch between being a customer and a service provider anytime.',

      // ── Login / Register ──
      'login': 'Login',
      'register': 'Register',
      'phoneNumber': 'Phone Number',
      'password': 'Password',
      'confirmPassword': 'Confirm Password',
      'forgotPassword': 'Forgot Password?',
      'noAccount': "Don't have an account?",
      'hasAccount': 'Already have an account?',
      'signUp': 'Sign Up',
      'signIn': 'Sign In',
      'welcome': 'Welcome Back!',
      'welcomeSub': 'Sign in to continue',
      'createAccount': 'Create Account',
      'createAccountSub': 'Sign up to get started',
      'fullName': 'Full Name',
      'email': 'Email',
      'name': 'Name',

      // ── Home / Customer ──
      'home': 'Home',
      'emergency': 'Emergency',
      'appointments': 'Appointments',
      'notifications': 'Notifications',
      'profile': 'Profile',
      'settings': 'Settings',
      'myRequests': 'My Requests',
      'nearbyMechanics': 'Nearby Mechanics',
      'requestService': 'Request Service',
      'bookAppointment': 'Book Appointment',
      'searchMechanic': 'Search Mechanic',
      'serviceType': 'Service Type',
      'carService': 'Car Service',
      'bikeService': 'Bike Service',
      'puncherService': 'Puncher Service',
      'engineService': 'Engine Service',

      // ── Map / Emergency ──
      'findingMechanic': 'Finding Mechanic...',
      'mechanicFound': 'Mechanic Found!',
      'mechanicOnWay': 'Mechanic is on the way',
      'trackMechanic': 'Track Mechanic',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'enRoute': 'EN ROUTE',
      'startNavigation': 'START NAVIGATION',
      'iHaveArrived': 'I HAVE ARRIVED',
      'sendCharges': 'SEND CHARGES',
      'workCompleted': 'WORK COMPLETED',
      'waitingApproval': 'Waiting for Approval',
      'waitingPayment': 'Waiting for Payment',
      'confirmPayment': 'CONFIRM PAYMENT RECEIVED',
      'distance': 'Distance',
      'eta': 'ETA',

      // ── Mechanic Dashboard ──
      'dashboard': 'Dashboard',
      'online': 'Online',
      'offline': 'Offline',
      'earnings': 'Earnings',
      'totalEarnings': 'Total Earnings',
      'completedJobs': 'Completed Jobs',
      'activeRequests': 'Active Requests',
      'history': 'History',
      'noRequests': 'No requests yet',
      'accept': 'Accept',
      'reject': 'Reject',
      'emergencyRequest': 'Emergency Request',
      'newRequest': 'New Request!',
      'serviceRequest': 'Service Request',

      // ── Settings ──
      'language': 'Language',
      'nightMode': 'Night Mode',
      'darkTheme': 'Dark Theme',
      'lightTheme': 'Light Theme',
      'english': 'English',
      'urdu': 'Urdu',
      'logout': 'Logout',
      'logoutQ': 'Do you want to log out?',
      'deleteAccount': 'Delete Account',
      'deleteQ': 'All data associated with your account will be erased.',
      'yes': 'Yes',
      'no': 'No',

      // ── Common ──
      'loading': 'Loading...',
      'error': 'Something went wrong',
      'errorGeneric': 'Error: {msg}',
      'retry': 'Retry',
      'save': 'Save',
      'submit': 'Submit',
      'back': 'Back',
      'close': 'Close',
      'ok': 'OK',
      'send': 'Send',
      'notes': 'Notes',
      'noNotes': 'No notes provided.',
      'userNotes': 'User Notes',
      'location': 'Location',
      'userId': 'User ID',
      'status': 'Status',
    },

    'ur': {
      // ── App General ──
      'appName': 'اون فکس',
      'appTagline': 'آپ کی گاڑی، ہماری ذمہ داری',

      // ── Role Selection ──
      'continueAs': 'جاری رکھیں بطور',
      'customer': 'گاہک',
      'mechanic': 'مکینک',

      // ── Onboarding ──
      'skip': 'چھوڑیں >',
      'next': 'آگے',
      'getStarted': 'شروع کریں',
      'onboard1Title': 'اون فکس میں خوش آمدید',
      'onboard1Desc': 'گاڑی خراب ہونے پر قریبی مکینک آسانی سے تلاش کریں۔',
      'onboard2Title': 'اپوائنٹمنٹ بُک کریں',
      'onboard2Desc': 'گھر یا سڑک پر اپنی گاڑی کی سروس کے لیے مکینک بُک کریں۔',
      'onboard3Title': 'تیز اور قابل اعتماد سروس',
      'onboard3Desc': 'ماہرین سے فوری اور قابل اعتماد مدد — چاہے آپ کہیں بھی ہوں۔',
      'onboard4Title': 'آسانی سے کردار بدلیں',
      'onboard4Desc': 'کسی بھی وقت گاہک اور خدمت فراہم کنندہ کے درمیان آسانی سے سوئچ کریں۔',

      // ── Login / Register ──
      'login': 'لاگ ان',
      'register': 'رجسٹر',
      'phoneNumber': 'فون نمبر',
      'password': 'پاس ورڈ',
      'confirmPassword': 'پاس ورڈ کی تصدیق',
      'forgotPassword': 'پاس ورڈ بھول گئے؟',
      'noAccount': 'اکاؤنٹ نہیں ہے؟',
      'hasAccount': 'پہلے سے اکاؤنٹ ہے؟',
      'signUp': 'سائن اپ',
      'signIn': 'سائن ان',
      'welcome': 'خوش آمدید!',
      'welcomeSub': 'جاری رکھنے کے لیے سائن ان کریں',
      'createAccount': 'اکاؤنٹ بنائیں',
      'createAccountSub': 'شروع کرنے کے لیے سائن اپ کریں',
      'fullName': 'پورا نام',
      'email': 'ای میل',
      'name': 'نام',

      // ── Home / Customer ──
      'home': 'ہوم',
      'emergency': 'ایمرجنسی',
      'appointments': 'اپوائنٹمنٹ',
      'notifications': 'اطلاعات',
      'profile': 'پروفائل',
      'settings': 'سیٹنگز',
      'myRequests': 'میری درخواستیں',
      'nearbyMechanics': 'قریبی مکینک',
      'requestService': 'سروس درخواست',
      'bookAppointment': 'اپوائنٹمنٹ بُک کریں',
      'searchMechanic': 'مکینک تلاش کریں',
      'serviceType': 'سروس کی قسم',
      'carService': 'کار سروس',
      'bikeService': 'بائیک سروس',
      'puncherService': 'پنکچر سروس',
      'engineService': 'انجن سروس',

      // ── Map / Emergency ──
      'findingMechanic': 'مکینک تلاش ہو رہا ہے...',
      'mechanicFound': 'مکینک مل گیا!',
      'mechanicOnWay': 'مکینک راستے میں ہے',
      'trackMechanic': 'مکینک کو ٹریک کریں',
      'cancel': 'منسوخ',
      'confirm': 'تصدیق',
      'enRoute': 'راستے میں',
      'startNavigation': 'نیویگیشن شروع کریں',
      'iHaveArrived': 'میں پہنچ گیا',
      'sendCharges': 'چارجز بھیجیں',
      'workCompleted': 'کام مکمل',
      'waitingApproval': 'منظوری کا انتظار',
      'waitingPayment': 'ادائیگی کا انتظار',
      'confirmPayment': 'ادائیگی موصول تصدیق کریں',
      'distance': 'فاصلہ',
      'eta': 'پہنچنے کا وقت',

      // ── Mechanic Dashboard ──
      'dashboard': 'ڈیش بورڈ',
      'online': 'آن لائن',
      'offline': 'آف لائن',
      'earnings': 'آمدنی',
      'totalEarnings': 'کل آمدنی',
      'completedJobs': 'مکمل کام',
      'activeRequests': 'فعال درخواستیں',
      'history': 'تاریخ',
      'noRequests': 'ابھی کوئی درخواست نہیں',
      'accept': 'قبول کریں',
      'reject': 'مسترد کریں',
      'emergencyRequest': 'ایمرجنسی درخواست',
      'newRequest': 'نئی درخواست!',
      'serviceRequest': 'سروس درخواست',

      // ── Settings ──
      'language': 'زبان',
      'nightMode': 'نائٹ موڈ',
      'darkTheme': 'ڈارک تھیم',
      'lightTheme': 'لائٹ تھیم',
      'english': 'انگریزی',
      'urdu': 'اردو',
      'logout': 'لاگ آؤٹ',
      'logoutQ': 'کیا آپ لاگ آؤٹ کرنا چاہتے ہیں؟',
      'deleteAccount': 'اکاؤنٹ ڈیلیٹ کریں',
      'deleteQ': 'آپ کے اکاؤنٹ سے منسلک تمام ڈیٹا ختم ہو جائے گا۔',
      'yes': 'ہاں',
      'no': 'نہیں',

      // ── Common ──
      'loading': 'لوڈ ہو رہا ہے...',
      'error': 'کچھ غلط ہو گیا',
      'errorGeneric': 'خرابی: {msg}',
      'retry': 'دوبارہ کوشش',
      'save': 'محفوظ کریں',
      'submit': 'جمع کریں',
      'back': 'واپس',
      'close': 'بند کریں',
      'ok': 'ٹھیک ہے',
      'send': 'بھیجیں',
      'notes': 'نوٹس',
      'noNotes': 'کوئی نوٹ نہیں۔',
      'userNotes': 'صارف کے نوٹس',
      'location': 'مقام',
      'userId': 'صارف آئی ڈی',
      'status': 'حیثیت',
    },
  };
}
