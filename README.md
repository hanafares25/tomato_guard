from pathlib import Path

readme = """# 🍅 TomatoGuard

**Offline AI for tomato leaf disease screening — built for the World Bank × Hack-Nation Small AI for Development Hackathon.**

TomatoGuard is a lightweight AI-powered tool designed to help smallholder farmers identify possible tomato leaf diseases using a photo. The application runs the computer-vision model **locally on the user's device**, making the core screening feature usable without an internet connection.

The project was developed during the **Small AI for Development Hackathon**, organized by **Hack-Nation in collaboration with the World Bank**, with a focus on practical AI solutions for agriculture in low-connectivity environments.

## 🌱 The Problem

Smallholder farmers may face:

- Limited access to agricultural extension officers
- Delays in identifying crop problems
- Poor or unreliable internet connectivity
- Language and literacy barriers
- Difficulty knowing when a visible leaf symptom requires further attention

A farmer may have a smartphone available but not have reliable access to an agricultural expert.

## 💡 Our Solution

**Take a picture. Get an answer.**

TomatoGuard uses a lightweight computer-vision model to analyze a tomato leaf and provide a **screening result** with a suggested next step.

```text
📷 Take a photo
      ↓
🍅 Tomato leaf check
      ↓
🤖 AI screening
      ↓
🩺 Possible problem 
      ↓
🔊 Egyptian Arabic voice guidance
🧠 AI Model

The project uses MobileNetV3-Small, selected for its lightweight architecture and suitability for on-device inference.

**The model is trained on the tomato subset of the PlantVillage dataset, covering 10 classes:**
Healthy	
Bacterial Spot	
Early Blight	
Late Blight	
Leaf Mold	
Mosaic Virus	
Septoria Leaf Spot	
Spider Mites	
Target Spot	
Yellow Leaf Curl Virus

##📱 Offline-First Design

TomatoGuard is designed around the Small AI principle: the AI capability should be practical on a device that a user already has.

After the application and model have been downloaded, the core prediction process does not require sending the image to a server.

No farmer image needs to be uploaded to a cloud inference API.
