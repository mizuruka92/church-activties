"""Deterministic random helpers.

Only random.Random.random() is used. Its output for a given seed is stable across
Python versions, while helpers such as choice() or shuffle() are allowed to change
between releases. Stable output matters because the generated SQL files are
committed and compared against a fresh run (see --check).
"""

import random


class Rng:
    """A named, seeded random stream. Each module uses its own stream, so
    changing one domain does not shift the random numbers of the others."""

    def __init__(self, seed, name):
        self._r = random.Random(f"{seed}:{name}")

    def random(self):
        return self._r.random()

    def randint(self, low, high):
        """Integer in [low, high], both ends included."""
        return low + int(self._r.random() * (high - low + 1))

    def chance(self, probability):
        return self._r.random() < probability

    def choice(self, items):
        return items[int(self._r.random() * len(items))]

    def weighted(self, pairs):
        """pairs is a list of (value, weight)."""
        total = sum(weight for _, weight in pairs)
        point = self._r.random() * total
        running = 0.0
        for value, weight in pairs:
            running += weight
            if point < running:
                return value
        return pairs[-1][0]

    def normal(self, mean, deviation):
        """Approximately normal (Irwin-Hall: sum of 12 uniforms). Uses only
        addition, so the result is identical on every platform."""
        total = sum(self._r.random() for _ in range(12)) - 6.0
        return mean + deviation * total

    def shuffled(self, items):
        result = list(items)
        for i in range(len(result) - 1, 0, -1):
            j = int(self._r.random() * (i + 1))
            result[i], result[j] = result[j], result[i]
        return result

    def sample(self, items, count):
        return self.shuffled(items)[:count]
