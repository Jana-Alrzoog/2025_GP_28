
# Masar  
AI-Powered Digital Twin System for Enhanced Riyadh Metro Services  

<img width="171" height="127" alt="image" src="https://github.com/user-attachments/assets/da692b85-c357-42a6-a620-5c190b871de7" />
<img width="837" height="448" alt="image" src="https://github.com/user-attachments/assets/f58440d3-4a4c-42b4-a50f-e90155725aa7" />



---

## Introduction
Masar is a **graduation project** designed to improve the **Riyadh Metro passenger experience**.  

**Goal:**  
The main goal of Masar is to provide passengers and metro staff with **accurate, real-time data and intelligent predictions** to support safer, faster, and more convenient travel decisions.  
The system integrates a **digital twin** of Riyadh Metro with **machine-learning models** and an **interactive web/mobile interface**, enabling live crowd monitoring, short-term crowd prediction, and smart chatbot support for station information and Lost & Found updates.

---

## Technology
- **Programming Languages & Frameworks:**  
  - **Frontend (Web):** HTML5, CSS3, JavaScript (React.js)  
  - **Mobile App:** Flutter (cross-platform for Android & iOS)  
  - **Backend:** Node.js with Express (REST APIs), Firebase (authentication, database, hosting)  
  - **Machine Learning:** Python (pandas, scikit-learn)  
- **Tools & Services:**  
  - Visual Studio Code, Android Studio  
  - **Google Maps API** – provides real-time mapping, routing, and station-level location services  
  - GPT API (OpenAI/Azure) – powers the intelligent chatbot  
  - GitHub – version control and collaboration

---

## Launching Instructions

1. Open the **2025_GP_28** repository on GitHub:  
   [https://github.com/Jana-Alrzoog/2025_GP_28](https://github.com/<your-username>/2025_GP_28)

2. Click on the **Code** button and download the project as a **.zip** file.

3. Unzip the file to a preferred location on your computer.

4. Open **Android Studio** (for the Flutter mobile app) **or** **Visual Studio Code** (for the web/Node.js project).

5. In the IDE, go to **File → Open**, select the unzipped project folder, and click **OK**.

6. **Backend (Node.js)**  
   ```bash
   cd src/backend
   npm install
   npm start
````

* Ensure a `.env` file contains your Firebase credentials, Google Maps API key, and GPT API key.

7. **Frontend Web (React)**

   ```bash
   cd src/frontend
   npm install
   npm run dev
   ```

   * Open `http://localhost:5173` in a browser.

8. **Mobile App (Flutter)**

   ```bash
   cd src/mobile
   flutter pub get
   flutter run
   ```

   * Requires Flutter SDK and an Android emulator or a connected Android device.

9. **Machine-Learning Service (Optional)**

   ```bash
   cd src/ml
   pip install -r requirements.txt
   python model_service.py
   ```


