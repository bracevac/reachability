Require Export Arith.EqNat.
Require Export Arith.Le.
Require Import Coq.Program.Equality.
Require Import Coq.Bool.Bool.
Require Import Coq.Arith.Arith.
Require Import Coq.Lists.List.
Require Import Psatz.
Require Import Coq.Arith.Compare_dec.
Import ListNotations.

Require Import Coq.Logic.ProofIrrelevance.

Require Import vars.
Require Import env.
Require Import tactics.
Require Import NatSets.
Require Import setfacts.

Import NatSet.F.

(* Type qualifiers. *)

Inductive qual : Type :=
| qbot (* untracked *)
| qset : nats(* free variables *) -> nats(* bound variables *) -> nats(* store locations *) -> qual
.

Definition just_fv (x : id) : qual := qset (singleton x) {}N {}N.
Definition just_bv (x : id) : qual := qset {}N (singleton x) {}N.
Definition just_loc (l : loc) : qual := qset {}N {}N (singleton l).

Definition qfvs (q: qual) : nats :=
  match q with
  | qbot => {}N
  | qset fvs _ _ => fvs
  end.

Definition qbvs (q: qual) : nats :=
  match q with
  | qbot => {}N
  | qset _ bvs _ => bvs
  end.

Definition qlocs (q: qual) : nats :=
  match q with
  | qbot => {}N
  | qset _ _ ls => ls
  end.

Definition qmemb (v : var + loc) (d : qual) : bool  :=
  match d with
  | qbot => false
  | qset vs bs ls => match v with
                    | inl (varF v) => mem v vs
                    | inl (varB v) => mem v bs
                    | inr l        => mem l ls
                    end
  end.

Definition qmem (v : var + loc) (d : qual) : Prop :=
  match d with
  | qbot => False
  | qset vs bs ls => match v with
                    | inl (varF v) => In v vs
                    | inl (varB v) => In v bs
                    | inr l        => In l ls
                    end
  end.

Definition subqual (d1 d2 : qual) : Prop :=
  match d1 , d2 with
  | qbot, _ => True
  | _, qbot => False
  | qset fs1 bs1 ls1 , qset fs2 bs2 ls2 => (Subset fs1 fs2) /\ (Subset bs1 bs2) /\ (Subset ls1 ls2)
  end.

Definition subqualb (d1 d2 : qual) : bool :=
  match d1, d2 with
  | qbot, _ => true
  | _, qbot => false
  | qset vs1 bs1 ls1, qset vs2 bs2 ls2 =>
    fold_right andb true [(subset vs1 vs2); (subset bs1 bs2); (subset ls1 ls2)]
  end.

Definition eqqual (d1 d2 : qual) : Prop :=
  match d1 , d2 with
  | qbot, qbot => True
  | qset fs1 bs1 ls1 , qset fs2 bs2 ls2 => (Equal fs1 fs2) /\ (Equal bs1 bs2) /\ (Equal ls1 ls2)
  | _, _ => False
  end.

Definition eqqualb (d1 d2 : qual): bool :=
  match d1 , d2 with
  | qbot, qbot => true
  | qset fs1 bs1 ls1 , qset fs2 bs2 ls2 => (equal fs1 fs2) && (equal bs1 bs2) && (equal ls1 ls2)
  | _, _ => false
  end.

(* Semilattice ops on qualifiers *)
Definition qlub (d1 d2 : qual) : qual :=
  match d1, d2 with
  | qbot, d2 => d2
  | d1, qbot => d1
  | qset vs1 bs1 ls1, qset vs2 bs2 ls2 => qset (union vs1 vs2) (union bs1 bs2) (union ls1 ls2)
  end.

Definition qglb (d1 d2 : qual) : qual :=
  match d1, d2 with
  | qbot, _ => qbot
  | _, qbot => qbot
  | qset vs1 bs1 ls1, qset vs2 bs2 ls2 => qset (inter vs1 vs2) (inter bs1 bs2) (inter ls1 ls2)
  end.

