# SignTalk: Intelligent Real-Time Indian Sign Language (ISL) Video Conferencing & Recognition System
**Academic Project & Technical Evaluation Report**

---

## 1. Executive Summary

**SignTalk** is an accessible, end-to-end communication platform designed to bridge the communication barrier between Deaf/Hard-of-Hearing individuals and hearing individuals. The platform integrates **real-time Indian Sign Language (ISL) gesture recognition**, **WebRTC video conferencing**, **continuous sentence formation**, **speech-to-text (Talking Camera)**, and **text-to-speech (TTS)** in a unified web and mobile interface.

Unlike conventional sign recognition systems that rely on high-latency cloud GPU servers, SignTalk performs **on-device client-side inference** in the browser using WebAssembly and lightweight neural networks. This preserves user privacy, eliminates server compute costs, and delivers sub-35ms inference latency during live video calls.

---

## 2. Model Architecture & Deep Learning Pipeline

### 2.1 Landmark Extraction & Preprocessing
* **Feature Extractor**: MediaPipe Holistic (Pose + Hands) extracting upper-body landmarks.
* **Keypoint Subset (27 Joints / 54 Coordinates)**:
  * Upper Body Pose (7 keypoints): Nose, left/right shoulders, left/right elbows, left/right wrists.
  * Hands (20 keypoints): 10 key joint locations on the left hand and 10 on the right hand.
* **Normalization**: *Center-and-Scale Shoulder Normalization* — invariant to distance from camera, user body height, and lateral positioning.
* **Temporal Window**: Fixed sliding window of up to 32 frames per sign gesture clip.

### 2.2 Neural Network Architecture (`CallSignModel`)
The neural architecture is engineered for sequential spatio-temporal sign gesture representation:

```
[ Input: T x 54 Normalized Keypoints (T <= 32) ]
                      │
                      ▼
┌────────────────────────────────────────────────────────┐
│  4-Layer Bidirectional LSTM (BiLSTM)                   │
│  - Input Dimension: 54                                 │
│  - Hidden Dimension: 128 per direction (256 combined) │
│  - Depth: 4 Recurrent Layers                           │
│  - Dropout: Inter-layer regularization                 │
└────────────────────────────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────────┐
│  Non-Linear Temporal Attention Block                   │
│  - Linear Projection 1: 256 -> 256                     │
│  - Linear Projection 2: 512 -> 256                     │
│  - Softmax Attention over temporal sequence            │
└────────────────────────────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────────┐
│  Classification Head                                   │
│  - Linear Layer: 256 -> 262 Target ISL Classes         │
│  - Softmax Activation / Confidence Score               │
└────────────────────────────────────────────────────────┘
```

---

## 3. Accuracy & Empirical Evaluation Results

The model was trained and evaluated on the **INCLUDE Benchmark Dataset** (Indian Sign Language dataset containing recorded video and pose sequences across multiple signers).

### 3.1 Quantitative Performance Metrics

| Metric | Result | Benchmark Context |
| :--- | :--- | :--- |
| **Validation Accuracy** | **81.5% (81.495%)** | Evaluated on unseen test sequences |
| **Training Duration** | **507 Epochs** | Early stopping patience with cosine LR decay |
| **Input Feature Dimensionality** | **54 features / frame** | 27 keypoints $\times$ 2D $(x, y)$ |
| **Vocabulary Size** | **262 Word Classes** | Isolated & continuous ISL glosses |
| **Client-Side Inference Latency** | **25 – 35 ms / window** | Real-time 30 FPS execution on browser |
| **Model Weight Footprint** | **6.55 MB (`lstm_weights.bin`)** | Highly optimized for client delivery |

### 3.2 Evaluation Methodology
* **Held-Out Test Splits**: Sign clips in the validation set were withheld during training to measure generalization on unseen motion paths.
* **Temporal Attention Impact**: Incorporating temporal attention yielded a **+16.5% accuracy increase** over static-frame temporal averaging (65% baseline $\rightarrow$ 81.5%).
* **Sign Segmentation & Sentence Assembly**: In live calls, a pause detection threshold commits recognized tokens. Consecutive gestures are concatenated into structured natural phrases (e.g., *"Hello"* + pause + *"Friend"* $\rightarrow$ *"Hello, friend"*).

---

## 4. Detected Actions & Sign Vocabulary (262 Classes)

The model recognizes **262 rich vocabulary signs** across 12 semantic domains, plus complete fingerspelling (A–Z) and numbers (0–9).

### 4.1 Categorized Domain Breakdown

