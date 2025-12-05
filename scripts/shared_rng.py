# shared_rng.py
from typing import List, TypeVar

T = TypeVar("T")

class XorShift32:
    def __init__(self, seed: int):
        s = seed & 0xFFFFFFFF
        if s == 0:
            s = 1
        self.state = s

    def _next32(self) -> int:
        x = self.state
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= (x >> 17)
        x ^= (x << 5) & 0xFFFFFFFF
        self.state = x & 0xFFFFFFFF
        return self.state

    def next_int(self, max_val: int) -> int:
        return self._next32() % max_val


def shuffle_with_seed(seq: List[T], seed: int) -> None:
    rng = XorShift32(seed)
    for i in range(len(seq) - 1, 0, -1):
        j = rng.next_int(i + 1)
        seq[i], seq[j] = seq[j], seq[i]
