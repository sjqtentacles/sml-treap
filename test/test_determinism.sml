(* test_determinism.sml -- reproducibility across builds and compilers.

   The tree shape depends ONLY on the injected seed and the insertion order, so
   two builds from the same seed+sequence produce an identical structural
   fingerprint, and the fingerprint is pinned to an exact string (which is
   therefore also asserted byte-identical on MLton and Poly/ML). A different
   seed yields a different shape. *)

structure DeterminismTests =
struct
  open Support

  val ks = [5, 3, 8, 1, 4, 7, 9, 2, 6, 0]

  (* Pinned fingerprint of `ofKeys seed [4,2,6,1,3,5,7]` (seed = golden gamma).
     This exact string must reproduce on every run and both compilers. *)
  val pinnedKeys = [4, 2, 6, 1, 3, 5, 7]
  val pinnedFingerprint =
    "(6:F88BB8A8724C81EC (4:6E789E6AA1B965F4 (3:53CB9F0C747EA2EA (1:1B39896A51A8749B . (2:6C45D188009454F . .)) .) (5:2C829ABE1F4532E1 . .)) (7:C584133AC916AB3C . .))"

  fun run () =
    let
      val () = Harness.section "same seed + sequence => identical fingerprint"
      val a = ofKeys seed ks
      val b = ofKeys seed ks
      val () = Harness.checkString "two builds match" (T.fingerprint a, T.fingerprint b)
      val () = Harness.checkBool "both valid" (true, T.valid a andalso T.valid b)

      val () = Harness.section "pinned fingerprint (byte-identical reference)"
      val pinned = ofKeys seed pinnedKeys
      val () = Harness.checkString "fingerprint matches reference vector"
                 (pinnedFingerprint, T.fingerprint pinned)

      val () = Harness.section "different seed => different shape"
      val c = ofKeys 0w1 ks
      val () = Harness.checkBool "fingerprint differs with new seed"
                 (true, T.fingerprint a <> T.fingerprint c)
      val () = Harness.checkIntList "but the key set is identical"
                 (T.keys a, T.keys c)
      val () = Harness.checkBool "alternate-seed tree still valid" (true, T.valid c)

      val () = Harness.section "string-keyed treap is deterministic too"
      val s1 = StringTreap.fromList seed
                 [("pear", 1), ("apple", 2), ("fig", 3), ("kiwi", 4)]
      val s2 = StringTreap.fromList seed
                 [("pear", 1), ("apple", 2), ("fig", 3), ("kiwi", 4)]
      val () = Harness.checkStringList "string keys sorted"
                 (["apple", "fig", "kiwi", "pear"], StringTreap.keys s1)
      val () = Harness.checkString "string treap reproducible"
                 (StringTreap.fingerprint s1, StringTreap.fingerprint s2)
      val () = Harness.checkBool "string treap valid" (true, StringTreap.valid s1)
    in
      ()
    end
end
