# Milk Billing App — Expert Build

આ project milk distributor માટે બનાવવામાં આવ્યો છે.

## Features
- Customer add / edit / delete
- Customer ID, name, address, mobile
- Product list with rates
- Daily customer-wise milk distribution
- Automatic daily amount
- Monthly billing from saved daily entries
- Local offline data storage
- Cash / QR / Wallet / NFC payment menu
- Gujarati + English labels
- GitHub Actions દ્વારા Android APK build

## Product Rates
- Sampoorna Milk — ₹37
- Cow Milk — ₹30
- A2 Milk — ₹40
- Super Gold 500ML — ₹29
- Tak Chhas — ₹17

## GitHub Actions
1. Repository માં આ files upload/commit કરો.
2. Actions → Build Milk Billing APK → Run workflow.
3. Build complete થયા પછી Artifacts માં `milk-billing-release-apk` download કરો.

જો Android folder repositoryમાં નથી તો workflow `flutter create --platforms=android .` ચલાવીને Android project automatically બનાવશે.

## Important
`lib/main.dart` આ projectનું મુખ્ય application code છે. Root માં અલગ `main.dart` રાખવાની જરૂર નથી.
