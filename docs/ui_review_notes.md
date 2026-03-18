# UI Review Notes: ISSUE-010 -- Wire AnimationManager to menu bar icon

## State Coverage
- **OFF**: Static sleeping zombie icon (ZombieSleep via animationManager.staticOffIcon) -- PASS
- **ON**: Animated frames cycling at 6fps via frame observer -- PASS
- **OFF->ON**: Wake-up transition frames play before main loop starts -- PASS
- **ON->OFF (manual)**: Fall-asleep transition plays then static OFF -- PASS
- **ON->OFF (auto)**: Auto-OFF transition (4 frames) via playAutoOffTransition() -- PASS
- **Launch**: 200ms opacity fade-in via NSAnimationContext -- PASS
- **Error + animation**: Red dot overlay preserved during animated frames -- PASS

## Copy Compliance
- No new user-facing strings introduced.
- Existing VoiceOver announcements maintained from ISSUE-017.

## Accessibility
- VoiceOver labels preserved from prior implementation
- Reduced motion: AnimationManager handles static frame fallback (inherited from ISSUE-009)
- Error announcements maintained during animation states

## Interaction Fidelity
- Left-click triggers toggle with appropriate transition animation
- Frame observer timer syncs with AnimationManager fps (no drift)
- stopAnimation() before playTransition(.wakeUp) prevents visual glitches
- Frame observer stopped before fall-asleep transition starts

## Findings
- No Critical or High severity findings.
