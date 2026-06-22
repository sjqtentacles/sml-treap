# sml-treap

A persistent (purely functional) **treap** in pure Standard ML — a binary
search tree that is simultaneously a max-heap on per-node priorities, giving
expected-logarithmic operations without explicit balancing. Priorities are
drawn from an **injected, seeded** pseudo-random generator (the vendored
[`sml-prng`](https://github.com/sjqtentacles/sml-prng)), so the tree shape
depends only on the seed and the insertion order — never on ambient randomness
— and is **deterministic**, byte-identically under both
[MLton](http://mlton.org/) and [Poly/ML](https://www.polyml.org/).

The treap is a key → value map supporting `insert`, `delete`, `lookup`,
`split`, `merge`, ordered iteration, `size`, structural fingerprinting and an
invariant validator. It is a functor over the key type and the generator, with
ready-made `IntTreap` and `StringTreap` instantiations.

## Status

- 51 assertions, green on MLton and Poly/ML.
- Basis-library + vendored `sml-prng` only; deterministic across compilers.
- Vendors `sml-prng` (Layout B), so the repo builds standalone.

## Install

With [`smlpkg`](https://github.com/diku-dk/smlpkg):

```
smlpkg add github.com/sjqtentacles/sml-treap
smlpkg sync
```

Include the MLB from your own (it pulls in the vendored `sml-prng`):

```
local
  $(SML_LIB)/basis/basis.mlb
  lib/github.com/sjqtentacles/sml-treap/... (via smlpkg)
in
  ...
end
```

This brings `functor TreapFn`, `structure IntTreap`, `structure StringTreap`
(and the vendored generators) into scope.

## Quick start

```sml
structure T = IntTreap

(* Build from a 64-bit seed + a key/value list (priorities are seeded). *)
val t = T.fromList 0w42 [(5,"e"),(3,"c"),(8,"h"),(1,"a"),(4,"d")]

val n  = T.size t                 (* 5 *)
val v  = T.lookup t 4             (* SOME "d" *)
val ks = T.keys t                 (* [1,3,4,5,8]  -- always sorted *)

(* split / merge are exact inverses (same fingerprint round-trips). *)
val (lo, hi) = T.split t 4        (* lo: keys < 4, hi: keys >= 4 *)
val t'       = T.merge (lo, hi)   (* fingerprint t' = fingerprint t *)

(* persistence: deleting returns a new treap; `t` is untouched *)
val t2 = T.delete t 3
val ok = T.valid t                (* BST + heap invariants still hold *)

(* reproducibility: same seed + sequence => identical structure *)
val a = T.fromList 0w7 [(1,1),(2,2),(3,3)]
val b = T.fromList 0w7 [(1,1),(2,2),(3,3)]
val same = (T.fingerprint a = T.fingerprint b)   (* true *)

(* a custom key type via the functor *)
structure RealTreap =
  TreapFn (structure Key = struct
                             type t = real
                             val compare = Real.compare
                             val toString = Real.toString
                           end
           structure Rng = Xoshiro256ss)
```

## API (`signature TREAP`)

```sml
type key
type 'a t

val empty   : Word64.word -> 'a t          (* seed the priority generator *)
val isEmpty : 'a t -> bool
val size    : 'a t -> int

val insert   : 'a t -> key * 'a -> 'a t     (* draws a fresh priority      *)
val fromList : Word64.word -> (key * 'a) list -> 'a t
val delete   : 'a t -> key -> 'a t
val lookup   : 'a t -> key -> 'a option
val member   : 'a t -> key -> bool

val split : 'a t -> key -> 'a t * 'a t      (* (< k, >= k)                 *)
val merge : 'a t * 'a t -> 'a t             (* all keys in l < all in r    *)

val toList : 'a t -> (key * 'a) list        (* in-order (sorted)           *)
val keys   : 'a t -> key list
val app    : (key * 'a -> unit) -> 'a t -> unit
val foldl  : (key * 'a * 'b -> 'b) -> 'b -> 'a t -> 'b

val validBST  : 'a t -> bool                (* in-order keys increasing    *)
val validHeap : 'a t -> bool                (* parent prio >= children     *)
val valid     : 'a t -> bool

val fingerprint : 'a t -> string            (* pre-order key:priority      *)
val pretty      : ('a -> string) -> 'a t -> string
```

The library is a functor

```sml
functor TreapFn (structure Key : TREAP_KEY structure Rng : RANDOM)
  :> TREAP where type key = Key.t
```

over an ordered `TREAP_KEY` (`compare` + `toString`) and a `sml-prng`
generator. `structure IntTreap = TreapFn (… IntKey … SplitMix64)` and
`structure StringTreap = TreapFn (… StringKey … SplitMix64)` are provided;
instantiate `TreapFn` yourself for other key types or to draw priorities from
`Xoshiro256ss` / `Pcg32`.

### Conventions

- **Priorities** are 64-bit words pulled from the injected generator, one per
  `insert`; the treap is a **max-heap** on them (a parent's priority is `>=`
  each child's). The generator state rides inside the treap and advances only
  on `insert`; `split`, `merge` and `delete` reuse the priorities already
  stored in the nodes, so they never consume randomness.
- **Determinism**: the shape is a pure function of (seed, insertion order).
  There is no ambient randomness, no FFI and no wall-clock; the same seed and
  sequence yield a byte-identical `fingerprint` on every run and both
  compilers. A re-inserted key keeps its priority/position (only the value is
  replaced), so `fingerprint` is stable under value updates.
- **Persistence**: every operation returns a new treap and shares structure
  with the old one; previous versions remain valid.
- **`split t k`** puts keys `< k` on the left and keys `>= k` on the right;
  **`merge (l, r)`** requires every key in `l` to be less than every key in
  `r`. They are exact inverses, so `merge (split t k) = t` structurally.
- **`fingerprint`** is a pre-order `"(key:priorityHex left right)"`
  serialisation (leaves are `.`); two treaps share a fingerprint iff they have
  the same shape, keys and priorities. `pretty` draws the tree sideways (root
  at the left) with `key [p=hi16(priority)] => value` labels.
- Everything is **integer/comparison-based** — there is no floating-point
  arithmetic anywhere in the core, so assertions are exact.

## Build & test

```
make test        # MLton
make test-poly   # Poly/ML
make all-tests   # both
make example     # build + run examples/demo.sml (writes assets/treap.txt)
make clean
```

Both compilers run the same strict-TDD suite: a fixed key sequence under a
fixed seed whose in-order traversal equals the sorted keys (BST invariant) and
whose priority max-heap invariant is asserted by a validator at every node;
`split`/`merge` round-trips checked by fingerprint equality; deletion checked
to preserve both invariants and the key set (down to the empty tree);
persistence of old versions; and a **pinned structural fingerprint** that is
asserted identical across builds and both compilers (plus a string-keyed treap
to exercise the functor).

## Example

`make example` builds a 10-key treap from a fixed seed, pretty-prints it,
shows the in-order traversal, the structural fingerprint, and a split/merge
round-trip (output is byte-identical under MLton and Poly/ML, and is the
committed asset [`assets/treap.txt`](assets/treap.txt)):

```
=== sml-treap demo ============================================

Seeded SplitMix64 priorities (seed = 0x9E3779B97F4A7C15).
Inserted keys (in order): [50, 30, 70, 20, 40, 60, 80, 10, 35, 65]
Values are k*k.   size = 10

Treap (drawn sideways, root at the left;  key [p=hi16(priority)] => value):

    80 [p=C584] => 6400
70 [p=F88B] => 4900
            65 [p=657E] => 4225
                60 [p=2C82] => 3600
        50 [p=6E78] => 2500
            40 [p=53CB] => 1600
    35 [p=F3B8] => 1225
                30 [p=06C4] => 900
            20 [p=1B39] => 400
        10 [p=3EE5] => 100

In-order traversal (sorted by key, the BST invariant):
  [10->100, 20->400, 30->900, 35->1225, 40->1600, 50->2500, 60->3600, 65->4225, 70->4900, 80->6400]

Invariants:
  validBST  = true
  validHeap = true

Structural fingerprint (pre-order key:priority; byte-identical):
  (70:F88BB8A8724C81EC (35:F3B8488C368CB0A6 (10:3EE5789041C98AC3 . (20:1B39896A51A8749B . (30:6C45D188009454F . .))) (50:6E789E6AA1B965F4 (40:53CB9F0C747EA2EA . .) (65:657EECDD3CB13D09 (60:2C829ABE1F4532E1 . .) .))) (80:C584133AC916AB3C . .))

split t 50:
  left  (keys < 50)  = [10, 20, 30, 35, 40]
  right (keys >= 50) = [50, 60, 65, 70, 80]
  merge(left,right) reproduces t : true

===============================================================
```

The root is key `70` (priority `F88B…`, the largest drawn), confirming the
max-heap on priorities; the in-order traversal is sorted, confirming the BST.

### Poly/ML note

CI builds Poly/ML 5.9.1 from source rather than using the Ubuntu package
(Poly/ML 5.7.1), whose X86 code generator crashes (`asGenReg raised while
compiling`) on heavy code; the from-source build also matches the local
toolchain so the seeded `Word64` priorities are byte-identical. See
`.github/workflows/ci.yml`.

## License

MIT — see [LICENSE](LICENSE).
