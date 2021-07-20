(* XML escape extracted here to avoid dependency cycle:
   CilType -> Goblintutil -> GobConfig -> Tracing -> Node -> CilType *)

let escape (x:string):string =
  (* Safe to escape all these everywhere in XML: https://stackoverflow.com/a/1091953/854540 *)
  String.escaped x |>(* Needed to escape byte sequences that are not valid utf8 code points *)
  Str.global_replace (Str.regexp "&") "&amp;" |>
  Str.global_replace (Str.regexp "<") "&lt;" |>
  Str.global_replace (Str.regexp ">") "&gt;" |>
  Str.global_replace (Str.regexp "\"") "&quot;" |>
  Str.global_replace (Str.regexp "'") "&apos;" |>
  Str.global_replace (Str.regexp "[\x0b\001\x0c\x0f\x0e]") "" (* g2html just cannot handle from some kernel benchmarks, even when escaped... *)
