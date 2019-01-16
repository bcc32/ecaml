open! Core_kernel
open! Import

module Q = struct
  let defconst = "defconst" |> Symbol.intern
end

let defconst_i symbol here ~docstring (type_ : _ Value.Type.t) initial_value =
  Load_history.add_entry here (Var symbol);
  Form.list
    [ Form.symbol Q.defconst
    ; Form.symbol symbol
    ; Form.quote (type_.to_value initial_value)
    ; Form.string (docstring |> String.strip)
    ]
  |> Form.eval_i
;;

let defconst symbol here ~docstring type_ initial_value =
  defconst_i symbol here ~docstring type_ initial_value;
  Var.create symbol type_
;;