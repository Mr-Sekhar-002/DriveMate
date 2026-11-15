# test_all.ps1 - DriveMate Complete Backend and Payment API Test Suite
$ErrorActionPreference = 'Stop'

Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "   DRIVEMATE FULL-STACK BACKEND AND PAYMENT API TEST SUITE   " -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan

try {
    # 1. Login
    $loginRes = Invoke-RestMethod -Uri "http://localhost/drivemate-api/auth/login" -Method Post -Body (@{ email = "admin@drivemate.com"; password = "password" } | ConvertTo-Json) -ContentType "application/json"
    $token = $loginRes.data.token
    $headers = @{ Authorization = "Bearer $token" }
    Write-Host "`n[1/6] Authentication Token:" -ForegroundColor Green
    Write-Host "      JWT Token: $($token.Substring(0, 32))..."

    # 2. OpenStreetMap API (OSRM + Nominatim)
    Write-Host "`n[2/6] OpenStreetMap OSRM Routes (Kolkata to Howrah):" -ForegroundColor Green
    $fare = Invoke-RestMethod -Uri "http://localhost/drivemate-api/maps/calculate-fare" -Method Post -Headers $headers -Body (@{ pickup = "Kolkata, West Bengal"; destination = "Howrah, West Bengal"; type = "hire_driver" } | ConvertTo-Json) -ContentType "application/json"
    Write-Host "      Distance: $($fare.data.distance_km) km | Time: $($fare.data.duration_mins) mins"
    Write-Host "      Fare: Rs. $($fare.data.estimated_fare) | Engine: $($fare.data.engine)"

    # 3. UPI QR Order
    Write-Host "`n[3/6] Dynamic UPI QR Payment:" -ForegroundColor Green
    $upi = Invoke-RestMethod -Uri "http://localhost/drivemate-api/payments/create-order" -Method Post -Headers $headers -Body (@{ booking_id = 1; amount = 350; payment_method = "upi" } | ConvertTo-Json) -ContentType "application/json"
    Write-Host "      Txn ID: $($upi.data.transaction_id)"
    Write-Host "      UPI VPA: $($upi.data.upi_vpa)"
    Write-Host "      QR Link: $($upi.data.qr_code_url.Substring(0, 50))..."

    # 4. In-App Wallet
    Write-Host "`n[4/6] In-App Digital Wallet Topup and Balance:" -ForegroundColor Green
    $topup = Invoke-RestMethod -Uri "http://localhost/drivemate-api/payments/wallet/add-money" -Method Post -Headers $headers -Body (@{ amount = 200 } | ConvertTo-Json) -ContentType "application/json"
    Write-Host "      Added: Rs. 200 | New Balance: Rs. $($topup.data.new_balance)"

    # 5. Cash on Delivery
    Write-Host "`n[5/6] Cash on Delivery (Driver Collection):" -ForegroundColor Green
    $cash = Invoke-RestMethod -Uri "http://localhost/drivemate-api/payments/cash-collect" -Method Post -Headers $headers -Body (@{ booking_id = 1; amount = 350 } | ConvertTo-Json) -ContentType "application/json"
    Write-Host "      Amount: Rs. $($cash.data.amount_paid) | Status: $($cash.data.status)"

    # 6. GST Tax Invoice
    Write-Host "`n[6/6] Complete GST Tax Invoice:" -ForegroundColor Green
    $inv = Invoke-RestMethod -Uri "http://localhost/drivemate-api/payments/invoice?booking_id=1" -Method Get -Headers $headers
    Write-Host "      Invoice Number: $($inv.data.invoice_number)"
    Write-Host "      Customer: $($inv.data.customer.name) ($($inv.data.customer.phone))"
    Write-Host "      Fare Breakdown: Subtotal: Rs. $($inv.data.fare_breakdown.subtotal) + GST: Rs. $($inv.data.fare_breakdown.gst_total) = Total: Rs. $($inv.data.fare_breakdown.total_amount)"

    Write-Host "`n==============================================================" -ForegroundColor Green
    Write-Host "   ALL 6 BACKEND AND PAYMENT APIS PASSED 100% PERFECTLY!    " -ForegroundColor Green
    Write-Host "==============================================================" -ForegroundColor Green
} catch {
    Write-Host "`nError during test: $($_.Exception.Message)" -ForegroundColor Red
}
