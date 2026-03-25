#  About the Project

##  Inspiration
While commuting to my college every day, I constantly encountered numerous potholes along the way. These not only made the journey uncomfortable but also posed safety risks. That experience made me realize how common and overlooked this issue is. I felt a strong need to build something that could contribute to **social good**—a solution where people like me could **crowdsource pothole data** and help improve road conditions collectively.

---

##  What I Learned
This project taught me an important lesson:  
> *Not everything is difficult or impossible—you just need to start.*

As this was my **first mobile application built using Android Studio**, the journey itself was a huge learning experience. Over the course of a month, I:
- Learned how **Gradle** works and how it simplifies dependency management and builds in Android development.
- Explored mobile sensors like the **gyroscope** and **accelerometer**.
- Discovered that pothole detection could be achieved without relying on heavy tools like OpenCV (which would require continuous camera usage and drain battery).

Instead, I used sensor-based detection, which is **more efficient and battery-friendly**.

---

## ⚙️ How I Built the Project
I developed this application using:
- **Android Studio** (primary development environment)
- My AI coding partner (**Claude AI**) for guidance and support

### Key Features:
-  Supports both **Android and iOS platforms**
-  Uses **gyroscope and accelerometer data** to detect road anomalies
-  Implements a **Decision Tree algorithm** to:
  - Accurately detect potholes  
  - Differentiate between **speed breakers** and **potholes**
-  Introduces a **threshold frequency model** to identify potholes:
  
  $$
  f > f_{\text{threshold}} \Rightarrow \text{Potential pothole detected}
  $$

- 🗺️ Integrated **Google Maps** to:
  - Mark detected potholes
  - Enable real-time tracking and visualization
- 👥 Designed for **crowdsourcing**, allowing multiple users to contribute data

---

## ⚡ Challenges Faced
One of the biggest challenges I encountered during testing was **classification accuracy**:
- The app sometimes detected **speed breakers as potholes**
- And occasionally misclassified potholes inconsistently

This highlighted the difficulty of working with **real-world sensor data**, where noise and variations can affect predictions.

To address this, I:
- Tuned the **threshold frequency**
- Improved the **decision tree logic**
- Focused on better distinguishing motion patterns between road features

---

## 🚀 Final Thoughts
This project is more than just an app—it's a step toward **smarter, safer roads powered by the community**. It also marks my journey into mobile development, proving that with curiosity and persistence, even a beginner can build impactful solutions.
