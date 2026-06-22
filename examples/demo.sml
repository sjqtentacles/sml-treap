(* demo.sml

   A deterministic tour of `sml-treap`: build a treap from a fixed seed and key
   sequence, pretty-print it (drawn sideways, root at the left), show the
   structural fingerprint and in-order traversal, then split it and confirm the
   invariants hold. The full report is printed to stdout AND written verbatim to
   assets/treap.txt, so the committed asset is byte-identical under MLton and
   Poly/ML. Build and run with `make example`. *)

structure T = IntTreap

val buf = ref []
fun line s = buf := (s ^ "\n") :: !buf
fun emit () = String.concat (List.rev (!buf))

(* SplitMix64 golden-gamma seed; the tree shape is fixed by (seed, keys). *)
val seed : Word64.word = 0wx9E3779B97F4A7C15
val keys = [50, 30, 70, 20, 40, 60, 80, 10, 35, 65]

val t = T.fromList seed (map (fn k => (k, k * k)) keys)

fun showKVs kvs =
  "[" ^ String.concatWith ", "
          (map (fn (k, v) => Int.toString k ^ "->" ^ Int.toString v) kvs) ^ "]"

val () = line "=== sml-treap demo ============================================"
val () = line ""
val () = line "Seeded SplitMix64 priorities (seed = 0x9E3779B97F4A7C15)."
val () = line ("Inserted keys (in order): "
               ^ "[" ^ String.concatWith ", " (map Int.toString keys) ^ "]")
val () = line ("Values are k*k.   size = " ^ Int.toString (T.size t))
val () = line ""
val () = line "Treap (drawn sideways, root at the left;  key [p=hi16(priority)] => value):"
val () = line ""
val () = line (T.pretty Int.toString t)
val () = line "In-order traversal (sorted by key, the BST invariant):"
val () = line ("  " ^ showKVs (T.toList t))
val () = line ""
val () = line "Invariants:"
val () = line ("  validBST  = " ^ Bool.toString (T.validBST t))
val () = line ("  validHeap = " ^ Bool.toString (T.validHeap t))
val () = line ""
val () = line "Structural fingerprint (pre-order key:priority; byte-identical):"
val () = line ("  " ^ T.fingerprint t)
val () = line ""

(* split at 50, then merge back *)
val (lo, hi) = T.split t 50
val () = line "split t 50:"
val () = line ("  left  (keys < 50)  = "
               ^ "[" ^ String.concatWith ", " (map Int.toString (T.keys lo)) ^ "]")
val () = line ("  right (keys >= 50) = "
               ^ "[" ^ String.concatWith ", " (map Int.toString (T.keys hi)) ^ "]")
val merged = T.merge (lo, hi)
val () = line ("  merge(left,right) reproduces t : "
               ^ Bool.toString (T.fingerprint merged = T.fingerprint t))
val () = line ""
val () = line "==============================================================="

val output = emit ()
val () = print output

val () =
  let val os = TextIO.openOut "assets/treap.txt"
  in TextIO.output (os, output); TextIO.closeOut os end
