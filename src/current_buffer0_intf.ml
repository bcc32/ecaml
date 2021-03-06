open! Core_kernel
open! Import0

module type Current_buffer0_public = sig
  (** [(describe-function 'current-buffer)] *)
  val get : unit -> Buffer0.t

  (** [(describe-function 'set-buffer)] *)
  val set : Buffer0.t -> unit

  (** [set_temporarily t ~f] runs [f] with the current buffer set to [t].
      [(describe-function 'with-current-buffer)]. *)
  val set_temporarily : Buffer0.t -> f:(unit -> 'a) -> 'a

  (** [(describe-function 'symbol-value)] *)
  val symbol_value : Symbol.t -> Value.t

  (** [(describe-function 'symbol-value)   ] *)
  val value : 'a Var.t -> 'a option

  (** [(describe-function 'symbol-value)   ] *)
  val value_exn : 'a Var.t -> 'a

  (** [value_opt_exn] is like [value_exn], except that it raises if the variable is
      defined but [None].  This is useful for buffer-local variables of type ['a option],
      with a default value of nil. *)
  val value_opt_exn : 'a option Var.t -> 'a

  (** [(describe-function 'set)]. *)
  val set_value : 'a Var.t -> 'a -> unit

  val set_values : Var.And_value.t list -> unit

  (** [(describe-function 'makunbound)] *)
  val clear_value : 'a Var.t -> unit

  val set_value_temporarily : 'a Var.t -> 'a -> f:(unit -> 'b) -> 'b
  val set_values_temporarily : Var.And_value.t list -> f:(unit -> 'a) -> 'a

  (** [(describe-function 'bound-and-true-p]. *)
  val has_non_null_value : _ Var.t -> bool
end

module type Current_buffer0 = sig
  include Current_buffer0_public

  module Q : sig
    include module type of Q

    val boundp : Symbol.t
    val current_buffer : Symbol.t
    val makunbound : Symbol.t
    val set_buffer : Symbol.t
  end
end
