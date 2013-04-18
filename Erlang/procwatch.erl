-module(procwatch).
%-export([list_current_procs/0, list_new_procs/2, get_process_name/1,
%  process_check/2, checker/1, foo/0]).
-compile(export_all).

list_current_procs() ->
  {_, Procs} = file:list_dir("/proc"),
  Procs.

list_new_procs(OldProcs, NewProcs) ->
  NewProcs -- OldProcs.

get_process_name(Proc) ->
  {_, Exe} = file:read_link("/proc/" ++ Proc ++ "/exe"),
  Exe.


il(Num) ->
  integer_to_list(Num).

formatted_time() ->
  {{Year, Month, Day}, {Hour, Min, Sec}} = calendar:local_time(),
  [il(Year) ++ "/" ++ il(Month) ++ "/" ++  il(Day) ++ " " ++ il(Hour) ++ ":" ++ il(Min) ++ ":" ++ il(Sec)].

show_new_procs([]) ->
  ok;
show_new_procs([H|T]) ->
  Exe = get_process_name(H),
  Uid = grab_uid_from_file("/proc/" ++ H),
  display_proc(Uid, Exe),
  show_new_procs(T),
  ok.

display_proc(_, enotdir) ->
  ok;
display_proc(_, enoent) ->
  ok;
display_proc(Uid, Exe) ->
  io:format("~s: ~b ~s~n", [formatted_time(), Uid, Exe]).

process_check(OldProcs, CurrentProcs) ->
    NewProcs = list_new_procs(OldProcs, CurrentProcs),
    show_new_procs(NewProcs),
    NewProcs ++ OldProcs.

pull_uid_from_stats(Stats) -> 
    element(13, element(2, Stats)).

grab_uid_from_file(enotdir) ->
  "[NODIR]";
grab_uid_from_file(eacces) ->
  "[Access Error]";
grab_uid_from_file(enoent) ->
  io:format("the enoent block~n"),
  "[KERNEL]";
grab_uid_from_file(Filename) ->
    Stats = file:read_file_info(Filename),
    pull_uid_from_stats(Stats).

checker() ->
  receive 
    stop ->
      io:format("shutting down...~n"),
      ok;
    {check, Lpid, ProcList}  ->
      NewProcs = list_current_procs(),
      CurrentProcs = process_check(ProcList, NewProcs),
      Lpid ! {got, CurrentProcs},
      checker();
    Oops ->
      io:format("Barfing: ~s~n", [Oops])
  end.

looper(MyPid, CheckerPid) ->
  receive 
    {start, SelfPid, CheckPid} ->
      CheckPid ! {check, SelfPid, []},
      looper(SelfPid, CheckPid);
    {got, NewList} ->
      timer:sleep(5000),
      CheckerPid ! {check, MyPid, NewList},
      looper(MyPid, CheckerPid);
    Oops ->
      io:format("Looper-Barfing: ~s~n", [Oops])
  end.

     
kick_start() ->
  Cpid = spawn(procwatch, checker, []),
  Lpid = spawn(procwatch, looper, [Cpid, Cpid]),
  Lpid ! {start, Lpid, Cpid}.

