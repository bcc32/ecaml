open! Core_kernel
open! Import
open! Echo_area

(* Expect tests run with [emacs -batch], which causes messages to go to stderr in addition
   to the *Messages* buffer.  Since ppx_expect collects output on stderr, we get a second
   copy of the output. *)
let show () =
  let buffer = Buffer.find_or_create ~name:"*Messages*" in
  Current_buffer.set_temporarily buffer ~f:(fun () ->
    print_string (Current_buffer.contents () |> Text.to_utf8_bytes));
  Buffer.kill buffer
;;

let%expect_test "[message_s] of a value" =
  message_s [%sexp (13 |> Value.of_int_exn : Value.t)];
  show ();
  [%expect {|
    13
    13 |}]
;;

let%expect_test "[message]" =
  message "foobar";
  show ();
  [%expect {|
    foobar
    foobar |}]
;;

let%expect_test "[messagef]" =
  messagef "%d" 13;
  show ();
  [%expect {|
    13
    13 |}]
;;

let%expect_test "[message_s] of an atom" =
  message_s [%message "foo bar"];
  show ();
  [%expect {|
    foo bar
    foo bar |}]
;;

let%expect_test "[message_s]" =
  message_s [%message "foobar" ~_:(13 : int)];
  show ();
  [%expect {|
   (foobar 13)
   (foobar 13) |}]
;;

let%expect_test "[message ~echo:false]" =
  message "foo" ~echo:false;
  [%expect {| |}];
  show ();
  [%expect {| foo |}]
;;

let%expect_test "[inhibit_messages]" =
  inhibit_messages (fun () -> message "hello");
  [%expect {| |}];
  show ();
  [%expect {| hello |}]
;;
