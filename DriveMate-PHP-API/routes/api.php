<?php
// routes/api.php — Central router (no framework needed)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../controllers/AuthController.php';
require_once __DIR__ . '/../controllers/UserController.php';
require_once __DIR__ . '/../controllers/BookingController.php';
require_once __DIR__ . '/../controllers/TripController.php';
require_once __DIR__ . '/../controllers/PaymentController.php';
require_once __DIR__ . '/../controllers/NotificationController.php';
require_once __DIR__ . '/../controllers/ReviewController.php';
require_once __DIR__ . '/../controllers/CarController.php';
require_once __DIR__ . '/../controllers/DriverController.php';
require_once __DIR__ . '/../controllers/DocumentController.php';
require_once __DIR__ . '/../controllers/MapController.php';
require_once __DIR__ . '/../controllers/SupportController.php';
require_once __DIR__ . '/../controllers/SettingsController.php';
require_once __DIR__ . '/../controllers/NegotiationController.php';
require_once __DIR__ . '/../controllers/DriverHiringController.php';
require_once __DIR__ . '/../controllers/PricingController.php';
require_once __DIR__ . '/../controllers/SafetyController.php';
require_once __DIR__ . '/../controllers/PromotionController.php';

// Parse URI — strip /index.php or /drivemate-api prefix
$uri    = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$uri    = str_replace(['/index.php', '/drivemate-api', '/public', '/api'], '', $uri);
$uri    = rtrim($uri, '/');
$method = $_SERVER['REQUEST_METHOD'];

