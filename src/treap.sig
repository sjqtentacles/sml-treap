(* treap.sig

   A persistent (purely functional) treap: a binary search tree on keys that is
   simultaneously a max-heap on per-node priorities. Priorities are drawn from
   an INJECTED, seeded pseudo-random generator (a vendored
   [`sml-prng`](https://github.com/sjqtentacles/sml-prng) `RANDOM`), so the tree
   shape depends only on the seed and the insertion order -- never on ambient
   randomness -- and is byte-identical on MLton and Poly/ML.

   The treap is a key -> value map. Every operation returns a new treap; old
   versions remain valid (persistence). The generator state rides along inside
   the treap and advances on each `insert`; `split`/`merge`/`delete` reuse the
   priorities already stored in the nodes, so they never touch the generator.

   `TREAP_KEY` is an ordered key with a `toString` for fingerprints/rendering. *)

signature TREAP_KEY =
sig
  type t
  val compare  : t * t -> order
  val toString : t -> string
end

signature TREAP =
sig
  type key
  type 'a t

  (* An empty treap seeded for priority generation. *)
  val empty   : Word64.word -> 'a t
  val isEmpty : 'a t -> bool
  val size    : 'a t -> int

  (* Insert / update (draws a fresh priority for a new key; an existing key
     keeps its priority and position, only the value is replaced). *)
  val insert : 'a t -> key * 'a -> 'a t
  (* Build by inserting a list left-to-right from a seed. *)
  val fromList : Word64.word -> (key * 'a) list -> 'a t

  val delete : 'a t -> key -> 'a t
  val lookup : 'a t -> key -> 'a option
  val member : 'a t -> key -> bool

  (* split t k = (l, r): l has every key < k, r has every key >= k. *)
  val split : 'a t -> key -> 'a t * 'a t
  (* merge (l, r): every key in l must be < every key in r. *)
  val merge : 'a t * 'a t -> 'a t

  (* In-order (sorted by key) traversals. *)
  val toList : 'a t -> (key * 'a) list
  val keys   : 'a t -> key list
  val app    : (key * 'a -> unit) -> 'a t -> unit
  val foldl  : (key * 'a * 'b -> 'b) -> 'b -> 'a t -> 'b

  (* Invariant validators. *)
  val validBST  : 'a t -> bool   (* in-order keys strictly increasing      *)
  val validHeap : 'a t -> bool   (* every parent priority >= its children  *)
  val valid     : 'a t -> bool   (* both of the above                      *)

  (* A structural fingerprint: a pre-order "key:priority" serialisation that is
     identical iff two treaps have the same shape, keys and priorities. *)
  val fingerprint : 'a t -> string

  (* A deterministic ASCII rendering (tree drawn sideways, root at the left). *)
  val pretty : ('a -> string) -> 'a t -> string
end
