type ('t, 'module_type) ext = ..
type ('t, 'module_type, +'tag) t = ('t, 'module_type) ext

let create (type t mt) () =
  let module M = struct
    type (_, _) ext += T : (t, mt) ext
  end
  in
  M.T
;;

module Create (X : sig
    type !'a t
    type 'a module_type
  end) =
struct
  type (_, _) ext += T : ('a X.t, 'a X.module_type) ext

  let t = T
end

let phys_equal = ( == )
let phys_same t1 t2 = phys_equal (Obj.repr t1) (Obj.repr t2)

let same_witness (type tt m1 m2) (t1 : (tt, m1, _) t) (t2 : (tt, m2, _) t)
  : (m1, m2) Type.eq option
  =
  if phys_same t1 t2
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
