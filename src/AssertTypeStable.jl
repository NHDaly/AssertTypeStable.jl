module AssertTypeStable

using InteractiveUtils
using Cthulhu

export @assert_typestable, @istypestable

macro assert_typestable(ex0...)
    InteractiveUtils.gen_call_with_extracted_types_and_kwargs(__module__, :assert_typestable, ex0)
end

function assert_typestable(@nospecialize(F), @nospecialize(TT); kwargs...)
    # ============ Recurse into its children FIRST (so we get a bottom-up walk?) ================

    # ----- Copied from Cthulhu ---------
    methods = code_typed(F, TT; kwargs...)
    if isempty(methods)
        println("$(string(Callsite(-1 ,F, TT, Any))) has no methods")
    return
    end
    CI, rt = first(methods)
    callsites = Cthulhu.find_callsites(CI, TT; kwargs...)
    # ----- /Copied from Cthulhu -------Symbol--

    # Recurse
    for callsite in callsites
        assert_typestable(callsite.f, callsite.tt; kwargs...)
    end

    # ============ Then check this method. ==========================
    code_assertstable(F, TT)

end

@enum TypeStability stable=1 expected_union=2 unstable=3

# Copied from code_warntype:
function code_assertstable(@nospecialize(f), @nospecialize(t); debuginfo::Symbol=:default)
    for (src, rettype) in code_typed(f, t)
        stability = assert_type_type_checker(rettype)
        make_typestring(t) = join(["::$_t" for _t in t.parameters], ", ")
        if stability == unstable
            typestring = make_typestring(t)
            @warn "Type instability encountered in $f($typestring). Printing `@code_warntype $f($typestring)`:"
            code_warntype(f,t)
            throw(AssertionError("type-instability: $rettype"))
        elseif stability == expected_union
            typestring = make_typestring(t)
            @warn "Encountered expected small-union type in $f($typestring): $rettype"
        end
    end
    nothing
end

function assert_type_type_checker(@nospecialize(ty))
    if ty isa Type && (!Base.isdispatchelem(ty) || ty == Core.Box)
        if ty isa Union && Base.is_expected_union(ty)
            return expected_union
        else
            return unstable
        end
    else
        return stable
    end
end

macro istypestable(ex0...)
    esc(quote
        try
            @assert_typestable $(ex0...)
        catch e
            if e isa AssertionException
                return false
            end
        end
        return true
    end)
end

end
