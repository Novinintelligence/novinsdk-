# 📊 Available Public Datasets for Smart Home Security Benchmarking

**Updated**: October 1, 2025  
**Purpose**: Real-world datasets you can use to validate your AI

---

## 🎯 TL;DR - Best Options for You

### **Option 1: Build Your Own** ✅ **RECOMMENDED**
**Status**: ✅ Already built (BenchmarkDataset.swift)  
**Scenarios**: 10,000 synthetic but realistic  
**Advantage**: Tailored to Ring/Nest event formats  
**Disadvantage**: Not "real-world" data

### **Option 2: IoT Security Datasets** ⚠️ **NETWORK FOCUSED**
**Problem**: Most focus on network intrusion, not home security events  
**Use Case**: Not directly applicable to your SDK

### **Option 3: Partner with Brand** 🎯 **BEST LONG-TERM**
**Status**: Requires business relationship  
**Data**: Real Ring/Nest events from production  
**Advantage**: Actual ground truth, perfect fit  
**Disadvantage**: Need to close a deal first

---

## 📚 Public Datasets That Exist

### **1. CASAS Smart Home Dataset** (Washington State University)
- **URL**: http://casas.wsu.edu/datasets/
- **Size**: 15,000+ activity recognition events
- **Format**: Sensor data (motion, door, temperature)
- **Focus**: Activity recognition (cooking, sleeping, working)
- **Good For**: Pattern learning, temporal analysis
- **Bad For**: Security/threat classification (no burglar/delivery labels)

**Example Event**:
```
2011-11-28 00:03:50.209589 M003 ON
2011-11-28 00:04:04.345621 M003 OFF
```

**Why it's not perfect**: No threat labels (safe/burglar/delivery). Just motion on/off.

---

### **2. UCI Smart Home Dataset**
- **URL**: https://archive.ics.uci.edu/ml/datasets/CASAS+dataset+for+Activities+of+Daily+Living
- **Size**: ~10,000 events
- **Format**: Sensor activations
- **Focus**: Daily activities (showering, cooking, sleeping)
- **Good For**: Normal activity baselines
- **Bad For**: Security events (no intrusions, no deliveries)

---

### **3. IoT-23 Dataset** (Czech Technical University)
- **URL**: https://www.stratosphereips.org/datasets-iot23
- **Size**: 23 IoT device captures
- **Format**: Network traffic (pcap files)
- **Focus**: Malware, botnet attacks
- **Good For**: Network security
- **Bad For**: Physical security (no motion/door events)

**Not relevant to your SDK**: This is network-level, not event-level.

---

### **4. UNSW-NB15 Dataset** (Cyber Security)
- **URL**: https://research.unsw.edu.au/projects/unsw-nb15-dataset
- **Size**: 2.5 million network flows
- **Format**: Network packets
- **Focus**: Network intrusion detection
- **Bad For**: Physical security events

---

### **5. KDD Cup 99** (Classic Security Dataset)
- **URL**: http://kdd.ics.uci.edu/databases/kddcup99/kddcup99.html
- **Size**: 5 million network connections
- **Format**: Network traffic
- **Bad For**: Not relevant to smart home physical security

---

## ⚠️ The Problem: No Perfect Public Dataset Exists

### **What You Need:**
```json
{
  "event_type": "doorbell",
  "timestamp": "2024-10-01T14:30:00Z",
  "location": "front_door",
  "confidence": 0.95,
  "metadata": {
    "person_detected": true,
    "vehicle_visible": false
  },
  "ground_truth": "delivery"  // ← THIS IS WHAT'S MISSING
}
```

### **What Public Datasets Have:**
```json
{
  "sensor_id": "M003",
  "state": "ON",
  "timestamp": "2024-10-01T14:30:00Z"
  // No context, no threat label, no rich metadata
}
```

**Gap**: Public datasets have sensor activations, NOT security event classifications.

---

## 🎯 Your Best Options

### **Option A: Use Your Synthetic Dataset** ✅ **DO THIS NOW**

**Pros:**
- ✅ Already built (BenchmarkDataset.swift)
- ✅ 10,000 scenarios ready
- ✅ Realistic JSON formats (matches Ring/Nest)
- ✅ Ground truth labels included
- ✅ Covers all scenarios (delivery, burglar, pet, etc.)
- ✅ Can run TODAY

**Cons:**
- ⚠️ Not "real-world" data
- ⚠️ Brands might question validity

**Solution**: Call it "Synthetic Benchmark Dataset" and be transparent.

**Brand Pitch**:
> "We created a synthetic dataset of 10,000 scenarios modeled after Ring/Nest event formats. While synthetic, it covers all edge cases—deliveries, burglaries, pets, prowlers—with realistic JSON payloads. We're ready to validate on YOUR real data in a 30-day pilot."

---

### **Option B: Convert CASAS Dataset** ⚠️ **PARTIAL SOLUTION**

You could convert CASAS motion/door events to your format, but:
- ❌ No ground truth labels (safe/threat)
- ❌ Would need manual labeling (thousands of events)
- ❌ Not worth the effort vs. synthetic

**Verdict**: Skip this. Your synthetic data is better.

---

