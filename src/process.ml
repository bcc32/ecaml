open! Core_kernel
open! Import

module Q = struct
  include Q

  let call_process = "call-process" |> Symbol.intern
  and call_process_region = "call-process-region" |> Symbol.intern
  and closed = "closed" |> Symbol.intern
  and connect = "connect" |> Symbol.intern
  and delete_process = "delete-process" |> Symbol.intern
  and exit_ = "exit" |> Symbol.intern
  and failed = "failed" |> Symbol.intern
  and get_process = "get-process" |> Symbol.intern
  and listen = "listen" |> Symbol.intern
  and local = "local" |> Symbol.intern
  and make_network_process = "make-network-process" |> Symbol.intern
  and open_ = "open" |> Symbol.intern
  and output = "output" |> Symbol.intern
  and process = "process" |> Symbol.intern
  and process_buffer = "process-buffer" |> Symbol.intern
  and process_command = "process-command" |> Symbol.intern
  and process_exit_status = "process-exit-status" |> Symbol.intern
  and process_id = "process-id" |> Symbol.intern
  and process_list = "process-list" |> Symbol.intern
  and process_live_p = "process-live-p" |> Symbol.intern
  and process_mark = "process-mark" |> Symbol.intern
  and process_name = "process-name" |> Symbol.intern
  and process_query_on_exit_flag = "process-query-on-exit-flag" |> Symbol.intern
  and process_status = "process-status" |> Symbol.intern
  and run = "run" |> Symbol.intern
  and set_process_query_on_exit_flag = "set-process-query-on-exit-flag" |> Symbol.intern
  and signal = "signal" |> Symbol.intern
  and start_process = "start-process" |> Symbol.intern
  and stop = "stop" |> Symbol.intern
end

include Process0

module Status = struct
  module T = struct
    type t =
      | Closed
      | Connect
      | Exit
      | Failed
      | Listen
      | Open
      | Run
      | Signal
      | Stop
    [@@deriving enumerate, sexp_of]
  end

  include T

  let type_ =
    Value.Type.enum
      [%sexp "process-status"]
      (module T)
      (Symbol.to_value
       << function
         | Closed -> Q.closed
         | Connect -> Q.connect
         | Exit -> Q.exit_
         | Failed -> Q.failed
         | Listen -> Q.listen
         | Open -> Q.open_
         | Run -> Q.run
         | Signal -> Q.signal
         | Stop -> Q.stop)
  ;;

  let of_value_exn = Value.Type.of_value_exn type_
  let to_value = Value.Type.to_value type_
end

module F = struct
  open Funcall

  let is_alive = Q.process_live_p <: type_ @-> return bool
  let process_exit_status = Q.process_exit_status <: type_ @-> return int
  let process_status = Q.process_status <: type_ @-> return Status.type_
end

let equal = eq
let is_alive = F.is_alive

let buffer t =
  let v = Symbol.funcall1 Q.process_buffer (t |> to_value) in
  if Value.is_nil v then None else Some (v |> Buffer.of_value_exn)
;;

let command t =
  let v = Symbol.funcall1 Q.process_command (t |> to_value) in
  if Value.is_nil v || Value.eq v Value.t
  then None
  else Some (v |> Value.to_list_exn ~f:Value.to_utf8_bytes_exn)
;;

let name t = Symbol.funcall1 Q.process_name (t |> to_value) |> Value.to_utf8_bytes_exn

let pid t =
  let v = Symbol.funcall1 Q.process_id (t |> to_value) in
  if Value.is_nil v then None else Some (v |> Value.to_int_exn |> Pid.of_int)
;;

let mark t = Symbol.funcall1 Q.process_mark (t |> to_value) |> Marker.of_value_exn

let query_on_exit t =
  Symbol.funcall1 Q.process_query_on_exit_flag (t |> to_value) |> Value.to_bool
;;

let set_query_on_exit t b =
  Symbol.funcall2_i Q.set_process_query_on_exit_flag (t |> to_value) (b |> Value.of_bool)
;;

let status = F.process_status

module Exit_status = struct
  type t =
    | Not_exited
    | Exited of int
    | Fatal_signal of int
  [@@deriving sexp]
end

