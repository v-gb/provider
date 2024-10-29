type tag = [ `Int_printer ]
type 'a t = ([> tag ] as 'a) Provider.t

module Provider_interface = struct
  module type S = sig
    type t

    val string_of_int : t -> int -> string
  end

  module C = Provider.Trait.Create (struct
      type 't t = 't
      type 't module_type = (module S with type t = 't)
    end)

  let int_printer : (_, _, [> tag ]) Provider.Trait.t = C.t

  let make (type t) (module M : S with type t = t) =
    Provider.Handler.make [ Provider.Trait.implement int_printer ~impl:(module M) ]
  ;;
end

let print (Provider.T { t; handler }) i =
  let module M =
    (val Provider.Handler.lookup handler ~trait:Provider_interface.int_printer)
  in
  print_endline (M.string_of_int t i)
;;
