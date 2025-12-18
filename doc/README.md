# BLM-recorder Documentation

Complete technical documentation for BLM-recorder iOS app development, architecture, performance optimization, and troubleshooting.

---

## Documentation Files

### 📚 [development-history.md](development-history.md)
**Complete project timeline and changes**
- Latest updates (December 2025) - HIG refactoring, spin data fixes, OCR improvements
- Changelog summary of all changes
- Historical development phases and decisions
- Performance optimization implementation
- Key achievements and lessons learned

**Start here if:** You want to understand what changed recently or the complete project evolution

---

### 🏗️ [technical-reference.md](technical-reference.md)
**Architecture, design patterns, and visual diagrams**
- System architecture and component design
- ML model integration and data flow
- Design patterns and error handling
- Visual diagrams (before/after comparisons, OCR bounding boxes, data flows)
- Memory management and performance monitoring

**Start here if:** You want to understand how the system works or need visual references

---

### ⚡ [performance.md](performance.md)
**Performance optimization guide**
- OCR rate reduction strategy
- Smart consistency validation
- Lazy model loading
- Performance logging and monitoring
- Expected results and validation

**Start here if:** You need to optimize performance or understand performance characteristics

---

### 🔧 [troubleshooting.md](troubleshooting.md)
**Build issues, failed attempts, and quick reference**
- Build troubleshooting guide (OpenCV, signing, bundle ID issues)
- Failed optimization attempts and lessons learned
- Quick reference for common tasks
- Common problems and solutions

**Start here if:** You're encountering build errors or want to learn from past mistakes

---

## Quick Navigation

**I need to...**

- **See latest changes** → [development-history.md](development-history.md) (Recent Updates section)
- **Understand architecture** → [technical-reference.md](technical-reference.md)
- **Fix build errors** → [troubleshooting.md](troubleshooting.md)
- **Optimize performance** → [performance.md](performance.md)
- **View visual diagrams** → [technical-reference.md](technical-reference.md) (Visual Reference section)

---

## Documentation Structure

```
doc/
├── README.md (you are here)
│   └── Navigation and overview
│
├── development-history.md (40 KB)
│   ├── Recent Updates (Dec 2025)
│   │   ├── HIG refactoring completion
│   │   ├── Spin data accuracy fixes
│   │   ├── OCR bounding box tuning
│   │   ├── Log cleanup
│   │   └── Settings performance fixes
│   ├── Changelog (quick summary)
│   └── Project History (original development)
│
├── technical-reference.md (28 KB)
│   ├── Architecture Overview
│   ├── Core Components
│   ├── Performance Optimizations
│   ├── Data Flow Architecture
│   └── Visual Reference (diagrams)
│
├── performance.md (15 KB)
│   ├── Optimization Strategy
│   ├── Implementation Details
│   ├── Expected Results
│   └── Validation Guide
│
└── troubleshooting.md (28 KB)
    ├── Build Troubleshooting
    ├── Failed Optimization Attempts
    ├── Quick Reference
    └── Common Issues & Solutions
```

---

## Documentation Summary

### Total Coverage
- **113 KB** of comprehensive documentation
- **4 major guides** covering all aspects
- **Complete project history** from inception to latest updates
- **Visual diagrams** for understanding complex flows
- **Troubleshooting guides** for common issues

### Key Topics Covered

**Development**
- Project inception and goals
- Implementation phases
- Recent UI/UX improvements
- Data accuracy fixes

**Technical**
- System architecture
- Component design
- ML model integration
- Error handling strategies

**Performance**
- 60-70% CPU reduction achieved
- OCR rate optimization
- Lazy loading strategies
- Performance monitoring

**Operations**
- Build setup and configuration
- Common build issues
- Failed attempts and lessons
- Quick reference commands

---

## Getting Started

1. **New to the project?**
   - Read [development-history.md](development-history.md) for complete timeline
   - Review [technical-reference.md](technical-reference.md) for architecture

2. **Need to build the app?**
   - Check [troubleshooting.md](troubleshooting.md) for build setup
   - Review common issues and solutions

3. **Want to optimize performance?**
   - Study [performance.md](performance.md) for optimization strategies
   - Review performance monitoring in [technical-reference.md](technical-reference.md)

4. **Encountering issues?**
   - Check [troubleshooting.md](troubleshooting.md) first
   - Review failed attempts for context

---

## Documentation Maintenance

**Last Updated:** December 18, 2025

**Recent Consolidation:**
- Reduced from 10 files to 5 files
- Combined related topics for better organization
- Maintained all content while improving navigation
- Added comprehensive cross-references

**Update History:**
- Dec 2025: HIG refactoring and data accuracy updates
- Dec 2025: Documentation consolidation
- Dec 2024: Performance optimization implementation
- Earlier: Initial project documentation
