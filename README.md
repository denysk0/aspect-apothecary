# Aspect Apothecary

A single-player alchemy tycoon for iPhone, built as a final project for the
"Machine Learning in iOS" course. You run a mage's potion shop: each day a queue
of customers walks in with a problem, you tease out what they actually need,
solve an aspect-combination puzzle to brew the potion, and earn coin. At the end
of the day you pay rent, which keeps climbing, so the shop has to grow. Quality
moves guild reputation, which unlocks wealthier customers and deeper puzzles.

The ML component is Apple's on-device **Foundation Models** framework doing
guided text generation, plus the **Vision** framework for the photo-scan
feature. Everything runs on device: free, private, offline, no API key.

![Aspect Apothecary main screen](docs/screenshot-main.png)

## The one rule

**The engine owns all game truth. The language model owns only language.**

A deterministic Swift engine owns the aspect graph, puzzle generation, solution
validation, quality scoring, the economy, rent, reputation, and unlocks.
Foundation Models is used only for flavor: the customer persona, their desire
(mapped to a catalog enum), the potion name and description, and the review. The
model never validates a puzzle, decides solvability, or owns a number. This keeps
the game consistent and demo-safe even though the on-device model is small and
non-deterministic.

## Gameplay loop

1. A day begins with a queue of customers. Foundation Models writes each
   persona and desire.
2. The desire maps to a potion type and tier, and the engine builds a solvable
   aspect puzzle of matching difficulty.
3. You talk to the customer to reveal the facts you need, then solve the puzzle
   on the crafting board.
4. The engine validates your solution deterministically and scores its quality.
5. Payout is fixed per potion type; quality moves the guild's reputation.
6. Foundation Models writes a review whose tone follows the engine's quality
   score.
7. At day's end you pay rent. Spare coin buys upgrades and shop items; items
   break down in the cauldron into aspects for deeper potions.

## The puzzle

Inspired by Thaumcraft 4 aspect linking. Six primal aspects (fire, water, earth,
air, order, void) combine into derived aspects on a hand-authored graph. On a
hex board you link a central essence to its anchor aspects, routing chains
through derived intermediates. Puzzles are solvable by construction: the engine
walks the graph outward from aspects you own, so a legal path always exists.

<img src="docs/screenshot-crafting.png" width="320" alt="Crafting board" />

## ML features

- **Customer text generation.** On-device guided generation for persona, desire,
  potion name and description, and the review. The model stays in character even
  when a customer line tries to derail it.
- **Photo scan.** Point the camera at a real object. Vision recognizes it, the
  language model suggests which aspects it carries, and the engine grants a
  capped amount once per kind of object.
- **Autonomous apprentice.** The language model solves a puzzle itself, one move
  at a time, from the legal moves the engine offers. It is capable but imperfect,
  so you can watch it reason and sometimes pick a wrong link.

<p>
  <img src="docs/screenshot-conversation.png" width="320" alt="Customer conversation" />
  <img src="docs/screenshot-scan.png" width="320" alt="Photo scan with Vision" />
</p>

## Progression

Reputation per guild gates which customers appear and at what tier. Rent rises
each day, so you reinvest coin into upgrades: an extra counter to serve more
customers, more customer patience, better negotiation, and the apprentice that
can solve puzzles for you.

## Apple frameworks used

- **Foundation Models** ([docs](https://developer.apple.com/documentation/foundationmodels)):
  the on-device language model. This app uses
  [`SystemLanguageModel`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
  to check availability and
  [`LanguageModelSession`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession)
  to generate persona, desire, potion text, and reviews.
- **Vision** ([docs](https://developer.apple.com/documentation/vision)): on-device
  image classification for the photo scan, via
  [`ClassifyImageRequest`](https://developer.apple.com/documentation/vision/classifyimagerequest).

## Requirements

- iOS 27, built with Xcode 27.
- An Apple-Intelligence-capable device for the on-device model (iPhone 15 Pro or
  later, or an M-series Mac). A local fallback covers text when the model is
  unavailable.

## Build and run

```bash
open AspectApothecary.xcodeproj
```

Select the AspectApothecary scheme and run on a simulator or device.

## License

[MIT](LICENSE) © denysk0
