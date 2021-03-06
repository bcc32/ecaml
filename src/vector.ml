open! Core_kernel
open! Import

module Q = struct
  include Q

  let make_vector = "make-vector" |> Symbol.intern
  and vconcat = "vconcat" |> Symbol.intern
end

include Value.Make_subtype (struct
    let name = "vector"
    let here = [%here]
    let is_in_subtype = Value.is_vector
  end)

let create ~len value =
  Symbol.funcall2 Q.make_vector (len |> Value.of_int_exn) value |> of_value_exn
;;

let length t = Symbol.funcall1 Q.length (t |> to_value) |> Value.to_int_exn

let bounds_check t i name =
  let length = length t in
  if i < 0 || i >= length
  then
    raise_s
      [%message
        (concat [ "[Vector."; name; "] got invalid subscript" ])
          ~subscript:(i : int)
          (length : int)
          ~vector:(t : t)]
;;

let get t i =
  bounds_check t i "get";
  Symbol.funcall2 Q.aref (t |> to_value) (i |> Value.of_int_exn)
;;

let set t i v =
  bounds_check t i "set";
  Symbol.funcall3_i Q.aset (t |> to_value) (i |> Value.of_int_exn) v
;;

let of_list vs = Symbol.funcallN Q.vector vs |> of_value_exn
let concat ts = Symbol.funcallN Q.vconcat (ts : t list :> Value.t list) |> of_value_exn
let to_array t ~f = Array.init (length t) ~f:(fun i -> get t i |> f)

let type_ (type a) (type_ : a Value.Type.t) =
  Value.Type.create
    [%message "vector" ~_:(type_ : _ Value.Type.t)]
    (sexp_of_array (Value.Type.to_sexp type_))
    (fun v -> v |> of_value_exn |> to_array ~f:(Value.Type.of_value_exn type_))
    (fun a ->
       a
       |> Array.map ~f:(Value.Type.to_value type_)
       |> Array.to_list
       |> of_list
       |> to_value)
;;
