type ('t, 'module_type, +'tag) t

val create : unit -> _ t

module Create (X : sig
    type !'a t
    type 'a module_type
  end) : sig
  val t : ('a X.t, 'a X.module_type, _) t
end

val same_witness : ('t, 'mt1, _) t -> ('t, 'mt2, _) t -> ('mt1, 'mt2) Type.eq option
