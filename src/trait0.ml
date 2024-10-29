type ('t, 'module_type) ext = ..

type same_witness =
  { f : 't 'm1 'm2. ('t, 'm1) ext -> ('t, 'm2) ext -> ('m1, 'm2) Type.eq option }

type ('t, 'module_type, +'tag) t =
  { ext : ('t, 'module_type) ext
  ; same_witness : same_witness
  }

let same_witness : ('t, 'mt1, _) t -> ('t, 'mt2, _) t -> ('mt1, 'mt2) Type.eq option =
  fun t1 t2 -> t1.same_witness.f t1.ext t2.ext
;;

(* Alternatively, it would possible to stop storing same_witness inside the trait, and
   instead use the function below, which is the same implementation as the properly
   typed same_witness functions. *)
let phys_equal = ( == )
let phys_same t1 t2 = phys_equal (Obj.repr t1) (Obj.repr t2)

let _same_witness (type tt m1 m2) (t1 : (tt, m1, _) t) (t2 : (tt, m2, _) t)
  : (m1, m2) Type.eq option
  =
  if phys_same t1.ext t2.ext
  then
    (* Why this is safe: for t1 t2 to have type t, they must have come
       from either create or Create.
       For t1 and t2 to be phys_equal, they have must have come from the
       same runtime invocation of either create() or Create(..).
       In the case of create(), the resulting t will be monomorphic
       so, m1 = m2.
       In the case of Create(), t can be polymorphic, however since
       we know that the tt argument is the same, we know that the
       'a X.t is the same, which implies that the 'a is the same
       by injectivity of X.t, which implies that 'a X.module_type
       are the same, i.e m1 = m2.
    *)
    Some (Obj.magic Type.Equal)
  else None
;;

let create (type tt mt) () =
  let module M = struct
    type (_, _) ext += T : (tt, mt) ext
  end
  in
  { ext = M.T
  ; same_witness =
      { f =
          (fun (type tt m1 m2)
            (t1 : (tt, m1) ext)
            (t2 : (tt, m2) ext)
            : (m1, m2) Type.eq option ->
            match t1, t2 with
            | M.T, M.T -> Some Equal
            | _ -> None)
      }
  }
;;

module Create (X : sig
    type !'a t
    type 'a module_type
  end) =
struct
  type (_, _) ext += T : ('a X.t, 'a X.module_type) ext

  let same_witness (type tt m1 m2) t1 t2 : (m1, m2) Type.eq option =
    match (t1 : (tt, m1) ext), (t2 : (tt, m2) ext) with
    | T, T -> Some Type.Equal
    | _ -> None
  ;;

  let t = { ext = T; same_witness = { f = same_witness } }
end
