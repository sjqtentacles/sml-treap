(* treap.sml -- a persistent, seeded treap (BST + priority max-heap).

   `TreapFn` is parameterised over an ordered key and an injected `RANDOM`
   generator from the vendored sml-prng. Priorities are 64-bit words pulled from
   the generator on each insert; the tree is a max-heap on those priorities and
   a binary search tree on keys, so its shape is fixed by (seed, insertion
   order) and is byte-identical across compilers.

   All node operations are purely functional. `insert` advances the generator;
   `split`/`merge`/`delete` reuse stored priorities and never touch it. *)

functor TreapFn (structure Key : TREAP_KEY
                 structure Rng : RANDOM) :> TREAP where type key = Key.t =
struct
  structure W = Word64

  type key = Key.t

  datatype 'a node =
      Leaf
    | Node of { key : key, prio : W.word, value : 'a,
                left : 'a node, right : 'a node }

  type 'a t = { root : 'a node, gen : Rng.state }

  fun empty w = { root = Leaf, gen = Rng.seed w }

  fun isEmpty { root = Leaf, gen = _ } = true
    | isEmpty _ = false

  fun sizeN Leaf = 0
    | sizeN (Node { left, right, ... }) = 1 + sizeN left + sizeN right
  fun size { root, gen = _ } = sizeN root

  (* ---- rotations (preserve BST order, lift a child by priority) -------- *)
  fun rotR (Node { key, prio, value,
                   left = Node { key = lk, prio = lp, value = lv,
                                 left = ll, right = lr }, right }) =
        Node { key = lk, prio = lp, value = lv, left = ll,
               right = Node { key = key, prio = prio, value = value,
                              left = lr, right = right } }
    | rotR n = n

  fun rotL (Node { key, prio, value, left,
                   right = Node { key = rk, prio = rp, value = rv,
                                  left = rl, right = rr } }) =
        Node { key = rk, prio = rp, value = rv,
               left = Node { key = key, prio = prio, value = value,
                             left = left, right = rl }, right = rr }
    | rotL n = n

  (* ---- insert (rotation-based, max-heap) ------------------------------- *)
  fun insNode (Leaf, k, v, p) =
        Node { key = k, prio = p, value = v, left = Leaf, right = Leaf }
    | insNode (Node nd, k, v, p) =
        (case Key.compare (k, #key nd) of
           EQUAL =>
             (* key already present: keep priority/position, replace value *)
             Node { key = #key nd, prio = #prio nd, value = v,
                    left = #left nd, right = #right nd }
         | LESS =>
             let
               val n = Node { key = #key nd, prio = #prio nd, value = #value nd,
                              left = insNode (#left nd, k, v, p), right = #right nd }
             in
               case n of
                 Node { left = Node { prio = lp, ... }, prio, ... } =>
                   if W.> (lp, prio) then rotR n else n
               | _ => n
             end
         | GREATER =>
             let
               val n = Node { key = #key nd, prio = #prio nd, value = #value nd,
                              left = #left nd, right = insNode (#right nd, k, v, p) }
             in
               case n of
                 Node { right = Node { prio = rp, ... }, prio, ... } =>
                   if W.> (rp, prio) then rotL n else n
               | _ => n
             end)

  fun insert { root, gen } (k, v) =
    let val (w, gen') = Rng.next gen
    in { root = insNode (root, k, v, w), gen = gen' } end

  fun fromList w kvs = foldl (fn (kv, t) => insert t kv) (empty w) kvs

  (* ---- merge two subtrees (all keys in a < all keys in b) -------------- *)
  fun mergeN (Leaf, t) = t
    | mergeN (t, Leaf) = t
    | mergeN (a as Node na, b as Node nb) =
        if W.>= (#prio na, #prio nb) then
          Node { key = #key na, prio = #prio na, value = #value na,
                 left = #left na, right = mergeN (#right na, b) }
        else
          Node { key = #key nb, prio = #prio nb, value = #value nb,
                 left = mergeN (a, #left nb), right = #right nb }

  (* ---- delete ---------------------------------------------------------- *)
  fun delNode (Leaf, _) = Leaf
    | delNode (Node nd, k) =
        (case Key.compare (k, #key nd) of
           LESS =>
             Node { key = #key nd, prio = #prio nd, value = #value nd,
                    left = delNode (#left nd, k), right = #right nd }
         | GREATER =>
             Node { key = #key nd, prio = #prio nd, value = #value nd,
                    left = #left nd, right = delNode (#right nd, k) }
         | EQUAL => mergeN (#left nd, #right nd))

  fun delete { root, gen } k = { root = delNode (root, k), gen = gen }

  (* ---- split (left: keys < k, right: keys >= k) ------------------------ *)
  fun splitN (Leaf, _) = (Leaf, Leaf)
    | splitN (Node nd, k) =
        (case Key.compare (#key nd, k) of
           LESS =>
             let val (rl, rr) = splitN (#right nd, k)
             in (Node { key = #key nd, prio = #prio nd, value = #value nd,
                        left = #left nd, right = rl }, rr) end
         | _ =>
             let val (ll, lr) = splitN (#left nd, k)
             in (ll, Node { key = #key nd, prio = #prio nd, value = #value nd,
                            left = lr, right = #right nd }) end)

  fun split { root, gen } k =
    let val (l, r) = splitN (root, k)
    in ({ root = l, gen = gen }, { root = r, gen = gen }) end

  fun merge ({ root = l, gen }, { root = r, gen = _ }) =
    { root = mergeN (l, r), gen = gen }

  (* ---- queries --------------------------------------------------------- *)
  fun lookupN (Leaf, _) = NONE
    | lookupN (Node nd, k) =
        (case Key.compare (k, #key nd) of
           EQUAL => SOME (#value nd)
         | LESS => lookupN (#left nd, k)
         | GREATER => lookupN (#right nd, k))
  fun lookup { root, gen = _ } k = lookupN (root, k)
  fun member t k = case lookup t k of NONE => false | SOME _ => true

  (* ---- in-order traversals --------------------------------------------- *)
  fun foldrN f acc Leaf = acc
    | foldrN f acc (Node { key, value, left, right, ... }) =
        foldrN f (f (key, value, foldrN f acc right)) left

  fun toList { root, gen = _ } =
    foldrN (fn (k, v, acc) => (k, v) :: acc) [] root
  fun keys { root, gen = _ } = foldrN (fn (k, _, acc) => k :: acc) [] root

  fun foldl f acc { root, gen = _ } =
    let
      fun go (Leaf, a) = a
        | go (Node { key, value, left, right, ... }, a) =
            go (right, f (key, value, go (left, a)))
    in go (root, acc) end

  fun app f t = List.app f (toList t)

  (* ---- invariant validators -------------------------------------------- *)
  fun validBST t =
    let
      fun inc (a :: (rest as b :: _)) =
            Key.compare (a, b) = LESS andalso inc rest
        | inc _ = true
    in inc (keys t) end

  fun validHeap { root, gen = _ } =
    let
      fun chk (_, Leaf) = true
        | chk (p, Node { prio, ... }) = W.>= (p, prio)
      fun go Leaf = true
        | go (Node { prio, left, right, ... }) =
            chk (prio, left) andalso chk (prio, right)
            andalso go left andalso go right
    in go root end

  fun valid t = validBST t andalso validHeap t

  (* ---- fingerprint & rendering ----------------------------------------- *)
  fun fingerprint { root, gen = _ } =
    let
      fun go Leaf = "."
        | go (Node { key, prio, left, right, ... }) =
            "(" ^ Key.toString key ^ ":" ^ W.toString prio
            ^ " " ^ go left ^ " " ^ go right ^ ")"
    in go root end

  fun pretty valToString { root, gen = _ } =
    let
      val step = 4
      fun spaces n = CharVector.tabulate (n, fn _ => #" ")
      (* top 16 bits of the priority, as 4 hex digits, for a compact label *)
      fun shortPrio w =
        StringCvt.padLeft #"0" 4 (W.toString (W.>> (w, 0w48)))
      fun label (key, prio, value) =
        let val v = valToString value
        in
          Key.toString key ^ " [p=" ^ shortPrio prio ^ "]"
          ^ (if v = "" then "" else " => " ^ v)
        end
      fun go (Leaf, _) = ""
        | go (Node { key, prio, value, left, right }, d) =
            go (right, d + 1)
            ^ spaces (d * step) ^ label (key, prio, value) ^ "\n"
            ^ go (left, d + 1)
    in go (root, 0) end
end

(* ---- default key types and instantiations ----------------------------- *)

structure IntKey : TREAP_KEY =
struct
  type t = int
  val compare = Int.compare
  val toString = Int.toString
end

structure StringKey : TREAP_KEY =
struct
  type t = string
  val compare = String.compare
  fun toString s = s
end

(* The default treap: int keys, priorities from SplitMix64. *)
structure IntTreap = TreapFn (structure Key = IntKey structure Rng = SplitMix64)
structure StringTreap = TreapFn (structure Key = StringKey structure Rng = SplitMix64)
