# natpac_app
An enterprise-grade, AI-powered Flutter application for intelligent transportation data collection and analysis, developed for **NATPAC (National Transportation Planning and Research Centre)**.  
NATPAC Trip Tracker transforms everyday travel into actionable mobility insights using **real-time GPS tracking**, **on-device machine learning**, **sensor fusion**, and **privacy-first data processing** — enabling smarter, more sustainable, and more efficient cities.

## Getting Started

This project is a Flutter-based mobile application designed to automatically detect, track, and analyze user journeys with minimal user input. It is built to serve both **individual users** (by providing personal travel insights, gamification, and rewards) and **transportation authorities** (by generating anonymized, high-fidelity datasets for planning and policy-making).

### Core Features

- 📍 **Intelligent Trip Tracking** – Continuous 1Hz GPS sampling with Kalman filtering, automatic trip detection, and real-time transport mode classification (walk, cycle, drive, bus, train).  
- 🧠 **AI-Powered Activity Recognition** – Sensor fusion using GPS, accelerometer, and gyroscope data with on-device ML models or Activity Recognition API.  
- 🗺️ **Map Integration & Routing** – OpenStreetMap integration with OSRM route planning and live route visualization.  
- 📊 **Advanced Analytics Dashboard** – Speed profiles, mode share, trip chain analysis, OD flow maps, heatmaps, and one-click data exports.  
- 🏆 **Gamification & Engagement** – Points, badges, streaks, community challenges, and tangible rewards to improve user retention.  
- 🛡️ **Privacy by Design** – Granular consent settings, transparency dashboard, k-anonymity, geospatial blurring, and secure data deletion/export options.  
- 🔋 **Battery-Optimized Background Tracking** – Adaptive sampling and native background services for uninterrupted operation.  
- 📶 **Offline-First Data Architecture** – Hive NoSQL database for local storage with batched sync and crash-resilient `PointCache` architecture.

---

## 🏗️ Project Architecture
Flutter Mobile App
├── Authentication (Firebase Auth)
├── Real-Time Location Service (geolocator + Kalman filtering)
├── Activity Recognition Engine (on-device ML)
├── Local Data Storage (Hive NoSQL)
├── Background Services (flutter_background_service, WorkManager)
├── Map Integration (OpenStreetMap + OSRM)
└── Analytics & Visualization (fl_chart)

Backend Infrastructure
├── Firebase (Auth, Storage)
├── PostgreSQL / TimescaleDB (trip metadata + time-series data)
├── BigQuery / Snowflake (analytical warehouse)
├── ETL Pipeline (Cloud Functions / Airflow)
└── Scientist Dashboard (Web-based analytics portal)


---

## 🧰 Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Flutter (Dart 3.9.2), Material Design 3 |
| **State Management** | BLoC + Provider |
| **Database (Local)** | Hive NoSQL |
| **Database (Backend)** | PostgreSQL / TimescaleDB / InfluxDB |
| **Analytics Store** | BigQuery / Snowflake |
| **Authentication** | Firebase Auth |
| **Cloud Services** | Firebase, Google Cloud Platform / AWS |
| **Location Services** | geolocator, Kalman filtering |
| **Background Processing** | flutter_background_service, WorkManager, BGTaskScheduler |
| **Mapping & Routing** | OpenStreetMap, OSRM, Nominatim |
| **Machine Learning** | On-device ML model / Activity Recognition API |
| **Visualization** | fl_chart |
| **Security** | TLS, salted hashes, Keychain / Keystore |
| **CI/CD** | GitHub Actions / GitLab CI |

---

## 🔄 Data Flow

1. **Collection:** On-device ML processes sensor data to detect trips and modes.  
2. **Local Storage:** Data is batched into `PointCaches` and stored in Hive.  
3. **Upload:** Cached data is encrypted and uploaded when network is available.  
4. **Processing:** Server-side ETL validates, map-matches, enriches, and anonymizes data.  
5. **Analytics:** Cleaned datasets are aggregated into BigQuery or Snowflake for visualization.  
6. **Dashboard:** Scientists explore patterns, generate insights, and export data.

---

## 🛠️ Installation

### Prerequisites
- Flutter SDK ≥ 3.9  
- Dart ≥ 3.9  
- Firebase project configured  
- PostgreSQL / TimescaleDB backend (optional for analytics)

### Steps

```bash
# Clone the repository
git clone https://github.com/yourusername/natpac_app_fixed.git
cd natpac_app_fixed

# Install dependencies
flutter pub get

# Run the application
flutter run
```

## 📱 Usage

1. Sign Up / Log In – via Firebase Authentication.

2. Start Tracking – the app automatically detects trips in the background.

3. Review & Confirm – confirm detected trips or add/edit them manually.

4. View Insights – explore personal stats, CO₂ savings, and travel trends.

5. Earn Rewards – complete streaks, unlock badges, and join community goals.

6. Research Dashboard – planners can filter, analyze, and export anonymized data.


## 🔐 Privacy & Security

Consent-first: Data collection starts only after explicit user consent.

Transparency Dashboard: Users can view, download, or delete their data anytime.

Anonymization: Personally identifiable information is stripped before analysis (k-anonymity, geospatial blurring).

Encryption: TLS for all network communication; encryption at rest for all databases.

Pseudonymization: Device and user IDs are hashed with unique salts.