### **Option C: Partner with Ring for Real Data** 🎯 **BEST LONG-TERM**

**Approach:**
1. Pitch Ring with your synthetic benchmark (80% pass rate)
2. Offer 30-day free pilot with 100 homes
3. Request access to **anonymized event logs** during pilot
4. Use their real data to validate AND improve your AI
5. Publish joint case study: "Ring Pilot Validation"

**Advantages:**
- ✅ Real production data
- ✅ Ground truth from Ring's current system
- ✅ Builds partnership trust
- ✅ Creates marketing proof ("validated on 1M+ real Ring events")

**How to Ask**:
> "During our 30-day pilot, can you provide anonymized event logs (doorbell, motion, etc.) so we can validate our AI against your ground truth? We'll sign NDA and use it only for model validation."

---

## 📊 Comparison Table

| Dataset | Size | Relevant? | Has Ground Truth? | Cost | Status |
|---------|------|-----------|-------------------|------|--------|
| **Your Synthetic** | 10K | ✅ Perfect fit | ✅ Yes | Free | ✅ Ready |
| **CASAS** | 15K | ⚠️ Partial | ❌ No threat labels | Free | Available |
| **UCI Smart Home** | 10K | ⚠️ Partial | ❌ No threat labels | Free | Available |
| **IoT-23** | 23 devices | ❌ Network-only | ❌ No events | Free | Not useful |
| **Ring Real Data** | Millions | ✅ Perfect | ✅ Yes | Pilot deal | Future |

---

## 🚀 Recommended Strategy

### **Phase 1: NOW (Use Synthetic)**
1. ✅ Use your BenchmarkDataset.swift (10K scenarios)
2. ✅ Run tests, get 80-90% pass rate
3. ✅ Export ACTUAL_TEST_RESULTS.md as proof
4. ✅ Be transparent: "Synthetic but realistic dataset"

**Pitch to Brands**:
> "We created 10,000 synthetic scenarios modeled after Ring/Nest events. 80% pass rate. We're ready to validate on YOUR real data."

### **Phase 2: PILOT (Get Real Data)**
1. Close Ring/Nest pilot deal
2. Request anonymized event logs
3. Re-run benchmark on THEIR data
4. Fix issues specific to their events
5. Publish: "Validated on 100K real Ring events - 85% accuracy"

### **Phase 3: SCALE (Build Dataset Library)**
1. Aggregate learnings from multiple brands
2. Create "NovinIntelligence Standard Benchmark"
3. Open-source the dataset (anonymized)
4. Become the industry standard for smart home security AI

---

## 📄 Sample Data You Can Create Today

Want to test with "real-ish" data? Generate from multiple brand formats:

### **Ring Format** (from their API docs):
```json
{
  "kind": "ding",
  "created_at": "2024-10-01T14:30:00.000Z",
  "motion_detected": true,
  "person_detected": true,
  "cv_properties": {
    "person_detected": true,
    "detection_type": "human"
  }
}
```

### **Nest Format**:
```json
{
  "event_id": "abc123",
  "event_type": "person",
  "timestamp": "2024-10-01T14:30:00Z",
  "zone": ["Front Door"],
  "confidence": 0.92
}
```

### **Your Unified Format**:
```json
{
  "event_type": "doorbell",
  "timestamp": "2024-10-01T14:30:00Z",
  "location": "front_door",
  "confidence": 0.95,
  "metadata": {
    "brand": "ring",
    "person_detected": true,
    "motion_detected": true
  }
}
```

**You already have this in BenchmarkDataset.swift!** ✅

---

## ✅ Final Recommendation

### **Use Your Synthetic Dataset**

**Why:**
1. ✅ It's ready NOW
2. ✅ Covers all scenarios (10K events)
3. ✅ Realistic formats (Ring/Nest compatible)
4. ✅ Ground truth included
5. ✅ Can run 80% pass rate tests TODAY

**How to Frame It:**
> "We built a comprehensive synthetic benchmark of 10,000 smart home security scenarios. While synthetic, it's modeled after Ring, Nest, and ADT event formats with realistic edge cases. We're ready to validate on real production data during your 30-day pilot."

**Brands will respect this more than:**
- ❌ Using an irrelevant public dataset (network intrusion)
- ❌ Having no benchmark at all
- ❌ Claiming results on data you don't have

### **Then Get Real Data from Ring**

Once you close a pilot:
1. Request anonymized event logs
2. Re-benchmark on THEIR data
3. Publish: "Validated on 100K+ real Ring events"
4. That becomes your REAL proof

---

## 📞 Next Steps

1. ✅ **TODAY**: Use BenchmarkDataset.swift for testing
2. ✅ **THIS WEEK**: Export results, create pitch deck
3. ✅ **NEXT MONTH**: Pitch Ring with synthetic results
4. 🎯 **PILOT**: Get real Ring data, re-validate
5. 🏆 **SCALE**: Publish industry benchmark

---

**Your synthetic dataset is GOOD ENOUGH to pitch. Get real data from brands during pilots.** 🚀

---

**File**: `/Users/Ollie/Desktop/intelligence/AVAILABLE_DATASETS.md`  
**Generated**: October 1, 2025



