(* support.sml -- shared helpers for the sml-treap tests.

   The treap is keyed on ints with priorities from a seeded SplitMix64, so the
   structure is fully deterministic: every assertion is an exact integer / list
   / string / bool comparison (no floating point anywhere). *)

structure Support =
struct
  structure T = IntTreap

  (* A fixed seed used across the suite so structures are reproducible. *)
  val seed : Word64.word = 0wx9E3779B97F4A7C15

  (* Build an int-keyed treap whose values mirror the keys. *)
  fun ofKeys s ks = T.fromList s (map (fn k => (k, k)) ks)

  fun checkIntList name (e, a) = Harness.checkIntList name (e, a)
end
