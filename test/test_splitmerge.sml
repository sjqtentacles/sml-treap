(* test_splitmerge.sml -- split/merge round-trips and deletion.

   split t k partitions into (< k, >= k); merging the two halves back must
   reproduce the original tree exactly (same fingerprint). Deletion must
   preserve both invariants and the remaining key set. *)

structure SplitMergeTests =
struct
  open Support

  val ks = [50, 30, 70, 20, 40, 60, 80, 10, 25, 35, 65, 90]

  fun run () =
    let
      val t = ofKeys seed ks
      val sortedKs = [10,20,25,30,35,40,50,60,65,70,80,90]

      val () = Harness.section "split partitions by key"
      val (l, r) = T.split t 50
      val () = checkIntList "left half keys (< 50)" ([10,20,25,30,35,40], T.keys l)
      val () = checkIntList "right half keys (>= 50)" ([50,60,65,70,80,90], T.keys r)
      val () = Harness.checkBool "left valid" (true, T.valid l)
      val () = Harness.checkBool "right valid" (true, T.valid r)
      val () = Harness.checkInt "left size" (6, T.size l)
      val () = Harness.checkInt "right size" (6, T.size r)

      val () = Harness.section "merge is the inverse of split"
      val merged = T.merge (l, r)
      val () = checkIntList "merged keys = original sorted" (sortedKs, T.keys merged)
      val () = Harness.checkString "merge(split t) fingerprint = t"
                 (T.fingerprint t, T.fingerprint merged)
      val () = Harness.checkBool "merged valid" (true, T.valid merged)

      val () = Harness.section "split at an absent key still round-trips"
      val (l2, r2) = T.split t 55
      val () = checkIntList "left (< 55)" ([10,20,25,30,35,40,50], T.keys l2)
      val () = checkIntList "right (>= 55)" ([60,65,70,80,90], T.keys r2)
      val () = Harness.checkString "round-trip fingerprint"
                 (T.fingerprint t, T.fingerprint (T.merge (l2, r2)))

      val () = Harness.section "deletion preserves invariants"
      val d = T.delete t 50
      val () = checkIntList "key 50 removed"
                 ([10,20,25,30,35,40,60,65,70,80,90], T.keys d)
      val () = Harness.checkInt "size decreased" (11, T.size d)
      val () = Harness.checkBool "still valid after delete" (true, T.valid d)
      val () = Harness.check "deleted key absent" (T.lookup d 50 = NONE)
      val () = Harness.checkBool "delete absent key is a no-op (valid)"
                 (true, T.valid (T.delete t 999))
      val () = Harness.checkInt "delete absent key keeps size"
                 (12, T.size (T.delete t 999))

      val () = Harness.section "delete every key down to empty"
      val emptied = List.foldl (fn (k, acc) => T.delete acc k) t ks
      val () = Harness.checkBool "fully emptied" (true, T.isEmpty emptied)
      val () = Harness.checkInt "emptied size = 0" (0, T.size emptied)

      val () = Harness.section "persistence: old version intact"
      val () = Harness.checkInt "original size unchanged after delete" (12, T.size t)
      val () = Harness.check "original still has key 50" (T.lookup t 50 = SOME 50)
    in
      ()
    end
end