Definition qplus (d : qual) (x : id) : qual :=
  match d with
  | qbot => qbot
  | q => qlub d (just_fv x)
  end.

(* The cancelling union generalized to qualifiers as second arg *)
Definition qqplus (q1 q2 : qual) : qual :=
  match q1 with
  | qbot => qbot
  | q    => qlub q1 q2
  end.

(* The intersection as used by T-App *)
Definition qqcap (q1 q2 : qual) : qual :=
  match (q1, q2) with
  | (qbot, qbot) => qbot
  | (qbot, _) => (qset {}N {}N {}N)
  | (_, qbot) => (qset {}N {}N {}N)
  | (_, _) => qglb q1 q2
  end.

Definition ldom {A} (Σ : list A) := qset {}N {}N (dom Σ).
#[global] Hint Unfold ldom : core.

Module QualNotations.
  Declare Scope qualifiers.

  Notation "⊥" := qbot (at level 9) : qualifiers.
  Notation "∅" := (qset {}N {}N {}N) (at level 9) : qualifiers.

  Notation "l ∈ₗ d"  := (qmem (inr l) d) (at level 75) : qualifiers.
  Notation "v ∈ᵥ d"  := (qmem (inl v) d) (at level 75) : qualifiers.
  Notation "l ∈?ₗ d" := (qmemb (inr l) d) (at level 75) : qualifiers.
  Notation "v ∈?ᵥ d" := (qmemb (inl v) d) (at level 75) : qualifiers.

  Notation "$$ x " := (just_fv x) (at level 0, right associativity) : qualifiers.
  Notation "## x " := (just_bv x) (at level 0, right associativity) : qualifiers.
  Notation "&& l " := (just_loc l) (at level 0, right associativity) : qualifiers.

  Notation "d1 ⊑ d2" := (subqual d1 d2) (at level 75) : qualifiers.
  Notation "d1 ⊑? d2" := (subqualb d1 d2) (at level 75) : qualifiers.

  Notation "d1 ≡ d2" := (eqqual d1 d2) (at level 75) : qualifiers.
  Notation "d1 ≡? d2" := (eqqualb d1 d2) (at level 75) : qualifiers.

  Notation "d1 ⊔ d2" := (qlub d1 d2) (at level 70, right associativity) : qualifiers.
  Notation "d1 ⊓ d2" := (qglb d1 d2) (at level 65, right associativity) : qualifiers.

  Notation "d1 ⊕ x" := (qplus d1 x) (at level 70) : qualifiers.

  Notation "q1 ⋓ q2" := (qqplus q1 q2) (at level 70, right associativity) : qualifiers.
  Notation "q1 ⋒ q2" := (qqcap q1 q2) (at level 65, right associativity) : qualifiers.

End QualNotations.
Import QualNotations.
Local Open Scope qualifiers.

Require Import Coq.Bool.Bool.

Lemma qmem_reflect : forall {v d}, reflect (qmem v d) (qmemb v d).
  intros. destruct d.
  - simpl. constructor. intuition.
  - simpl. destruct v. destruct v.
    destruct (mem i t0) eqn:Hmem; try constructor; intuition.
    rewrite <- NatSetFacts.not_mem_iff in Hmem. auto.
    destruct (mem i t1) eqn:Hmem; try constructor; intuition.
    rewrite <- NatSetFacts.not_mem_iff in Hmem. auto.
    destruct (mem l t2) eqn:Hmem; try constructor; intuition.
    rewrite <- NatSetFacts.not_mem_iff in Hmem. auto.
Qed.

Lemma qmem_decidable : forall v d, {qmem v d} + {~ qmem v d}.
  intros. eapply reflect_dec. apply qmem_reflect.
Qed.

