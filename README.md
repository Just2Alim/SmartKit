# 🏥 SmartKit — Your Ultimate Health Companion

![SmartKit Banner](assets/readme/smartkit_readme_banner_1777584784757.jpg)

[![Flutter](https://img.shields.io/badge/Flutter-3.22.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL%20%7C%20Auth-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Ollama AI](https://img.shields.io/badge/AI-Local%20Ollama-FC6404?style=for-the-badge&logo=ollama&logoColor=white)](https://ollama.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

**SmartKit** is a premium, AI-driven mobile application designed to simplify medication management. From real-time barcode scanning to intelligent health assistance, SmartKit ensures you never miss a dose and always have the right information at your fingertips.

---

## ✨ Key Features

### 🔍 AI-Powered Medicine Scanner
- **Instant Identification**: Scan any medicine barcode or Data Matrix (RU "Честный ЗНАК") to automatically identify the product.
- **Cascaded Lookup**: Uses a robust logic flow:
  1. **OpenFDA**: For international medication data.
  2. **OpenFoodFacts**: Global barcode database.
  3. **Local Database**: Optimized for popular medications (30+ built-in records).
- **Damage Recovery**: Built-in logic for reporting missing items and manual entry fallback.

### 🏢 B2B Warehouse & Business Suite
- **Inventory Management**: Professional inventory tracking with location-aware stock management.
- **Unified Analytics**: Real-time reporting on sales, revenue, and stock levels, integrated directly into the main analytics dashboard.
- **OCR Logistics**: MLKit-powered scanning for quick stock receipt and automated product entry.
- **Smart Logistics**: Occupancy metrics and AI-driven spatial insights for warehouse optimization.

- **Health Chat**: Ask reference questions about medicines, first-aid kits, and safe next steps without diagnosis or treatment prescription.
- **Persistent Context**: AI chat history is stored in Supabase and restored per user.
- **Product Cards**: AI can return concrete catalog items that can be added to the cart from the chat.
- **Reference Sources**: The server-side AI context can use local knowledge, RxNorm, DailyMed, openFDA Drug Label, and PubMed.
- **Kit Builder**: Tell the AI your situation, and it will suggest a custom First Aid kit.
- **Business Intelligence**: Local AI analysis of inventory trends and sales performance.
- **Privacy First**: All AI processing happens locally via **Ollama**, ensuring your health and business data never leave the device.
- **Separate Admin Panel**: `admin/` provides AI monitoring, user metrics, commerce stats, and prompt/response observability through `admin-dashboard`.

### ⏰ Smart Reminders & Notifications
- **Dose Tracking**: Never miss a medication with automated push notifications.
- **Visual Dashboard**: A clean, intuitive overview of your daily health schedule.

### 💎 Premium Design System
- **Glassmorphism**: Modern, sleek UI with frosted glass effects.
- **Dynamic Themes**: Full support for Dark and Light modes.
- **Micro-animations**: Smooth transitions and animated scanning laser for a tactile feel.

---

## 🛠 Tech Stack

- **Frontend**: [Flutter](https://flutter.dev) (Dart)
- **Backend**: [Supabase](https://supabase.com) (PostgreSQL, Auth, RLS, Edge Functions)
- **AI**: Server-side Ollama/Qwen3 gateway
- **Admin**: Standalone static web dashboard + Supabase Edge Function
- **Scanning**: [mobile_scanner](https://pub.dev/packages/mobile_scanner) & MLKit OCR
- **State Management**: Provider

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- A Supabase project
- Hosted Ollama/Qwen3 or another LLM endpoint for Edge Functions

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Just2Alim/SmartKit.git
   cd smartkit
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure backend variables**:
   Use `.env.example` as the template and create a local `.env`. For Android
   release builds, use `scripts/build_android_release.ps1`; it passes only the
   public Flutter values to the app and does not embed server-only secrets.

4. **Run the application**:
   ```bash
   flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
   ```

### Docker Deployment

SmartKit can be served as a web release with Qwen3 through Docker Compose:

```bash
docker compose --env-file .env up --build
```

The web app is served on `http://localhost:8080`, and Ollama pulls
`qwen3:latest` by default. This is intentionally the full Qwen3 tag for better
answers, even if generation is slower on a laptop.

If Supabase Edge Functions must call a private Ollama host, expose
`scripts/ollama_proxy.mjs` behind your domain or tunnel and set Supabase
secrets:

```bash
supabase secrets set \
  OLLAMA_BASE_URL=https://your-ollama-proxy.example.com \
  OLLAMA_MODEL=qwen3:latest \
  OLLAMA_API_KEY=$OLLAMA_PROXY_TOKEN
```

### Admin Panel

```bash
python3 -m http.server 8090 --directory admin
```

Open `http://localhost:8090`, enter the Supabase URL/anon key, and sign in with
an account listed in `app_admins`.

---

## 📂 Project Structure

```text
lib/
├── core/               # App configuration, themes, constants, and services
│   ├── services/       # AI, Auth, Barcode, etc.
│   └── theme/          # Premium design system tokens
├── features/           # Feature-based architecture
│   ├── ai/             # AI Chat and Kit Builder logic
│   ├── auth/           # Login, Signup, and Onboarding
│   ├── dashboard/      # Main UI and daily overview
│   └── medicine/       # Scanner and medicine management
└── main.dart           # App entry point
admin/                  # Standalone AI/user/commerce monitoring panel
supabase/functions/     # Edge Functions: ai-chat, business-analysis, admin-dashboard
```

---

## 🗺 Roadmap
- [x] Offline AI support (Local LLM via Ollama).
- [ ] Advanced Drug-to-Drug interaction checker.
- [ ] Integration with Apple Health / Google Fit.

---

## 📜 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contact
**Alim** - [GitHub](https://github.com/Just2Alim)

---
*Developed with ❤️ for a healthier future.*
