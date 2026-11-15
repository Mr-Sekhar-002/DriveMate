# 🚗 DriveMate REST API Documentation

> Complete guide for Frontend Developers (Flutter / React Native / Web) connecting to the DriveMate PHP Backend.

**Base URL:**
- Localhost (Browser / iOS Simulator): `http://localhost/drivemate-api`
- Android Emulator: `http://10.0.2.2/drivemate-api`
- Physical Device (LAN): `http://<YOUR_COMPUTER_IP>/drivemate-api`

---

## 🔑 Authentication Flow

All protected endpoints require the **Bearer Token** in the `Authorization` header:

```http
Authorization: Bearer <your_jwt_token_here>
```

When you log in or register, the response contains `data.token`. Save this in local storage (`SharedPreferences` or Secure Storage) and pass it on subsequent requests.

---

## 📋 Endpoint Reference

### 1. Authentication
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `POST` | `/auth/register` | Register new user (customer, driver, or owner) | ❌ |
| `POST` | `/auth/login` | Authenticate with email & password | ❌ |
| `POST` | `/auth/send-otp` | Send SMS OTP for phone verification | ❌ |
| `POST` | `/auth/verify-otp` | Verify phone with OTP code | ❌ |

#### Example: Register User
`POST /auth/register`
```json
{
  "name": "Jane Doe",
  "email": "jane@example.com",
  "phone": "9876543210",
  "password": "Password@123",
  "role": "customer" // customer | driver | owner
}
```

---

### 2. User Profile
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `GET` | `/users/profile` | Get current user's profile | ✅ |
| `PUT` | `/users/profile` | Update user name / phone | ✅ |
| `POST` | `/users/avatar` | Upload avatar (Multipart form `avatar`) | ✅ |

---

### 3. Drivers
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `GET` | `/drivers/available` | List all verified and active drivers | ❌ / ✅ |
| `POST` | `/drivers/profile` | Driver updates DL number, car details | ✅ (Driver role) |
| `GET` | `/drivers/profile` | Get current driver profile & status | ✅ (Driver role) |

---

### 4. Cars & Rentals
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `GET` | `/cars/available?type=self_drive` | Search rentable cars (self_drive / rent_with_driver / both) | ❌ / ✅ |
| `POST` | `/cars/add` | Car Owner lists a new car | ✅ (Owner role) |
| `GET` | `/cars/my` | Car Owner views their listed vehicles | ✅ (Owner role) |

#### Example: Add Car Listing
`POST /cars/add`
```json
{
  "vehicle_type": "SUV",
  "model": "Toyota Fortuner",
  "number_plate": "DL-01-AB-1234",
  "color": "Black",
  "capacity": 7,
  "listing_type": "both",
  "daily_rate": 3500,
  "hourly_rate": 450,
  "description": "Clean SUV for long trips"
}
```

---

### 5. Bookings
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `POST` | `/bookings/create` | Create booking (hire driver, rent car, car+driver) | ✅ |
| `GET` | `/bookings/my` | Customer's booking history | ✅ |
| `GET` | `/bookings/detail?id=1` | Get detailed booking information | ✅ |
| `PUT` | `/bookings/cancel` | Cancel a booking (`booking_id`) | ✅ |
| `GET` | `/bookings/driver-requests` | Driver views pending ride requests | ✅ (Driver role) |
| `PUT` | `/bookings/accept` | Driver accepts ride (`booking_id`) | ✅ (Driver role) |

#### Example: Create Booking
`POST /bookings/create`
```json
{
  "type": "hire_driver", // hire_driver | rent_car | rent_car_driver
  "start_date": "2026-10-10 14:00:00",
  "pickup_location": "Bandra Kurla Complex",
  "destination": "Chhatrapati Shivaji Airport",
  "total_amount": 500.00
}
```

---

### 6. Trips & Live Tracking
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `POST` | `/trips/start` | Driver starts the trip (`booking_id`, lat, lng) | ✅ |
| `PUT` | `/trips/update-location` | Driver app pings GPS every 5s (`trip_id`, lat, lng) | ✅ |
| `GET` | `/trips/live-location?trip_id=1` | Customer app fetches driver live coordinates | ✅ |
| `PUT` | `/trips/complete` | Driver completes trip (calculates fare/dist) | ✅ |
| `GET` | `/trips/history` | User/Driver trip history | ✅ |

---

### 7. Payments & In-App Wallet
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `POST` | `/payments/create-order` | Create order (`booking_id`, `amount`, `payment_method`: razorpay/upi/cash/wallet) | ✅ |
| `POST` | `/payments/verify` | Verify Razorpay or online payment confirmation | ✅ |
| `POST` | `/payments/cash-collect` | Driver or Customer confirms cash received on drop-off | ✅ |
| `GET` | `/payments/invoice?booking_id=1` | Get full itemized tax invoice (GST 5%, fare breakdown) | ✅ |
| `GET` | `/payments/wallet` | Check in-app wallet balance & transaction ledger | ✅ |
| `POST` | `/payments/wallet/add-money` | Add funds to wallet (`amount`) | ✅ |
| `POST` | `/payments/refund` | Refund completed payment (`booking_id`, `to_wallet`: bool) | ✅ |
| `GET` | `/payments/history` | View customer/driver payment transactions | ✅ |
| `POST` | `/payments/webhook` | Razorpay webhook listener for asynchronous event capture | ❌ (Public) |

#### Example 1: Create UPI Order (Dynamic QR Code)
`POST /payments/create-order`
```json
{
  "booking_id": 1,
  "amount": 350.00,
  "payment_method": "upi"
}
```
**Response:**
```json
{
  "success": true,
  "data": {
    "booking_id": 1,
    "amount": 350.00,
    "currency": "INR",
    "payment_method": "upi",
    "upi_vpa": "drivemate@icici",
    "transaction_id": "UPI_C26DFC208067",
    "upi_intent_url": "upi://pay?pa=drivemate@icici&pn=DriveMate%20Mobility&am=350&cu=INR&tn=DriveMate%20Ride%20%231&tr=UPI_C26DFC208067",
    "qr_code_url": "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=...",
    "status": "pending"
  }
}
```

#### Example 2: Cash on Delivery Collection
`POST /payments/cash-collect`
```json
{
  "booking_id": 1,
  "amount": 350.00
}
```

#### Example 3: In-App Wallet Payment
`POST /payments/create-order`
```json
{
  "booking_id": 1,
  "amount": 150.00,
  "payment_method": "wallet"
}
```

#### Example 4: Get Detailed Tax Invoice
`GET /payments/invoice?booking_id=1`
Returns:
- `invoice_number`: `"INV-DM-000001"`
- `customer`: Name, Phone, Email
- `driver`: Name, Phone, Rating, Vehicle Model & Plate
- `fare_breakdown`: Subtotal, CGST (2.5%), SGST (2.5%), Platform Fee, Total
- `payment`: Method, Transaction ID, Status, Timestamp

---

### 8. Documents & KYC
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `POST` | `/documents/upload` | Multipart form: `type` (kyc/rc/dl/insurance) + `document` file | ✅ |
| `GET` | `/documents/my` | Check verification status of uploaded documents | ✅ |

---

### 9. Reviews & Ratings
| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `POST` | `/reviews/add` | Submit rating (1 to 5) & review for a completed booking | ✅ |
| `GET` | `/reviews/driver?driver_id=2` | Fetch reviews and average rating for a driver | ✅ |

---

## 📦 How to Import into Postman
1. Open **Postman**
2. Click **Import** (top left)
3. Select file: `postman_collection.json`
4. All endpoints will be ready with auto-token capture!
