# Bottle Catcher Pro

A luxury, high-performance arcade game built with Flutter and Dart. This project demonstrates smooth 60 FPS physics, premium visual effects, and a progressive milestone system.

## Features
- Pro Game Loop: Uses a Ticker-based engine for frame-independent, smooth 60 FPS movement.
- Luxury UI: Includes dynamic screen shake, golden particle explosions, and neon glow effects.
- Competitive Edge: Persistent High-Score system using shared_preferences for local data storage.
- Progressive Milestones: Unlock high-quality character rewards every 15 bottles.
- Multi-Platform: Fully optimized for Android, Web (Keyboard support), and Desktop.

## Technical Highlights
- State Management: Efficient single-tick setState batching to minimize rebuild overhead.
- Physics: Custom collision detection with "falling into crate" visual logic for realistic interaction.
- Optimization: Clean memory management with automatic object disposal to prevent leaks.

## How to Play
- Mobile: Drag the Stella crate anywhere on the screen to catch falling bottles.
- Web/PC: Use Arrow Keys or A/D keys to move left and right.
- Gameplay: Prevent bottles from hitting the floor. The player has a total of 3 lives.
