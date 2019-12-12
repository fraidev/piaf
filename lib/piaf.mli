module Config : sig
  type t =
    { follow_redirects : bool  (** whether to follow redirects *)
    ; max_redirects : int
          (** max redirects to follow. Could probably be rolled up into one
              option *)
    ; allow_insecure : bool
          (** Wether to allow insecure server connections when using SSL *)
    ; max_http_version : Versions.HTTP.t
          (** Use this as the highest HTTP version when sending requests *)
    ; h2c_upgrade : bool
          (** Send an upgrade to `h2c` (HTTP/2 over TCP) request to the server.
              `http2_prior_knowledge` below ignores this option. *)
    ; http2_prior_knowledge : bool
          (** Assume HTTP/2 prior knowledge -- don't use HTTP/1.1 Upgrade when
              communicating with "http" URIs, default to HTTP/2.0 when we can't
              agree to an ALPN protocol and communicating with "https" URIs. *)
    ; cacert : string option
          (** The path to a CA certificates file in PEM format *)
    ; capath : string option
          (** The path to a directory which contains CA certificates in PEM
              format *)
    }

  val default_config : t
end

module Response : sig
  type t =
    { (* `H2.Status.t` is a strict superset of `Httpaf.Status.t` *)
      status : H2.Status.t
    ; headers : H2.Headers.t
    ; version : Versions.HTTP.t
    }

  val persistent_connection : t -> bool

  val pp_hum : Format.formatter -> t -> unit [@@ocaml.toplevel_printer]
end

(** {2 Client -- Issuing requests} *)

(** There are two options for issuing requests with Piaf:

    + client: useful if multiple requests are going to be sent to the remote
      endpoint, avoids setting up a TCP connection for each request.
    + oneshot: issues a single request and tears down the underlying connection
      once the request is done. Useful for isolated requests. *)

module Client : sig
  type t

  val create : ?config:Config.t -> Uri.t -> (t, string) Lwt_result.t
  (** [create ?config uri] opens a connection to [uri] (initially) that can be
      used to issue multiple requests to the remote endpoint. *)

  val head
    :  t
    -> ?headers:(string * string) list
    -> string
    -> (Response.t * string Lwt_stream.t, string) Lwt_result.t

  val get
    :  t
    -> ?headers:(string * string) list
    -> string
    -> (Response.t * string Lwt_stream.t, string) Lwt_result.t

  val post
    :  t
    -> ?headers:(string * string) list
    -> string
    -> (Response.t * string Lwt_stream.t, string) Lwt_result.t

  val put
    :  t
    -> ?headers:(string * string) list
    -> string
    -> (Response.t * string Lwt_stream.t, string) Lwt_result.t

  val patch
    :  t
    -> ?headers:(string * string) list
    -> string
    -> (Response.t * string Lwt_stream.t, string) Lwt_result.t

  val delete
    :  t
    -> ?headers:(string * string) list
    -> string
    -> (Response.t * string Lwt_stream.t, string) Lwt_result.t

  val request
    :  t
    -> ?headers:(string * string) list
    -> meth:Method.t
    -> string
    -> (Response.t * string Lwt_stream.t, string) Lwt_result.t

  val shutdown : t -> unit
  (** [shutdown t] tears down the connection [t] and frees up all the resources
      associated with it. *)

  module Oneshot : sig
    val head
      :  ?config:Config.t
      -> ?headers:(string * string) list
      -> Uri.t
      -> (Response.t * string Lwt_stream.t, string) Lwt_result.t

    val get
      :  ?config:Config.t
      -> ?headers:(string * string) list
      -> Uri.t
      -> (Response.t * string Lwt_stream.t, string) Lwt_result.t

    val post
      :  ?config:Config.t
      -> ?headers:(string * string) list
      -> Uri.t
      -> (Response.t * string Lwt_stream.t, string) Lwt_result.t

    val put
      :  ?config:Config.t
      -> ?headers:(string * string) list
      -> Uri.t
      -> (Response.t * string Lwt_stream.t, string) Lwt_result.t

    val patch
      :  ?config:Config.t
      -> ?headers:(string * string) list
      -> Uri.t
      -> (Response.t * string Lwt_stream.t, string) Lwt_result.t

    val delete
      :  ?config:Config.t
      -> ?headers:(string * string) list
      -> Uri.t
      -> (Response.t * string Lwt_stream.t, string) Lwt_result.t

    val request
      :  ?config:Config.t
      -> ?headers:(string * string) list
      -> meth:Method.t
      -> Uri.t
      -> (Response.t * string Lwt_stream.t, string) Lwt_result.t
    (** Use another request method. *)
  end

  (* (Httpaf.Response.t * (string, 'a) result) Lwt.t *)
end

module Method : module type of Method

module Headers : module type of struct
  include H2.Headers
end

module Scheme : sig
  type t =
    | HTTP
    | HTTPS

  val of_uri : Uri.t -> (t, string) result

  val to_string : t -> string

  val pp_hum : Format.formatter -> t -> unit [@@ocaml.toplevel_printer]
end

module Status : module type of struct
  include H2.Status
end

module Versions : sig
  module HTTP : sig
    include module type of struct
      include Httpaf.Version
    end

    val v1_0 : t

    val v1_1 : t

    val v2_0 : t
  end

  module ALPN : sig
    type nonrec t =
      | HTTP_1_0
      | HTTP_1_1
      | HTTP_2

    val of_version : HTTP.t -> t option

    val to_version : t -> HTTP.t

    val of_string : string -> t option

    val to_string : t -> string
  end
end
