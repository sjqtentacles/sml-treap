(* test_invariants.sml -- BST + heap invariants and basic map operations.

   Inserting any key sequence with a fixed seed must yield an in-order
   traversal equal to the sorted, de-duplicated keys (the BST invariant), and
   the priority max-heap invariant must hold at every node. *)

structure InvariantTests =
struct
  open Support

  val ks = [5, 3, 8, 1, 4, 7, 9, 2, 6, 0]
  val sorted = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

  fun run () =
    let
      val t = ofKeys seed ks

      val () = Harness.section "BST invariant (in-order = sorted keys)"
      val () = checkIntList "in-order traversal is sorted" (sorted, T.keys t)
      val () = Harness.checkBool "validBST" (true, T.validBST t)

      val () = Harness.section "heap invariant"
      val () = Harness.checkBool "validHeap" (true, T.validHeap t)
      val () = Harness.checkBool "valid (both)" (true, T.valid t)

      val () = Harness.section "size"
      val () = Harness.checkInt "size = 10" (10, T.size t)
      val () = Harness.checkBool "empty isEmpty" (true, T.isEmpty (T.empty seed))
      val () = Harness.checkInt "empty size = 0" (0, T.size (T.empty seed))
      val () = Harness.checkBool "non-empty not isEmpty" (false, T.isEmpty t)

      val () = Harness.section "lookup / member"
      val () = Harness.checkBool "member 7" (true, T.member t 7)
      val () = Harness.checkBool "not member 42" (false, T.member t 42)
      val () = Harness.check "lookup 4 = SOME 4" (T.lookup t 4 = SOME 4)
      val () = Harness.check "lookup 42 = NONE" (T.lookup t 42 = NONE)

      val () = Harness.section "duplicate keys / value update"
      val t2 = T.insert t (4, 400)
      val () = Harness.checkInt "size unchanged after re-insert" (10, T.size t2)
      val () = Harness.check "value updated to 400" (T.lookup t2 4 = SOME 400)
      val () = Harness.checkBool "still valid after update" (true, T.valid t2)
      val () = Harness.checkString "fingerprint shape unchanged by value update"
                 (T.fingerprint t, T.fingerprint t2)

      val () = Harness.section "insertion order independence (set semantics)"
      val a = ofKeys seed [1, 2, 3, 4, 5, 6, 7]
      val b = ofKeys seed [7, 6, 5, 4, 3, 2, 1]
      (* Same seed assigns priority by draw order, so different insert orders
         give different priorities -- but both must be valid BSTs with the same
         key set. *)
      val () = checkIntList "ascending insert keys" ([1,2,3,4,5,6,7], T.keys a)
      val () = checkIntList "descending insert keys" ([1,2,3,4,5,6,7], T.keys b)
      val () = Harness.checkBool "ascending valid" (true, T.valid a)
      val () = Harness.checkBool "descending valid" (true, T.valid b)
    in
      ()
    end
end
