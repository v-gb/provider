type tag = [ `Directory_reader ]
type 'a t = ([> tag ] as 'a) Provider.t

module Provider_interface = struct
  module type S = sig
    type t

    val readdir : t -> path:string -> string list
  end

  module C = Provider.Trait.Create (struct
      type 't t = 't
      type 't module_type = (module S with type t = 't)
    end)

  let directory_reader : (_, _, [> tag ]) Provider.Trait.t = C.t

  let make (type t) (module M : S with type t = t) =
    Provider.Handler.make [ Provider.Trait.implement directory_reader ~impl:(module M) ]
  ;;
end

let readdir (Provider.T { t; handler }) ~path =
  let module M =
    (val Provider.Handler.lookup handler ~trait:Provider_interface.directory_reader)
  in
  M.readdir t ~path
;;

(* The implementation of that function is the same regardless of the provider
   used. *)
let find_files_with_extension t ~path ~ext =
  let files = readdir t ~path in
  List.filter files ~f:(fun file -> String.is_suffix file ~suffix:ext)
;;
