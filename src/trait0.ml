type ('t1, 't2) is_a_function_of

let the_one_value = Obj.magic ()
let the_one_value : _ is_a_function_of = the_one_value
let create () = the_one_value

module Make (X : sig
    type !'a t
    type 'a module_type
  end) =
struct
  let is_a_function_of : ('a X.t, 'a X.module_type) is_a_function_of = the_one_value
end

type ('t, 'module_type, 'tag) c = ..

type ('t, 'module_type, 'tag) t =
  { c : ('t, 'module_type, 'tag) c
  ; is_a_function_of : ('t, 'module_type) is_a_function_of
  }