Lemma subqual_reflect : forall {d1 d2}, reflect (subqual d1 d2) (subqualb d1 d2).
Proof.
  intros.
  destruct (d1 ⊑? d2) eqn:Hsub; try constructor;
    destruct d1; destruct d2; simpl in *; intuition;
    repeat rewrite andb_true_iff in Hsub; intuition.
  repeat rewrite andb_false_iff in Hsub. intuition.
  apply subset_1 in H0. rewrite H0 in H1. discriminate.
  apply subset_1 in H. rewrite H in H3. discriminate.
  apply subset_1 in H2. rewrite H2 in H1. discriminate.
Qed.

Lemma subqual_decidable : forall d1 d2, {d1 ⊑ d2} + {~ d1 ⊑ d2}.
  intros. eapply reflect_dec. apply subqual_reflect.
Qed.

Lemma subqualb_true_iff : forall {d1 d2}, (d1 ⊑? d2) = true <-> d1 ⊑ d2.
  intuition. erewrite reflect_iff. eauto. apply subqual_reflect.
  erewrite <- reflect_iff; eauto. apply subqual_reflect.
Qed.

Lemma subqualb_false_iff : forall {d1 d2}, (d1 ⊑? d2) = false <-> ~ d1 ⊑ d2.
  intuition. rewrite <- subqualb_true_iff in H0. rewrite H in H0.
  discriminate. destruct (d1 ⊑? d2) eqn:Heq.
  rewrite subqualb_true_iff in Heq. contradiction.
  auto.
Qed.

Lemma eqqual_reflect : forall {d1 d2}, reflect (eqqual d1 d2) (eqqualb d1 d2).
Proof.
  intros. destruct d1; destruct d2; simpl; intuition.
  apply iff_reflect. split; intros; intuition.
  apply equal_1 in H0. apply equal_1 in H. apply equal_1 in H2. intuition.
  1-3: repeat rewrite andb_true_iff in H; intuition; fnsetdec.
Qed.

Lemma eqqual_decidable : forall d1 d2, {d1 ≡ d2} + {~ d1 ≡ d2}.
  intros. eapply reflect_dec. apply eqqual_reflect.
Qed.

(* Lifts the extensional equality of the underlying set impl to qualifiers *)
Lemma eq_if_eqqual : forall {d1 d2}, d1 ≡ d2 -> d1 = d2.
  intros. destruct d1; destruct d2; auto; inversion H. unfold eqqual in H. intuition.
  f_equal; apply NatSet.eq_if_Equal; auto.
Qed.

Lemma subqual_refl : forall {d1}, d1 ⊑ d1.
  intros. unfold subqual.
  destruct d1; intuition.
Qed.
#[global] Hint Resolve subqual_refl : core.

Lemma subqual_trans : forall {d1 d2 d3}, d1 ⊑ d2 -> d2 ⊑ d3 -> d1 ⊑ d3.
  intros. unfold subqual in *. destruct d1; auto.
  destruct d2; auto; intuition. destruct d3; auto. fnsetdec.
Qed.

Lemma subqual_antisymm : forall {d1 d2}, d1 ⊑ d2 -> d2 ⊑ d1 -> d1 ≡ d2.
  intros. unfold eqqual in *. unfold subqual in *.
  destruct d1; auto. destruct d2; auto. intuition.
Qed.

Lemma eqqual_refl : forall {d}, d ≡ d.
  intros. unfold eqqual. destruct d; auto. intuition.
Qed.
#[global] Hint Resolve eqqual_refl : core.

Lemma eqqual_sym : forall {d1 d2}, d1 ≡ d2 -> d2 ≡ d1.
  unfold eqqual. destruct d1; auto. destruct d2; auto. intuition.
Qed.

Lemma eqqual_trans : forall {d1 d2 d3}, d1 ≡ d2 -> d2 ≡ d3 -> d1 ≡ d3.
  unfold eqqual. destruct d1; auto; destruct d2; auto; destruct d3; auto;
                   intros; intuition; fnsetdec.
Qed.

Ltac qdec :=
  try apply eq_if_eqqual;
  try unfold qglb in *;
  try unfold qlub in *;
  try unfold eqqual in *;
  try unfold subqual in *;
  simpl;
  intuition;
  try apply NatSet.eq_if_Equal; NatSetDecide.fsetdec.

