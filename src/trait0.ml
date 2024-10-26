type ('t, 'module_type, 'tag) key = ..

module type S = sig
  type t
  type module_type
  type tag
  type (_, _, _) key += T : (t, module_type, tag) key
end

type ('t, 'module_type, 'tag) t =
  (module S with type t = 't and type module_type = 'module_type and type tag = 'tag)

let create (type tparam module_type tag) () : (tparam, module_type, tag) t =
  (module struct
    type nonrec t = tparam
    type nonrec module_type = module_type
    type nonrec tag = tag
    type (_, _, _) key += T : (t, module_type, tag) key
  end)
;;
