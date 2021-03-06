open! Core_kernel
open! Import
open! Hook

let t = create ("some-hook" |> Symbol.intern) ~hook_type:Normal
let () = clear t
let show t = print_s [%sexp (t : _ t)]

let create_function s =
  Function.create
    (s |> Symbol.intern)
    [%here]
    ~hook_type:Normal
    (Returns Value.Type.unit)
    (fun () -> print_s [%message s])
;;

let f1 = create_function "f1"
let f2 = create_function "f2"
let f3 = create_function "f3"

let%expect_test "[add]" =
  show t;
  [%expect {|
    ((symbol    some-hook)
     (hook_type Normal)
     (value ())) |}];
  add t f1;
  show t;
  [%expect {|
    ((symbol    some-hook)
     (hook_type Normal)
     (value (f1))) |}];
  add t f2;
  show t;
  [%expect
    {|
    ((symbol    some-hook)
     (hook_type Normal)
     (value (f2 f1))) |}];
  add t f3 ~where:End;
  show t;
  [%expect
    {|
    ((symbol    some-hook)
     (hook_type Normal)
     (value (f2 f1 f3))) |}];
  clear t
;;

let%expect_test "[add] when present" =
  add t f1;
  add t f1;
  show t;
  [%expect {|
    ((symbol    some-hook)
     (hook_type Normal)
     (value (f1))) |}];
  clear t
;;

let%expect_test "[remove]" =
  add t f2;
  add t f1;
  show t;
  [%expect
    {|
    ((symbol    some-hook)
     (hook_type Normal)
     (value (f1 f2))) |}];
  remove t f2;
  show t;
  [%expect {|
    ((symbol    some-hook)
     (hook_type Normal)
     (value (f1))) |}];
  remove t f1;
  show t;
  [%expect {|
    ((symbol    some-hook)
     (hook_type Normal)
     (value ())) |}];
  clear t
;;

let%expect_test "[remove] when absent" =
  remove t f1;
  show t;
  [%expect {|
    ((symbol    some-hook)
     (hook_type Normal)
     (value ())) |}];
  add t f2;
  show t;
  [%expect {|
    ((symbol    some-hook)
     (hook_type Normal)
     (value (f2))) |}];
  remove t f1;
  show t;
  [%expect {|
    ((symbol    some-hook)
     (hook_type Normal)
     (value (f2))) |}];
  clear t
;;

let%expect_test "[run]" =
  run t;
  add t f1;
  run t;
  [%expect {|
    f1 |}];
  add t f2;
  run t;
  [%expect {|
    f2
    f1 |}]
;;

let create_after_load_fun s =
  Function.create
    (s |> Symbol.intern)
    [%here]
    ~hook_type:File
    (Returns Value.Type.unit)
    (fun _ -> print_s [%message s])
;;

let%expect_test "[after_load] hooks" =
  let f1 = create_after_load_fun "f1" in
  let f2 = create_after_load_fun "f2" in
  add after_load f1;
  after_load_once (fun _ -> print_endline "after_load_once hook");
  add after_load f2;
  let file = Caml.Filename.temp_file "ecamltest" ".el" in
  Out_channel.write_all file ~data:"'()";
  Load.load ~message:false file;
  [%expect {|
    f2
    after_load_once hook
    f1 |}];
  Load.load ~message:false file;
  [%expect {|
    f2
    f1 |}];
  remove after_load f1;
  remove after_load f2
;;

let%expect_test "Blocking async hook" =
  let test ~pause =
    let f1 =
      Function.create
        ("f1" |> Symbol.intern)
        [%here]
        ~hook_type:File
        (Returns_deferred Value.Type.unit)
        (fun _ ->
           let%map.Async () = Async.Clock.after pause in
           print_s [%message "f1"])
    in
    add after_load f1;
    let file = Caml.Filename.temp_file "ecamltest" ".el" in
    Out_channel.write_all file ~data:"'()";
    Load.load ~message:false file;
    remove after_load f1
  in
  test ~pause:(sec 0.01);
  [%expect {| f1 |}]
;;

let%expect_test "[after_save], [kill_buffer]" =
  let file = "test-after-save.tmp" in
  Selected_window.Blocking.find_file file;
  add
    after_save
    ~buffer_local:true
    (Function.create
       ("test-after-save-hook" |> Symbol.intern)
       [%here]
       ~hook_type:Normal
       (Returns Value.Type.unit)
       (fun () -> print_s [%message "after-save hook ran"]));
  print_s [%sexp (Current_buffer.is_buffer_local (var after_save) : bool)];
  [%expect {|
    true |}];
  add
    kill_buffer
    ~buffer_local:true
    (Function.create
       ("test-kill-buffer-hook" |> Symbol.intern)
       [%here]
       ~hook_type:Normal
       (Returns Value.Type.unit)
       (fun () -> print_s [%message "kill-buffer hook ran"]));
  Point.insert "foo";
  Current_buffer.save ();
  [%expect {|
    "after-save hook ran" |}];
  Current_buffer.kill ();
  [%expect {|
    "kill-buffer hook ran" |}];
  File.delete file
;;

let%expect_test "hook raise" =
  let hook_type = Hook_type.Normal in
  let t = create ("for-raising" |> Symbol.intern) ~hook_type in
  add
    t
    (Function.create
       ("hook-raise1" |> Symbol.intern)
       [%here]
       ~hook_type
       (Returns Value.Type.unit)
       (fun () -> raise_s [%message "raise1"]));
  add
    t
    ~where:End
    (Function.create
       ("hook-raise2" |> Symbol.intern)
       [%here]
       ~hook_type
       (Returns_deferred Value.Type.unit)
       (fun () -> raise_s [%message "raise2"]));
  run t;
  [%expect
    {|
    ("Error in hook" hook-raise1 raise1)
    ("Error in hook" hook-raise2 raise2) |}]
;;