Lemma subqual_plus : forall {d1 d2}, d1 ⊑ d2 -> forall {x}, d1 ⊕ x ⊑ d2 ⊕ x.
  intros. destruct d1; auto; destruct d2; auto; simpl in *; intuition; fnsetdec.
Qed.

Lemma qplus_empty : forall {x}, ∅ ⊕ x = (just_fv x).
  intros. compute. repeat rewrite empty_union_left. auto.
Qed.

Lemma qmem_lub_or_commute: forall {vl d1 d2}, qmem vl (d1 ⊔ d2) <-> qmem vl d1 \/ qmem vl d2.
  destruct d1; auto; destruct d2; auto; simpl; intuition; destruct a; fnsetdec.
Qed.

Lemma qmem_glb_and_commute: forall {vl d1 d2}, qmem vl (d1 ⊓ d2) <-> qmem vl d1 /\ qmem vl d2.
  destruct d1; auto; destruct d2; auto; simpl; intuition; try fnsetdec; destruct a; fnsetdec.
Qed.

Lemma qlub_is_lub : forall {d1 d2},
    d1 ⊑ (d1 ⊔ d2) /\
    d2 ⊑ (d1 ⊔ d2) /\
    forall {d3}, d1 ⊑ d3 /\ d2 ⊑ d3 -> (d1 ⊔ d2) ⊑ d3.
  destruct d1; auto; destruct d2; auto; intuition; unfold subqual; auto;
    simpl; unfold qlub; intuition.
  destruct d3; intuition; unfold subqual in *; try fnsetdec.
Qed.

Lemma qglb_is_glb : forall {d1 d2},
    (d1 ⊓ d2) ⊑ d1 /\
    (d1 ⊓ d2) ⊑ d2 /\
      forall {d3}, d3 ⊑ d1 /\ d3 ⊑ d2 -> d3 ⊑ (d1 ⊓ d2).
  destruct d1; auto; destruct d2; auto; simpl; intuition.
  destruct d3; auto. unfold subqual.
  destruct H0. destruct H1. intuition; try fnsetdec.
Qed.

Lemma qlub_empty_right : forall {d}, d <> qbot -> (d ⊔ ∅) = d.
  intros. destruct d; qdec.
Qed.
#[global] Hint Resolve qlub_empty_right : core.

Lemma qglb_empty_right : forall {d}, d <> qbot -> (d ⊓ ∅) = ∅.
  intros. destruct d; qdec.
Qed.
#[global] Hint Resolve qglb_empty_right : core.

Lemma qglb_empty_left : forall {d}, d <> qbot -> (∅ ⊓ d) = ∅.
  intros. destruct d; qdec.
Qed.
#[global] Hint Resolve qglb_empty_left : core.

Lemma qlub_idem : forall {q}, (q ⊔ q) = q.
 intros. destruct q; qdec.
Qed.

Lemma qlub_assoc : forall {q1 q2 q3},
    (q1 ⊔ (q2 ⊔ q3)) = ((q1 ⊔ q2) ⊔ q3).
Proof.
  intros. destruct q1, q2, q3; simpl; qdec.
Qed.

Lemma qglb_qlub_dist : forall {d1 d2 d3}, (d1 ⊓ (d2 ⊔ d3)) = ((d1 ⊓ d2) ⊔ (d1 ⊓ d3)).
  destruct d1; destruct d2; destruct d3; qdec.
Qed.

Lemma qglb_commute : forall {d1 d2}, d1 ⊓ d2 = d2 ⊓ d1.
  intros. destruct d1; destruct d2; qdec.
Qed.

Lemma qlub_commute : forall {d1 d2}, (d1 ⊔ d2) = (d2 ⊔ d1).
  intros. destruct d1; destruct d2; qdec.
Qed.

