open! Core_kernel
open! Import
open! Ecaml_filename

module Q = struct
  include Q

  let copy_file = "copy-file" |> Symbol.intern
  and delete_file = "delete-file" |> Symbol.intern
  and file_directory_p = "file-directory-p" |> Symbol.intern
  and file_executable_p = "file-executable-p" |> Symbol.intern
  and file_exists_p = "file-exists-p" |> Symbol.intern
  and file_in_directory_p = "file-in-directory-p" |> Symbol.intern
  and file_readable_p = "file-readable-p" |> Symbol.intern
  and file_regular_p = "file-regular-p" |> Symbol.intern
  and file_symlink_p = "file-symlink-p" |> Symbol.intern
  and file_truename = "file-truename" |> Symbol.intern
  and file_writable_p = "file-writable-p" |> Symbol.intern
  and locate_file = "locate-file" |> Symbol.intern
  and locate_dominating_file = "locate-dominating-file" |> Symbol.intern
  and make_temp_file = "make-temp-file" |> Symbol.intern
  and no_message = "no-message" |> Symbol.intern
  and rename_file = "rename-file" |> Symbol.intern
  and write_region = "write-region" |> Symbol.intern
end

module F = struct
  open Funcall

  let locate_file =
    Q.locate_file
    <: string
       @-> list string
       @-> nil_or (list string)
       @-> nil_or value
       @-> return (nil_or string)
  ;;
end

let to_value = Value.of_utf8_bytes
let predicate q file = Symbol.funcall1 q (file |> to_value) |> Value.to_bool

let exists = predicate Q.file_exists_p
and is_directory = predicate Q.file_directory_p
and is_executable = predicate Q.file_executable_p
and is_readable = predicate Q.file_readable_p
and is_regular = predicate Q.file_regular_p
and is_symlink = predicate Q.file_symlink_p
and is_writable = predicate Q.file_writable_p

let is_below file ~dir =
  Symbol.funcall2 Q.file_in_directory_p (file |> to_value) (dir |> to_value)
  |> Value.to_bool
;;

let truename file =
  Symbol.funcall1 Q.file_truename (file |> to_value) |> Value.to_utf8_bytes_exn
;;

let delete file = Symbol.funcall1_i Q.delete_file (file |> to_value)
let copy ~src ~dst = Symbol.funcall2_i Q.copy_file (src |> to_value) (dst |> to_value)

let rename ~src ~dst ~replace_dst_if_exists =
  Symbol.funcall3_i
    Q.rename_file
    (src |> to_value)
    (dst |> to_value)
    (replace_dst_if_exists |> Value.of_bool)
;;

let locate ?suffixes ?predicate ~filename ~path () =
  F.locate_file filename path suffixes predicate
;;

let locate_dominating_file ~above ~basename =
  let result =
    Symbol.funcall2
      Q.locate_dominating_file
      (above |> Value.of_utf8_bytes)
      (basename |> Value.of_utf8_bytes)
  in
  if Value.is_nil result then None else Some (result |> Filename.of_value_exn)
;;

let locate_dominating_file_exn ~above ~basename =
  match locate_dominating_file ~above ~basename with
  | Some x -> x
  | None ->
    raise_string [ "Unable to find ["; basename; "] in directory above ["; above; "]." ]
;;

let write ?(append = false) filename data =
  Symbol.funcall5_i
    Q.write_region
    (data |> Value.of_utf8_bytes)
    Value.nil
    (filename |> to_value)
    (append |> Value.of_bool)
    (Q.no_message |> Symbol.to_value)
;;

let ensure_exists filename = write filename "" ~append:true

(* squelch the [Wrote file] message *)

let make_temp_file ~prefix ~suffix =
  Symbol.funcall3
    Q.make_temp_file
    (prefix |> Value.of_utf8_bytes)
    Value.nil
    (suffix |> Value.of_utf8_bytes)
  |> Filename.of_value_exn
;;

let with_temp_file ~f ~prefix ~suffix =
  let filename = make_temp_file ~prefix ~suffix in
  Exn.protect ~f:(fun () -> f filename) ~finally:(fun () -> delete filename)
;;
