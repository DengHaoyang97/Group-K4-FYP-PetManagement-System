# 🐶 Pet Health Management System

A cross-platform mobile app to help pet owners manage their pets' health, access AI-based consultations, and recognize pet food or medicine packaging through image classification.

---

## 📁 Project Structure

```
project_root/
├── dog/                  # Flutter mobile application
├── backend/              # Node.js backend for chat and data
├── image_rec_model/      # FastAPI-based image classification API
```

---

## 📱 Mobile App (`dog/`)

### Features

- 🐾 Pet health records management
- 🧠 AI chatbot consultation
- 🖼️ Image classification for pet food/medicine
- 📊 Data visualization (charts)
- 📍 Geolocation-enabled features
- 💾 Local storage with SQLite & Shared Preferences

### Test Account

- **Username:** `groupk4`
- **Password:** `abc123`

### Setup

```bash
cd dog
flutter clean      # Removes old build artifacts to prevent conflicts and resolve build issues
flutter pub get    # Fetches all necessary Flutter/Dart dependencies
flutter run        # Launches the app on the connected device or emulator
```

> Ensure you have Flutter SDK ≥3.10 and Dart SDK ≥3.5 installed.

### Notes

- If you experience slow MongoDB connections, consider switching to a local MongoDB instance for testing. Update the connection string at:

  ```
  dog/lib/mongo_service.dart (line 7)
  ```

- To change the image classification API endpoint, update:

  ```
  dog/lib/image_classification.dart (line 41)
  ```

---

## 🧠 Backend (`backend/`)

### Overview

- Node.js + Express server
- Handles chat logic and MongoDB communication
- Simple credential-based login

### Setup

```bash
cd backend
npm install
node server-chat.js
```

### Admin Account

- **Username:** `admin`
- **Password:** `123`

> Node.js ≥18 is recommended

---

## 🖼️ Image Recognition API (`image_rec_model/`)

### Overview

- Powered by **FastAPI** and **TensorFlow Lite**
- Performs classification of pet-related images

### Setup

```bash
cd image_rec_model
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn api-deploy:app --reload
```

### Requirements

Make sure the following packages are installed:

```bash
pip install fastapi uvicorn pillow numpy tflite-runtime
```

### Notes

- Uses `model.tflite` and `labels.txt` (stored in `assets/`)
- Default input size: **224x224**
- Accepts images via POST and returns top prediction with confidence

---

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd project_root
```

### 2. Start the Image Recognition API

```bash
cd image_rec_model
uvicorn api-deploy:app --reload
```

### 3. Start the Backend Server

```bash
cd backend
node server-chat.js
```

### 4. Run the Flutter App

```bash
cd dog
flutter clean
flutter pub get
flutter run
```

---

## ⚠️ Troubleshooting

- ❗ **MongoDB slow response**: Using a cloud-hosted MongoDB (e.g., MongoDB Atlas) may introduce latency. For faster response during development, use a local MongoDB instance and update the connection string.
- ❗ **Image classification not working**: Ensure the image recognition API server is running and the endpoint in your Flutter code is correct.
- ❗ **Assets not loading**: Make sure `pubspec.yaml` has correct asset paths and the files exist.
- ❗ **Backend not responding**: Verify MongoDB is running and the connection string is correct.

---

## 🔐 Security Notice

This system uses basic credential-based authentication for demonstration. **Do not** use in production without adding proper security measures such as JWT, HTTPS, OAuth, and secure password storage.

---

## 🙌 Contribution

We welcome contributions! Please fork the repo and submit pull requests. For major changes, open an issue first to discuss what you would like to change.

---

## 📬 Contact

**Deng Hao Yang**  
📧 billydeng97@gmail.com
