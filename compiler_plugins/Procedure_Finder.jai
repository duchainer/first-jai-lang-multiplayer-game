/*
Taken from The Secret Beta Discord: https://discord.com/channels/661732390355337246/1320851611920105646/1498359114965979226

plugin that gives you IDE-style "dot completion"

The way you use it is a bit strang, but it works!
Let's say you have a variable sb of type String_Builder and want to find
all "methods" that work on a String_Builder. You would activate the plugin by doing:

_ := sb;@.

If the plugin detects this "pattern" (a declaration followed by the completion_note (defaults to .)
it will report all possible procedures that take that type and print them in a copy paste friendly way:

jai/modules/Basic/float_to_string.jai:4,20:   stb_print_float(*sb, FormatFloat) -> (s64)
jai/modules/Basic/String_Builder.jai:49,24:   init_string_builder(*sb, s64) -> ()
jai/modules/Basic/String_Builder.jai:65,17:   free_buffers(*sb) -> ()
jai/modules/Basic/String_Builder.jai:77,10:   reset(*sb) -> ()
jai/modules/Basic/String_Builder.jai:85,28:   ensure_contiguous_space(*sb, s64) -> (*void)
jai/modules/Basic/String_Builder.jai:97,55:   ensure_contiguous_space_and_return_available_range(*sb, s64) -> ([] u8)
jai/modules/Basic/String_Builder.jai:118,34:  advance_through_ensured_space(*sb, s64) -> ()
jai/modules/Basic/String_Builder.jai:138,11:  append(*sb, *u8, s64) -> ()
jai/modules/Basic/String_Builder.jai:172,18:  append(*sb, string) -> ()
jai/modules/Basic/String_Builder.jai:176,18:  append(*sb, u8) -> ()
.... etc

*/

get_plugin :: () -> *Metaprogram_Plugin { return New(Procedure_Finder_Plugin); }

Procedure_Finder_Plugin :: struct {
    #as using base: Metaprogram_Plugin;
    completion_note := "."; // trigger search by doing  _ := value_you_want_to_autocomplete; @.
    headers: [..]*Code_Procedure_Header;
    query: struct {
        text: string;
        type: *Type_Info;
        loc: Source_Code_Location;
    };
    init = (p: *Metaprogram_Plugin, options: [] string) -> bool {
        using p.(*Procedure_Finder_Plugin);
        if !options return true;
        found, index := array_find(options, "-completion_note");
        if !found {
            log_error("Unrecognized options `%`", options);
            return false;
        }
        if index == options.count-1 {
            log_error("Expected note text after option `%`", options[index]);
            return false;
        }
        completion_note = options[index+1];
        return true;
    }
    message = (p: *Metaprogram_Plugin, m: *Message) {
        using p.(*Procedure_Finder_Plugin);
        if m.kind == {
        case .TYPECHECKED; {
            typechecked := m.(*Message_Typechecked);
            for typechecked.procedure_headers if it.expression.name then array_add(*headers, it.expression);
            
            if !query.type
            for body: typechecked.procedure_bodies
            for stmt: body.expression.block.statements
            if  stmt.kind == .DECLARATION
            for note: stmt.(*Code_Declaration).notes
            if  note.text == completion_note {
                sb: String_Builder;
                expr := stmt.(*Code_Declaration).expression;
                print_expression(*sb, expr);
                query = {
                    builder_to_string(*sb),
                    expr.type,
                    make_location(expr)
                };
            }
        }
        case .PHASE; {
            phase := m.(*Message_Phase);
            if phase.phase != .ALL_TARGET_CODE_BUILT return;
            if !query.type return;
            
            push_allocator(temp);
            
            longest_location := 0;
            matches: [..]struct {
                location: string;
                procedure: string;
            };
            
            sb: String_Builder;
            if query.type {
                for header: headers {
                    type  := header.type.(*Type_Info_Procedure);
                    match := NewArray(type.argument_types.count, enum { NONE; EXACT; REF; DEREF; });
                    for type.argument_types {
                        if it == query.type {
                            match[it_index] = .EXACT;
                            continue;
                        }
                        
                        if query.type.type == .POINTER && query.type.(*Type_Info_Pointer).pointer_to == it {
                            match[it_index] = .DEREF;
                            continue;
                        }
                        
                        if it.type == .POINTER && it.(*Type_Info_Pointer).pointer_to == query.type {
                            match[it_index] = .REF;
                            continue;
                        }
                    }
                    
                    has_match := false;
                    for match if it != .NONE has_match = true;
                    if !has_match continue;
                    
                    m := array_add(*matches);
                    print(*sb, "%:%,%:",
                        header.enclosing_load.fully_pathed_filename,
                        header.l0,
                        header.c0
                    );
                    m.location = builder_to_string(*sb);
                    if   m.location.count > longest_location
                    then longest_location = m.location.count;
                    
                    append(*sb, header.name);
                    append(*sb, "(");
                    for type.argument_types {
                        if it_index append(*sb, ", ");
                        if #complete match[it_index] == {
                        case .NONE;  print_item_to_builder(*sb, get_type(it));
                        case .EXACT; append(*sb, query.text);
                        case .REF;   print(*sb, "*%", query.text);
                        case .DEREF; print(*sb, "%.*", query.text);
                        }
                    }
                    append(*sb, ") -> (");
                    
                    for type.return_types {
                        if it_index append(*sb, ", ");
                        print_item_to_builder(*sb, get_type(it));
                    }
                    append(*sb, ")\n");
                    m.procedure = builder_to_string(*sb);
                }
            }
            
            print(*sb, "% completions for type %: \n", matches.count, get_type(query.type));
            for matches {
                append(*sb, it.location);
                for 0..longest_location - it.location.count append(*sb, " ");
                append(*sb, it.procedure);
            }
            
            
            compiler_report(builder_to_string(*sb), loc=query.loc, mode=.INFO);
            compiler_set_workspace_status(.FAILED, workspace);
        }
        }
    }
}

#import "Basic";
#import "Compiler";
#import "Program_Print";
