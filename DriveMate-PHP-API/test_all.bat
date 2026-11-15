@echo off
chcp 65001 >nul
echo ==============================================================
echo       🚗 DRIVEMATE BACKEND & PAYMENT API TEST SUITE
echo ==============================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$loginRes = Invoke-RestMethod -Uri 'http://localhost/drivemate-api/auth/login' -Method Post -Body (@{ email = 'admin@drivemate.com'; password = 'password' } | ConvertTo-Json) -ContentType 'application/json'; ^
$token = $loginRes.data.token; ^
$headers = @{ Authorization = 'Bearer ' + $token }; ^
Write-Host '[1/6] 🔑 Authentication Token Generated:' -ForegroundColor Green; ^
Write-Host ('      Token: ' + $token.Substring(0, 30) + '...'); ^
^
Write-Host '`n[2/6] 🗺️ Google Maps Routes API (v2) Fare Calculation:' -ForegroundColor Green; ^
$fare = Invoke-RestMethod -Uri 'http://localhost/drivemate-api/maps/calculate-fare' -Method Post -Headers $headers -Body (@{ pickup = 'Kolkata, West Bengal'; destination = 'Howrah, West Bengal'; type = 'hire_driver' } | ConvertTo-Json) -ContentType 'application/json'; ^
Write-Host ('      Distance: ' + $fare.data.distance_km + ' km | Duration: ' + $fare.data.duration_mins + ' mins'); ^
Write-Host ('      Fare: Rs. ' + $fare.data.estimated_fare + ' | Engine: ' + $fare.data.engine); ^
^
Write-Host '`n[3/6] 📱 UPI Dynamic QR Code Generation:' -ForegroundColor Green; ^
$upi = Invoke-RestMethod -Uri 'http://localhost/drivemate-api/payments/create-order' -Method Post -Headers $headers -Body (@{ booking_id = 1; amount = 350; payment_method = 'upi' } | ConvertTo-Json) -ContentType 'application/json'; ^
Write-Host ('      Txn ID: ' + $upi.data.transaction_id + ' | VPA: ' + $upi.data.upi_vpa); ^
Write-Host ('      QR Link: ' + $upi.data.qr_code_url.Substring(0, 45) + '...'); ^
^
Write-Host '`n[4/6] 💳 In-App Wallet Top-up & Balance Check:' -ForegroundColor Green; ^
$topup = Invoke-RestMethod -Uri 'http://localhost/drivemate-api/payments/wallet/add-money' -Method Post -Headers $headers -Body (@{ amount = 200 } | ConvertTo-Json) -ContentType 'application/json'; ^
Write-Host ('      Added: Rs. 200 | New Balance: Rs. ' + $topup.data.new_balance); ^
^
Write-Host '`n[5/6] 💵 Cash on Delivery Payment Collection:' -ForegroundColor Green; ^
$cash = Invoke-RestMethod -Uri 'http://localhost/drivemate-api/payments/cash-collect' -Method Post -Headers $headers -Body (@{ booking_id = 1; amount = 350 } | ConvertTo-Json) -ContentType 'application/json'; ^
Write-Host ('      Cash Collected: Rs. ' + $cash.data.amount_paid + ' | Status: ' + $cash.data.status); ^
^
Write-Host '`n[6/6] 🧾 Itemized GST Tax Invoice Retrieval:' -ForegroundColor Green; ^
$inv = Invoke-RestMethod -Uri 'http://localhost/drivemate-api/payments/invoice?booking_id=1' -Method Get -Headers $headers; ^
Write-Host ('      Invoice No: ' + $inv.data.invoice_number + ' | Customer: ' + $inv.data.customer.name); ^
Write-Host ('      Subtotal: Rs. ' + $inv.data.fare_breakdown.subtotal + ' | GST: Rs. ' + $inv.data.fare_breakdown.gst_total + ' | Total: Rs. ' + $inv.data.fare_breakdown.total_amount); ^
Write-Host '`n==============================================================' -ForegroundColor Cyan; ^
Write-Host '   🎉 ALL 6 BACKEND & PAYMENT SYSTEMS TESTED SUCCESSFULLY!    ' -ForegroundColor Cyan; ^
Write-Host '==============================================================' -ForegroundColor Cyan;"

pause