let exit_status t : Exit_status.t =
  match status t with
  | Exit -> Exited (F.process_exit_status t)
  | Signal -> Fatal_signal (F.process_exit_status t)
  | Closed | Connect | Failed | Listen | Open | Run | Stop -> Not_exited
;;

let find_by_name name =
  Symbol.funcall1 Q.get_process (name |> Value.of_utf8_bytes)
  |> Value.Type.(nil_or type_ |> of_value_exn)
;;

let all_emacs_children () =
  Symbol.funcall0 Q.process_list |> Value.to_list_exn ~f:of_value_exn
;;

let create ?buffer () ~args ~name ~prog =
  Symbol.funcallN
    Q.start_process
    ([ name |> Value.of_utf8_bytes
     ; (match buffer with
        | None -> Value.nil
        | Some b -> b |> Buffer.to_value)
     ; prog |> Value.of_utf8_bytes
     ]
     @ (args |> List.map ~f:Value.of_utf8_bytes))
  |> of_value_exn
;;

let kill t = Symbol.funcall1_i Q.delete_process (t |> to_value)

let create_unix_network_process () ~filter ~name ~socket_path =
  of_value_exn
    (Symbol.funcallN
       Q.make_network_process
       [ Q.K.name |> Symbol.to_value
       ; name |> Value.of_utf8_bytes
       ; Q.K.family |> Symbol.to_value
       ; Q.local |> Symbol.to_value
       ; Q.K.server |> Symbol.to_value
       ; Q.t |> Symbol.to_value
       ; Q.K.service |> Symbol.to_value
       ; socket_path |> Value.of_utf8_bytes
       ; Q.K.filter |> Symbol.to_value
       ; Function.to_value
           (Function.create
              [%here]
              ~docstring:"Network process filter."
              ~args:[ Q.process; Q.output ]
              (function
                | [| process; output |] ->
                  filter (process |> of_value_exn) (output |> Text.of_value_exn);
                  Value.nil
                | _ -> assert false))
       ])
;;

module Call = struct
  module Input = struct
    type t =
      | Dev_null
      | File of string
    [@@deriving sexp_of]

    let to_value = function
      | Dev_null -> Value.nil
      | File file -> file |> Value.of_utf8_bytes
    ;;
  end

  module Region_input = struct
    type t =
      | Region of { start : Position.t; end_ : Position.t; delete : bool }
      | String of string
    [@@deriving sexp_of]
  end

  module Output = struct
    module Stdout = struct
      type t =
        | Before_point_in of Buffer.t
        | Before_point_in_current_buffer
        | Dev_null
        | Overwrite_file of string
      [@@deriving sexp_of]

      let to_value = function
        | Before_point_in buffer -> buffer |> Buffer.to_value
        | Before_point_in_current_buffer -> Value.t
        | Dev_null -> Value.nil
        | Overwrite_file string ->
          Value.list [ Q.K.file |> Symbol.to_value; string |> Value.of_utf8_bytes ]
      ;;
    end

    module Stderr = struct
      type t =
        | Dev_null
        | Overwrite_file of string
      [@@deriving sexp_of]

      let to_value = function
        | Dev_null -> Value.nil
        | Overwrite_file string -> string |> Value.of_utf8_bytes
      ;;
    end

    type t =
      | Before_point_in of Buffer.t
      | Before_point_in_current_buffer
      | Dev_null
      | Overwrite_file of string
      | Split of { stderr : Stderr.t; stdout : Stdout.t }
    [@@deriving sexp_of]

    let to_value = function
      | Before_point_in buffer -> buffer |> Buffer.to_value
      | Before_point_in_current_buffer -> Value.t
      | Dev_null -> Value.nil
      | Overwrite_file string ->
        Value.list [ Q.K.file |> Symbol.to_value; string |> Value.of_utf8_bytes ]
      | Split { stderr; stdout } ->
        Value.list [ stdout |> Stdout.to_value; stderr |> Stderr.to_value ]
    ;;
  end

  module Result = struct
    type t =
      | Exit_status of int
      | Signaled of string
    [@@deriving sexp_of]

    let of_value_exn value =
      if Value.is_integer value
      then Exit_status (value |> Value.to_int_exn)
      else if Value.is_string value
      then Signaled (value |> Value.to_utf8_bytes_exn)
      else
        raise_s
          [%message
            "[Process.Call.Result.of_value_exn] got unexpected value" (value : Value.t)]
    ;;
  end