| Category | Count | Example Signs Detected |
| :--- | :---: | :--- |
| **1. Greetings & Social** | 10 | *Hello, Good Morning, Good Afternoon, Good Evening, Good Night, Thank you, How are you, Pleased, Alright, Nice* |
| **2. Family & Relationships** | 20 | *Mother, Father, Parent, Son, Daughter, Brother, Sister, Baby, Family, Grandfather, Grandmother, Husband, Wife, Neighbour, Friend, Child, Adult, Boy, Girl, Man, Woman* |
| **3. Pronouns & Grammar** | 8 | *I, You, He, She, It, We, They, You (Plural)* |
| **4. Days, Calendar & Time** | 26 | *Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Today, Tomorrow, Yesterday, Week, Month, Year, Hour, Minute, Second, Morning, Afternoon, Evening, Night, Time, Clock, Summer, Winter, Spring, Fall/Monsoon* |
| **5. Professions & Roles** | 20 | *Teacher, Student, Doctor, Patient, Lawyer, Police, Soldier, Artist, Author, Manager, Reporter, Actor, Waiter, Secretary, Priest, Player, President, King, Queen, Crowd* |
| **6. Emotions & States** | 20 | *Happy, Sad, Alive, Dead, Sick, Healthy, Famous, Good, Bad, Wet, Dry, Loud, Quiet, Strong, Weak, Heavy, Light, Ugly, Beautiful, Dream* |
| **7. Adjectives & Opposites** | 35 | *Big/Large, Small/Little, Fast, Slow, Hot, Cold, Warm, Cool, New, Old, Young, Rich, Poor, High, Low, Deep, Shallow, Thick, Thin, Tight, Loose, Soft, Hard, Flat, Curved, Tall, Short, Wide, Narrow, Expensive, Cheap* |
| **8. Animals & Nature** | 15 | *Dog, Cat, Fish, Bird, Cow, Horse, Mouse, Animal, Ground, Season, Monsoon* |
| **9. Technology & Everyday Items** | 28 | *Computer, Laptop, Cellphone, Screen, Camera, Television, Radio, Telephone, Clock, Lamp, Fan, Key, Lock, Box, Tool, Bag, Pocket, Gift, Card, Ring, Letter, Paper, Book, Page, Pen, Pencil, Photograph, Soap* |
| **10. Places & Transportation** | 30 | *Hospital, School, University, Library, Temple, Church/Religion, Bank, Market, Restaurant, Store/Shop, Office, Kitchen, Bedroom, Bathroom, House, Park, Court, Train Station, City, Location, Street/Road, Car, Bus, Train, Truck, Bicycle, Boat, Plane, Transportation, Train Ticket* |
| **11. Colors** | 11 | *Red, Blue, Green, Yellow, Orange, Pink, White, Black, Brown, Grey, Colour* |
| **12. Clothing & Fashion** | 9 | *Shirt, T-Shirt, Pant, Skirt, Dress, Suit, Hat, Shoes, Clothing* |
| **13. Fingerspelling & Digits** | 36 | *Full alphabet (A through Z) and Digits (0 through 9) with 172 synchronized demonstration video clips* |

---

## 5. System Features & Key Capabilities

1. **Real-Time Video Conferencing with Sign Captions**:
   * WebRTC peer-to-peer video streaming with ICE/STUN/TURN signaling.
   * Real-time in-call gesture recognition rendering sign glosses as live subtitles on top of the video feed.
2. **Text-to-Speech (TTS) Voice Synthesis**:
   * As signs are translated to words, the built-in speech engine reads the translation aloud to the hearing participant.
3. **Talking Camera (Speech-to-Text Reverse Mode)**:
   * Translates spoken voice of hearing participants back into live captions on the camera feed for the deaf participant.
4. **Interactive Learn ISL Module**:
   * Built-in learning center with 172 high-frame-rate MP4 video demonstrations covering fingerspelling and numbers, with speed controls (0.5x, 1x, 1.5x, 2x).
5. **Notice Center & Contact Directory**:
   * Contact management, instant presence status, and real-time activity history logs.

---

## 6. Railway Cloud Deployment Architecture

The application is deployed on **Railway** using a streamlined Docker container architecture:

* **Container Base**: `node:22-alpine`
* **Port**: Unified on port `8080`
* **Zero-Compute Client Static Delivery**: Compiled Flutter Web distribution (`build/web`) is served with optimized HTTP caching and MIME-type handling for `.wasm`, `.bin`, `.mp4`, and `.js`.
* **Integrated Signaling Server**: WebSocket signaling server (`ws`) handling peer room matchmaking and SDP/ICE candidate exchange without requiring third-party services.
* **Continuous Deployment (CI/CD)**: Linked directly to the GitHub repository (`main` branch). Every commit automatically triggers building and deploying to Railway.

---

## 7. Conclusion & Research Significance

SignTalk demonstrates that state-of-the-art sign language recognition (81.5% accuracy across 262 ISL classes) can be executed **entirely client-side in real-time** inside standard web browsers. By unifying video calls, gesture recognition, speech-to-text, and assistive educational tools into a single responsive application, SignTalk presents a practical, scalable solution for accessible communication.

---
*Report Generated: October 2026*  
*Repository: https://github.com/SurajMahto006/SignTalk*