Lemma qlub_empty_left : forall {d}, d <> qbot -> (∅ ⊔ d) = d.
  intros. rewrite qlub_commute. auto.
Qed.
#[global] Hint Resolve qlub_empty_left : core.

Lemma qqcap_commute:  forall {d1 d2}, d1 ⋒ d2 = d2 ⋒ d1.
Proof.
  intros. destruct d1, d2; qdec.
Qed.

Lemma qqplus_qbot_right_neutral : forall {d}, (d ⋓ qbot) = d.
  destruct d; simpl; intros; intuition.
Qed.
#[global] Hint Resolve qqplus_qbot_right_neutral : core.

Lemma qqplus_gt : forall {q1 q2}, q1 ⊑ (q1 ⋓ q2).
  destruct q1; destruct q2; simpl; intuition.
Qed.
#[global] Hint Resolve qqplus_gt : core.

Lemma subqual_qlub : forall {d1 d2 d}, d1 ⊑ d2 -> d1 ⊔ d ⊑ d2 ⊔ d.
  destruct d1; destruct d2; destruct d; qdec.
Qed.

Lemma subqual_qglb : forall {d1 d2 d}, d1 ⊑ d2 -> d ⊓ d1 ⊑ d ⊓ d2.
  destruct d1; destruct d2; destruct d; qdec.
Qed.

Lemma subqual_qglb_r : forall {d1 d2 d}, d1 ⊑ d2 -> d1 ⊓ d ⊑ d2 ⊓ d.
  destruct d1; destruct d2; destruct d; qdec.
Qed.

Lemma subqual_qqplus : forall {d1 d2 d}, d1 ⊑ d2 -> d1 ⋓ d ⊑ d2 ⋓ d.
  destruct d1; destruct d2; destruct d; qdec.
Qed.

Lemma subqual_qlub_l : forall {d1 d2 d}, d1 ⊑ d2 -> d ⊔ d1 ⊑ d ⊔ d2.
  destruct d1; destruct d2; destruct d; qdec.
Qed.

Lemma subqual_qqplus_l : forall {d1 d2 d}, d1 ⊑ d2 -> d ⋓ d1 ⊑ d ⋓ d2.
  destruct d1; destruct d2; destruct d; qdec.
Qed.

Lemma qbot_smallest : forall {d}, qbot ⊑ d.
  intros. destruct d; simpl; qdec.
Qed.
#[global] Hint Resolve qbot_smallest : core.

Lemma empty_smallest_set : forall {d}, d <> qbot -> ∅ ⊑ d.
  intros. destruct d; simpl; qdec.
Qed.
#[global] Hint Resolve empty_smallest_set : core.

Lemma empty_superqual : forall {df}, df <> qbot -> df ⊑ ∅ -> df = ∅.
  intros. destruct df. simpl in *. intuition. qdec.
Qed.

Lemma qlub_qglb_dist_r:
  forall {d1 d2 d3 : qual}, ((d2 ⊓ d3) ⊔ d1) = ((d2 ⊔ d1) ⊓ (d3 ⊔ d1)).
  destruct d1; destruct d2; destruct d3; qdec.
Qed.

Lemma qlub_qglb_dist_l:
  forall {d1 d2 d3 : qual}, ((d2 ⊓ d3) ⊔ d1) = ((d2 ⊔ d1) ⊓ (d3 ⊔ d1)).
  destruct d1; destruct d2; destruct d3; simpl; qdec.
Qed.

Lemma qglb_qlub_dist_r:
  forall {d1 d2 d3 : qual}, ((d2 ⊔ d3) ⊓ d1) = ((d2 ⊓ d1) ⊔ (d3 ⊓ d1)).
  destruct d1; destruct d2; destruct d3; simpl; qdec.
Qed.

Lemma qglb_qlub_dist_l:
  forall {d1 d2 d3 : qual}, (d1 ⊓ (d2 ⊔ d3)) = ((d1 ⊓ d2) ⊔ (d1 ⊓ d3)).
  destruct d1; destruct d2; destruct d3; simpl; qdec.