// ─── Route Table ─────────────────────────────────────────────────────────────
$routes = [
    // Auth
    'POST /auth/register'              => [AuthController::class,         'register'],
    'POST /auth/login'                 => [AuthController::class,         'login'],
    'POST /auth/send-otp'              => [AuthController::class,         'sendOtp'],
    'POST /auth/verify-otp'            => [AuthController::class,         'verifyOtp'],
    'POST /auth/forgot-password'       => [AuthController::class,         'forgotPassword'],
    'POST /auth/reset-password'        => [AuthController::class,         'resetPassword'],

    // Users
    'GET /users/profile'               => [UserController::class,         'profile'],
    'PUT /users/profile'               => [UserController::class,         'updateProfile'],
    'POST /users/change-password'      => [UserController::class,         'changePassword'],
    'PUT /users/change-password'       => [UserController::class,         'changePassword'],
    'POST /users/avatar'               => [UserController::class,         'uploadAvatar'],
    'GET /users/list'                  => [UserController::class,         'listUsers'],
    'POST /users/set-language'         => [UserController::class,         'setLanguage'],
    'PUT /users/set-language'          => [UserController::class,         'setLanguage'],

    // Drivers
    'GET /drivers/available'           => [DriverController::class,       'availableDrivers'],
    'GET /drivers/eligible'            => [DriverController::class,       'eligibleDrivers'],
    'GET /drivers/profile-detail'      => [DriverController::class,       'profileDetail'],
    'POST /drivers/smart-match'        => [DriverController::class,       'smartMatch'],
    'POST /drivers/profile'            => [DriverController::class,       'updateProfile'],
    'GET /drivers/profile'             => [DriverController::class,       'getProfile'],
    'POST /drivers/upload-document'    => [DriverController::class,       'uploadDocument'],
    'PUT /admin/drivers/verify'        => [DriverController::class,       'verifyKyc'],
    'POST /admin/drivers/verify'       => [DriverController::class,       'verifyKyc'],
    'POST /drivers/toggle-online'      => [DriverController::class,       'toggleOnline'],
    'GET /drivers/nearby'              => [DriverController::class,       'nearbyDrivers'],
    'GET /drivers/earnings'            => [DriverController::class,       'getEarnings'],

    // Cars & Rentals
    'GET /cars/available'              => [CarController::class,          'availableCars'],
    'POST /cars/add'                   => [CarController::class,          'addCar'],
    'GET /cars/my'                     => [CarController::class,          'myCars'],
    'GET /cars/requests'               => [CarController::class,          'rentalRequests'],
    'PUT /cars/requests/respond'       => [CarController::class,          'respondRequest'],
    'GET /cars/earnings'               => [CarController::class,          'getEarnings'],

    // Bookings
    'POST /bookings/create'            => [BookingController::class,      'create'],
    'POST /bookings/check-availability'=> [BookingController::class,      'checkAvailability'],
    'GET /bookings/check-availability' => [BookingController::class,      'checkAvailability'],
    'POST /bookings/refresh-otp'       => [BookingController::class,      'refreshOtp'],
    'GET /bookings/my'                 => [BookingController::class,      'myBookings'],
    'GET /bookings/detail'             => [BookingController::class,      'getById'],
    'GET /bookings/status'             => [BookingController::class,      'getById'],
    'PUT /bookings/cancel'             => [BookingController::class,      'cancel'],
    'POST /bookings/cancel'            => [BookingController::class,      'cancel'],
    'PUT /bookings/accept'             => [BookingController::class,      'accept'],
    'POST /bookings/accept'            => [BookingController::class,      'accept'],
    'PUT /bookings/reject'             => [BookingController::class,      'reject'],
    'POST /bookings/reject'            => [BookingController::class,      'reject'],
    'GET /bookings/driver-requests'    => [BookingController::class,      'driverRequests'],
    'GET /bookings/all'                => [BookingController::class,      'allBookings'],

    // Trips
    'POST /trips/verify-otp'           => [TripController::class,         'verifyOtp'],
    'POST /trips/arrived'              => [TripController::class,         'arrived'],
    'PUT /trips/arrived'               => [TripController::class,         'arrived'],
    'POST /trips/start'                => [TripController::class,         'start'],
    'PUT /trips/update-location'       => [TripController::class,         'updateLocation'],
    'GET /trips/live-location'         => [TripController::class,         'getLiveLocation'],
    'PUT /trips/complete'              => [TripController::class,         'complete'],
    'GET /trips/history'               => [TripController::class,         'history'],
    'GET /trips/status-history'        => [TripController::class,         'statusHistory'],
    'GET /trips/share-info'            => [TripController::class,         'getShareInfo'],
    'POST /trips/share-trip'           => [TripController::class,         'shareTrip'],

    // Fare Negotiations (Two-Way Negotiable Pricing Engine)
    'POST /negotiation/offer'          => [NegotiationController::class,  'submitOffer'],
    'POST /negotiation/respond'        => [NegotiationController::class,  'respondOffer'],
    'GET /negotiation/history'         => [NegotiationController::class,  'getHistory'],
    'GET /negotiation/status'          => [NegotiationController::class,  'getStatus'],

    // Payments & Wallet
    'POST /payments/create-order'      => [PaymentController::class,      'createOrder'],
    'POST /payments/verify'            => [PaymentController::class,      'verify'],
    'POST /payments/cash-collect'      => [PaymentController::class,      'cashCollect'],
    'GET /payments/invoice'            => [PaymentController::class,      'invoice'],
    'GET /payments/invoice/pdf'        => [PaymentController::class,      'invoicePdf'],
    'GET /payments/wallet'             => [PaymentController::class,      'wallet'],
    'POST /payments/wallet/add-money'  => [PaymentController::class,      'addWalletMoney'],
    'POST /payments/withdraw'          => [PaymentController::class,      'withdraw'],
    'POST /payments/webhook'           => [PaymentController::class,      'webhook'],
    'POST /payments/refund'            => [PaymentController::class,      'refund'],
    'GET /payments/history'            => [PaymentController::class,      'history'],

    // Documents (KYC, DL, RC, Insurance)
    'POST /documents/upload'           => [DocumentController::class,     'upload'],
    'GET /documents/my'                => [DocumentController::class,      'myDocuments'],

    // Notifications
    'POST /notifications/save-token'   => [NotificationController::class, 'saveToken'],
    'POST /notifications/remove-token' => [NotificationController::class, 'removeToken'],
    'GET /notifications/my'            => [NotificationController::class, 'myNotifications'],
    'PUT /notifications/mark-read'     => [NotificationController::class, 'markRead'],

    // Reviews
    'POST /reviews/add'                => [ReviewController::class,       'add'],
    'GET /reviews/driver'              => [ReviewController::class,       'byDriver'],
    'GET /reviews/my'                  => [ReviewController::class,       'myReviews'],

    // Pricing & Smart Fare Calculator (Feature 4)
    'POST /pricing/calculate'          => [PricingController::class,       'calculateFare'],
    'GET /pricing/rules'               => [PricingController::class,       'getRules'],
    'PUT /admin/pricing/rules'         => [PricingController::class,       'updateRule'],
    'POST /admin/pricing/rules'        => [PricingController::class,       'updateRule'],

    // Safety Center & SOS Emergency (Feature 5)
    'GET /safety/contacts'             => [SafetyController::class,        'getContacts'],
    'POST /safety/contacts'            => [SafetyController::class,        'addContact'],
    'DELETE /safety/contacts'          => [SafetyController::class,        'deleteContact'],
    'POST /safety/sos'                 => [SafetyController::class,        'triggerSos'],
    'POST /safety/report-issue'        => [SafetyController::class,        'reportIssue'],
    'GET /safety/emergency-info'       => [SafetyController::class,        'getEmergencyInfo'],

    // Promotions & Rewards (Feature 9)
    'GET /promotions'                  => [PromotionController::class,     'listPromotions'],
    'POST /promotions/validate'        => [PromotionController::class,     'validatePromo'],
    'GET /rewards/my'                  => [PromotionController::class,     'myRewards'],
    'POST /rewards/redeem'             => [PromotionController::class,     'redeemPoints'],

    // Maps & Distance & Fare
    'POST /maps/calculate-fare'        => [MapController::class,          'calculateFare'],
    'GET /maps/geocode'                => [MapController::class,          'geocode'],
    'GET /maps/autocomplete'           => [MapController::class,          'autocomplete'],
    'GET /maps/directions'             => [MapController::class,          'directions'],
    'GET /maps/reverse-geocode'        => [MapController::class,          'reverseGeocode'],

    // Support & Complaints
    'GET /support/faqs'                => [SupportController::class,      'getFaqs'],
    'POST /support/create-ticket'      => [SupportController::class,      'createTicket'],
    'GET /support/my-tickets'          => [SupportController::class,      'myTickets'],
    'GET /admin/support/tickets'       => [SupportController::class,      'listAll'],
    'PUT /admin/support/reply'         => [SupportController::class,      'replyTicket'],

    // System Settings & Analytics Reports
    'GET /settings'                    => [SettingsController::class,     'getSettings'],
    'PUT /admin/settings'              => [SettingsController::class,     'updateSettings'],
    'GET /admin/reports/analytics'     => [SettingsController::class,     'getAnalytics'],

    // Phase 19: Driver-Only Hiring & Location-Based Negotiation
    'POST /driver-hiring/estimate'     => [DriverHiringController::class,  'estimate'],
    'POST /driver-hiring/booking'      => [DriverHiringController::class,  'createBooking'],
    'POST /driver-hiring/offer'        => [DriverHiringController::class,  'submitOffer'],
    'POST /driver-hiring/counter-offer'=> [DriverHiringController::class,  'counterOffer'],
    'POST /driver-hiring/accept-offer' => [DriverHiringController::class,  'acceptOffer'],
    'GET /driver-hiring/negotiation'   => [DriverHiringController::class,  'getNegotiation'],
];

// ─── Dispatch ─────────────────────────────────────────────────────────────────
$key = "$method $uri";

if (preg_match('#^GET /driver-hiring/negotiation/(\d+)$#', $key, $matches)) {
    (new DriverHiringController())->getNegotiation((int)$matches[1]);
    exit;
}

if (isset($routes[$key])) {
    [$class, $action] = $routes[$key];
    (new $class())->$action();
} else {
    Response::error("Route not found: $method $uri", 404);
}
