type ('t, 'module_type) same_witness =
  { f :
      'module_type2 'tag2.
      ('t, 'module_type2, 'tag2) Trait0.t -> ('module_type, 'module_type2) Type.eq
  }

type _ t =
  | T :
      { trait : ('t, 'module_type, _) Trait0.t
      ; implementation : 'module_type
      ; same_witness : ('t, 'module_type) same_witness
      }
      -> 't t

let implement
  (type a i)
  (trait : (a, i, _) Trait0.t)
  ~impl:(implementation : i)
  ~same_witness
  : a t
  =
  T { trait; implementation; same_witness }
;;
