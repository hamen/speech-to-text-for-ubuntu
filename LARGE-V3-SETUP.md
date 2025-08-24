# 🎯 Large-v3 GPU Setup Guide

## **Your Perfect Speech-to-Text Configuration**

This guide sets up your **NVIDIA RTX 4070** for maximum quality speech recognition with:
- **Best accuracy** using the `large-v3` model
- **GPU acceleration** for fast processing
- **Manual pasting** (reliable clipboard + notification)
- **Intelligent text cleaning** (removes fillers, fixes stuttering)

---

## 🚀 **Quick Start**

### **1. Test Your Configuration**
```bash
./test-large-v3.sh
```
This will verify everything is working correctly.

### **2. Launch Full System**
```bash
sudo ./launch-large-v3.sh
```
This starts the complete speech-to-text system.

### **3. Manual Configuration**
```bash
source ./large-v3-config.sh
python3 speech_to_text.py <audio_file>
```

---

## ⚙️ **Configuration Details**

### **Model Settings**
- **Model**: `large-v3` (best accuracy, ~3GB VRAM)
- **Device**: `cuda` (GPU acceleration)
- **Compute Type**: `float16` (optimal precision/speed)
- **Beam Size**: `5` (maximum accuracy)

### **Output Mode**
- **Mode**: `clipboard` (manual pasting)
- **Behavior**: Text copied to clipboard + notification
- **Usage**: Press Ctrl+V to paste cleaned text

### **Text Cleaning (Post-Processing)**
- **Enabled**: Yes (Conservative Mode)
- **Filler Removal**: Removes only obvious speech sounds ("um", "uh", "you know")
- **Repetition Fixing**: Fixes stuttering and duplicates
- **Punctuation**: Cleans up excessive marks
- **Sentence Structure**: Proper capitalization and endings
- **Content Preservation**: Keeps meaningful words like "okay", "well", "now"
- **Mode**: Conservative by default (less aggressive than previous versions)

---

## 🎮 **Hardware Requirements**

### **GPU**
- **Required**: NVIDIA GPU with CUDA support
- **Recommended**: RTX 4070 or better
- **VRAM**: Minimum 4GB (large-v3 uses ~3GB)
- **Driver**: CUDA 12.1+ compatible

### **System**
- **OS**: Ubuntu 24.04.2 LTS
- **Python**: 3.x with virtual environment
- **Memory**: 8GB+ RAM recommended

---

## 📋 **File Structure**

```
speech-to-text-for-ubuntu/
├── large-v3-config.sh      # Your configuration file
├── launch-large-v3.sh      # Launcher script
├── test-large-v3.sh        # Test script
├── speech_to_text.py       # Core processing (with text cleaning)
├── key_listener.py         # Hotkey listener
├── requirements.txt         # Dependencies
└── venv/                   # Python virtual environment
```

---

## 🔧 **Usage Instructions**

### **Step 1: Press Hotkey**
- Press and hold **F16** (or your configured key)
- Speak clearly into your microphone
- Release the key when done

### **Step 2: Processing**
- Audio is processed using `large-v3` model on GPU
- Text is automatically cleaned and improved
- Processing time: ~2-5 seconds (depending on audio length)

### **Step 3: Get Results**
- Text is copied to clipboard automatically
- Desktop notification shows preview
- Press **Ctrl+V** to paste the cleaned text

---

## 🧹 **Text Cleaning Examples**

### **Before (Raw Speech)**
```
"um I I I think that um you know the the the thing is basically um actually"
```

### **After (Cleaned)**
```
"I think that the thing is."
```

### **What Gets Cleaned**
- **Filler words**: "um", "uh", "you know", "like", "basically"
- **Repetitions**: "I I I think" → "I think"
- **Stuttering**: "I-I-I think" → "I think"
- **False starts**: Incomplete thoughts removed
- **Punctuation**: Excessive marks cleaned up

---

## ⚡ **Performance Expectations**

### **Speed**
- **Model Loading**: ~10-15 seconds (first time)
- **Transcription**: ~2-5 seconds per audio clip
- **Text Cleaning**: <1 second

### **Quality**
- **Accuracy**: Significantly better than smaller models
- **Language Understanding**: Excellent context awareness
- **Noise Handling**: Good at filtering background noise

### **Memory Usage**
- **GPU VRAM**: ~3GB for large-v3 model
- **System RAM**: ~2-4GB additional
- **Storage**: ~3GB for model files

---

## 🚨 **Troubleshooting**

### **Common Issues**

#### **GPU Memory Error**
```bash
# Check available GPU memory
nvidia-smi

# Close other GPU applications
# Restart system if needed
```

#### **CUDA Not Available**
```bash
# Install CUDA-optimized PyTorch
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
```

#### **Model Download Issues**
```bash
# Test model loading
./test-large-v3.sh

# Check internet connection
# Verify Hugging Face access
```

### **Performance Tips**
- **Close other GPU applications** (games, video editors)
- **Use good microphone** for better input quality
- **Speak clearly** for best transcription results
- **Keep system updated** for optimal GPU drivers

---

## 🔄 **Switching Models**

### **Quick Model Change**
```bash
# Switch to medium.en (faster, still good quality)
export STT_MODEL="medium.en"

# Switch to small.en (fastest, basic quality)
export STT_MODEL="small.en"

# Return to large-v3 (best quality)
export STT_MODEL="large-v3"
```

### **Model Comparison**
| Model     | VRAM    | Speed   | Quality      | Best For        |
|-----------|----------|---------|--------------|------------------|
| `tiny.en` | 0.1GB   | ⚡⚡⚡⚡⚡ | 🟡 Basic     | Testing, speed  |
| `small.en`| 0.5GB   | ⚡⚡⚡    | 🟢 Good      | Balanced        |
| `medium.en`| 1.5GB   | ⚡⚡      | 🟢 Very Good | Real-time       |
| `large-v3`| 3GB      | ⚡       | 🔴 Excellent | **Best quality** |

---

## 📚 **Advanced Configuration**

### **Customize Text Cleaning**
```bash
# Conservative mode (default) - preserves meaningful content
export STT_AGGRESSIVE_CLEANING="0"
export STT_PRESERVE_COMMON_WORDS="1"

# Aggressive mode - removes more filler words
export STT_AGGRESSIVE_CLEANING="1"

# Disable specific features
export STT_REMOVE_FILLERS="0"        # Keep all words
export STT_FIX_REPETITIONS="0"       # Keep repetitions
export STT_FIX_PUNCTUATION="0"       # Keep all punctuation

# Adjust sentence length requirements
export STT_MIN_SENTENCE_WORDS="3"    # Require longer sentences
```

### **Adjust Model Parameters**
```bash
# Lower beam size for speed
export STT_BEAM_SIZE="3"

# Higher temperature for creativity
export STT_TEMPERATURE="0.5"

# Disable voice activity detection
export STT_VAD="0"
```

---

## 🎉 **You're All Set!**

Your RTX 4070 is now configured for **maximum quality speech recognition** with:

✅ **Best accuracy** using large-v3 model
✅ **GPU acceleration** for fast processing
✅ **Intelligent text cleaning** for professional output
✅ **Manual pasting** for reliable operation
✅ **Easy configuration** with dedicated scripts

**Next step**: Run `./test-large-v3.sh` to verify everything is working!

---

## 📞 **Need Help?**

- **Test your setup**: `./test-large-v3.sh`
- **Check GPU status**: `nvidia-smi`
- **View logs**: `tail -f log/speech_to_text.log`
- **Verify configuration**: `./switch-model.sh -c`

**Happy transcribing! 🎤✨**
