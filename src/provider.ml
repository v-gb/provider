open! Import

exception E of Sexp.t

let () =
  Sexplib0.Sexp_conv.Exn_converter.add [%extension_constructor E] (function
    | E sexp -> sexp
    | _ -> assert false)
;;

let raise_s msg sexp = raise (E (Sexp.List [ Atom msg; sexp ]))
let phys_same t1 t2 = phys_equal (Obj.repr t1) (Obj.repr t2)

module Trait = struct
  type ('t, 'module_type, 'tag) t = ('t, 'module_type, 'tag) Trait0.t = ..

  let extension_constructor =
    (Obj.Extension_constructor.of_val : _ t -> Obj.Extension_constructor.t)
  ;;

  module Info = struct
    type t = Obj.Extension_constructor.t

    let sexp_of_id_default _ = Sexp.Atom "#id"
    let sexp_of_id = ref sexp_of_id_default

    let sexp_of_t t =
      let sexp_of_id id = !sexp_of_id id in
      Sexp.List
        [ List [ Atom "id"; sexp_of_id (Obj.Extension_constructor.id t) ]
        ; List [ Atom "name"; Atom (Obj.Extension_constructor.name t) ]
        ]
    ;;
  end

  let info = extension_constructor

  module Uid = struct
    type t = int

    let sexp_of_t = Sexplib0.Sexp_conv.sexp_of_int
    let equal = Int.equal
    let compare = Int.compare
    let hash = Int.hash
  end

  let uid (t : _ t) = Obj.Extension_constructor.id (extension_constructor t)
  let compare_by_uid id1 id2 = Uid.compare (uid id1) (uid id2)
  let same (id1 : _ t) (id2 : _ t) = phys_same id1 id2
  let implement = Binding0.implement
end

module Binding = struct
  type 'a t = 'a Binding0.t = private
    | T :
        { trait : ('t, 'module_type, _) Trait.t
        ; implementation : 'module_type
        }
        -> 't t

  let uid (T { trait; implementation = _ }) = Trait.uid trait
  let info (T { trait; implementation = _ }) = Trait.info trait
  let compare_by_uid t1 t2 = Trait.Uid.compare (uid t1) (uid t2)
end

module Handler = struct
  (* We sort the element by their extension_id in increasing order. Element.(0)
     is a cache of the most recently looked up method. *)
  type ('t, -'tags) t = 't Binding.t array

  let dedup_sorted_keep_last =
    let[@tail_mod_cons] rec aux list ~compare =
      match list with
      | [] -> []
      | [ elt ] -> [ elt ]
      | elt1 :: (elt2 :: _ as tl) ->
        if compare elt1 elt2 = 0 then aux tl ~compare else elt1 :: aux tl ~compare
    in
    aux
  ;;

  let make (type a) (bindings : a Binding.t list) : (a, _) t =
    let bindings =
      bindings
      |> List.stable_sort ~compare:Binding.compare_by_uid
      |> dedup_sorted_keep_last ~compare:Binding.compare_by_uid
    in
    match bindings with
    | [] -> [||]
    | hd :: _ ->
      (* We initialize the cache arbitrarily with the left most trait. *)
      Array.of_list (hd :: bindings)
  ;;

  let same_trait_uids : type a b tags1 tags2. (a, tags1) t -> (b, tags2) t -> bool =
    fun t1 t2 ->
    (* We skip the cell 0 which contains the cache. *)
    if Array.length t1 <> Array.length t2
    then false
    else
      Array.for_alli t1 ~f:(fun i implementation ->
        i = 0 || 0 = Binding.compare_by_uid implementation t2.(i))
  ;;

  let is_empty t = Array.length t = 0
  let cache t = if Array.length t = 0 then None else Some (Binding.uid t.(0))

  let bindings t =
    match Array.to_list t with
    | [] -> []
    | _ :: tl -> tl
  ;;

  let extend t ~with_ = make (bindings t @ with_)

  let rec binary_search
    : type a implementation tags b.
      (a, tags) t
      -> trait:(a, implementation, tags) Trait.t
      -> update_cache:bool
      -> if_not_found:(trait_info:Trait.Info.t -> b)
      -> if_found:(implementation -> b)
      -> from:int
      -> to_:int
      -> b
    =
    fun t ~trait ~update_cache ~if_not_found ~if_found ~from ~to_ ->
    if from > to_
    then if_not_found ~trait_info:(Trait.info trait)
    else (
      let mid = (from + to_) / 2 in
      let (Binding.T { trait = elt; implementation } as binding) = t.(mid) in
      match Trait.compare_by_uid elt trait |> Ordering.of_int with
      | Equal ->
        if update_cache then t.(0) <- binding;
        if_found (Obj.magic implementation)
      | Less ->
        binary_search t ~trait ~update_cache ~if_not_found ~if_found ~from:(mid + 1) ~to_
      | Greater ->
        binary_search t ~trait ~update_cache ~if_not_found ~if_found ~from ~to_:(mid - 1))
  ;;

  let make_lookup
    : type a implementation tags b.
      (a, tags) t
      -> trait:(a, implementation, tags) Trait.t
      -> update_cache:bool
      -> if_not_found:(trait_info:Trait.Info.t -> b)
      -> if_found:(implementation -> b)
      -> b
    =
    fun t ~trait ~update_cache ~if_not_found ~if_found ->
    if Array.length t = 0
    then if_not_found ~trait_info:(Trait.info trait)
    else (
      let (Binding.T { trait = cached_id; implementation }) = t.(0) in
      if Trait.same trait cached_id
      then if_found (Obj.magic implementation)
      else
        binary_search
          t
          ~trait
          ~update_cache
          ~if_not_found
          ~if_found
          ~from:1
          ~to_:(Array.length t - 1))
  ;;

  module If_not_found = struct
    let raise ~trait_info =
      raise_s
        "Trait not implemented"
        (Sexp.List [ List [ Atom "trait_info"; trait_info |> Trait.Info.sexp_of_t ] ])
    ;;

    let none ~trait_info:_ = None
    let false_ ~trait_info:_ = false
  end

  let lookup t ~trait =
    make_lookup
      t
      ~trait
      ~update_cache:true
      ~if_not_found:If_not_found.raise
      ~if_found:Fun.id
  ;;

  let lookup_opt t ~trait =
    make_lookup
      t
      ~trait
      ~update_cache:true
      ~if_not_found:If_not_found.none
      ~if_found:Option.some
  ;;

  let implements t ~trait =
    (* Only checking for the availability of the trait doesn't affect the cache,
       we leave it untouched in this case. *)
    make_lookup
      t
      ~trait
      ~update_cache:false
      ~if_not_found:If_not_found.false_
      ~if_found:(Fun.const true)
  ;;
end

type -'tags t =
  | T :
      { t : 't
      ; handler : ('t, 'tags) Handler.t
      }
      -> 'tags t

module Private = struct
  module Import = Import
  module Handler = Handler
end
