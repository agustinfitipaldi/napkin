# Napkin

A native Apple personal finance calculator for macOS and iOS. Track credit card payments, manage subscriptions, and calculate optimal payment strategies. CloudKit sync keeps your data in sync across all your devices.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)
![iOS](https://img.shields.io/badge/iOS-18.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0+-green.svg)
![CloudKit](https://img.shields.io/badge/CloudKit-Sync-purple.svg)

Here's me flipping around the different views using demo data:

https://github.com/user-attachments/assets/ff2ffbcc-7730-4b0c-8ace-8967ed6610e4

## Features

### Account Management
- Track multiple credit cards, loans, mortgages, and asset accounts
- Support for APR tracking (fixed and variable rates)
- Credit limit and utilization monitoring
- Payment due dates and minimum payment calculations

### Smart Payment Strategies
- **Debt Avalanche**: Prioritize highest APR accounts first
- **Debt Snowball**: Pay off smallest balances first
- Intelligent payment planning with paycheck timing
- Shortfall protection for upcoming payment periods

### Financial Dashboard
- Credit utilization
- Net Worth breakdown
- Monthly payment minimums calculation
- Historical net worth trends with interactive charts

### Subscription Tracking
- Manage recurring expenses by category
- Flexible frequency options (what do you pay, how many times per year do you pay that)
- Cost breakdowns and category totals
- Active/inactive subscription management

### Data Management
- Import/export functionality for all data
- Settings management including prime rate adjustments
- iCloud sync via CloudKit across all your devices
- Clean, native Apple interface for macOS and iOS

## System Requirements

- **macOS**: 14.0 (Sonoma) or later
- **iOS**: 18.0 or later (iPhone and iPad)
- **Xcode**: 15.0+ (for building from source)
- **Swift**: 5.9+
- **iCloud account**: Required for CloudKit sync between devices

## Installation

### Option 1: Download Release (Coming Soon)
Pre-built binaries will be available in the [Releases](../../releases) section.

### Option 2: Build from Source

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/napkin.git
   cd napkin
   ```

2. **Open in Xcode:**
   ```bash
   open napkin.xcodeproj
   ```

3. **Build and run:**
   - Select your target device (Mac, iPhone, or iPad)
   - Press `Cmd + R` to build and run
   - Or use `Cmd + B` to build only

### CloudKit Setup

The app uses CloudKit for syncing data across your devices. For development:

1. **Sign in with your Apple ID** in Xcode (Xcode → Settings → Accounts)
2. **Select your development team** in the project settings (Signing & Capabilities)
3. **Ensure you're signed into iCloud** on your test devices
4. **Development builds** automatically use the Development CloudKit database
5. **TestFlight/App Store builds** use the Production CloudKit database

**Important for Production Builds:**
- The CloudKit schema must be manually deployed from Development to Production via the [CloudKit Console](https://icloud.developer.apple.com/)
- Schema changes made during development won't automatically appear in production
- Always deploy schema changes before releasing TestFlight builds

### Project Structure

```
napkin/
├── napkin/
│   ├── Models.swift          # Core data models
│   ├── ContentView.swift     # Main app interface  
│   ├── AccountListView.swift # Account management
│   ├── SettingsView.swift    # App preferences
│   └── ...
├── napkinTests/             # Unit tests... :)
└── napkinUITests/           # UI tests... :)
```

### Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following the existing code style
4. Ensure all tests pass
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with Claude Code!
---

**Note**: Napkin is a personal finance calculator, not financial advice. Always consult with qualified financial advisors for important financial decisions.