Qed.

Lemma empty_neutral_set : forall {a b c}, ((qset a b c) ⊔ ∅) = (qset a b c).
Proof. intros. simpl. repeat rewrite empty_union_right. auto. Qed.

Lemma empty_smallest_set' : forall {l1 l2 l3}, ∅ ⊑ qset l1 l2 l3.
Proof.
  intros. simpl. intuition.
Qed.

Lemma qlub_swallow_l : forall {q1 q2}, q1 ⊑ q2 -> (q1 ⊔ q2) = q2.
  intros. destruct q1; destruct q2; simpl; auto; qdec.
Qed.

Lemma qlub_swallow_r : forall {q1 q2}, q1 ⊑ q2 -> (q2 ⊔ q1) = q2.
  intros. destruct q1; destruct q2; simpl; auto; qdec.
Qed.

Lemma qqplus_swallow_r : forall {q1 q2}, q1 ⊑ q2 -> (q2 ⋓ q1) = q2.
  intros. destruct q1; destruct q2; simpl; auto; qdec.
Qed.

Lemma qlub_bound : forall {q1 q2 q3}, q1 ⊑ q3 -> q2 ⊑ q3 -> q1 ⊔ q2 ⊑ q3.
  intros. destruct q1; destruct q2; destruct q3; qdec.
Qed.

Lemma qqplus_bound : forall {q1 q2 q3}, q1 ⊑ q3 -> q2 ⊑ q3 -> q1 ⋓ q2 ⊑ q3.
  intros. destruct q1; destruct q2; destruct q3; qdec.
Qed.

Lemma qglb_bound : forall {q1 q2 q3}, q3 ⊑ q1 -> q3 ⊑ q2 -> q3 ⊑ q1 ⊓ q2.
  intros. destruct q1; destruct q2; destruct q3; qdec.
Qed.

Lemma qqcap_bound : forall {q1 q2 q3}, q3 ⊑ q1 -> q3 ⊑ q2 -> q3 ⊑ q1 ⋒ q2.
  intros. destruct q1; destruct q2; destruct q3; qdec.
Qed.

Lemma subqual_bound : forall {q1 q2},
    q1 ⊑ q2 ->
    (bound (qfvs q1)) <= (bound (qfvs q2))
    /\ (bound (qbvs q1)) <= (bound (qbvs q2))
    /\ (bound (qlocs q1)) <= (bound (qlocs q2)).
  intros. destruct q1; destruct q2; simpl in *; intuition; apply subset_bound'; fnsetdec.
Qed.

Lemma subqual_plus_var_bound : forall {q1 x q2},
    q1 <> qbot ->
    q1 ⊕ x ⊑ q2 -> x < bound (qfvs q2).
  intros q1 x q2 Hq1 H. apply subqual_bound in H. intuition.
  destruct q1; intuition.
  simpl in *. apply bound_union in H0. intuition.
  rewrite bound_singleton in H3. lia.
Qed.

Lemma subqual_just_loc_bound : forall {l q},
    just_loc l ⊑ q -> l < bound (qlocs q).
  intros. apply subqual_bound in H. intuition. simpl in *.
  rewrite bound_singleton in H2. lia.
Qed.

Lemma subqual_just_fv_bound : forall {x q},
    just_fv x ⊑ q -> x < bound (qfvs q).
  intros. apply subqual_bound in H. intuition. simpl in *.
  rewrite bound_singleton in H0. lia.
Qed.

Lemma subqual_qplus : forall {q x}, q ⊑ q ⊕ x.
  intros. destruct q; simpl; intuition; fnsetdec.
Qed.
#[global] Hint Resolve subqual_qplus : core.

Lemma qset_empty_inv : forall {a b c}, qset a b c = ∅ <->  a [=] {}N /\ b [=] {}N /\ c [=] {}N.
  intros. split. intros.
  inversion H. intuition.
  intros. intuition. f_equal; fnsetdec.
