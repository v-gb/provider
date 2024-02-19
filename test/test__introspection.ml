(* This test demonstrates how to access information about the classes
   implemented by a provider at runtime. This is a key aspect of introspection,
   allowing you to understand the capabilities of a provider dynamically, as the
   program is running. *)

let print_implemented_classes (Provider.T { t = _; interface }) =
  let info =
    List.map (Provider.Interface.classes interface) ~f:(fun class_ ->
      [%sexp (Provider.Class.info class_ : Provider.Class_id.Info.t)])
  in
  print_s [%sexp (info : Sexp.t list)]
;;

let print_implements (Provider.T { t = _; interface }) =
  let implements class_id = Provider.Interface.implements interface ~class_id in
  print_s
    [%sexp
      { implements =
          { file_reader =
              (implements Interface.File_reader.Provider_interface.File_reader : bool)
          ; directory_reader =
              (implements Interface.Directory_reader.Provider_interface.Directory_reader
               : bool)
          }
      }]
;;

let%expect_test "introspection" =
  require_does_not_raise [%here] (fun () ->
    print_implements (Provider.T { t = (); interface = Provider.Interface.make [] });
    [%expect.unreachable]);
  [%expect
    {|
    (* CR require-failed: repo/provider/test/test__introspection.ml:29:25.
       Do not 'X' this CR; instead make the required property true,
       which will make the CR disappear.  For more information, see
       [Expect_test_helpers_base.require]. *)
    ("unexpectedly raised" (
      "Class not implemented" ((
        class_info (
          (id #id)
          (name
           Provider_test__Interface__Directory_reader.Provider_interface.Directory_reader)))))) |}];
  let unix_reader = Providers.Unix_reader.make () in
  Eio_main.run
  @@ fun env ->
  let eio_reader = Providers.Eio_reader.make ~env in
  print_implements eio_reader;
  [%expect
    {|
    ((
      implements (
        (file_reader      true)
        (directory_reader true)))) |}];
  print_implements unix_reader;
  [%expect
    {|
    ((
      implements (
        (file_reader      false)
        (directory_reader true)))) |}];
  let id_mapping = Hashtbl.create (module Int) in
  let next_id = ref 0 in
  let sexp_of_id id =
    let id =
      match Hashtbl.find id_mapping id with
      | Some id -> id
      | None ->
        let data = !next_id in
        Int.incr next_id;
        Hashtbl.set id_mapping ~key:id ~data;
        data
    in
    Sexp.Atom (Int.to_string id)
  in
  Ref.set_temporarily Provider.Class_id.Info.sexp_of_id sexp_of_id ~f:(fun () ->
    print_implemented_classes unix_reader;
    [%expect
      {|
      ((
        (id 0)
        (name
         Provider_test__Interface__Directory_reader.Provider_interface.Directory_reader))) |}];
    print_implemented_classes eio_reader;
    [%expect
      {|
      (((id 0)
        (name
         Provider_test__Interface__Directory_reader.Provider_interface.Directory_reader))
       ((id 1)
        (name Provider_test__Interface__File_reader.Provider_interface.File_reader))) |}];
    ());
  ()
;;
