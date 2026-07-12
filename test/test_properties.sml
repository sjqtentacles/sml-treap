(* test_properties.sml -- sml-check property-based tests for sml-treap.

   Uses the same fixed Support.seed as the rest of the suite so every build
   is fully deterministic (the treap shape depends only on the seed and the
   insertion order). Keys/values are small ints so nothing overflows the
   default 32-bit int on MLton. *)

structure PropertyTests =
struct
  open Support

  val smallInt = Check.choose (~500, 500)
  val genPair = Check.tuple2 (smallInt, smallInt)
  val genList = Check.listOf genPair

  fun showPair (k, v) = "(" ^ Int.toString k ^ "," ^ Int.toString v ^ ")"
  fun showPairList xs = "[" ^ String.concatWith "," (List.map showPair xs) ^ "]"
  fun showIntList xs = "[" ^ String.concatWith "," (List.map Int.toString xs) ^ "]"

  fun dedupKeys ks =
    List.foldr
      (fn (k, acc) => if List.exists (fn k' => k' = k) acc then acc else k :: acc)
      [] ks

  fun buildFromPairs xs = List.foldl (fn ((k, v), t) => T.insert t (k, v)) (T.empty seed) xs

  fun isSorted xs =
    case xs of
        [] => true
      | [_] => true
      | a :: (rest as b :: _) => a < b andalso isSorted rest

  fun run () =
    let
      val () = Harness.section "properties (sml-check)"

      (* insert-then-lookup returns the inserted value. *)
      val () =
        Harness.check "prop: insert-then-lookup returns the inserted value"
          (case Check.quickCheck
                  (Check.forAll
                     (Check.tuple3 (genList, smallInt, smallInt))
                     (fn (xs, k, v) => showPairList xs ^ " k=" ^ Int.toString k
                                        ^ " v=" ^ Int.toString v)
                     (fn (xs, k, v) =>
                        let val t = buildFromPairs xs
                            val t' = T.insert t (k, v)
                        in T.lookup t' k = SOME v end)) of
               Check.Passed _ => true
             | Check.Failed _ => false)

      (* delete-then-lookup returns NONE, whether or not the key was present. *)
      val () =
        Harness.check "prop: delete-then-lookup returns NONE"
          (case Check.quickCheck
                  (Check.forAll
                     (Check.tuple2 (genList, smallInt))
                     (fn (xs, k) => showPairList xs ^ " k=" ^ Int.toString k)
                     (fn (xs, k) =>
                        let val t = buildFromPairs xs
                            val t' = T.delete t k
                        in T.lookup t' k = NONE end)) of
               Check.Passed _ => true
             | Check.Failed _ => false)

      (* both the BST and max-heap invariants hold, and the in-order key
         traversal is strictly ascending, after any sequence of inserts. *)
      val () =
        Harness.check "prop: valid (BST + heap) and keys strictly ascending"
          (case Check.quickCheck
                  (Check.forAll genList showPairList
                     (fn xs =>
                        let val t = buildFromPairs xs
                        in T.valid t andalso isSorted (T.keys t) end)) of
               Check.Passed _ => true
             | Check.Failed _ => false)

      (* split t k, then merge the two halves back, reproduces the original
         tree exactly (same structural fingerprint) for any split key. *)
      val () =
        Harness.check "prop: merge(split t k) = t (fingerprint round-trip)"
          (case Check.quickCheck
                  (Check.forAll
                     (Check.tuple2 (genList, smallInt))
                     (fn (xs, k) => showPairList xs ^ " k=" ^ Int.toString k)
                     (fn (xs, k) =>
                        let val t = buildFromPairs xs
                            val (l, r) = T.split t k
                            val merged = T.merge (l, r)
                        in T.fingerprint merged = T.fingerprint t
                           andalso T.valid l andalso T.valid r andalso T.valid merged
                        end)) of
               Check.Passed _ => true
             | Check.Failed _ => false)

      (* inserting a set of distinct keys yields a treap of exactly that
         size. *)
      val () =
        Harness.check "prop: size after inserting N distinct keys = N"
          (case Check.quickCheck
                  (Check.forAll (Check.listOf smallInt) showIntList
                     (fn ks =>
                        let val distinct = dedupKeys ks
                            val t = ofKeys seed distinct
                        in T.size t = List.length distinct end)) of
               Check.Passed _ => true
             | Check.Failed _ => false)
    in
      ()
    end
end
