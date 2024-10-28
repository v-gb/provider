type ('t, 'module_type) same_witness =
  { f :
      'module_type2 'tag2.
      ('t, 'module_type2, 'tag2) Trait0.t -> ('module_type, 'module_type2) Type.eq
  }

type _ t = private
  | T :
      { trait : ('t, 'module_type, _) Trait0.t
      ; implementation : 'module_type
      ; same_witness : ('t, 'module_type) same_witness
      }
      -> 't t

val implement
  :  ('t, 'module_type, 'tag) Trait0.t
  -> impl:'module_type
  -> same_witness:('t, 'module_type) same_witness
  -> 't t
