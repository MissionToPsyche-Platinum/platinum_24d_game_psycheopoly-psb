# Psyche-opoly: Acquiring Asteroids

A lightweight, browser-based board game inspired by Monopoly for 2-6 players (human and AI). Built to communicate the NASA Psyche mission through accessible, privacy-respecting gameplay.

**Team:** Jason Baris, Christopher Buckley, John Fugate, Giovanni Zarrillo  
**Advisors:** Naseem Ibrahim (Course Instructor & Faculty Advisor), Cassie Bowman (Project Mentor)  
**Sponsor:** NASA/ASU Psyche Capstone Program  
**Institution:** Pennsylvania State University, World Campus

## Overview

A turn-based web game that supports STEM education by combining Monopoly-style gameplay with space-science themes. Features include turn management, dice mechanics, property system, trading, card effects, and win/loss detection—all without user accounts, data collection, or network requirements.

## Architecture

**Pattern:** Model-View-Controller (MVC)
- **Model:** Game state and logic (Game Engine Core, Game Data & Assets)
- **View:** UI rendering (game board, player tokens, panels)
- **Controller:** Input handling (user input and AI controllers)

**Deployment:** HTML5 web game with client-side execution in web browsers

## Technologies

**Engine:** Godot 4.x (open-source, HTML5 export, lightweight web performance)  
**Language:** GDScript (Python-like syntax, native Godot integration, C# fallback available)  
**Alternatives Considered:** Unity (licensing/weight issues), Unreal (deprecated web export), Phaser.js (lacks visual tooling)

## Development Practices

### Coding Conventions

The project follows official GDScript style guidelines (inspired by Python's PEP 8):

**Naming Conventions:**
- **Class Names & Nodes:** PascalCase (e.g., `GameBoard`, `PlayerToken`)
- **Functions & Variables:** snake_case (e.g., `roll_dice`, `current_player_money`)
- **Constants:** CONSTANT_CASE (e.g., `MAX_PLAYERS`, `STARTING_MONEY`)
- **Private Members:** Prefixed with underscore (e.g., `_calculate_rent()`)

**Comments:**
- Non-trivial functions and lines of code include explanatory comments
- Both block comments and inline comments are used as appropriate

### Version Control

**Git & GitHub:**
- Git for distributed version control
- GitHub for hosting code, tracking issues, and code reviews
- Industry-standard tools that make collaboration and change tracking easy

**Feature Branch Workflow:**
- `main` branch as the canonical version with restricted direct commits
- All development on separate feature branches
- Merge via Pull Requests (PR) with at least one team member review
- Ensures code quality and encourages team communication

**Commit Message Convention:**
- Format: `<commit type>: short explanation of change`
- Example: `feat: added dice roll animation`
- Provides clarity and easy traceability

## Features

### Core Gameplay
- **Player Support:** 2-6 players (human and AI)
- **Turn Management:** Fair, automated turn-based system
- **Dice Mechanics:** True random dice rolls
- **Movement & Spaces:** Complete board traversal with space resolution
- **Property System:** Acquisition, ownership, and upgrades
- **Economy:** Cash flow management and transactions
- **Trading:** Player-to-player property and resource trading
- **Card Effects:** Chance and community chest mechanics
- **Win/Loss Detection:** Automatic game conclusion

### Non-Functional Features
- **Accessibility:** UI clarity, color-safe palettes, audio-independent cues
- **Performance:** Responsive on consumer hardware
- **Privacy:** No personal data collection
- **Offline First:** Zero network connectivity required after initial load
- **Universal Access:** No user accounts needed
- **Lightweight:** Minimal resource requirements for school and low-end devices

## Getting Started

### Prerequisites
- Modern web browser with HTML5 support
- No installation required for playing
- For development: Godot Engine 4.x

### Development Setup
1. Clone the repository
2. Open the project in Godot Engine 4.x
3. Follow the coding conventions outlined above
4. Create feature branches for new development
5. Submit pull requests for code review

## License

NASA/ASU Psyche Capstone program project

## Acknowledgments

Special thanks to:
- The NASA Psyche Mission team
- Arizona State University
- Pennsylvania State University, World Campus
- All project mentors and advisors
- The Godot Engine community

---

*Merging ethical software engineering, STEM education, and space exploration accessibility.*
