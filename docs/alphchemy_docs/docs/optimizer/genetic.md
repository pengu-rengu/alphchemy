# Optimizer settings

The Optimizer node maintains a **population** of candidate strategies. Each iteration (one "generation"), it:

1. Scores every candidate in the population on training and validation.
2. Keeps the top performers ("elites") unchanged.
3. Fills the rest of the next generation by **selecting** two parents from the current generation, **crossing them over** to produce a child, and **mutating** that child.
4. Updates its best-seen-so-far records and checks if it should stop.

Over many generations, the population drifts toward strategies that score well. Mutation keeps it exploring; crossover combines successful pieces; elitism preserves the best findings.

## Optimizer fields

| Field | Meaning |
|---|---|
| Population Size | How many candidate strategies live in the population each generation. Must be > 0. Bigger = more thorough exploration, slower per generation. Typical: 50–200. |
| Sequence Length | How many build operations each candidate is built from. Bigger = more capacity to build complex networks. **Bigger also means more overfitting risk.** Typical: 20–60. |
| # Of Elites | How many top scorers carried to the next generation unchanged. Must be ≤ Population Size. Typical: 5–10% of Population Size. |
| Mutation Rate | Probability that any single operation in a child gets randomly replaced. Range 0–1. Typical: 0.05–0.15. Higher = more exploration but slower convergence. |
| Crossover Rate | Probability that a child is built by combining two parents (vs cloned from one). Range 0–1. Typical: 0.7–0.9. |
| Tournament Size | When picking a parent, this many candidates are chosen at random and the highest-scoring one wins. Bigger = stronger selection pressure (faster convergence, more chance of getting stuck in a local optimum). Must be between 1 and Population Size. Typical: 3–7. |

## Tuning tips

| Symptom | Try |
|---|---|
| Search finishes too fast and the result is weak | Increase Population Size and Sequence Length, lower Tournament Size to keep more variety. |
| Search runs to Max Iterations and never converges | Increase Tournament Size, raise # Of Elites, lower Mutation Rate. |
| Overfitting | Lower Sequence Length (smaller candidates), shorten Validation Patience, raise complexity penalties on the Penalties node. |

**Sequence Length** is the single most powerful overfitting lever here. A long sequence can build a wildly complex network even if you start from a small Base Network.