Qed.

Lemma qlub_qbot_left : forall {d}, (qbot ⊔ d) = d.
Proof. intros. destruct d; simpl; auto. Qed.

Lemma glb_qbot : forall {d}, d ⊓ qbot = qbot.
Proof. intros. destruct d; simpl; auto. Qed.

Lemma qqcap_lub_empty_preserve : forall {d1 d2}, d1 ⋒ d2 ⊑ ∅ -> d1 ⋒ (d2 ⊔ ∅) ⊑ ∅.
Proof.
  intros. destruct d1; destruct d2; simpl in *; intuition; fnsetdec.
Qed.

Lemma qlub_empty : forall {d}, d ⊑ d ⊔ ∅.
Proof.
  intros. destruct d; simpl; auto. intuition; fnsetdec.
Qed.

Lemma qqplus_empty_right_neutral : forall {d}, d <> qbot -> (d ⋓ ∅) = d.
  destruct d; simpl; intros; intuition.
  repeat rewrite empty_union_right. auto.
Qed.

Lemma qbot_is_bottom : forall q, q ⊑ qbot -> q = qbot.
Proof.
  intros. destruct q; auto. simpl in H. inversion H.
Qed.

Lemma qqcap_sub_l : forall {q1 q2}, q1 <> qbot -> q1 ⋒ q2 ⊑ q1.
  intros. destruct q1 eqn:Hq1; destruct q2 eqn:Hq2; simpl; intuition.
Qed.

Lemma qqcap_sub_r : forall {q1 q2}, q1 <> qbot -> q2 ⋒ q1 ⊑ q1.
  intros. destruct q1; destruct q2; simpl; intuition.
Qed.

Lemma qqcap_qbot : forall d1 d2, d1 ⋒ d2 ⊑ qbot -> d1 = qbot /\ d2 = qbot.
Proof.
  intros. destruct d1; destruct d2; simpl; intuition; inversion H.
Qed.

Lemma qqcap_qbot' : forall d1 d2, d1 ⋒ d2 = qbot -> d1 = qbot /\ d2 = qbot.
Proof.
  intros. destruct d1; destruct d2; simpl; intuition; inversion H.
Qed.

Lemma qqcap_lub_empty_preserve' : forall {d1 d2 d3},
    d1 ⋒ d2 ⊑ ∅ -> d3 ⋒ d1 = ∅ -> d1 ⋒ (d2 ⋓ d3) ⊑ ∅.
Proof.
  intros. destruct d1; destruct d2; destruct d3; simpl in *; intuition; cbv in H0;
  apply qset_empty_inv in H0; intuition; fnsetdec.
Qed.

Lemma subqual_qqcap' :  forall {a b c d'}, qset a b c ⋒ d' ⊑ qset a b c.
  destruct d'.
  - simpl. intuition.
  - specialize @qglb_is_glb with (d1:=(qset a b c)) (d2:=(qset t0 t1 t2)). intuition.
Qed.

Lemma qual_less_than_empty : forall q, q ⊑ ∅ <-> q = qbot \/ q = ∅.
Proof.
  intros. split.
  - destruct q; simpl in *. left. auto. right.
    intuition. apply subset_of_empty in H0, H, H2. subst. auto.
  - destruct q; simpl in *; intros; auto.
    destruct H. discriminate H. inversion H. intuition; fnsetdec.
Qed.

Lemma just_fv_mem_iff : forall {x y}, $x ∈ᵥ just_fv y <-> x = y.
  intros. simpl. rewrite NatSetFacts.singleton_iff. intuition.
Qed.

Lemma qglb_bot_right : forall {d}, (d ⊓ qbot) = qbot.
  intros. destruct d; qdec.
Qed.
#[global] Hint Resolve qglb_bot_right : core.

Lemma qglb_bot_left : forall {d}, (qbot ⊓ d) = qbot.
  intros. destruct d; qdec.
Qed.
#[global] Hint Resolve qglb_bot_left : core.

