# Napkin

A native macOS personal finance calculator that helps you manage credit card payments and debt reduction strategies. Think of it as a structured spreadsheet with smart payment calculations — no cloud sync, no external APIs, just a simple tool for your financial planning.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0+-green.svg)

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
- Real-time net worth tracking
- Credit utilization monitoring
- Monthly payment minimums calculation
- Historical net worth trends with interactive charts

### Subscription Tracking
- Manage recurring expenses by category
- Flexible frequency options (weekly, monthly, annually, etc.)
- Cost breakdowns and category totals
- Active/inactive subscription management

### Data Management
- Import/export functionality for all data
- Settings management including prime rate adjustments
- Local-only storage with no cloud dependencies
- Clean, native macOS interface

## System Requirements

- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.0+ (for building from source)
- **Swift**: 5.9+

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
   - Select your target device (Mac)
   - Press `Cmd + R` to build and run
   - Or use `Cmd + B` to build only

## Usage

### Getting Started

1. **Set up your accounts:** Start by adding your credit cards, loans, and bank accounts in the Accounts tab
2. **Enter current balances:** Use the balance entry forms to record your current account balances
3. **Configure payment strategy:** In the Dashboard, choose between Avalanche or Snowball methods
4. **Set paycheck schedule:** Input your next paycheck dates and amounts for accurate planning
5. **Review payment plan:** The app generates specific payment recommendations based on your strategy

### Account Types Supported

- **Credit Cards**: Full APR tracking, credit limits, minimum payments
- **Loans & Mortgages**: APR calculations, payment due dates
- **Checking & Savings**: Asset tracking for net worth calculations
- **Retirement Accounts**: 401(k), IRA tracking
- **Investment Accounts**: Brokerage account balances

### Payment Strategies

**Debt Avalanche (Recommended):**
- Focuses on highest APR debts first
- Mathematically optimal for minimizing total interest paid
- Better for long-term financial health

**Debt Snowball:**
- Pays off smallest balances first
- Provides psychological wins with quicker account closures
- Better for motivation and momentum

### Data Import/Export

Access import/export functionality through the Settings window (`Cmd + ,`):

- **Export**: Save all your data as JSON for backup or analysis
- **Import**: Restore from previous exports or migrate data
- **Clean Import**: Start fresh while preserving your account structure

## Development

### Project Structure

```
napkin/
├── napkin/
│   ├── Models.swift          # Core data models
│   ├── ContentView.swift     # Main app interface  
│   ├── AccountListView.swift # Account management
│   ├── SettingsView.swift    # App preferences
│   └── ...
├── napkinTests/             # Unit tests
└── napkinUITests/           # UI tests
```

### Key Technologies

- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Core Data successor for persistence
- **Charts**: Native charting for financial trends
- **Decimal**: Precise monetary calculations (never Float/Double)

### Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following the existing code style
4. Ensure all tests pass
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Style Guidelines

- Use `Decimal` for all monetary values
- Follow Apple's Swift naming conventions
- Keep SwiftUI views small and focused
- Use SwiftData's `@Model` macro for data persistence
- Prioritize keyboard navigation for efficiency

## Architecture

Napkin follows a simple, maintainable architecture:

- **Local-only**: No network requests, authentication, or cloud sync
- **Native macOS**: Built specifically for macOS with native controls
- **Data-driven**: All calculations based on your input data
- **Privacy-focused**: Your financial data never leaves your machine

## Roadmap

- [x] **Phase 1**: Foundation with account management
- [x] **Phase 2**: Payment strategy calculator  
- [x] **Phase 2.5**: Subscription tracking
- [x] **Phase 2.8**: Settings and import/export
- [ ] **Phase 3**: Calendar integration with due dates
- [ ] **Phase 4**: Historical balance snapshots
- [ ] **Phase 5**: Enhanced keyboard shortcuts and Mac integration

See [ROADMAP.md](ROADMAP.md) for detailed development plans.

## Why I Built This

[Your personal story and motivation goes here]

## Support

- **Issues**: Report bugs or request features in [Issues](../../issues)
- **Discussions**: Ask questions in [Discussions](../../discussions)
- **Email**: [Your contact email]

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with Apple's SwiftUI and SwiftData frameworks
- Icons from SF Symbols
- Inspired by the need for simple, local financial planning tools

---

**Note**: Napkin is a personal finance calculator, not financial advice. Always consult with qualified financial advisors for important financial decisions.