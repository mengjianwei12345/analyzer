(** This is the main program! *)

module CF = Cilfacade
module GU = Goblintutil
module JB = Json_type.Browse
module M = Messages

let main () =
  let usage_str = "Usage: goblint [options] source-files" in
  let fileNames : string list ref = ref [] in
  (* default settings for the command line arguments: *)
  let myname = Filename.dirname Sys.executable_name in
  let include_dir = ref (Filename.concat myname "includes") in 
(*  let kernel_root = "/lib/modules/`uname -r`/build" in*)
  let kernel_root = Filename.concat myname "../linux-headers" in
  let kernel_dir = kernel_root ^ "/include" in
  let asm_dir = kernel_root ^ "/arch/x86/include" in
  let other_includes = ref "" in
  let add_include x = other_includes := "-I " ^ x ^ " " ^ !other_includes in
  let add_include_kernel x = other_includes := "-I " ^ Filename.concat kernel_root x ^ " " ^ !other_includes in
  let use_libc = ref false in
  let justCil = ref false in
  let dopartial = ref false in
  let keep_cpp = ref false in
  let cppflags = ref "" in
  let outFile = ref "" in 
  let cilout = ref stderr in
  (* Function for setting the style, basically Haskell's read function: *)
  let setstyle x = 
    GU.result_style := match x with
      | "none" -> GU.NoOutput
      | "state" -> GU.State
      | "indented" -> GU.Indented
      | "compact" -> GU.Compact
      | "pretty" -> GU.Pretty
      | _ -> raise (Arg.Bad "invalid result style") 
  in
  let setdump path = GU.dump_path := Some (GU.create_dir path) in
  let add_exitfun f = GU.exitfun := f :: !GU.exitfun in
  let setcil path = cilout := open_out path in
  let analyzer str = (*legacy: use .json, --with and --no instead *)
      MCP.Analysis.analyze   
  in
  let analyze = ref (analyzer (JB.string (JB.field !GU.conf "analysis"))) in
  let oil file = (*GU.allfuns := true;*) GU.oil := true; GU.conf_osek (); Osek.Spec.oilFile := file in
  let setanalysis str = 
    begin match str with
            | "containment" -> GU.conf_containment ()
            | "uninit" -> GU.conf_uninit ()
            | "malloc_null" -> GU.conf_malloc ()
            | "osek" -> GU.conf_osek ()
            | _ -> ()
    end;
    analyze := analyzer str 
  in
  let set_feature b x =
    match x with
      | x when List.exists (fun y -> y.MCP.featurename = x) !MCP.analysesList
          -> GU.modify_ana x b
      | _ -> raise (Arg.Bad ("no such feature: "^x))
  in
  let setsolver str = 
    GU.solver := match str with
      | "effectWCon"
      | "solverConSideRR"
      | "solverConSideWNRR"
      | "effectWNCon" -> str
      | _ -> raise (Arg.Bad "no such solver")
  in
  let set_trace sys = 
    if M.tracing then Trace.traceAddMulti sys
    else (prerr_endline "Goblin has been compiled without tracing, run ./trace_on to recompile."; exit 2)
  in
  let speclist = [
                 ("-o", Arg.Set_string outFile, "<file>  Prints the output to file.");
                 ("-v", Arg.Set GU.verbose, " Prints some status information.");
                 ("-I", Arg.String add_include,  " Add include directory.");
                 ("-IK", Arg.String add_include_kernel,  " Add kernel include directory.");
                 ("--includes", Arg.Set_string include_dir, " Uses custom include files.");
                 ("--libc", Arg.Set use_libc, " Merge with a custom implementation of standard libs.");
                 ("--justcil", Arg.Set justCil, " Just print the transformed CIL output.");
                 ("--dopartial", Arg.Set dopartial, " Apply CIL's constant folding and partial evaluation.");
                 ("--cfg", Arg.Set GU.cfg_print, " prints the cfg into cfg.dot.");
                 ("--debug", Arg.Set GU.debug, " Debug mode: for testing the analyzer itself.");
                 ("--warnings", Arg.Set M.warnings, " Print soundness warnings.");
                 ("--trace", Arg.String set_trace, "<sys>  subsystem to show debug printfs for: con, sol.");
                 ("--stats", Arg.Set Cilutil.printStats, " Outputs timing information.");
                 ("--eclipse", Arg.Set GU.eclipse, " Flag for Goblin's Eclipse Plugin.");
                 ("--gccwarn", Arg.Set GU.gccwarn, " Output warnings in GCC format.");
                 ("--allfuns", Arg.Set GU.allfuns, " Analyzes all the functions (not just beginning from main).");
				 ("--noverify", Arg.Clear GU.verify, " Skip the verification phase.");
                 ("--class", Arg.Set_string GU.mainclass, " Analyzes all the member functions of the class (CXX.json file required).");
                 ("--nonstatic", Arg.Set GU.nonstatic, " Analyzes all non-static functions.");
                 ("--mainfun", Arg.Set_string GU.mainfun, " Sets the name of the main function.");
                 ("--exitfun", Arg.String add_exitfun, " Sets the name of the main function.");
                 ("--allglobs", Arg.Set GU.allglobs, " Prints access information about all globals, not just races.");
                 ("--earlyglobs", Arg.Set GU.earlyglobs, " Side-effecting of globals right after initialization.");
                 ("--write-races", Arg.Set Mutex.no_read, " Ignores read accesses altogether in reporting races.");
                 ("--failing-locks", Arg.Set Mutex.failing_locks, " Takes the possible failing of locking operations into account.");
                 ("--field-insensitive", Arg.Set Mutex.field_insensitive, " Turns off field-sensitivity.");
                 ("--unmerged-fields", Arg.Set Mutex.unmerged_fields, " Does not merge accesses to possibly same fields, unsound.");
                 ("--die-on-collapse", Arg.Set GU.die_on_collapse, " Raise an exception as soon as an array collapses.");
                 ("--keepcpp", Arg.Set keep_cpp, " Keep the intermediate output of running the C preprocessor.");
                 ("--cppflags", Arg.Set_string cppflags, "<flags>  Pre-processing parameters.");
                 ("--kernel", Arg.Set GU.kernel, "For analyzing Linux Device Drivers.");
                 ("--showtemps", Arg.Set CF.showtemps, " Shows CIL's temporary variables when printing the state.");
                 ("--uncalled", Arg.Set GU.print_uncalled, " Display uncalled functions.");
                 ("--result", Arg.String setstyle, "<style>  Result style: none, state, indented, compact, or pretty.");
                 ("--analysis", Arg.String setanalysis, "<name>  Deprecated: Picks the analysis: mcp.");
                 ("--with", Arg.String (set_feature true), "<name>  Enables features:" ^ List.fold_left (fun xs x -> xs ^ " " ^ x.MCP.featurename) "" !MCP.analysesList^".");
                 ("--no", Arg.String (set_feature false), "<name>  Disables features:" ^ List.fold_left (fun xs x -> xs ^ " " ^ x.MCP.featurename) "" !MCP.analysesList^".");
                 ("--solver", Arg.String setsolver, "<name>  Picks the solver: effectWCon, effectWNCon, solverConSideRR, solverConSideWNRR.");
                 ("--dump", Arg.String setdump, "<path>  Dumps the results to the given path");
                 ("--cilout", Arg.String setcil, "<path>  Where to dump cil output");
		 ("--oil", Arg.String oil, "<file>  Oil file for the analysed program");
                 ("--intrpts", Arg.Set GU.intrpts, " Enable constraints for interrupts.");
                 ] in
  let jsonRegex = Str.regexp ".+\\.json$" in
  let recordFile fname = 
    if Str.string_match jsonRegex fname 0
    then GU.jsonFiles := fname :: !GU.jsonFiles 
    else fileNames := fname :: !fileNames
  in
  (* The temp directory for preprocessing the input files *)
  let dirName = GU.create_dir "goblin_temp" in
  Stats.reset Stats.HardwareIfAvail;  
  CF.init();
  Arg.parse speclist recordFile usage_str;
  if !GU.allfuns || !GU.nonstatic || !GU.oil then GU.multi_threaded := true;
  if !GU.debug then M.warnings := true;
  (* GU.regions := true; *)
  let _ = match !GU.dump_path with
    | Some path -> begin
        M	.warn_out := open_out (Filename.concat path "warnings.out");
        outFile := "" (*Filename.concat path "analysis.out";*)
        (* --dump overwrites the -o flag*)
      end
    | _ -> ()
  in
  (* The include files, libc stuff  *)
  let warn_includes () = print_endline "Warning, cannot find goblin's custom include files." in
  let includes = ref (if Sys.file_exists(!include_dir) then "-I" ^ !include_dir else (warn_includes () ; "")) in
  let _ = includes := !includes ^ " " ^ !other_includes in
  let libc = Filename.concat !include_dir "lib.c" in 
  fileNames := List.rev !fileNames;
  if !use_libc then fileNames := libc :: !fileNames;
  if !GU.kernel then begin
    let preconf = Filename.concat !include_dir "linux/goblint_preconf.h" in 
    let autoconf = Filename.concat kernel_dir "generated/autoconf.h" in 
    cppflags := "-D__KERNEL__ -U__i386__ -include " ^ preconf ^ " -include " ^ autoconf ^ " " ^ !cppflags;
    includes := !includes ^ " -I" ^ kernel_dir ^ " -I" ^ asm_dir ^ " -I" ^ asm_dir ^ "/asm/mach-default"
  end;
  (* preprocess all the files *)
  let preproFile fname =
    (* The actual filename of the preprocessed sourcefile *)
    let nname =  Filename.concat dirName (Filename.basename fname) in 
    (* Preprocess using gcc -E *)
    let command = "gcc --undef __BLOCKS__ -E " ^ !cppflags ^ " " ^ !includes ^ " " ^ fname ^ " -o " ^ nname in
      if !GU.verbose then print_endline command;
      ignore (Unix.system command);  (* MAYBE BAD IDEA to ingore! *)
      nname
  in
  let cpp_file_names = 
    if !GU.verbose then print_endline "Preprocessing files.";
    List.map preproFile !fileNames in
  (* and get their AST *)
  let files_AST = 
    if !GU.verbose then print_endline "Parsing files.";
    List.map CF.getAST cpp_file_names in
  let _ = if !keep_cpp then () else ignore (GU.rm_rf dirName) in
  (* direct the output to file if requested  *)
  let _ = if not (!outFile = "") then GU.out :=  open_out !outFile in
  let _ = Errormsg.logChannel := M.get_out "cil" !cilout in
  (* we use CIL to merge all inputs to ONE file *)
  let merged_AST = 
    match files_AST with
      | [one] -> one
      | [] -> 
          prerr_endline "No arguments for Goblint?"; 
          prerr_endline usage_str; 	  
          prerr_endline "Try `goblint --help' for more information."; 
          exit 2
      | xs -> CF.getMergedAST xs 
  in
    (* using CIL's partial evaluation and constant folding! *)
    if !dopartial then CF.partial merged_AST;
    CF.rmTemps merged_AST;
    (* creat the Control Flow Graph from CIL's AST *)
    CF.createCFG merged_AST;
    CF.ugglyImperativeHack := merged_AST;
    (* we let the "--eclipse" flag override result style: *)
    if !GU.eclipse then GU.result_style := GU.Compact;
    if !justCil then 
      (* if we only want to print the output created by CIL: *)
      CF.print merged_AST
    else begin
      (* we first find the functions to analyze: *)
      if !GU.verbose then print_endline "And now...  the Goblin!";
      let funs = CF.getFuns merged_AST in
        if funs = [] then failwith "No suitable function to start from.";
        (* and here we run the analysis! *)
        Stats.time "analysis" (!analyze merged_AST) funs;
        if !Cilutil.printStats then 
        begin
          flush_all ();
          prerr_endline "Solver stats:";
          prerr_endline ("  globals changed "^string_of_int !Goblintutil.globals_changed^" times");
          Stats.print (M.get_out "timing" stderr) "Timings:\n"
        end
    end

let _ = 
  main ()
