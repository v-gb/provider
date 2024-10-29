type tag = [ `File_reader ]
type 'a t = ([> tag ] as 'a) Provider.t

module Provider_interface = struct
  module type S = sig
    type t

    val load : t -> path:string -> string
  end

  module C = Provider.Trait.Create (struct
      type 't t = 't
      type 't module_type = (module S with type t = 't)
    end)

  let file_reader : (_, _, [> tag ]) Provider.Trait.t = C.t
end

let load (Provider.T { t; handler }) ~path =
  let module M =
    (val Provider.Handler.lookup handler ~trait:Provider_interface.file_reader)
  in
  M.load t ~path
;;