end

let call_region_exn
      ?(input =
        Call.Region_input.Region
          { start = Point.min (); end_ = Point.max (); delete = false })
      ?(output = Call.Output.Dev_null)
      ?(redisplay_on_output = false)
      ?(working_directory = Working_directory.Root)
      prog
      args
  =
  Working_directory.within working_directory ~f:(fun () ->
    let start, end_, delete =
      match input with
      | Region { start; end_; delete } ->
        start |> Position.to_value, end_ |> Position.to_value, delete
      | String s -> s |> Value.of_utf8_bytes, Value.nil, false
    in
    Symbol.funcallN
      Q.call_process_region
      ([ start
       ; end_
       ; prog |> Value.of_utf8_bytes
       ; delete |> Value.of_bool
       ; output |> Call.Output.to_value
       ; redisplay_on_output |> Value.of_bool
       ]
       @ (args |> List.map ~f:Value.of_utf8_bytes))
    |> Call.Result.of_value_exn)
;;

let call_result_exn
      ?(input = Call.Input.Dev_null)
      ?(output = Call.Output.Dev_null)
      ?(redisplay_on_output = false)
      ?(working_directory = Working_directory.Root)
      prog
      args
  =
  Working_directory.within working_directory ~f:(fun () ->
    Symbol.funcallN
      Q.call_process
      ([ prog |> Value.of_utf8_bytes
       ; input |> Call.Input.to_value
       ; output |> Call.Output.to_value
       ; redisplay_on_output |> Value.of_bool
       ]
       @ (args |> List.map ~f:Value.of_utf8_bytes))
    |> Call.Result.of_value_exn)
;;

module Lines_or_sexp = struct
  include Async_unix.Process.Lines_or_sexp

  let of_text text = text |> Text.to_utf8_bytes |> String.strip |> create
end

let call_exn
      ?input
      ?working_directory
      ?(strip_whitespace = true)
      ?(verbose_exn = true)
      prog
      args
  =
  Current_buffer.set_temporarily_to_temp_buffer (fun () ->
    match
      call_result_exn
        prog
        args
        ?input
        ?working_directory
        ~output:Before_point_in_current_buffer
    with
    | Exit_status 0 ->
      let buffer_contents = Current_buffer.contents () |> Text.to_utf8_bytes in
      if strip_whitespace then String.strip buffer_contents else buffer_contents
    | result ->
      let output = Current_buffer.contents () |> Lines_or_sexp.of_text in
      (match verbose_exn with
       | true ->
         raise_s
           [%message
             "[Process.call_exn] failed"
               (prog : string)
               (args : string list)
               (result : Call.Result.t)
               (output : Lines_or_sexp.t)]
       | false -> raise_s [%sexp (output : Lines_or_sexp.t)]))
;;

let call_expect_no_output_exn
      ?input
      ?working_directory
      ?(strip_whitespace = false)
      ?verbose_exn
      prog
      args
  =
  let result =
    call_exn ?input ?working_directory ?verbose_exn ~strip_whitespace prog args
  in
  if String.is_empty result
  then ()
  else
    raise_s
      [%message
        "[Process.call_expect_no_output_exn] produced unexpected output"
          (prog : string)
          (args : string list)
          (result : string)
          ~output:(Current_buffer.contents () |> Lines_or_sexp.of_text : Lines_or_sexp.t)]
;;

let bash = "/bin/bash"

let shell_command_result ?input ?output ?redisplay_on_output ?working_directory command =
  call_result_exn
    bash
    [ "-c"; command ]
    ?input
    ?output
    ?redisplay_on_output
    ?working_directory
;;

let shell_command_exn ?input ?working_directory ?verbose_exn command =
  call_exn bash [ "-c"; command ] ?input ?working_directory ?verbose_exn
;;

let shell_command_expect_no_output_exn ?input ?working_directory ?verbose_exn command =
  call_expect_no_output_exn bash [ "-c"; command ] ?input ?working_directory ?verbose_exn
;;
