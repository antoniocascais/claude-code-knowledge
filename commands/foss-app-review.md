---
description: Security review between two versions of a FOSS Android app
argument-hint: TAG1..TAG2 (e.g., v1.2.0..v1.3.0)
allowed-tools: Read, Glob, Grep, Bash
---

# FOSS Android App Security Review

Compare two versions of a FOSS Android app to identify security regressions or concerns before updating.

**IMPORTANT**: Execute immediately without asking for confirmation.

## Workflow

### Step 1: Parse Arguments

Extract version tags from `$ARGUMENTS`:
- Expected format: `TAG1..TAG2` (e.g., `v1.2.0..v1.3.0`, `1.0..2.0`)
- If missing/invalid, show: "Usage: /foss-app-review v1.2.0..v1.3.0"

Validate tags exist:
```bash
git rev-parse --verify TAG1
git rev-parse --verify TAG2
```

### Step 2: Get Diff Overview

Generate change summary:
```bash
git diff --stat TAG1..TAG2
git diff --name-only TAG1..TAG2
```

Assess complexity for thinking budget:
- <20 files changed → standard
- 20-100 files changed → think hard
- >100 files or native code changes → ultrathink

### Step 3: Security-Focused Analysis

Analyze the diff (`git diff TAG1..TAG2`) focusing on these mobile-specific concerns:

#### 3.1 Permission Changes (Critical)
- **AndroidManifest.xml**: New `<uses-permission>`, especially dangerous ones:
  - `INTERNET`, `READ_CONTACTS`, `READ_SMS`, `CAMERA`, `RECORD_AUDIO`
  - `ACCESS_FINE_LOCATION`, `READ_EXTERNAL_STORAGE`, `SYSTEM_ALERT_WINDOW`
  - `RECEIVE_BOOT_COMPLETED`, `FOREGROUND_SERVICE`
- New `<service>`, `<receiver>`, `<provider>` with exported=true
- Intent filters that expose components

#### 3.2 Network & Data Exfiltration
- New HTTP endpoints, URLs, API calls
- New analytics/tracking SDKs
- Firebase, Crashlytics, or telemetry additions
- WebSocket connections
- Changes to network security config (`network_security_config.xml`)
- Cleartext traffic settings

#### 3.3 Cryptography Changes
- New crypto implementations or algorithm changes
- Hardcoded keys, IVs, or salts
- Weakened encryption (e.g., ECB mode, MD5, SHA1 for security)
- Certificate pinning additions/removals
- Custom TrustManagers or HostnameVerifiers

#### 3.4 Native Code (High Risk)
- New `.so` files or JNI code
- NDK/CMake changes
- Native library additions in `jniLibs/`
- System.loadLibrary() calls

#### 3.5 Code Execution & Injection
- Dynamic code loading (`DexClassLoader`, `PathClassLoader`)
- JavaScript interfaces in WebViews (`addJavascriptInterface`)
- `eval()` or reflection-based code execution
- New `ProcessBuilder`, `Runtime.exec()` calls
- SQL queries without parameterization

#### 3.6 Data Storage
- SharedPreferences for sensitive data (without encryption)
- New database schemas with PII fields
- External storage writes (`getExternalStorageDirectory`)
- Backup changes (`android:allowBackup`)

#### 3.7 Dependencies (build.gradle, pom.xml)
- New dependencies (especially closed-source)
- Version downgrades (potential vuln reintroduction)
- Suspicious or unknown libraries
- Removed security libraries

#### 3.8 Obfuscation & Anti-Analysis
- ProGuard/R8 rule changes
- Root detection additions
- Debugger detection code
- Emulator detection
- Code that behaves differently in debug vs release

#### 3.9 IPC & Deep Links
- New content providers
- Broadcast receivers without permissions
- Deep link handlers (`<intent-filter>` with `<data>`)
- PendingIntent usage without FLAG_IMMUTABLE

### Step 4: Generate Report

Output structured Markdown report:

```markdown
# Security Review: [APP_NAME] TAG1 → TAG2

## Summary
- **Files Changed**: X
- **Severity Assessment**: [Safe/Caution/Risky/Do Not Update]
- **Key Concerns**: [1-2 sentence summary]

## Permission Changes
| Permission | Status | Risk | Notes |
|------------|--------|------|-------|
| INTERNET   | Added  | Med  | New network capability |

## Findings

### [Critical/High/Medium/Low] - [Issue Title]
- **Location**: `path/to/file.java:123`
- **What Changed**: Brief description
- **Risk**: Why this matters for your phone
- **Recommendation**: Action to take

[Repeat for each finding]

## New Dependencies
| Dependency | Version | Risk Assessment |
|------------|---------|-----------------|
| lib-name   | 1.2.3   | Unknown - research needed |

## Network Changes
- New endpoints: [list]
- Tracking/analytics: [added/removed/unchanged]

## Verdict

**[SAFE TO UPDATE / PROCEED WITH CAUTION / DO NOT UPDATE]**

Reasoning: [2-3 sentences explaining verdict]

### If Cautious/Risky:
- [ ] Monitor network traffic after update
- [ ] Check app permissions in settings
- [ ] [Other specific recommendations]
```

## Constraints

- Only analyze repository files (no external lookups)
- Skip binary files, note if large binaries added
- Focus diff output on security-relevant changes
- Keep report actionable and concise (<500 lines)
- Prioritize findings by exploitability on user's phone
