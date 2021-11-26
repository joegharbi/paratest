-module(para).
-export([bucket_sort/1,pany/2,multi/3,fib/1]).

pany(F,List)->
    MainPid=self(),
    Pids=[spawn(fun() -> MainPid ! {lists:any(F,[E]),E} end) || E <- List],
    giveme(Pids).

giveme(P)->
    if length(P)==0->
        false;
    true->
    receive
        {true,E}->
            {true,E};
        {false,_}->
            giveme(tl(P))
    end
end.

bucket_sort([])->
    [];
bucket_sort(List) when length(List)==1->
    List;
bucket_sort(List)->
    MainPid=self(),
    Bucket1=[E||E<-List,E<(lists:sum(List) / length(List))],
    Bucket2=[E||E<-List,E>=(lists:sum(List) / length(List))],
      
    Pid1= spawn(fun()-> MainPid ! {self(),bucket_sort(Bucket1)} end), 
    Pid2=spawn(fun()-> MainPid ! {self(),bucket_sort(Bucket2)} end),
    
    receive
    {Pid1,Val}->
    receive
        {Pid2,Val2}->Val++Val2
    end
    end.
    

spowner(_, [], [])->
    [];
    spowner(_,_,[])->
    [];
    spowner(_,[],_)->
    [];
spowner(F,L1,L2)->
    MainPid= self(),
    [spawn_monitor(fun() -> MainPid ! {self(),F(hd(L1),hd(L2))} end)|spowner(F,tl(L1),tl(L2))].
multi(F,L1,L2)->
    Pidsnref=spowner(F, L1, L2),
    Pids=[element(1, P)||P<-Pidsnref],
    getval (Pids).
getval(P)->
    [receive
        {Pid,Val}->Val;
        {_,_,_,_,{Reason,_}} when Reason /=normal ->
            {'EXIT',Reason}
    end|| Pid<-P].



fib(N)->
    C=whereis(cache),
    if  C == undefined ->
            register(cache,spawn(fun() -> cache([]) end)),
            pfib(N);
        true->
            pfib(N) 
    end.

cache(L)->
    receive
        {to_add,S}->
            Find=lists:keyfind(S,1, L),
            if Find ==false->
                    T=lists:append(L,[S]),
                    cache(T);
                true->
                    cache(L)
            end;
        {give_me,E,From}->
            From ! {get_this,lists:keyfind(E,1, L)},
            cache(L)
    end.

pfib(0) -> 1;
pfib(1) -> 1;
pfib(N) ->
    Main = self(),
    cache ! {give_me,N,Main},
    receive
        {get_this,false}->
            spawn(fun() -> Main ! pfib(N-1) end),
            spawn(fun() -> Main ! pfib(N-2) end),
            receive
                Val1 ->
                    receive
                        Val2 -> E=Val1+Val2,
                        cache ! {to_add,{N,E}},
                        E
                    end
                end;
        {get_this,V}->
            {_,S}=V,
            S
    end.
